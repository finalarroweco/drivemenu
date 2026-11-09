-- ============ PREORDERS + COUPONS ============

alter table public.restaurants
  add column if not exists preorder_enabled boolean not null default true,
  add column if not exists preorder_max_hours int not null default 24 check (preorder_max_hours between 1 and 168);
grant update (preorder_enabled, preorder_max_hours) on public.restaurants to authenticated;

create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  code text not null check (code ~ '^[A-Z0-9_-]{3,20}$'),
  kind text not null check (kind in ('percent','amount')),
  value numeric(10,3) not null check (value > 0),
  min_order numeric(10,3) not null default 0 check (min_order >= 0),
  max_discount numeric(10,3) check (max_discount is null or max_discount > 0),
  starts_at timestamptz,
  ends_at timestamptz,
  max_uses int check (max_uses is null or max_uses > 0),
  per_phone_limit int check (per_phone_limit is null or per_phone_limit > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint coupons_percent_range check (kind <> 'percent' or value <= 100),
  constraint coupons_dates check (ends_at is null or starts_at is null or ends_at > starts_at)
);
create unique index if not exists coupons_rest_code on public.coupons(restaurant_id, code);
alter table public.coupons enable row level security;
create policy "owners read coupons" on public.coupons for select to authenticated using (public.is_owner(restaurant_id));
create policy "owners insert coupons" on public.coupons for insert to authenticated with check (public.is_owner(restaurant_id));
create policy "owners update coupons" on public.coupons for update to authenticated using (public.is_owner(restaurant_id)) with check (public.is_owner(restaurant_id));
create policy "owners delete coupons" on public.coupons for delete to authenticated using (public.is_owner(restaurant_id));
grant select, insert, update, delete on public.coupons to authenticated;

alter table public.orders
  add column if not exists scheduled_for timestamptz,
  add column if not exists discount numeric(10,3) not null default 0,
  add column if not exists coupon_id uuid references public.coupons(id) on delete set null,
  add column if not exists coupon_code text;
create index if not exists orders_coupon on public.orders(coupon_id) where coupon_id is not null;

-- evaluate a coupon (raises COUPON_* errors)
create or replace function public.coupon_eval(p_restaurant uuid, p_code text, p_subtotal numeric, p_phone text)
returns table(coupon_id uuid, code text, discount numeric)
language plpgsql stable security definer set search_path = public as $$
declare c public.coupons; v_used int; v_phone text; v_disc numeric;
begin
  select * into c from public.coupons where restaurant_id = p_restaurant and coupons.code = upper(trim(p_code));
  if not found or not c.is_active then raise exception 'COUPON_INVALID'; end if;
  if c.starts_at is not null and now() < c.starts_at then raise exception 'COUPON_NOT_STARTED'; end if;
  if c.ends_at is not null and now() >= c.ends_at then raise exception 'COUPON_EXPIRED'; end if;
  if p_subtotal < c.min_order then raise exception 'COUPON_MIN_ORDER:%', c.min_order; end if;
  if c.max_uses is not null then
    select count(*) into v_used from public.orders o
     where o.coupon_id = c.id and o.status <> 'cancelled'
       and not (o.status = 'awaiting_payment' and o.created_at < now() - interval '30 minutes');
    if v_used >= c.max_uses then raise exception 'COUPON_USED_UP'; end if;
  end if;
  if c.per_phone_limit is not null then
    v_phone := right(regexp_replace(coalesce(p_phone,''), '\D', '', 'g'), 8);
    if length(v_phone) >= 7 then
      select count(*) into v_used from public.orders o
       where o.coupon_id = c.id and o.status <> 'cancelled'
         and not (o.status = 'awaiting_payment' and o.created_at < now() - interval '30 minutes')
         and right(regexp_replace(coalesce(o.customer_phone,''), '\D', '', 'g'), 8) = v_phone;
      if v_used >= c.per_phone_limit then raise exception 'COUPON_PHONE_LIMIT'; end if;
    end if;
  end if;
  if c.kind = 'percent' then
    v_disc := round(p_subtotal * c.value / 100, 3);
    if c.max_discount is not null then v_disc := least(v_disc, c.max_discount); end if;
  else
    v_disc := c.value;
  end if;
  v_disc := least(v_disc, p_subtotal);
  return query select c.id, c.code, v_disc;
