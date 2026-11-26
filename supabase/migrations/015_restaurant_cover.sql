alter table public.restaurants add column if not exists cover_url text;
grant update (cover_url) on public.restaurants to authenticated;
