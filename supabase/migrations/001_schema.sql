-- DriveMenu platform schema
-- Multi-restaurant curbside ordering: QR -> menu -> order from car -> pay by card -> cashier screen

create extension if not exists pgcrypto;

-- ============ TABLES ============

create table public.restaurants (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{2,39}$'),
  name_ar text not null check (length(name_ar) between 1 and 80),
  name_en text not null check (length(name_en) between 1 and 80),
  logo_url text,
  phone text,
  currency text not null default 'OMR',
  timezone text not null default 'Asia/Muscat',
  is_open boolean not null default true,
  base_prep_minutes int not null default 10 check (base_prep_minutes between 1 and 180),
  per_order_load_minutes int not null default 2 check (per_order_load_minutes between 0 and 30),
  payment_mode text not null default 'test' check (payment_mode in ('test','live')),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.restaurant_members (
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','cashier')),
  created_at timestamptz not null default now(),
  primary key (restaurant_id, user_id)
);
create index on public.restaurant_members(user_id);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  name_ar text not null,
  name_en text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index on public.categories(restaurant_id);

create table public.menu_items (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name_ar text not null,
  name_en text not null,
  description_ar text,
  description_en text,
  price numeric(10,3) not null check (price >= 0),
  prep_minutes int not null default 10 check (prep_minutes between 0 and 180),
  image_url text,
  is_available boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index on public.menu_items(restaurant_id);
create index on public.menu_items(category_id);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  restaurant_id uuid not null references public.restaurants(id) on delete cascade,
  order_number int not null,
  access_token uuid not null default gen_random_uuid(),
  customer_name text,
  customer_phone text,
  car_make text,
  car_color text,
  car_plate text not null,
  parking_spot text,
  notes text,
  subtotal numeric(10,3) not null,
  total numeric(10,3) not null,
  currency text not null,
  status text not null default 'awaiting_payment'
    check (status in ('awaiting_payment','pending','preparing','ready','completed','cancelled')),
  payment_status text not null default 'unpaid'
    check (payment_status in ('unpaid','paid','refund_pending','refunded','failed')),
  payment_provider text,
  payment_ref text,
  card_last4 text,
  estimated_minutes int,
  estimated_ready_at timestamptz,
  arrived_at timestamptz,
  paid_at timestamptz,
  accepted_at timestamptz,
  ready_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancel_reason text,
  created_at timestamptz not null default now()
);
create index on public.orders(restaurant_id, created_at desc);
create index on public.orders(restaurant_id, status);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  menu_item_id uuid references public.menu_items(id) on delete set null,
  name_ar text not null,
  name_en text not null,
  unit_price numeric(10,3) not null,
  qty int not null check (qty between 1 and 50),
  line_total numeric(10,3) not null,
  prep_minutes int not null default 0
);
create index on public.order_items(order_id);

-- ============ HELPERS ============

create or replace function public.is_member(p_restaurant uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.restaurant_members
                 where restaurant_id = p_restaurant and user_id = auth.uid());
$$;

create or replace function public.is_owner(p_restaurant uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.restaurant_members
                 where restaurant_id = p_restaurant and user_id = auth.uid() and role = 'owner');
$$;

create or replace function public.is_owner_text(p_restaurant text)
returns boolean language plpgsql stable security definer set search_path = public as $$
begin
  return public.is_owner(p_restaurant::uuid);
exception when others then
  return false;
end $$;

-- owner becomes a member automatically
create or replace function public.tg_restaurant_owner_member()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.restaurant_members(restaurant_id, user_id, role)
  values (new.id, new.owner_id, 'owner')
  on conflict do nothing;
  return new;
end $$;

create trigger restaurant_owner_member
after insert on public.restaurants
for each row execute function public.tg_restaurant_owner_member();

-- ============ RLS ============

alter table public.restaurants enable row level security;
alter table public.restaurant_members enable row level security;
alter table public.categories enable row level security;
alter table public.menu_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

create policy "restaurants are public" on public.restaurants
  for select using (true);
create policy "users create own restaurant" on public.restaurants
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy "owners update restaurant" on public.restaurants
  for update to authenticated using (public.is_owner(id)) with check (public.is_owner(id));
