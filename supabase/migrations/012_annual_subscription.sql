-- Annual subscription: restaurants receive orders only while subscription_until is in the future.
alter table public.restaurants add column if not exists subscription_until timestamptz;
alter table public.restaurants alter column accept_card set default false;
-- owners cannot change subscription_until (not in the column grant)

create or replace function public.admin_set_subscription(p_restaurant uuid, p_until timestamptz)
returns timestamptz language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'NOT_ALLOWED'; end if;
  update public.restaurants set subscription_until = p_until where id = p_restaurant;
  return p_until;
end $$;

create or replace function public.admin_extend_subscription(p_restaurant uuid, p_years int default 1)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare v timestamptz;
begin
  if not public.is_platform_admin() then raise exception 'NOT_ALLOWED'; end if;
  if p_years < 1 or p_years > 5 then raise exception 'BAD_YEARS'; end if;
  update public.restaurants
     set subscription_until = greatest(coalesce(subscription_until, now()), now()) + make_interval(years => p_years)
   where id = p_restaurant
  returning subscription_until into v;
  return v;
end $$;
revoke execute on function public.admin_set_subscription(uuid, timestamptz), public.admin_extend_subscription(uuid, int) from public, anon;
grant execute on function public.admin_set_subscription(uuid, timestamptz), public.admin_extend_subscription(uuid, int) to authenticated;

-- place_order rejects orders without an active subscription; admin_overview reports subscription data
do $do$
declare d text; d2 text;
begin
  d := pg_get_functiondef('public.place_order(text,jsonb,jsonb)'::regprocedure);
  if position('SUBSCRIPTION_INACTIVE' in d) = 0 then
    d2 := replace(d, $x$  if not r.is_open then raise exception 'RESTAURANT_CLOSED'; end if;$x$,
      $x$  if r.subscription_until is null or r.subscription_until < now() then raise exception 'SUBSCRIPTION_INACTIVE'; end if;
  if not r.is_open then raise exception 'RESTAURANT_CLOSED'; end if;$x$);
    execute d2;
  end if;
  d := pg_get_functiondef('public.admin_overview()'::regprocedure);
  if position('subscription_until' in d) = 0 then
    d2 := replace(d, $x$'is_open', r.is_open, 'is_suspended', r.is_suspended,$x$, $x$'is_open', r.is_open, 'is_suspended', r.is_suspended, 'subscription_until', r.subscription_until,$x$);
    d2 := replace(d2, $x$'active_restaurants', (select count(*) from restaurants where not is_suspended),$x$,
      $x$'active_restaurants', (select count(*) from restaurants where not is_suspended),
      'subscribed', (select count(*) from restaurants where subscription_until > now()),
      'expiring_30d', (select count(*) from restaurants where subscription_until > now() and subscription_until < now() + interval '30 days'),$x$);
    execute d2;
  end if;
end $do$;
