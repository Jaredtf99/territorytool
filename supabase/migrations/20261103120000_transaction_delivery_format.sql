-- Formato de entrega de cada transacción: físico (por defecto) o virtual.

alter table public.territory_transactions
  add column if not exists delivery_format text not null default 'physical';

alter table public.territory_transactions
  drop constraint if exists territory_transactions_delivery_format_check;
alter table public.territory_transactions
  add constraint territory_transactions_delivery_format_check
  check (delivery_format in ('physical', 'virtual'));

-- Vistas: la columna nueva va al final para que `create or replace view` sea válido.
create or replace view public.territory_current_state
with (security_invoker = true) as
 SELECT t.id,
    t.code,
    t.name,
    t.map_url,
    t.image_path,
    t.archived,
    open_tx.id AS active_transaction_id,
    open_tx.person_id,
    p.name AS person_name,
    open_tx.given_at,
    last_picked.last_picked_at,
    t.congregation_id,
    t.map_geometry,
    open_tx.delivery_format
   FROM territories t
     LEFT JOIN territory_transactions open_tx ON open_tx.territory_id = t.id AND open_tx.picked_at IS NULL
     LEFT JOIN persons p ON p.id = open_tx.person_id
     LEFT JOIN LATERAL ( SELECT max(tt.picked_at) AS last_picked_at
           FROM territory_transactions tt
          WHERE tt.territory_id = t.id) last_picked ON true;

create or replace view public.territory_details
with (security_invoker = true) as
 SELECT t.id AS territory_id,
    t.code,
    t.name,
    t.map_url,
    t.image_path,
    t.archived,
    tt.id AS transaction_id,
    tt.person_id,
    p.name AS person_name,
    tt.given_at,
    tt.picked_at,
    tt.is_automatic_given_date,
    tt.is_automatic_picked_date,
    given.username AS given_by_username,
    picked.username AS picked_by_username,
    t.congregation_id,
    t.map_geometry,
    tt.delivery_format
   FROM territories t
     LEFT JOIN territory_transactions tt ON tt.territory_id = t.id
     LEFT JOIN persons p ON p.id = tt.person_id
     LEFT JOIN profiles given ON given.id = tt.given_by
     LEFT JOIN profiles picked ON picked.id = tt.picked_by;

create or replace view public.recent_transactions
with (security_invoker = true) as
 SELECT tt.id AS transaction_id,
    tt.territory_id,
    t.name AS territory_name,
    t.code AS territory_code,
    tt.person_id,
    p.name AS person_name,
    tt.given_at,
    tt.picked_at,
    tt.is_automatic_given_date,
    tt.is_automatic_picked_date,
    given.username AS given_by_username,
    picked.username AS picked_by_username,
    tt.congregation_id,
    tt.delivery_format
   FROM territory_transactions tt
     JOIN territories t ON t.id = tt.territory_id
     JOIN persons p ON p.id = tt.person_id
     JOIN profiles given ON given.id = tt.given_by
     LEFT JOIN profiles picked ON picked.id = tt.picked_by
  WHERE tt.given_at >= (now() - '3 days'::interval) OR tt.picked_at >= (now() - '3 days'::interval);

-- Edición de transacciones: `delivery_format` opcional (null conserva el actual) para
-- que los clientes que aún no lo envían sigan funcionando.
drop function if exists public.update_transaction(integer, integer, timestamptz, timestamptz);
drop function if exists public.update_transaction_undoable(integer, integer, timestamptz, timestamptz);

create or replace function public.update_transaction(
  transaction_id integer,
  person_id integer,
  given_at timestamptz,
  picked_at timestamptz default null,
  delivery_format text default null
)
returns public.territory_transactions
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid := public.require_admin(); v_cong uuid := public.require_congregation();
  v_existing public.territory_transactions%rowtype; v_result public.territory_transactions%rowtype;
