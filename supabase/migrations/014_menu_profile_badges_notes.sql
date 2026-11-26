-- Restaurant type + opening hours, item badges (top seller / top rated / new), per-line customer notes.
alter table public.restaurants
  add column if not exists kind_ar text,
  add column if not exists kind_en text,
  add column if not exists open_time time,
  add column if not exists close_time time;
grant update (kind_ar, kind_en, open_time, close_time) on public.restaurants to authenticated;

alter table public.menu_items add column if not exists badge text;
alter table public.menu_items drop constraint if exists menu_items_badge_check;
alter table public.menu_items add constraint menu_items_badge_check check (badge is null or badge in ('top_seller','top_rated','new'));

alter table public.order_items add column if not exists note text;

-- place_order: store an optional per-line note (max 140 chars) from p_items[].note
do $$
declare d text;
begin
  d := pg_get_functiondef('public.place_order(text,jsonb,jsonb)'::regprocedure);
  if position('prep_minutes, options, note)' in d) = 0 then
    d := replace(d, 'line_total, prep_minutes, options)', 'line_total, prep_minutes, options, note)');
    d := replace(d, 'm.prep_minutes, v_snap);', 'm.prep_minutes, v_snap, left(nullif(trim(v_item->>''note''), ''''), 140));');
    if position('options, note)' in d) = 0 or position('v_snap, left(' in d) = 0 then raise exception 'patch failed'; end if;
    execute d;
  end if;
end $$;
