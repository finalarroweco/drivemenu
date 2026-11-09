create or replace function public.owner_report(p_restaurant uuid, p_from date, p_to date)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  r public.restaurants;
  tz text;
  v_start timestamptz; v_end timestamptz;
  v_days int;
  p_start timestamptz; p_end timestamptz;
  res jsonb;
begin
  if not public.is_owner(p_restaurant) and not public.is_platform_admin() then raise exception 'NOT_ALLOWED'; end if;
  if p_from is null or p_to is null or p_to < p_from then raise exception 'BAD_RANGE'; end if;
  if p_to - p_from > 366 then raise exception 'RANGE_TOO_LONG'; end if;
  select * into r from public.restaurants where id = p_restaurant;
  tz := coalesce(r.timezone, 'Asia/Muscat');
  v_start := p_from::timestamp at time zone tz;
  v_end   := (p_to + 1)::timestamp at time zone tz;
  v_days  := p_to - p_from + 1;
  p_start := (p_from - v_days)::timestamp at time zone tz;
  p_end   := v_start;

  with o as (
    select * from public.orders
     where restaurant_id = p_restaurant and created_at >= v_start and created_at < v_end
       and status <> 'awaiting_payment'
  ), ok as (select * from o where status <> 'cancelled'),
  prev as (
    select * from public.orders
     where restaurant_id = p_restaurant and created_at >= p_start and created_at < p_end
       and status <> 'awaiting_payment'
  ), prev_ok as (select * from prev where status <> 'cancelled'),
  items as (
    select oi.* from public.order_items oi join ok on ok.id = oi.order_id
  )
  select jsonb_build_object(
    'currency', r.currency,
    'timezone', tz,
    'from', p_from, 'to', p_to,
    'kpi', jsonb_build_object(
      'sales', (select coalesce(sum(total),0) from ok),
      'orders', (select count(*) from ok),
      'avg', (select coalesce(round(avg(total),3),0) from ok),
      'cancelled', (select count(*) from o where status = 'cancelled'),
      'cancel_rate', (select case when count(*) = 0 then 0 else round(100.0 * count(*) filter (where status='cancelled') / count(*), 1) end from o),
      'items_sold', (select coalesce(sum(qty),0) from items),
      'discounts', (select coalesce(sum(discount),0) from ok),
      'coupon_orders', (select count(*) from ok where coupon_id is not null),
      'scheduled', (select count(*) from ok where scheduled_for is not null)
    ),
    'prev', jsonb_build_object(
      'sales', (select coalesce(sum(total),0) from prev_ok),
      'orders', (select count(*) from prev_ok),
      'avg', (select coalesce(round(avg(total),3),0) from prev_ok),
      'cancelled', (select count(*) from prev where status = 'cancelled')
    ),
    'daily', (select coalesce(jsonb_agg(jsonb_build_object('d', d::date, 'orders', coalesce(x.n,0), 'sales', coalesce(x.s,0)) order by d), '[]'::jsonb)
              from generate_series(p_from::timestamp, p_to::timestamp, interval '1 day') d
              left join (select (created_at at time zone tz)::date dd, count(*) n, sum(total) s from ok group by 1) x on x.dd = d::date),
    'hours', (select jsonb_agg(coalesce(x.n,0) order by h)
              from generate_series(0,23) h
              left join (select extract(hour from created_at at time zone tz)::int hh, count(*) n from ok group by 1) x on x.hh = h),
    'weekdays', (select jsonb_agg(coalesce(x.n,0) order by w)
              from generate_series(0,6) w
              left join (select extract(dow from created_at at time zone tz)::int ww, count(*) n from ok group by 1) x on x.ww = w),
    'top_items', (select coalesce(jsonb_agg(t order by (t->>'qty')::int desc, (t->>'sales')::numeric desc), '[]'::jsonb) from (
              select jsonb_build_object('name_ar', max(name_ar), 'name_en', max(name_en), 'qty', sum(qty), 'sales', sum(line_total)) t
                from items group by coalesce(menu_item_id::text, name_en)
               order by sum(qty) desc, sum(line_total) desc limit 10) z),
    'top_options', (select coalesce(jsonb_agg(t order by (t->>'qty')::int desc), '[]'::jsonb) from (
              select jsonb_build_object('name_ar', max(op->>'name_ar'), 'name_en', max(op->>'name_en'),
                                        'group_ar', max(op->>'group_ar'), 'group_en', max(op->>'group_en'),
                                        'qty', sum(i.qty), 'sales', sum(coalesce((op->>'price')::numeric,0) * i.qty)) t
                from items i cross join lateral jsonb_array_elements(coalesce(i.options,'[]'::jsonb)) op
               group by op->>'group_en', op->>'name_en'
               order by sum(i.qty) desc limit 10) z),
    'ops', (select jsonb_build_object(
              'avg_prep', round(avg(extract(epoch from ready_at - accepted_at)/60) filter (where ready_at is not null and accepted_at is not null)::numeric, 1),
              'avg_estimated', round(avg(estimated_minutes) filter (where estimated_minutes is not null)::numeric, 1),
              'avg_total_wait', round(avg(extract(epoch from ready_at - created_at)/60) filter (where ready_at is not null)::numeric, 1),
              'on_time_pct', case when count(*) filter (where ready_at is not null and estimated_ready_at is not null) = 0 then null
                                  else round(100.0 * count(*) filter (where ready_at <= estimated_ready_at + interval '1 minute')
                                       / count(*) filter (where ready_at is not null and estimated_ready_at is not null), 1) end,
              'measured', count(*) filter (where ready_at is not null and accepted_at is not null),
              'arrived', count(*) filter (where arrived_at is not null)
            ) from ok),
    'payments', (select jsonb_build_object(
              'cash_orders', count(*) filter (where payment_method = 'cash'),
              'cash_sales', coalesce(sum(total) filter (where payment_method = 'cash'),0),
              'cash_collected', coalesce(sum(total) filter (where payment_method = 'cash' and payment_status = 'paid'),0),
              'cash_uncollected', coalesce(sum(total) filter (where payment_method = 'cash' and payment_status <> 'paid'),0),
              'card_orders', count(*) filter (where payment_method = 'card'),
              'card_sales', coalesce(sum(total) filter (where payment_method = 'card'),0)
            ) from ok)
  ) into res;
  return res;