begin
  if picked_at is not null and picked_at < given_at then raise exception 'INVALID_DATES' using errcode = '22007'; end if;
  if delivery_format is not null and delivery_format not in ('physical', 'virtual') then raise exception 'INVALID_DELIVERY_FORMAT' using errcode = '22023'; end if;
  if not exists (select 1 from public.persons p where p.id = update_transaction.person_id and p.congregation_id = v_cong and p.enabled = true) then raise exception 'PERSON_NOT_FOUND' using errcode = 'P0002'; end if;
  select * into v_existing from public.territory_transactions tt where tt.id = update_transaction.transaction_id and tt.congregation_id = v_cong for update;
  if not found then raise exception 'TRANSACTION_NOT_FOUND' using errcode = 'P0002'; end if;
  if picked_at is null and exists (select 1 from public.territory_transactions tt where tt.territory_id = v_existing.territory_id and tt.picked_at is null and tt.id <> update_transaction.transaction_id) then raise exception 'TERRITORY_ALREADY_IN_USE' using errcode = '23505'; end if;
  update public.territory_transactions tt set person_id = update_transaction.person_id, given_at = update_transaction.given_at, picked_at = update_transaction.picked_at,
      picked_by = case when update_transaction.picked_at is null then null else coalesce(tt.picked_by, v_user_id) end,
      is_automatic_picked_date = case when update_transaction.picked_at is null then null else coalesce(tt.is_automatic_picked_date, false) end,
      delivery_format = coalesce(update_transaction.delivery_format, tt.delivery_format)
  where tt.id = update_transaction.transaction_id returning * into v_result;
  perform public.add_action_log(14, format('Transaction %s updated', transaction_id), v_user_id, true);
  return v_result;
end; $function$;

create or replace function public.update_transaction_undoable(
  transaction_id integer,
  person_id integer,
  given_at timestamptz,
  picked_at timestamptz default null,
  delivery_format text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_before public.territory_transactions%rowtype;
  v_after public.territory_transactions%rowtype;
begin
  if picked_at is not null and picked_at < given_at then
    raise exception 'INVALID_DATES' using errcode = '22007';
  end if;

  if delivery_format is not null and delivery_format not in ('physical', 'virtual') then
    raise exception 'INVALID_DELIVERY_FORMAT' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.persons p
    where p.id = update_transaction_undoable.person_id
      and p.congregation_id = v_cong
      and p.enabled = true
  ) then
    raise exception 'PERSON_NOT_FOUND' using errcode = 'P0002';
  end if;

  select * into v_before
  from public.territory_transactions tt
  where tt.id = update_transaction_undoable.transaction_id
    and tt.congregation_id = v_cong
  for update;

  if not found then
    raise exception 'TRANSACTION_NOT_FOUND' using errcode = 'P0002';
  end if;

  if picked_at is null and exists (
    select 1
    from public.territory_transactions tt
    where tt.territory_id = v_before.territory_id
      and tt.picked_at is null
      and tt.id <> update_transaction_undoable.transaction_id
  ) then
    raise exception 'TERRITORY_ALREADY_IN_USE' using errcode = '23505';
  end if;

  update public.territory_transactions tt
  set person_id = update_transaction_undoable.person_id,
      given_at = update_transaction_undoable.given_at,
      picked_at = update_transaction_undoable.picked_at,
      picked_by = case when update_transaction_undoable.picked_at is null then null else coalesce(tt.picked_by, v_user_id) end,
      is_automatic_picked_date = case when update_transaction_undoable.picked_at is null then null else coalesce(tt.is_automatic_picked_date, false) end,
      delivery_format = coalesce(update_transaction_undoable.delivery_format, tt.delivery_format)
  where tt.id = update_transaction_undoable.transaction_id
  returning * into v_after;

  perform public.add_action_log(14, format('Transaction %s updated', transaction_id), v_user_id, true);
  return public.create_undoable_action('update_transaction', 'territory_transaction', jsonb_build_object('before', to_jsonb(v_before), 'after', to_jsonb(v_after)), v_user_id, v_cong);
end;
$function$;

revoke all on function public.update_transaction(integer, integer, timestamptz, timestamptz, text) from public, anon;
revoke all on function public.update_transaction_undoable(integer, integer, timestamptz, timestamptz, text) from public, anon;
grant execute on function public.update_transaction(integer, integer, timestamptz, timestamptz, text) to authenticated, service_role;
grant execute on function public.update_transaction_undoable(integer, integer, timestamptz, timestamptz, text) to authenticated, service_role;

