// Thawani Pay per-restaurant gateway.
// Actions (POST JSON):
//   connect  { restaurant_id, mode, publishable_key, secret_key }   (owner, Authorization: Bearer <user JWT>)
//   checkout { order_id, token, origin }                             (customer)
//   verify   { order_id, token }                                     (customer / order page)
import { createClient } from "npm:@supabase/supabase-js@2";

const BASE = { test: "https://uatcheckout.thawani.om", live: "https://checkout.thawani.om" } as const;
const ALLOWED_ORIGINS = ["https://drivemenu.app", "https://www.drivemenu.app", "https://drivemenu.vercel.app"];
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
const fail = (code: string, status = 400) => json({ error: code }, status);

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

async function thawani(mode: "test" | "live", secret: string, path: string, init: RequestInit = {}) {
  const res = await fetch(BASE[mode] + "/api/v1" + path, {
    ...init,
    headers: { "Content-Type": "application/json", "thawani-api-key": secret, ...(init.headers || {}) },
  });
  let body: any = null;
  try { body = await res.json(); } catch { /* ignore */ }
  return { ok: res.ok && body && body.success !== false, status: res.status, body };
}

async function createSession(mode: "test" | "live", secret: string, payload: Record<string, unknown>) {
  return thawani(mode, secret, "/checkout/session", { method: "POST", body: JSON.stringify(payload) });
}

async function loadOrder(orderId: string, token: string) {
  const { data: o } = await admin.from("orders").select("*").eq("id", orderId).eq("access_token", token).maybeSingle();
  if (!o) return null;
  const { data: r } = await admin.from("restaurants").select("id, slug, name_en, accept_card, card_provider").eq("id", o.restaurant_id).single();
  const { data: g } = await admin.from("restaurant_gateways").select("*").eq("restaurant_id", o.restaurant_id).maybeSingle();
  return { o, r, g };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return fail("METHOD", 405);
  let p: any;
  try { p = await req.json(); } catch { return fail("BAD_JSON"); }

  try {
    // ---------- owner connects their Thawani account ----------
    if (p.action === "connect") {
      const jwt = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
      const { data: u } = await admin.auth.getUser(jwt);
      if (!u?.user) return fail("NOT_ALLOWED", 401);
      const rid = String(p.restaurant_id || "");
      const { data: mem } = await admin.from("restaurant_members").select("role").eq("restaurant_id", rid).eq("user_id", u.user.id).maybeSingle();
      if (!mem || mem.role !== "owner") return fail("NOT_ALLOWED", 403);
      const mode = p.mode === "live" ? "live" : "test";
      const pk = String(p.publishable_key || "").trim(), sk = String(p.secret_key || "").trim();
      if (pk.length < 10 || sk.length < 10) return fail("KEYS_REQUIRED");
      // validate keys with a tiny session that is never paid
      const test = await createSession(mode, sk, {
        client_reference_id: "verify-" + rid.slice(0, 8), mode: "payment",
        products: [{ name: "DriveMenu key check", quantity: 1, unit_amount: 100 }],
        success_url: "https://drivemenu.app/", cancel_url: "https://drivemenu.app/", metadata: { purpose: "key_check" },
      });
      if (!test.ok || !test.body?.data?.session_id) return json({ error: "KEYS_INVALID", detail: test.body?.description || test.status }, 400);
      const { error: e1 } = await admin.from("restaurant_gateways").upsert({
        restaurant_id: rid, provider: "thawani", mode, publishable_key: pk, secret_key: sk,
        verified_at: new Date().toISOString(), updated_at: new Date().toISOString(),
      });
      if (e1) throw e1;
      const { error: e2 } = await admin.from("restaurants").update({ card_provider: "thawani", accept_card: true }).eq("id", rid);
      if (e2) throw e2;
      return json({ ok: true, mode });
    }

    // ---------- customer starts card payment ----------
    if (p.action === "checkout") {
      const x = await loadOrder(String(p.order_id || ""), String(p.token || ""));
      if (!x) return fail("ORDER_NOT_FOUND", 404);
      const { o, r, g } = x;
      if (o.payment_status === "paid") return json({ paid: true });
      if (o.status !== "awaiting_payment") return fail("ORDER_NOT_PAYABLE");
      if (!r.accept_card || r.card_provider !== "thawani" || !g) return fail("CARD_NOT_ACCEPTED");
      const origin = ALLOWED_ORIGINS.includes(p.origin) ? p.origin : ALLOWED_ORIGINS[0];
      const baisa = Math.round(Number(o.total) * 1000);
      if (!(baisa >= 100)) return fail("AMOUNT_TOO_SMALL");
      const s = await createSession(g.mode, g.secret_key, {
        client_reference_id: o.id, mode: "payment",
        products: [{ name: `${r.name_en} #${o.order_number}`.slice(0, 40), quantity: 1, unit_amount: baisa }],
        success_url: `${origin}/o/${o.id}?t=${o.access_token}&paid=1`,
        cancel_url: `${origin}/r/${r.slug}?pay=cancelled`,
        metadata: { order_id: o.id, restaurant: r.slug },
      });
      const sid = s.body?.data?.session_id;
      if (!s.ok || !sid) return json({ error: "GATEWAY_ERROR", detail: s.body?.description || s.status }, 502);
      await admin.from("orders").update({ payment_provider: "thawani", payment_ref: sid, payment_method: "card" }).eq("id", o.id);
      return json({ url: `${BASE[g.mode as "test" | "live"]}/pay/${sid}?key=${g.publishable_key}` });
    }

    // ---------- confirm payment with Thawani ----------
    if (p.action === "verify") {
      const x = await loadOrder(String(p.order_id || ""), String(p.token || ""));
      if (!x) return fail("ORDER_NOT_FOUND", 404);
      const { o, g } = x;
      if (o.payment_status === "paid") return json({ status: o.status, paid: true });
      if (o.payment_provider !== "thawani" || !o.payment_ref || !g) return json({ status: o.status, paid: false });
      const s = await thawani(g.mode, g.secret_key, `/checkout/session/${encodeURIComponent(o.payment_ref)}`);
      const ps = s.body?.data?.payment_status;
      if (ps === "paid" && String(s.body?.data?.client_reference_id) === o.id) {
        const { data, error } = await admin.rpc("finalize_card_payment", { p_order: o.id, p_provider: "thawani", p_ref: o.payment_ref });
        if (error) throw error;
        return json({ status: data?.status || "pending", paid: true });
      }
      return json({ status: o.status, paid: false, gateway_status: ps || null });
    }

    return fail("UNKNOWN_ACTION");
  } catch (e) {
    console.error(e);
    return fail("SERVER_ERROR", 500);
  }
});
