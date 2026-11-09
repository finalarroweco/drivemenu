create table public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.platform_admins enable row level security;
create policy "admins see themselves" on public.platform_admins for select to authenticated using (user_id = (select auth.uid()));

-- add platform admins by email:
-- insert into public.platform_admins(user_id) select id from auth.users where lower(email) = 'you@example.com';

alter table public.restaurants add column is_suspended boolean not null default false;
-- owners cannot change is_suspended (not in the column grant)

create or replace function public.is_platform_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.platform_admins where user_id = auth.uid());
$$;

create or replace function public.tg_orders_block_suspended()
returns trigger language plpgsql set search_path = public as $$
begin
  if exists (select 1 from public.restaurants where id = new.restaurant_id and is_suspended) then
    raise exception 'RESTAURANT_SUSPENDED';
  end if;
  return new;
end $$;
create trigger orders_block_suspended before insert on public.orders
for each row execute function public.tg_orders_block_suspended();

create or replace function public.admin_overview()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_today timestamptz := date_trunc('day', now() at time zone 'Asia/Muscat') at time zone 'Asia/Muscat';
  v_month timestamptz := date_trunc('month', now() at time zone 'Asia/Muscat') at time zone 'Asia/Muscat';
begin
  if not public.is_platform_admin() then raise exception 'NOT_ALLOWED'; end if;
  return jsonb_build_object(
    'totals', jsonb_build_object(
      'restaurants', (select count(*) from restaurants),
      'active_restaurants', (select count(*) from restaurants where not is_suspended),
      'users', (select count(*) from auth.users),
      'orders_today', (select count(*) from orders where created_at >= v_today and status not in ('awaiting_payment','cancelled')),
      'orders_month', (select count(*) from orders where created_at >= v_month and status not in ('awaiting_payment','cancelled')),
      'sales_month', (select coalesce(sum(total),0) from orders where created_at >= v_month and status not in ('awaiting_payment','cancelled'))
    ),
    'restaurants', coalesce((select jsonb_agg(x order by x->>'created_at' desc) from (
      select jsonb_build_object(
        'id', r.id, 'slug', r.slug, 'name_ar', r.name_ar, 'name_en', r.name_en, 'currency', r.currency,
        'is_open', r.is_open, 'is_suspended', r.is_suspended, 'created_at', r.created_at, 'phone', r.phone,
        'owner_email', (select email from auth.users where id = r.owner_id),
        'items', (select count(*) from menu_items m where m.restaurant_id = r.id),
        'orders_today', (select count(*) from orders o where o.restaurant_id = r.id and o.created_at >= v_today and o.status not in ('awaiting_payment','cancelled')),
        'orders_month', (select count(*) from orders o where o.restaurant_id = r.id and o.created_at >= v_month and o.status not in ('awaiting_payment','cancelled')),
        'sales_month', (select coalesce(sum(total),0) from orders o where o.restaurant_id = r.id and o.created_at >= v_month and o.status not in ('awaiting_payment','cancelled')),
        'last_order_at', (select max(created_at) from orders o where o.restaurant_id = r.id and o.status <> 'awaiting_payment')
      ) x from restaurants r) t), '[]'::jsonb)
  );
end $$;

create or replace function public.admin_set_suspended(p_restaurant uuid, p_suspended boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'NOT_ALLOWED'; end if;
  update public.restaurants set is_suspended = p_suspended where id = p_restaurant;
end $$;

revoke execute on function public.is_platform_admin(), public.admin_overview(), public.admin_set_suspended(uuid, boolean) from public, anon;
grant execute on function public.is_platform_admin(), public.admin_overview(), public.admin_set_suspended(uuid, boolean) to authenticated;
revoke execute on function public.tg_orders_block_suspended() from public, anon, authenticated;
