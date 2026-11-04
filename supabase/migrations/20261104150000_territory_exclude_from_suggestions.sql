-- Permite marcar un territorio para que NO aparezca en las sugerencias de "a quién
-- entregar" (territorios que normalmente no se dan a hermanos y, al llevar mucho
-- tiempo libres, salían siempre los primeros).
--
-- - territories.exclude_from_suggestions (false por defecto).
-- - territory_current_state lo expone al final (create or replace view exige añadir
--   columnas al final), así que search_territories / search_territory_explorer /
--   search_quick_action lo devuelven sin tocarlas.
-- - get_give_suggestions los descarta.
-- - add_territory(_undoable) y update_territory(_undoable) aceptan el parámetro
--   opcional exclude_from_suggestions: null = no tocar (update) / false (add), así que
--   los clientes que aún no lo envían siguen funcionando sin pisar el valor guardado.
-- - undo_action restaura el flag al deshacer una edición o un borrado definitivo.

alter table public.territories
  add column if not exists exclude_from_suggestions boolean not null default false;

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
    open_tx.delivery_format,
    t.exclude_from_suggestions
   FROM territories t
     LEFT JOIN territory_transactions open_tx ON open_tx.territory_id = t.id AND open_tx.picked_at IS NULL
     LEFT JOIN persons p ON p.id = open_tx.person_id
     LEFT JOIN LATERAL ( SELECT max(tt.picked_at) AS last_picked_at
           FROM territory_transactions tt
          WHERE tt.territory_id = t.id) last_picked ON true;

create or replace function public.get_give_suggestions(count integer default 3)
returns setof public.territory_current_state
language sql
stable
security invoker
set search_path = public
as $$
  select *
  from public.territory_current_state t
  where t.archived = false
    and t.person_id is null
    and t.exclude_from_suggestions = false
  order by t.last_picked_at asc nulls first, t.id asc
  limit greatest(count, 0);
$$;

drop function if exists public.add_territory(text, text, text);
drop function if exists public.add_territory_undoable(text, text, text);
drop function if exists public.update_territory(integer, text, text, text);
drop function if exists public.update_territory_undoable(integer, text, text, text);

create or replace function public.add_territory(
  code text,
  name text,
  map_url text,
  exclude_from_suggestions boolean default null
)
returns public.territories
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_result public.territories%rowtype;
begin
  if code is null or btrim(code) = '' or name is null or btrim(name) = '' or map_url is null or btrim(map_url) = '' then
    raise exception 'INVALID_PARAMETERS' using errcode = '22023';
  end if;

  insert into public.territories (code, name, map_url, congregation_id, exclude_from_suggestions)
  values (btrim(code), btrim(name), btrim(map_url), v_cong, coalesce(add_territory.exclude_from_suggestions, false))
  returning * into v_result;

  perform public.add_action_log(1, format('Added territory %s %s', v_result.code, v_result.name), v_user_id, true);
  return v_result;
exception
  when unique_violation then
    raise exception 'TERRITORY_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