create policy "owners delete restaurant" on public.restaurants
  for delete to authenticated using (public.is_owner(id));

create policy "members see members" on public.restaurant_members
  for select to authenticated using (user_id = (select auth.uid()) or public.is_member(restaurant_id));

create policy "categories are public" on public.categories for select using (true);
create policy "owners manage categories" on public.categories
  for all to authenticated using (public.is_owner(restaurant_id)) with check (public.is_owner(restaurant_id));

create policy "menu is public" on public.menu_items for select using (true);
create policy "owners manage menu" on public.menu_items
  for all to authenticated using (public.is_owner(restaurant_id)) with check (public.is_owner(restaurant_id));

-- orders: staff read only; all writes go through functions below
create policy "members read orders" on public.orders
  for select to authenticated using (public.is_member(restaurant_id));
create policy "members read order items" on public.order_items
  for select to authenticated using (
    exists (select 1 from public.orders o where o.id = order_id and public.is_member(o.restaurant_id)));

-- ============ CUSTOMER FUNCTIONS (anon) ============

-- Estimate prep time: slowest item (or base) + queue load
create or replace function public.estimate_minutes(p_restaurant uuid, p_order uuid)
returns int language plpgsql stable security definer set search_path = public as $$
declare
  r public.restaurants;
  v_item_max int;
  v_queue int;
begin
  select * into r from public.restaurants where id = p_restaurant;
  select coalesce(max(prep_minutes), 0) into v_item_max from public.order_items where order_id = p_order;
  select count(*) into v_queue from public.orders
    where restaurant_id = p_restaurant and id <> p_order and status in ('pending','preparing');
  return greatest(r.base_prep_minutes, v_item_max) + least(v_queue * r.per_order_load_minutes, 45);
end $$;

create or replace function public.place_order(p_slug text, p_items jsonb, p_customer jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  r public.restaurants;
  v_order uuid;
  v_number int;
  v_subtotal numeric(10,3) := 0;
  v_item jsonb;
  m public.menu_items;
  v_qty int;
  v_token uuid;
  v_count int := 0;
begin
  select * into r from public.restaurants where slug = p_slug;
  if not found then raise exception 'RESTAURANT_NOT_FOUND'; end if;
  if not r.is_open then raise exception 'RESTAURANT_CLOSED'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'EMPTY_CART'; end if;
  if jsonb_array_length(p_items) > 40 then raise exception 'CART_TOO_LARGE'; end if;
  if coalesce(trim(p_customer->>'car_plate'), '') = '' then raise exception 'CAR_PLATE_REQUIRED'; end if;

  perform pg_advisory_xact_lock(hashtext(r.id::text));
  select coalesce(max(order_number), 0) + 1 into v_number from public.orders
   where restaurant_id = r.id
     and (created_at at time zone r.timezone)::date = (now() at time zone r.timezone)::date;

  insert into public.orders(restaurant_id, order_number, customer_name, customer_phone, car_make, car_color,
                            car_plate, parking_spot, notes, subtotal, total, currency)
  values (r.id, v_number,
          left(nullif(trim(p_customer->>'name'),''), 60),
          left(nullif(trim(p_customer->>'phone'),''), 20),
          left(nullif(trim(p_customer->>'car_make'),''), 40),
          left(nullif(trim(p_customer->>'car_color'),''), 30),
          left(trim(p_customer->>'car_plate'), 20),
          left(nullif(trim(p_customer->>'parking_spot'),''), 20),
          left(nullif(trim(p_customer->>'notes'),''), 300),
          0, 0, r.currency)
  returning id, access_token into v_order, v_token;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'qty')::int;
    if v_qty is null or v_qty < 1 or v_qty > 50 then raise exception 'BAD_QTY'; end if;
    select * into m from public.menu_items where id = (v_item->>'id')::uuid and restaurant_id = r.id;
    if not found then raise exception 'ITEM_NOT_FOUND'; end if;
    if not m.is_available then raise exception 'ITEM_UNAVAILABLE:%', m.name_en; end if;
    insert into public.order_items(order_id, menu_item_id, name_ar, name_en, unit_price, qty, line_total, prep_minutes)
    values (v_order, m.id, m.name_ar, m.name_en, m.price, v_qty, m.price * v_qty, m.prep_minutes);
    v_subtotal := v_subtotal + m.price * v_qty;
    v_count := v_count + 1;
  end loop;

  update public.orders set subtotal = v_subtotal, total = v_subtotal where id = v_order;

  return jsonb_build_object('order_id', v_order, 'token', v_token, 'order_number', v_number,
                            'total', v_subtotal, 'currency', r.currency, 'payment_mode', r.payment_mode,
                            'estimated_minutes', public.estimate_minutes(r.id, v_order));
