-- Coupon limits count only confirmed orders; re-checked when an order is confirmed (cash or card)
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
     where o.coupon_id = c.id and o.status not in ('cancelled','awaiting_payment');
    if v_used >= c.max_uses then raise exception 'COUPON_USED_UP'; end if;
  end if;
  if c.per_phone_limit is not null then
    v_phone := right(regexp_replace(coalesce(p_phone,''), '\D', '', 'g'), 8);
    if length(v_phone) >= 7 then
      select count(*) into v_used from public.orders o
       where o.coupon_id = c.id and o.status not in ('cancelled','awaiting_payment')
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

create or replace function public.coupon_recheck(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare o public.orders; c public.coupons; v_used int; v_phone text;
begin
  select * into o from public.orders where id = p_order;
  if o.coupon_id is null then return; end if;
  select * into c from public.coupons where id = o.coupon_id;
  if not found then return; end if;
  perform pg_advisory_xact_lock(hashtext('coupon:' || c.id::text));
  if c.max_uses is not null then
    select count(*) into v_used from public.orders x
     where x.coupon_id = c.id and x.id <> o.id and x.status not in ('cancelled','awaiting_payment');
    if v_used >= c.max_uses then raise exception 'COUPON_USED_UP'; end if;
  end if;
  if c.per_phone_limit is not null then
    v_phone := right(regexp_replace(coalesce(o.customer_phone,''), '\D', '', 'g'), 8);
    select count(*) into v_used from public.orders x
     where x.coupon_id = c.id and x.id <> o.id and x.status not in ('cancelled','awaiting_payment')
       and right(regexp_replace(coalesce(x.customer_phone,''), '\D', '', 'g'), 8) = v_phone;
    if v_used >= c.per_phone_limit then raise exception 'COUPON_PHONE_LIMIT'; end if;
  end if;
end $$;
revoke execute on function public.coupon_recheck(uuid) from public, anon, authenticated;

-- confirm_cash_order and pay_order_test call `perform public.coupon_recheck(o.id);`
-- right before `v_min := public.estimate_minutes(o.restaurant_id, o.id);`
do $do$
declare f text; d text; d2 text;
begin
  foreach f in array array['public.confirm_cash_order(uuid,uuid)', 'public.pay_order_test(uuid,uuid,text,boolean)'] loop
    d := pg_get_functiondef(f::regprocedure);
    if position('coupon_recheck' in d) > 0 then continue; end if;
    d2 := replace(d, '  v_min := public.estimate_minutes(o.restaurant_id, o.id);', '  perform public.coupon_recheck(o.id);
  v_min := public.estimate_minutes(o.restaurant_id, o.id);');
    execute d2;
  end loop;
end $do$;