end $$;

drop function if exists public.owner_report_rows(uuid, date, date);
create or replace function public.owner_report_rows(p_restaurant uuid, p_from date, p_to date)
returns table(order_number int, created_local timestamp, status text, payment_method text, payment_status text,
              subtotal numeric, discount numeric, coupon_code text, total numeric, currency text, scheduled_local timestamp, items text, customer_name text, customer_phone text,
              car text, car_plate text, parking_spot text, estimated_minutes int, actual_minutes numeric)
language plpgsql stable security definer set search_path = public as $$
declare tz text;
begin
  if not public.is_owner(p_restaurant) and not public.is_platform_admin() then raise exception 'NOT_ALLOWED'; end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then raise exception 'BAD_RANGE'; end if;
  select coalesce(r.timezone,'Asia/Muscat') into tz from public.restaurants r where r.id = p_restaurant;
  return query
  select o.order_number, (o.created_at at time zone tz), o.status, o.payment_method, o.payment_status,
         o.subtotal, o.discount, o.coupon_code, o.total, o.currency, (o.scheduled_for at time zone tz),
         (select string_agg(oi.qty || 'x ' || oi.name_ar ||
                   coalesce(' (' || (select string_agg(op->>'name_ar', ', ') from jsonb_array_elements(coalesce(oi.options,'[]'::jsonb)) op) || ')', ''), ' | ')
            from public.order_items oi where oi.order_id = o.id),
         o.customer_name, o.customer_phone,
         concat_ws(' ', o.car_make, o.car_color), o.car_plate, o.parking_spot, o.estimated_minutes,
         round((extract(epoch from o.ready_at - o.accepted_at)/60)::numeric, 1)
    from public.orders o
   where o.restaurant_id = p_restaurant
     and o.created_at >= (p_from::timestamp at time zone tz)
     and o.created_at <  ((p_to + 1)::timestamp at time zone tz)
     and o.status <> 'awaiting_payment'
   order by o.created_at;
end $$;

revoke execute on function public.owner_report_rows(uuid, date, date) from public, anon;
grant execute on function public.owner_report_rows(uuid, date, date) to authenticated;