end $$;

-- Test-mode payment. Live mode will be confirmed by a payment-gateway webhook (edge function) instead.
create or replace function public.pay_order_test(p_order uuid, p_token uuid, p_card_last4 text, p_success boolean default true)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  o public.orders;
  r public.restaurants;
  v_min int;
begin
  select * into o from public.orders where id = p_order and access_token = p_token for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  select * into r from public.restaurants where id = o.restaurant_id;
  if r.payment_mode <> 'test' then raise exception 'TEST_PAYMENTS_DISABLED'; end if;
  if o.payment_status = 'paid' then return jsonb_build_object('status', o.status); end if;
  if o.status <> 'awaiting_payment' then raise exception 'ORDER_NOT_PAYABLE'; end if;

  if not p_success then
    update public.orders set payment_status = 'failed' where id = o.id;
    raise exception 'CARD_DECLINED';
  end if;

  v_min := public.estimate_minutes(o.restaurant_id, o.id);
  update public.orders
     set payment_status = 'paid', status = 'pending', paid_at = now(),
         payment_provider = 'test', payment_ref = 'TEST-' || substr(md5(random()::text), 1, 10),
         card_last4 = left(regexp_replace(coalesce(p_card_last4,''), '\D', '', 'g'), 4),
         estimated_minutes = v_min, estimated_ready_at = now() + make_interval(mins => v_min)
   where id = o.id;
  return jsonb_build_object('status', 'pending', 'estimated_minutes', v_min);
end $$;