-- Deshacer: restaura también el formato (las acciones previas a esta migración no lo traen).
CREATE OR REPLACE FUNCTION public.undo_action(p_undo_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user_id uuid := public.require_authenticated();
  v_cong uuid := public.require_congregation();
  v_action public.undoable_actions%rowtype;
  v_snapshot jsonb;
  v_before jsonb;
  v_after jsonb;
  v_current public.territory_transactions%rowtype;
  v_person public.persons%rowtype;
  v_territory public.territories%rowtype;
begin
  select * into v_action
  from public.undoable_actions
  where id = p_undo_id
  for update;

  if not found or v_action.actor_id <> v_user_id or v_action.congregation_id <> v_cong then
    raise exception 'UNDO_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_action.consumed_at is not null then
    raise exception 'UNDO_ALREADY_CONSUMED' using errcode = 'P0002';
  end if;
  if v_action.expires_at <= now() then
    raise exception 'UNDO_EXPIRED' using errcode = '22023';
  end if;

  case v_action.action_type
  when 'give_territory' then
    v_snapshot := v_action.payload -> 'transaction';
    select * into v_current
    from public.territory_transactions
    where id = (v_snapshot ->> 'id')::integer
      and congregation_id = v_cong
    for update;
    if not found or v_current.picked_at is not null then
      raise exception 'UNDO_CONFLICT' using errcode = '40001';
    end if;
    delete from public.territory_transactions where id = v_current.id;

  when 'pick_territory' then
    v_before := v_action.payload -> 'before';
    v_after := v_action.payload -> 'after';
    select * into v_current
    from public.territory_transactions
    where id = (v_before ->> 'id')::integer
      and congregation_id = v_cong
    for update;
    if not found
      or v_current.picked_at is distinct from (v_after ->> 'picked_at')::timestamptz
      or v_current.picked_by is distinct from (v_after ->> 'picked_by')::uuid then
      raise exception 'UNDO_CONFLICT' using errcode = '40001';
    end if;
    update public.territory_transactions
    set picked_by = null,
        picked_at = null,
        is_automatic_picked_date = null
    where id = v_current.id;

  when 'add_person' then
    v_snapshot := v_action.payload -> 'person';
    if exists (select 1 from public.territory_transactions where person_id = (v_snapshot ->> 'id')::integer) then
      raise exception 'UNDO_CONFLICT' using errcode = '40001';
    end if;
    delete from public.persons
    where id = (v_snapshot ->> 'id')::integer
      and congregation_id = v_cong;

  when 'update_person' then
    v_before := v_action.payload -> 'before';
    v_after := v_action.payload -> 'after';
    select * into v_person
    from public.persons
    where id = (v_before ->> 'id')::integer
      and congregation_id = v_cong
    for update;
    if not found
      or v_person.name is distinct from (v_after ->> 'name')
      or v_person.enabled is distinct from (v_after ->> 'enabled')::boolean then
      raise exception 'UNDO_CONFLICT' using errcode = '40001';
    end if;
    update public.persons
    set name = v_before ->> 'name',
        enabled = (v_before ->> 'enabled')::boolean,
        updated_at = (v_before ->> 'updated_at')::timestamptz
    where id = v_person.id;

  when 'delete_person' then
    v_snapshot := v_action.payload -> 'person';
    if v_action.payload ->> 'mode' = 'soft' then
      update public.persons
      set enabled = (v_snapshot ->> 'enabled')::boolean,
          updated_at = (v_snapshot ->> 'updated_at')::timestamptz
      where id = (v_snapshot ->> 'id')::integer
        and congregation_id = v_cong;
      if not found then
        raise exception 'UNDO_CONFLICT' using errcode = '40001';
      end if;
    else
      insert into public.persons (id, name, enabled, created_at, updated_at, congregation_id)
      values (
        (v_snapshot ->> 'id')::integer,
        v_snapshot ->> 'name',
        (v_snapshot ->> 'enabled')::boolean,
        (v_snapshot ->> 'created_at')::timestamptz,
        (v_snapshot ->> 'updated_at')::timestamptz,
        (v_snapshot ->> 'congregation_id')::uuid
      );
    end if;

  when 'add_territory' then
    v_snapshot := v_action.payload -> 'territory';
    if exists (select 1 from public.territory_transactions where territory_id = (v_snapshot ->> 'id')::integer) then
      raise exception 'UNDO_CONFLICT' using errcode = '40001';
    end if;
    delete from public.territories
    where id = (v_snapshot ->> 'id')::integer
      and congregation_id = v_cong;

  when 'update_territory' then
    v_before := v_action.payload -> 'before';
    v_after := v_action.payload -> 'after';
    select * into v_territory
    from public.territories
    where id = (v_before ->> 'id')::integer
      and congregation_id = v_cong
    for update;
    if not found
      or v_territory.code::text is distinct from (v_after ->> 'code')
      or v_territory.name is distinct from (v_after ->> 'name')
      or v_territory.map_url is distinct from (v_after ->> 'map_url') then
      raise exception 'UNDO_CONFLICT' using errcode = '40001';
    end if;
    update public.territories
    set code = (v_before ->> 'code')::extensions.citext,
        name = v_before ->> 'name',
        map_url = v_before ->> 'map_url',
        updated_at = (v_before ->> 'updated_at')::timestamptz
    where id = v_territory.id;

  when 'delete_territory' then
    v_snapshot := v_action.payload -> 'territory';
    if v_action.payload ->> 'mode' = 'soft' then
      update public.territories
      set archived = (v_snapshot ->> 'archived')::boolean,
          updated_at = (v_snapshot ->> 'updated_at')::timestamptz
      where id = (v_snapshot ->> 'id')::integer
        and congregation_id = v_cong;
      if not found then
        raise exception 'UNDO_CONFLICT' using errcode = '40001';
      end if;
    else
      insert into public.territories (id, code, name, map_url, image_path, archived, created_at, updated_at, congregation_id, map_geometry)
      values (
        (v_snapshot ->> 'id')::integer,
        (v_snapshot ->> 'code')::extensions.citext,
        v_snapshot ->> 'name',
        v_snapshot ->> 'map_url',
        v_snapshot ->> 'image_path',
        (v_snapshot ->> 'archived')::boolean,
        (v_snapshot ->> 'created_at')::timestamptz,
        (v_snapshot ->> 'updated_at')::timestamptz,
        (v_snapshot ->> 'congregation_id')::uuid,
        v_snapshot -> 'map_geometry'
      );
    end if;

  when 'update_transaction' then
    v_before := v_action.payload -> 'before';
    v_after := v_action.payload -> 'after';
    select * into v_current
    from public.territory_transactions
    where id = (v_before ->> 'id')::integer
      and congregation_id = v_cong
    for update;
    if not found
      or v_current.person_id is distinct from (v_after ->> 'person_id')::integer
      or v_current.given_at is distinct from (v_after ->> 'given_at')::timestamptz
      or v_current.picked_at is distinct from (v_after ->> 'picked_at')::timestamptz
      or v_current.delivery_format is distinct from coalesce(v_after ->> 'delivery_format', v_current.delivery_format) then
      raise exception 'UNDO_CONFLICT' using errcode = '40001';
    end if;
    update public.territory_transactions
    set person_id = (v_before ->> 'person_id')::integer,
        given_at = (v_before ->> 'given_at')::timestamptz,
        picked_at = (v_before ->> 'picked_at')::timestamptz,
        picked_by = (v_before ->> 'picked_by')::uuid,
        is_automatic_picked_date = (v_before ->> 'is_automatic_picked_date')::boolean,
        delivery_format = coalesce(v_before ->> 'delivery_format', v_current.delivery_format),
        updated_at = (v_before ->> 'updated_at')::timestamptz
    where id = v_current.id;

  when 'delete_transaction' then
    v_snapshot := v_action.payload -> 'transaction';
    if exists (
      select 1 from public.territory_transactions
      where id = (v_snapshot ->> 'id')::integer
        and congregation_id = v_cong
    ) then
      raise exception 'UNDO_CONFLICT' using errcode = '40001';
    end if;
    insert into public.territory_transactions (
      id,
      territory_id,
      person_id,
      given_by,
      given_at,
      is_automatic_given_date,
      picked_by,
      picked_at,
      is_automatic_picked_date,
      created_at,
      updated_at,
      congregation_id,
      delivery_format
    )
    values (
      (v_snapshot ->> 'id')::integer,
      (v_snapshot ->> 'territory_id')::integer,
      (v_snapshot ->> 'person_id')::integer,
      (v_snapshot ->> 'given_by')::uuid,
      (v_snapshot ->> 'given_at')::timestamptz,
      (v_snapshot ->> 'is_automatic_given_date')::boolean,
      (v_snapshot ->> 'picked_by')::uuid,
      (v_snapshot ->> 'picked_at')::timestamptz,
      (v_snapshot ->> 'is_automatic_picked_date')::boolean,
      (v_snapshot ->> 'created_at')::timestamptz,
      (v_snapshot ->> 'updated_at')::timestamptz,
      (v_snapshot ->> 'congregation_id')::uuid,
      coalesce(v_snapshot ->> 'delivery_format', 'physical')
    );

  else
    raise exception 'UNDO_UNSUPPORTED' using errcode = '22023';
  end case;

  update public.undoable_actions
  set consumed_at = now()
  where id = v_action.id;

  perform public.add_action_log(0, format('Undo action %s (%s)', v_action.id, v_action.action_type), v_user_id, true);
  return jsonb_build_object('ok', true);
end;
$function$;

-- Historial de movimientos y tablero: exponen el formato para que editar desde ahí no lo pise.
CREATE OR REPLACE FUNCTION public.get_movement_history(p_page integer DEFAULT 1, p_page_size integer DEFAULT 25, p_search text DEFAULT NULL::text, p_event_type text DEFAULT 'all'::text, p_sort_ascending boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with transaction_base as (
    select
      tt.id,
      tt.territory_id,
      tt.person_id,
      tt.given_at,
      tt.picked_at,
      tt.delivery_format,
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
    where tt.congregation_id = public.current_congregation_id()
  ),
  events as (
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
      given_by_username as actor_name,
      delivery_format
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
      picked_by_username,
      delivery_format
    from transaction_base
    where picked_at is not null
  ),
  filtered as (
    select *
    from events
    where (p_event_type = 'all' or event_type = p_event_type)
      and (
        p_search is null
        or btrim(p_search) = ''
        or territory_code ilike '%' || btrim(p_search) || '%'
        or territory_name ilike '%' || btrim(p_search) || '%'
        or person_name ilike '%' || btrim(p_search) || '%'
        or actor_name ilike '%' || btrim(p_search) || '%'
      )
  ),
  page_rows as (
    select *
    from filtered
    order by
      case when p_sort_ascending then event_date end asc,
      case when not p_sort_ascending then event_date end desc,
      transaction_id desc
    limit greatest(p_page_size, 1)
    offset (greatest(p_page, 1) - 1) * greatest(p_page_size, 1)
  )
  select jsonb_build_object(
    'data', coalesce((
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
        'actorName', actor_name,
        'deliveryFormat', delivery_format
      ) order by
        case when p_sort_ascending then event_date end asc,
        case when not p_sort_ascending then event_date end desc,
        transaction_id desc
      )
      from page_rows
    ), '[]'::jsonb),
    'current_page', greatest(p_page, 1),
    'last_page', greatest(
      1,
      ceil((select count(*) from filtered)::numeric / greatest(p_page_size, 1))::integer
    ),
    'total', (select count(*)::integer from filtered)
  );
$function$;

CREATE OR REPLACE FUNCTION public.get_dashboard_snapshot(p_week_start timestamp with time zone, p_timezone text DEFAULT 'UTC'::text, p_attention_days integer DEFAULT 90)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
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
      tt.delivery_format,
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
      given_by_username as actor_name,
      delivery_format
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
      picked_by_username,
      delivery_format
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
        'actorName', actor_name,
        'deliveryFormat', delivery_format
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
        'actorName', actor_name,
        'deliveryFormat', delivery_format
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
$function$;

notify pgrst, 'reload schema';