end $$;
revoke execute on function public.coupon_eval(uuid, text, numeric, text) from public, anon, authenticated;

-- public preview for the cart
create or replace function public.check_coupon(p_slug text, p_code text, p_subtotal numeric, p_phone text default null)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r public.restaurants; e record; c public.coupons;
begin
  select * into r from public.restaurants where slug = p_slug;
  if not found then raise exception 'RESTAURANT_NOT_FOUND'; end if;
  if coalesce(trim(p_code),'') = '' then raise exception 'COUPON_INVALID'; end if;
  select * into e from public.coupon_eval(r.id, p_code, greatest(coalesce(p_subtotal,0),0), p_phone);
  select * into c from public.coupons where id = e.coupon_id;
  return jsonb_build_object('code', e.code, 'discount', e.discount, 'kind', c.kind, 'value', c.value,
                            'min_order', c.min_order, 'max_discount', c.max_discount);
end $$;
grant execute on function public.check_coupon(text, text, numeric, text) to anon, authenticated;

-- owner list with usage
create or replace function public.list_coupons(p_restaurant uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_owner(p_restaurant) then raise exception 'NOT_ALLOWED'; end if;
  return coalesce((select jsonb_agg(to_jsonb(c) || jsonb_build_object(
      'uses', (select count(*) from orders o where o.coupon_id = c.id and o.status not in ('cancelled','awaiting_payment')),
      'discount_total', (select coalesce(sum(o.discount),0) from orders o where o.coupon_id = c.id and o.status not in ('cancelled','awaiting_payment')))
    order by c.created_at desc) from coupons c where c.restaurant_id = p_restaurant), '[]'::jsonb);
end $$;
revoke execute on function public.list_coupons(uuid) from public, anon;
grant execute on function public.list_coupons(uuid) to authenticated;

-- ETA helper: honours scheduled pickup time
create or replace function public.ready_at_for(p_order uuid, p_min int)
returns timestamptz language sql stable security definer set search_path = public as $$
  select case when o.scheduled_for is not null then greatest(o.scheduled_for, now() + make_interval(mins => p_min))
              else now() + make_interval(mins => p_min) end
    from public.orders o where o.id = p_order
$$;
revoke execute on function public.ready_at_for(uuid, int) from public, anon, authenticated;

create or replace function public.estimate_minutes(p_restaurant uuid, p_order uuid)
returns integer language plpgsql stable security definer set search_path = public as $$
declare
  r public.restaurants;
  v_item_max int;
  v_queue int;
begin
  select * into r from public.restaurants where id = p_restaurant;
  select coalesce(max(prep_minutes), 0) into v_item_max from public.order_items where order_id = p_order;
  select count(*) into v_queue from public.orders
    where restaurant_id = p_restaurant and id <> p_order and status in ('pending','preparing')
      and (scheduled_for is null or scheduled_for <= now() + interval '45 minutes');
  return greatest(r.base_prep_minutes, v_item_max) + least(v_queue * r.per_order_load_minutes, 45);
end $$;

create or replace function public.confirm_cash_order(p_order uuid, p_token uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  o public.orders;
  r public.restaurants;
  v_min int; v_ready timestamptz;
begin
  select * into o from public.orders where id = p_order and access_token = p_token for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  select * into r from public.restaurants where id = o.restaurant_id;
  if not r.accept_cash then raise exception 'CASH_NOT_ACCEPTED'; end if;
  if o.status <> 'awaiting_payment' then return jsonb_build_object('status', o.status); end if;

  v_min := public.estimate_minutes(o.restaurant_id, o.id);
  v_ready := public.ready_at_for(o.id, v_min);
  update public.orders
     set payment_method = 'cash', status = 'pending',
         estimated_minutes = ceil(extract(epoch from v_ready - now()) / 60)::int, estimated_ready_at = v_ready
   where id = o.id;
  return jsonb_build_object('status', 'pending', 'estimated_minutes', ceil(extract(epoch from v_ready - now()) / 60)::int);
end $$;

create or replace function public.pay_order_test(p_order uuid, p_token uuid, p_card_last4 text, p_success boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  o public.orders;
  r public.restaurants;
  v_min int; v_ready timestamptz;
begin
  select * into o from public.orders where id = p_order and access_token = p_token for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  select * into r from public.restaurants where id = o.restaurant_id;
  if not r.accept_card then raise exception 'CARD_NOT_ACCEPTED'; end if;
  if r.payment_mode <> 'test' then raise exception 'TEST_PAYMENTS_DISABLED'; end if;
  if o.payment_status = 'paid' then return jsonb_build_object('status', o.status); end if;
  if o.status <> 'awaiting_payment' then raise exception 'ORDER_NOT_PAYABLE'; end if;
  if not p_success then raise exception 'CARD_DECLINED'; end if;

  v_min := public.estimate_minutes(o.restaurant_id, o.id);
  v_ready := public.ready_at_for(o.id, v_min);
  update public.orders
     set payment_status = 'paid', payment_method = 'card', status = 'pending', paid_at = now(),
         payment_provider = 'test', payment_ref = 'TEST-' || substr(md5(random()::text), 1, 10),
         card_last4 = left(regexp_replace(coalesce(p_card_last4,''), '\D', '', 'g'), 4),
         estimated_minutes = ceil(extract(epoch from v_ready - now()) / 60)::int, estimated_ready_at = v_ready
   where id = o.id;
  return jsonb_build_object('status', 'pending', 'estimated_minutes', ceil(extract(epoch from v_ready - now()) / 60)::int);
end $$;

create or replace function public.staff_update_order(p_order uuid, p_action text, p_minutes integer default null, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  o public.orders;
begin
  select * into o from public.orders where id = p_order for update;
  if not found or not public.is_member(o.restaurant_id) then raise exception 'NOT_ALLOWED'; end if;
  if p_minutes is not null and (p_minutes < 1 or p_minutes > 10080) then raise exception 'BAD_MINUTES'; end if;

  if p_action = 'accept' and o.status = 'pending' then
    update public.orders set status = 'preparing', accepted_at = now(),
      estimated_minutes = coalesce(p_minutes, estimated_minutes),
      estimated_ready_at = case when p_minutes is not null then now() + make_interval(mins => p_minutes)
                                else estimated_ready_at end
    where id = o.id;
  elsif p_action = 'set_time' and o.status in ('pending','preparing') and p_minutes is not null then
    update public.orders set estimated_minutes = p_minutes,
      estimated_ready_at = now() + make_interval(mins => p_minutes) where id = o.id;
  elsif p_action = 'ready' and o.status in ('pending','preparing') then
    update public.orders set status = 'ready', ready_at = now(),
      accepted_at = coalesce(accepted_at, now()) where id = o.id;
  elsif p_action = 'complete' and o.status in ('ready','preparing','pending') then
    update public.orders set status = 'completed', completed_at = now(),
      ready_at = coalesce(ready_at, now()),
      payment_status = case when payment_method = 'cash' then 'paid' else payment_status end,
      paid_at = case when payment_method = 'cash' then now() else paid_at end
    where id = o.id;
  elsif p_action = 'cancel' and o.status in ('awaiting_payment','pending','preparing','ready') then
    update public.orders set status = 'cancelled', cancelled_at = now(), cancel_reason = left(p_reason, 200),
      payment_status = case when payment_status = 'paid' then 'refund_pending' else payment_status end
    where id = o.id;
  else
    raise exception 'BAD_TRANSITION';
  end if;
end $$;
