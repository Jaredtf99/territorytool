-- Ficha de hermano: perfil, resumen comparado con la congregación, territorios
-- en curso, actividad mensual, territorios más trabajados e historial completo
-- en una sola llamada. `security invoker`: RLS limita todo a la congregación
-- activa (y oculta territorios archivados / hermanos inactivos a no-admins).

create or replace function public.get_person_detail(
  p_person_id integer,
  p_timezone text default 'UTC'
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
  v_tz text := coalesce(nullif(btrim(p_timezone), ''), 'UTC');
  v_person public.persons%rowtype;
  v_result jsonb;
begin
  if v_cong is null then
    raise exception 'NO_ACTIVE_CONGREGATION' using errcode = '42501';
  end if;

  -- Zona horaria inválida: se cae a UTC en vez de reventar la pantalla.
  if not exists (select 1 from pg_timezone_names where name = v_tz) then
    v_tz := 'UTC';
  end if;

  select * into v_person
  from public.persons p
  where p.id = p_person_id
    and p.congregation_id = v_cong;

  if not found then
    raise exception 'PERSON_NOT_FOUND' using errcode = 'P0002';
  end if;

  with
  person_tx as (
    select
      tt.id,
      tt.territory_id,
      t.code::text as territory_code,
      t.name as territory_name,
      t.map_geometry,
      tt.given_at,
      tt.picked_at,
      tt.delivery_format,
      given.username::text as given_by_username,
      picked.username::text as picked_by_username,
      greatest(
        floor(extract(epoch from (coalesce(tt.picked_at, v_now) - tt.given_at)) / 86400),
        0
      )::integer as days
    from public.territory_transactions tt
    join public.territories t on t.id = tt.territory_id
    left join public.profiles given on given.id = tt.given_by
    left join public.profiles picked on picked.id = tt.picked_by
    where tt.person_id = p_person_id
      and tt.congregation_id = v_cong
  ),
  completed as (
    select * from person_tx where picked_at is not null
  ),
  congregation_completed as (
    select
      tt.person_id,
      extract(epoch from (tt.picked_at - tt.given_at)) / 86400 as days
    from public.territory_transactions tt
    where tt.congregation_id = v_cong
      and tt.picked_at is not null
  ),
  person_usage as (
    select
      tt.person_id,
      count(*)::integer as usage_count
    from public.territory_transactions tt
    where tt.congregation_id = v_cong
    group by tt.person_id
  ),
  months as (
    select (date_trunc('month', v_now at time zone v_tz) - make_interval(months => offs))::date as month_start
    from generate_series(0, 11) as offs
  ),
  monthly as (
    select
      m.month_start,
      (
        select count(*)::integer
        from person_tx tx
        where date_trunc('month', tx.given_at at time zone v_tz)::date = m.month_start
      ) as given_count,
      (
        select count(*)::integer
        from person_tx tx
        where tx.picked_at is not null
          and date_trunc('month', tx.picked_at at time zone v_tz)::date = m.month_start
      ) as returned_count
    from months m
  ),
  top_territories as (
    select
      territory_id,
      territory_code,
      territory_name,
      count(*)::integer as times,
      max(given_at) as last_given_at,
      coalesce(sum(days), 0)::integer as total_days
    from person_tx
    group by territory_id, territory_code, territory_name
    -- Solo los repetidos: con una sola vez el ranking no aporta nada.
    having count(*) > 1
    order by count(*) desc, max(given_at) desc
    limit 5
  )
  select jsonb_build_object(
    'generatedAt', v_now,
    'person', jsonb_build_object(
      'id', v_person.id,
      'name', v_person.name,
      'enabled', v_person.enabled,
      'createdAt', v_person.created_at
    ),
    'summary', jsonb_build_object(
      'totalAssignments', (select count(*)::integer from person_tx),
      'activeAssignments', (select count(*)::integer from person_tx where picked_at is null),
      'completedAssignments', (select count(*)::integer from completed),
      'uniqueTerritories', (select count(distinct territory_id)::integer from person_tx),
      'virtualAssignments', (select count(*)::integer from person_tx where delivery_format = 'virtual'),
      'averageHoldingDays', (select round(avg(days)::numeric, 1) from completed),
      'congregationAverageHoldingDays', (select round(avg(days)::numeric, 1) from congregation_completed),
      'longestHoldingDays', (select max(days) from person_tx),
      'firstAssignmentAt', (select min(given_at) from person_tx),
      'lastAssignmentAt', (select max(given_at) from person_tx),
      'lastReturnAt', (select max(picked_at) from person_tx),
      'assignmentsLastYear', (
        select count(*)::integer from person_tx where given_at >= v_now - interval '1 year'
      ),
      'activityRank', (
        select r.rank
        from (
          select
            pu.person_id,
            (rank() over (order by pu.usage_count desc))::integer as rank
          from person_usage pu
        ) r
        where r.person_id = p_person_id
      ),
      'activePersonsCount', (select count(*)::integer from person_usage)
    ),
    'current', coalesce((
      select jsonb_agg(jsonb_build_object(
        'transactionId', tx.id,
        'territoryId', tx.territory_id,
        'territoryCode', tx.territory_code,
        'territoryName', tx.territory_name,
        'givenAt', tx.given_at,
        'days', tx.days,
        'deliveryFormat', tx.delivery_format,
        'givenBy', tx.given_by_username,
        'mapGeometry', tx.map_geometry
      ) order by tx.given_at asc)
      from person_tx tx
      where tx.picked_at is null
    ), '[]'::jsonb),
    'activity', coalesce((
      select jsonb_agg(jsonb_build_object(
        'month', to_char(m.month_start, 'YYYY-MM-DD'),
        'givenCount', m.given_count,
        'returnedCount', m.returned_count
      ) order by m.month_start asc)
      from monthly m
    ), '[]'::jsonb),
    'topTerritories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'territoryId', tt.territory_id,
        'territoryCode', tt.territory_code,
        'territoryName', tt.territory_name,
        'times', tt.times,
        'totalDays', tt.total_days,
        'lastGivenAt', tt.last_given_at
      ) order by tt.times desc, tt.last_given_at desc)
      from top_territories tt
    ), '[]'::jsonb),
    'history', coalesce((
      select jsonb_agg(jsonb_build_object(
        'transactionId', tx.id,
        'territoryId', tx.territory_id,
        'territoryCode', tx.territory_code,
        'territoryName', tx.territory_name,
        'givenAt', tx.given_at,
        'pickedAt', tx.picked_at,
        'days', tx.days,
        'deliveryFormat', tx.delivery_format,
        'givenBy', tx.given_by_username,
        'pickedBy', tx.picked_by_username
      ) order by tx.given_at desc, tx.id desc)
      from person_tx tx
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;

revoke all on function public.get_person_detail(integer, text) from public, anon;
grant execute on function public.get_person_detail(integer, text) to authenticated, service_role;

select pg_notify('pgrst', 'reload schema');
