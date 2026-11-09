-- Item options / extras
-- menu_items.options: [{"id","name_ar","name_en","type":"single"|"multi","required",
--   "choices":[{"id","name_ar","name_en","price"}]}]
-- order_items.options: snapshot of chosen choices with group names and prices
alter table public.menu_items add column options jsonb not null default '[]'::jsonb;
alter table public.order_items add column options jsonb not null default '[]'::jsonb;
-- place_order with option validation: final version in 012