create or replace function public.add_territory_undoable(
  code text,
  name text,
  map_url text,
  exclude_from_suggestions boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_result public.territories%rowtype;
begin
  if code is null or btrim(code) = '' or name is null or btrim(name) = '' or map_url is null or btrim(map_url) = '' then
    raise exception 'INVALID_PARAMETERS' using errcode = '22023';
  end if;

  insert into public.territories (code, name, map_url, congregation_id, exclude_from_suggestions)
  values (btrim(code), btrim(name), btrim(map_url), v_cong, coalesce(add_territory_undoable.exclude_from_suggestions, false))
  returning * into v_result;

  perform public.add_action_log(1, format('Added territory %s %s', v_result.code, v_result.name), v_user_id, true);
  return public.create_undoable_action('add_territory', 'territory', jsonb_build_object('territory', to_jsonb(v_result)), v_user_id, v_cong);
exception
  when unique_violation then
    raise exception 'TERRITORY_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

create or replace function public.update_territory(
  territory_id integer,
  code text,
  name text,
  map_url text,
  exclude_from_suggestions boolean default null
)
returns public.territories
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_result public.territories%rowtype;
begin
  if code is null or btrim(code) = '' or name is null or btrim(name) = '' or map_url is null or btrim(map_url) = '' then
    raise exception 'INVALID_PARAMETERS' using errcode = '22023';
  end if;

  update public.territories t
  set code = btrim(update_territory.code),
      name = btrim(update_territory.name),
      map_url = btrim(update_territory.map_url),
      exclude_from_suggestions = coalesce(update_territory.exclude_from_suggestions, t.exclude_from_suggestions)
  where t.id = update_territory.territory_id
    and t.congregation_id = v_cong
  returning t.* into v_result;

  if not found then
    raise exception 'TERRITORY_NOT_FOUND' using errcode = 'P0002';
  end if;

  perform public.add_action_log(
    2,
    format('Edited territory ID %s to: Code (%s) Name (%s) MapURL (%s) ExcludeFromSuggestions (%s)', update_territory.territory_id, v_result.code, v_result.name, v_result.map_url, v_result.exclude_from_suggestions),
    v_user_id,
    true
  );

  return v_result;
exception
  when unique_violation then
    raise exception 'TERRITORY_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

create or replace function public.update_territory_undoable(
  territory_id integer,
  code text,
  name text,
  map_url text,
  exclude_from_suggestions boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_before public.territories%rowtype;
  v_after public.territories%rowtype;
begin
  if code is null or btrim(code) = '' or name is null or btrim(name) = '' or map_url is null or btrim(map_url) = '' then
    raise exception 'INVALID_PARAMETERS' using errcode = '22023';
  end if;

  select * into v_before
  from public.territories t
  where t.id = update_territory_undoable.territory_id and t.congregation_id = v_cong
  for update;
  if not found then
    raise exception 'TERRITORY_NOT_FOUND' using errcode = 'P0002';
  end if;

  update public.territories t
  set code = btrim(update_territory_undoable.code),
      name = btrim(update_territory_undoable.name),
      map_url = btrim(update_territory_undoable.map_url),
      exclude_from_suggestions = coalesce(update_territory_undoable.exclude_from_suggestions, t.exclude_from_suggestions)
  where t.id = update_territory_undoable.territory_id
  returning t.* into v_after;

  perform public.add_action_log(2, format('Edited territory ID %s to: Code (%s) Name (%s) MapURL (%s) ExcludeFromSuggestions (%s)', update_territory_undoable.territory_id, v_after.code, v_after.name, v_after.map_url, v_after.exclude_from_suggestions), v_user_id, true);
  return public.create_undoable_action('update_territory', 'territory', jsonb_build_object('before', to_jsonb(v_before), 'after', to_jsonb(v_after)), v_user_id, v_cong);
exception
  when unique_violation then
    raise exception 'TERRITORY_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

revoke all on function public.add_territory(text, text, text, boolean) from public, anon;
revoke all on function public.add_territory_undoable(text, text, text, boolean) from public, anon;
revoke all on function public.update_territory(integer, text, text, text, boolean) from public, anon;
revoke all on function public.update_territory_undoable(integer, text, text, text, boolean) from public, anon;
grant execute on function public.add_territory(text, text, text, boolean) to authenticated, service_role;
grant execute on function public.add_territory_undoable(text, text, text, boolean) to authenticated, service_role;
grant execute on function public.update_territory(integer, text, text, text, boolean) to authenticated, service_role;
grant execute on function public.update_territory_undoable(integer, text, text, text, boolean) to authenticated, service_role;

-- Deshacer: restaura el flag al deshacer una edición y al recrear un territorio borrado.
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
      or v_territory.map_url is distinct from (v_after ->> 'map_url')
      or v_territory.exclude_from_suggestions is distinct from coalesce((v_after ->> 'exclude_from_suggestions')::boolean, v_territory.exclude_from_suggestions) then
      raise exception 'UNDO_CONFLICT' using errcode = '40001';
    end if;
    update public.territories
    set code = (v_before ->> 'code')::extensions.citext,
        name = v_before ->> 'name',
        map_url = v_before ->> 'map_url',
        exclude_from_suggestions = coalesce((v_before ->> 'exclude_from_suggestions')::boolean, v_territory.exclude_from_suggestions),
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
      insert into public.territories (id, code, name, map_url, image_path, archived, created_at, updated_at, congregation_id, map_geometry, exclude_from_suggestions)
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
        v_snapshot -> 'map_geometry',
        coalesce((v_snapshot ->> 'exclude_from_suggestions')::boolean, false)
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

select pg_notify('pgrst', 'reload schema');
