-- Per-restaurant card gateway (Thawani). Secrets live in a table clients can never read.
-- The edge function supabase/functions/thawani (service role) validates keys, creates checkout sessions
-- and confirms payments.
create table if not exists public.restaurant_gateways (
  restaurant_id uuid primary key references public.restaurants(id) on delete cascade,
  provider text not null default 'thawani' check (provider in ('thawani')),
  mode text not null default 'test' check (mode in ('test','live')),
  publishable_key text not null,
  secret_key text not null,
  verified_at timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.restaurant_gateways enable row level security;
revoke all on public.restaurant_gateways from anon, authenticated;

alter table public.restaurants add column if not exists card_provider text check (card_provider in ('thawani'));

create or replace function public.tg_restaurants_card_requires_gateway()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.accept_card and new.card_provider is null then
    raise exception 'CARD_GATEWAY_REQUIRED';
  end if;
  return new;
end $$;
drop trigger if exists restaurants_card_requires_gateway on public.restaurants;
create trigger restaurants_card_requires_gateway before insert or update of accept_card, card_provider on public.restaurants
for each row execute function public.tg_restaurants_card_requires_gateway();
revoke execute on function public.tg_restaurants_card_requires_gateway() from public, anon, authenticated;

create or replace function public.gateway_status(p_restaurant uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g public.restaurant_gateways;
begin
  if not public.is_owner(p_restaurant) then raise exception 'NOT_ALLOWED'; end if;
  select * into g from public.restaurant_gateways where restaurant_id = p_restaurant;
  if not found then return jsonb_build_object('connected', false); end if;
  return jsonb_build_object('connected', g.verified_at is not null, 'provider', g.provider, 'mode', g.mode,
    'publishable_key', g.publishable_key, 'secret_hint', '••••' || right(g.secret_key, 4), 'verified_at', g.verified_at);
end $$;
revoke execute on function public.gateway_status(uuid) from public, anon;
grant execute on function public.gateway_status(uuid) to authenticated;

create or replace function public.gateway_disconnect(p_restaurant uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner(p_restaurant) then raise exception 'NOT_ALLOWED'; end if;
  update public.restaurants set accept_card = false, card_provider = null, accept_cash = true where id = p_restaurant;
  delete from public.restaurant_gateways where restaurant_id = p_restaurant;
end $$;
revoke execute on function public.gateway_disconnect(uuid) from public, anon;
grant execute on function public.gateway_disconnect(uuid) to authenticated;

create or replace function public.finalize_card_payment(p_order uuid, p_provider text, p_ref text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare o public.orders; v_min int; v_ready timestamptz;
begin
  select * into o from public.orders where id = p_order for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if o.payment_status = 'paid' then return jsonb_build_object('status', o.status, 'already', true); end if;
  if o.status not in ('awaiting_payment','cancelled') then raise exception 'ORDER_NOT_PAYABLE'; end if;
  begin
    perform public.coupon_recheck(o.id);
  exception when others then
    -- payment already captured: keep the order and flag it for the restaurant
    update public.orders set notes = left(coalesce(notes || ' | ', '') || 'COUPON_LIMIT_EXCEEDED', 300) where id = o.id;
  end;
  v_min := public.estimate_minutes(o.restaurant_id, o.id);
  v_ready := public.ready_at_for(o.id, v_min);
  update public.orders
     set payment_status = 'paid', payment_method = 'card', status = 'pending', paid_at = now(),
         payment_provider = p_provider, payment_ref = p_ref, cancelled_at = null,
         estimated_minutes = ceil(extract(epoch from v_ready - now()) / 60)::int, estimated_ready_at = v_ready
   where id = o.id;
  return jsonb_build_object('status', 'pending');
end $$;
revoke execute on function public.finalize_card_payment(uuid, text, text) from public, anon, authenticated;
grant execute on function public.finalize_card_payment(uuid, text, text) to service_role;

-- test-mode card payments are retired now that real gateways exist
revoke execute on function public.pay_order_test(uuid, uuid, text, boolean) from public, anon, authenticated;

do $do$
declare d text; d2 text;
begin
  d := pg_get_functiondef('public.place_order(text,jsonb,jsonb)'::regprocedure);
  if position('card_provider' in d) = 0 then
    d2 := replace(d, $x$'accept_card', r.accept_card,$x$, $x$'accept_card', r.accept_card and r.card_provider is not null, 'card_provider', r.card_provider,$x$);
    execute d2;
  end if;
  d := pg_get_functiondef('public.get_order(uuid,uuid)'::regprocedure);
  if position('payment_provider' in d) = 0 then
    d2 := replace(d, $x$'payment_method', o.payment_method,$x$, $x$'payment_method', o.payment_method, 'payment_provider', o.payment_provider,$x$);
    execute d2;
  end if;
end $do$;
