-- Dashboard snapshot and contextual quick-action lookups.

create or replace function public.get_dashboard_snapshot(
  p_week_start timestamptz,
  p_timezone text default 'UTC',
  p_attention_days integer default 120
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_cong uuid := public.current_congregation_id();
  v_now timestamptz := now();
  v_week_end timestamptz := p_week_start + interval '7 days';
  v_result jsonb;
begin
  if v_cong is null then
    raise exception 'NO_ACTIVE_CONGREGATION' using errcode = '42501';
  end if;

  with
  current_territories as (
    select *
    from public.territory_current_state
    where congregation_id = v_cong
      and archived = false
  ),
  totals as (
    select
      count(*)::integer as total,
      count(*) filter (where person_id is null)::integer as free,
      count(*) filter (where person_id is not null)::integer as in_use
    from current_territories
  ),
  weekly_transactions as (
    select
      tt.id,
      tt.territory_id,
      tt.person_id,
      tt.given_at,
      tt.picked_at,
      t.code as territory_code,
      t.name as territory_name,
      p.name as person_name
    from public.territory_transactions tt
    join public.territories t on t.id = tt.territory_id
    join public.persons p on p.id = tt.person_id
    where tt.congregation_id = v_cong
      and (
        (tt.given_at >= p_week_start and tt.given_at < v_week_end)
        or (tt.picked_at >= p_week_start and tt.picked_at < v_week_end)
      )
  ),
  weekly_events as (
    select
      id as transaction_id,
      'given'::text as event_type,
      given_at as event_date,
      territory_id,
      territory_code,
      territory_name,
      person_id,
      person_name,
      given_at,
      picked_at
    from weekly_transactions
    where given_at >= p_week_start and given_at < v_week_end
    union all
    select
      id,
      'returned'::text,
      picked_at,
      territory_id,
      territory_code,
      territory_name,
      person_id,
      person_name,
      given_at,
      picked_at
    from weekly_transactions
    where picked_at >= p_week_start and picked_at < v_week_end
  ),
  days as (
    select generate_series(0, 6) as day_offset
  ),
  daily_activity as (
    select
      ((p_week_start at time zone p_timezone)::date + day_offset)::date as activity_date,
      count(e.*) filter (where e.event_type = 'given')::integer as given_count,
      count(e.*) filter (where e.event_type = 'returned')::integer as returned_count
    from days
    left join weekly_events e
      on (e.event_date at time zone p_timezone)::date =
         ((p_week_start at time zone p_timezone)::date + day_offset)::date
    group by day_offset
    order by day_offset
  ),
  priority as (
    select *
    from current_territories
    where person_id is not null
    order by given_at asc nulls last, id asc
    limit 1
  ),
  attention as (
    select *
    from current_territories
    where person_id is not null
      and given_at <= v_now - make_interval(days => greatest(p_attention_days, 0))
    order by given_at asc, id asc
  )
  select jsonb_build_object(
    'generatedAt', v_now,
    'totals', jsonb_build_object(
      'total', totals.total,
      'free', totals.free,
      'inUse', totals.in_use,
      'givenThisWeek', (
        select count(*)::integer from weekly_events where event_type = 'given'
      )
    ),
    'priority', (
      select jsonb_build_object(
        'territoryId', id,
        'code', code,
        'name', name,
        'personId', person_id,
        'personName', person_name,
        'givenAt', given_at,
        'mapUrl', map_url,
        'imagePath', image_path,
        'mapGeometry', map_geometry
      )
      from priority
    ),
    'activity', coalesce((
      select jsonb_agg(jsonb_build_object(
        'date', activity_date,
        'givenCount', given_count,
        'returnedCount', returned_count
      ) order by activity_date)
      from daily_activity
    ), '[]'::jsonb),
    'weeklyEvents', coalesce((
      select jsonb_agg(jsonb_build_object(
        'transactionId', transaction_id,
        'eventType', event_type,
        'eventDate', event_date,
        'territoryId', territory_id,
        'territoryCode', territory_code,
        'territoryName', territory_name,
        'personId', person_id,
        'personName', person_name,
        'givenAt', given_at,
        'pickedAt', picked_at
      ) order by event_date desc)
      from weekly_events
    ), '[]'::jsonb),
    'latestEvent', (
      select jsonb_build_object(
        'transactionId', transaction_id,
        'eventType', event_type,
        'eventDate', event_date,
        'territoryId', territory_id,
        'territoryCode', territory_code,
        'territoryName', territory_name,
        'personId', person_id,
        'personName', person_name,
        'givenAt', given_at,
        'pickedAt', picked_at
      )
      from weekly_events
      order by event_date desc
      limit 1
    ),
    'attentionTerritories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'territoryId', id,
        'code', code,
        'name', name,
        'personName', person_name,
        'givenAt', given_at,
        'mapBounds', map_geometry -> 'bounds'
      ) order by given_at asc)
      from attention
    ), '[]'::jsonb)
  )
  into v_result
  from totals;

  return v_result;
end;
$$;

create or replace function public.search_persons_with_assignments(
  term text default null,
  take integer default 100
)
returns table (
  id integer,
  name text,
  enabled boolean,
  territories_in_use jsonb
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select
    p.id,
    p.name,
    p.enabled,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'territoryId', t.id,
          'territoryCode', t.code,
          'territoryName', t.name,
          'givenDate', tt.given_at
        )
        order by tt.given_at asc
      ) filter (where t.id is not null),
      '[]'::jsonb
    ) as territories_in_use
  from public.persons p
  left join public.territory_transactions tt
    on tt.person_id = p.id
   and tt.picked_at is null
   and tt.congregation_id = public.current_congregation_id()
  left join public.territories t
    on t.id = tt.territory_id
   and t.archived = false
  where p.congregation_id = public.current_congregation_id()
    and (p.enabled or tt.id is not null)
    and (
      term is null
      or btrim(term) = ''
      or public.immutable_unaccent(lower(p.name)) % public.immutable_unaccent(lower(term))
      or public.immutable_unaccent(lower(p.name)) like '%' || public.immutable_unaccent(lower(term)) || '%'
    )
  group by p.id, p.name, p.enabled
  order by
    case when term is null or btrim(term) = '' then 0
      else similarity(public.immutable_unaccent(lower(p.name)), public.immutable_unaccent(lower(term)))
    end desc,
    p.name
  limit greatest(take, 0);
$$;

create or replace function public.resolve_territory_selector(value text)
returns setof public.territory_current_state
language sql
stable
security invoker
set search_path = public
as $$
  select t.*
  from public.territory_current_state t
  where t.congregation_id = public.current_congregation_id()
    and t.archived = false
    and (
      lower(t.code::text) = lower(btrim(value))
      or split_part(t.map_url, '?', 1) = split_part(btrim(value), '?', 1)
    )
  order by t.id
  limit 1;
$$;

revoke all on function public.get_dashboard_snapshot(timestamptz, text, integer) from public;
revoke all on function public.search_persons_with_assignments(text, integer) from public;
revoke all on function public.resolve_territory_selector(text) from public;

grant execute on function public.get_dashboard_snapshot(timestamptz, text, integer) to authenticated;
grant execute on function public.search_persons_with_assignments(text, integer) to authenticated;
grant execute on function public.resolve_territory_selector(text) to authenticated;
