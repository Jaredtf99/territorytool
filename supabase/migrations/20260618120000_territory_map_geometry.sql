alter table public.territories
  add column if not exists map_geometry jsonb;

comment on column public.territories.map_geometry is
  'Normalized geometry imported from the Google My Maps KML export.';

create or replace view public.territory_current_state
with (security_invoker = true)
as
select
  t.id,
  t.code,
  t.name,
  t.map_url,
  t.image_path,
  t.archived,
  open_tx.id as active_transaction_id,
  open_tx.person_id,
  p.name as person_name,
  open_tx.given_at,
  last_picked.last_picked_at,
  t.congregation_id,
  t.map_geometry
from public.territories t
left join public.territory_transactions open_tx
  on open_tx.territory_id = t.id
 and open_tx.picked_at is null
left join public.persons p
  on p.id = open_tx.person_id
left join lateral (
  select max(tt.picked_at) as last_picked_at
  from public.territory_transactions tt
  where tt.territory_id = t.id
) last_picked on true;

create or replace view public.territory_details
with (security_invoker = true)
as
select
  t.id as territory_id,
  t.code,
  t.name,
  t.map_url,
  t.image_path,
  t.archived,
  tt.id as transaction_id,
  tt.person_id,
  p.name as person_name,
  tt.given_at,
  tt.picked_at,
  tt.is_automatic_given_date,
  tt.is_automatic_picked_date,
  given.username as given_by_username,
  picked.username as picked_by_username,
  t.congregation_id,
  t.map_geometry
from public.territories t
left join public.territory_transactions tt on tt.territory_id = t.id
left join public.persons p on p.id = tt.person_id
left join public.profiles given on given.id = tt.given_by
left join public.profiles picked on picked.id = tt.picked_by;
