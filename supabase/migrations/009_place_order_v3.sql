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
  g jsonb;
  ch jsonb;
  v_sel jsonb;
  v_sel_count int;
  v_extra numeric(10,3);
  v_snap jsonb;
  v_cid text;
  v_sched timestamptz;
  v_coupon_id uuid;
  v_coupon_code text;
  v_discount numeric(10,3) := 0;
begin
  select * into r from public.restaurants where slug = p_slug;
  if not found then raise exception 'RESTAURANT_NOT_FOUND'; end if;
  if not r.is_open then raise exception 'RESTAURANT_CLOSED'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'EMPTY_CART'; end if;
  if jsonb_array_length(p_items) > 40 then raise exception 'CART_TOO_LARGE'; end if;
  if coalesce(trim(p_customer->>'car_plate'), '') = '' then raise exception 'CAR_PLATE_REQUIRED'; end if;

  if coalesce(p_customer->>'scheduled_for', '') <> '' then
    if not r.preorder_enabled then raise exception 'PREORDER_DISABLED'; end if;
    begin
      v_sched := (p_customer->>'scheduled_for')::timestamptz;
    exception when others then raise exception 'BAD_SCHEDULE';
    end;
    if v_sched < now() + interval '10 minutes' or v_sched > now() + make_interval(hours => r.preorder_max_hours) + interval '5 minutes' then
      raise exception 'BAD_SCHEDULE';
    end if;
  end if;

  perform pg_advisory_xact_lock(hashtext(r.id::text));
  select coalesce(max(order_number), 0) + 1 into v_number from public.orders
   where restaurant_id = r.id
     and (created_at at time zone r.timezone)::date = (now() at time zone r.timezone)::date;

  insert into public.orders(restaurant_id, order_number, customer_name, customer_phone, car_make, car_color,
                            car_plate, parking_spot, notes, subtotal, total, currency, scheduled_for)
  values (r.id, v_number,
          left(nullif(trim(p_customer->>'name'),''), 60),
          left(nullif(trim(p_customer->>'phone'),''), 20),
          left(nullif(trim(p_customer->>'car_make'),''), 40),
          left(nullif(trim(p_customer->>'car_color'),''), 30),
          left(trim(p_customer->>'car_plate'), 20),
          left(nullif(trim(p_customer->>'parking_spot'),''), 20),
          left(nullif(trim(p_customer->>'notes'),''), 300),
          0, 0, r.currency, v_sched)
  returning id, access_token into v_order, v_token;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'qty')::int;
    if v_qty is null or v_qty < 1 or v_qty > 50 then raise exception 'BAD_QTY'; end if;
    select * into m from public.menu_items where id = (v_item->>'id')::uuid and restaurant_id = r.id;
    if not found then raise exception 'ITEM_NOT_FOUND'; end if;
    if not m.is_available then raise exception 'ITEM_UNAVAILABLE:%', m.name_en; end if;

    v_extra := 0; v_snap := '[]'::jsonb;
    for g in select * from jsonb_array_elements(coalesce(m.options, '[]'::jsonb)) loop
      v_sel := coalesce(v_item->'options'->(g->>'id'), '[]'::jsonb);
      if jsonb_typeof(v_sel) <> 'array' then raise exception 'BAD_OPTIONS'; end if;
      v_sel_count := jsonb_array_length(v_sel);
      if coalesce((g->>'required')::boolean, false) and v_sel_count = 0 then raise exception 'OPTION_REQUIRED:%', g->>'name_en'; end if;
      if coalesce(g->>'type', 'single') = 'single' and v_sel_count > 1 then raise exception 'BAD_OPTIONS'; end if;
      for v_cid in select jsonb_array_elements_text(v_sel) loop
        select c into ch from jsonb_array_elements(g->'choices') c where c->>'id' = v_cid;
        if ch is null then raise exception 'BAD_OPTIONS'; end if;
        v_extra := v_extra + coalesce((ch->>'price')::numeric, 0);
        v_snap := v_snap || jsonb_build_array(jsonb_build_object(
          'group_ar', g->>'name_ar', 'group_en', g->>'name_en',
          'name_ar', ch->>'name_ar', 'name_en', ch->>'name_en', 'price', coalesce((ch->>'price')::numeric, 0)));
        ch := null;
      end loop;
    end loop;

    insert into public.order_items(order_id, menu_item_id, name_ar, name_en, unit_price, qty, line_total, prep_minutes, options)
    values (v_order, m.id, m.name_ar, m.name_en, m.price + v_extra, v_qty, (m.price + v_extra) * v_qty, m.prep_minutes, v_snap);
    v_subtotal := v_subtotal + (m.price + v_extra) * v_qty;
  end loop;

  if coalesce(trim(p_customer->>'coupon'), '') <> '' then
    select e.coupon_id, e.code, e.discount into v_coupon_id, v_coupon_code, v_discount
      from public.coupon_eval(r.id, p_customer->>'coupon', v_subtotal, p_customer->>'phone') e;
  end if;

  update public.orders set subtotal = v_subtotal, discount = v_discount, total = v_subtotal - v_discount,
         coupon_id = v_coupon_id, coupon_code = v_coupon_code
   where id = v_order;

  return jsonb_build_object('order_id', v_order, 'token', v_token, 'order_number', v_number,
                            'subtotal', v_subtotal, 'discount', v_discount,
                            'total', v_subtotal - v_discount, 'currency', r.currency, 'payment_mode', r.payment_mode,
                            'accept_card', r.accept_card, 'accept_cash', r.accept_cash, 'scheduled_for', v_sched,
                            'estimated_minutes', public.estimate_minutes(r.id, v_order));
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
    'payment_method', o.payment_method,
    'subtotal', o.subtotal, 'discount', o.discount, 'coupon_code', o.coupon_code, 'scheduled_for', o.scheduled_for,
    'total', o.total, 'currency', o.currency, 'car_make', o.car_make, 'car_color', o.car_color,
    'car_plate', o.car_plate, 'parking_spot', o.parking_spot, 'customer_name', o.customer_name,
    'estimated_minutes', o.estimated_minutes, 'estimated_ready_at', o.estimated_ready_at,
    'arrived_at', o.arrived_at, 'created_at', o.created_at, 'card_last4', o.card_last4,
    'payment_mode', r.payment_mode,
    'restaurant', jsonb_build_object('slug', r.slug, 'name_ar', r.name_ar, 'name_en', r.name_en,
                                     'logo_url', r.logo_url, 'phone', r.phone),
    'items', coalesce((select jsonb_agg(jsonb_build_object('name_ar', i.name_ar, 'name_en', i.name_en,
                         'qty', i.qty, 'unit_price', i.unit_price, 'line_total', i.line_total, 'options', i.options))
                       from public.order_items i where i.order_id = o.id), '[]'::jsonb),
    'server_now', now());
end $$;