create or replace function public.get_order(p_order uuid, p_token uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  o public.orders;
  r public.restaurants;
begin
  select * into o from public.orders where id = p_order and access_token = p_token;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  select * into r from public.restaurants where id = o.restaurant_id;
  return jsonb_build_object(
    'id', o.id, 'order_number', o.order_number, 'status', o.status, 'payment_status', o.payment_status,
    'total', o.total, 'currency', o.currency, 'car_make', o.car_make, 'car_color', o.car_color,
    'car_plate', o.car_plate, 'parking_spot', o.parking_spot, 'customer_name', o.customer_name,
    'estimated_minutes', o.estimated_minutes, 'estimated_ready_at', o.estimated_ready_at,
    'arrived_at', o.arrived_at, 'created_at', o.created_at, 'card_last4', o.card_last4,
    'payment_mode', r.payment_mode,
    'restaurant', jsonb_build_object('slug', r.slug, 'name_ar', r.name_ar, 'name_en', r.name_en,
                                     'logo_url', r.logo_url, 'phone', r.phone),
    'items', coalesce((select jsonb_agg(jsonb_build_object('name_ar', i.name_ar, 'name_en', i.name_en,
                         'qty', i.qty, 'unit_price', i.unit_price, 'line_total', i.line_total))
                       from public.order_items i where i.order_id = o.id), '[]'::jsonb),
    'server_now', now());
end $$;

create or replace function public.mark_arrived(p_order uuid, p_token uuid, p_parking_spot text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.orders
     set arrived_at = coalesce(arrived_at, now()),
         parking_spot = coalesce(left(nullif(trim(p_parking_spot),''), 20), parking_spot)
   where id = p_order and access_token = p_token and status in ('pending','preparing','ready');
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
end $$;

-- ============ STAFF FUNCTIONS (authenticated) ============

create or replace function public.staff_update_order(p_order uuid, p_action text, p_minutes int default null, p_reason text default null)
returns void language plpgsql security definer set search_path = public as $$
declare
  o public.orders;
begin
  select * into o from public.orders where id = p_order for update;
  if not found or not public.is_member(o.restaurant_id) then raise exception 'NOT_ALLOWED'; end if;
  if p_minutes is not null and (p_minutes < 1 or p_minutes > 240) then raise exception 'BAD_MINUTES'; end if;

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
      ready_at = coalesce(ready_at, now()) where id = o.id;
  elsif p_action = 'cancel' and o.status in ('awaiting_payment','pending','preparing','ready') then
    update public.orders set status = 'cancelled', cancelled_at = now(), cancel_reason = left(p_reason, 200),
      payment_status = case when payment_status = 'paid' then 'refund_pending' else payment_status end
    where id = o.id;
  else
    raise exception 'BAD_TRANSITION';
  end if;
end $$;

create or replace function public.list_members(p_restaurant uuid)
returns table(user_id uuid, email text, role text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_member(p_restaurant) then raise exception 'NOT_ALLOWED'; end if;
  return query select m.user_id, u.email::text, m.role, m.created_at
    from public.restaurant_members m join auth.users u on u.id = m.user_id
    where m.restaurant_id = p_restaurant order by m.created_at;
end $$;

create or replace function public.add_member(p_restaurant uuid, p_email text, p_role text default 'cashier')
returns void language plpgsql security definer set search_path = public as $$
declare v_user uuid;
begin
  if not public.is_owner(p_restaurant) then raise exception 'NOT_ALLOWED'; end if;
  if p_role not in ('owner','cashier') then raise exception 'BAD_ROLE'; end if;
  select id into v_user from auth.users where lower(email) = lower(trim(p_email));
  if v_user is null then raise exception 'USER_NOT_FOUND'; end if;
  insert into public.restaurant_members(restaurant_id, user_id, role) values (p_restaurant, v_user, p_role)
  on conflict (restaurant_id, user_id) do update set role = excluded.role;
end $$;

create or replace function public.remove_member(p_restaurant uuid, p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner(p_restaurant) then raise exception 'NOT_ALLOWED'; end if;
  if p_user = (select owner_id from public.restaurants where id = p_restaurant) then raise exception 'CANNOT_REMOVE_OWNER'; end if;
  delete from public.restaurant_members where restaurant_id = p_restaurant and user_id = p_user;
end $$;

-- ============ GRANTS ============

revoke execute on all functions in schema public from public, anon;
grant execute on function public.place_order(text, jsonb, jsonb) to anon, authenticated;
grant execute on function public.pay_order_test(uuid, uuid, text, boolean) to anon, authenticated;
grant execute on function public.get_order(uuid, uuid) to anon, authenticated;
grant execute on function public.mark_arrived(uuid, uuid, text) to anon, authenticated;
grant execute on function public.is_member(uuid), public.is_owner(uuid), public.is_owner_text(text) to authenticated;
grant execute on function public.staff_update_order(uuid, text, int, text) to authenticated;
grant execute on function public.list_members(uuid) to authenticated;
grant execute on function public.add_member(uuid, text, text) to authenticated;
grant execute on function public.remove_member(uuid, uuid) to authenticated;
revoke execute on function public.estimate_minutes(uuid, uuid) from authenticated;
revoke execute on function public.tg_restaurant_owner_member() from authenticated;

-- ============ REALTIME ============
alter publication supabase_realtime add table public.orders;

-- ============ STORAGE (menu images & logos) ============
insert into storage.buckets (id, name, public) values ('menu-images', 'menu-images', true)
on conflict (id) do nothing;

create policy "owners upload images" on storage.objects for insert to authenticated
  with check (bucket_id = 'menu-images' and public.is_owner_text((storage.foldername(name))[1]));
create policy "owners update images" on storage.objects for update to authenticated
  using (bucket_id = 'menu-images' and public.is_owner_text((storage.foldername(name))[1]));
create policy "owners delete images" on storage.objects for delete to authenticated
  using (bucket_id = 'menu-images' and public.is_owner_text((storage.foldername(name))[1]));

-- owners may only edit these restaurant columns (not owner_id / id)
revoke update on public.restaurants from authenticated, anon;
grant update (slug, name_ar, name_en, logo_url, phone, currency, timezone, is_open,
              base_prep_minutes, per_order_load_minutes, payment_mode) on public.restaurants to authenticated;
revoke insert, update, delete on public.orders, public.order_items, public.restaurant_members from anon, authenticated;
