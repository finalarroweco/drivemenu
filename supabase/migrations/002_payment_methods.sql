-- Card or cash on pickup, configurable per restaurant
alter table public.restaurants
  add column accept_card boolean not null default true,
  add column accept_cash boolean not null default true;
alter table public.restaurants add constraint restaurants_payment_any check (accept_card or accept_cash);
alter table public.orders add column payment_method text check (payment_method in ('card','cash'));
grant update (accept_card, accept_cash) on public.restaurants to authenticated;
-- confirm_cash_order / pay_order_test / staff_update_order / get_order: final versions in 011 and 012
revoke execute on function public.confirm_cash_order(uuid, uuid) from public;
grant execute on function public.confirm_cash_order(uuid, uuid) to anon, authenticated;
