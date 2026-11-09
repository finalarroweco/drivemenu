create or replace function public.tg_orders_require_phone()
returns trigger language plpgsql set search_path = public as $$
begin
  if length(regexp_replace(coalesce(new.customer_phone, ''), '\D', '', 'g')) < 7 then
    raise exception 'PHONE_REQUIRED';
  end if;
  return new;
end $$;
create trigger orders_require_phone before insert on public.orders
for each row execute function public.tg_orders_require_phone();
revoke execute on function public.tg_orders_require_phone() from public, anon, authenticated;
