-- Dashboard priority should only surface territories at or beyond the attention threshold.

create or replace function public.get_dashboard_snapshot(
  p_week_start timestamptz,
  p_timezone text default 'UTC',
  p_attention_days integer default 90
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
  transaction_base as (
    select
      tt.id,
      tt.territory_id,
      tt.person_id,
      tt.given_at,
      tt.picked_at,
      t.code as territory_code,
      t.name as territory_name,
      p.name as person_name,
      given.username::text as given_by_username,
      picked.username::text as picked_by_username
    from public.territory_transactions tt
    join public.territories t on t.id = tt.territory_id
    join public.persons p on p.id = tt.person_id
    join public.profiles given on given.id = tt.given_by
    left join public.profiles picked on picked.id = tt.picked_by
    where tt.congregation_id = v_cong
  ),
  all_events as (
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
      picked_at,
      given_by_username as actor_name
    from transaction_base
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
      picked_at,
      picked_by_username
    from transaction_base
    where picked_at is not null
  ),
  weekly_events as (
    select *
    from all_events
    where event_date >= p_week_start
      and event_date < v_week_end
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
      and given_at <= v_now - make_interval(days => greatest(p_attention_days, 0))
    order by given_at asc, id asc
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
        'pickedAt', picked_at,
        'actorName', actor_name
      ) order by event_date desc)
      from weekly_events
    ), '[]'::jsonb),
    'recentEvents', coalesce((
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
        'pickedAt', picked_at,
        'actorName', actor_name
      ) order by event_date desc)
      from (
        select *
        from all_events
        order by event_date desc
        limit 4
      ) recent
    ), '[]'::jsonb),
    'hasMoreRecentEvents', (select count(*) > 4 from all_events),
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
