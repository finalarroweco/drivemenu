alter table public.restaurants add column if not exists location_url text, add column if not exists address_ar text, add column if not exists address_en text;
alter table public.restaurants drop constraint if exists restaurants_location_url_check;
alter table public.restaurants add constraint restaurants_location_url_check check (location_url is null or location_url ~* '^https://');
grant update (location_url, address_ar, address_en) on public.restaurants to authenticated;
