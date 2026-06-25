-- Undo tokens for short-lived, user-initiated reversals from the iOS toast.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.undoable_actions (
  id uuid primary key default extensions.gen_random_uuid(),
  action_type text not null,
  entity_type text not null,
  actor_id uuid not null references public.profiles(id) on delete restrict,
  congregation_id uuid not null references public.congregations(id) on delete cascade,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 seconds'),
  consumed_at timestamptz
);

create index if not exists undoable_actions_actor_expires_idx
  on public.undoable_actions (actor_id, congregation_id, expires_at desc);

alter table public.undoable_actions enable row level security;

drop policy if exists "undoable actions no direct access" on public.undoable_actions;
create policy "undoable actions no direct access"
on public.undoable_actions for select
using (false);

grant select, insert, update on public.undoable_actions to authenticated;
grant all on public.undoable_actions to service_role;

create or replace function public.create_undoable_action(
  p_action_type text,
  p_entity_type text,
  p_payload jsonb,
  p_actor_id uuid,
  p_congregation_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_action public.undoable_actions%rowtype;
begin
  insert into public.undoable_actions (
    action_type,
    entity_type,
    actor_id,
    congregation_id,
    payload
  )
  values (
    p_action_type,
    p_entity_type,
    p_actor_id,
    p_congregation_id,
    p_payload
  )
  returning * into v_action;

  return jsonb_build_object(
    'undoId', v_action.id,
    'expiresAt', v_action.created_at + interval '5 seconds'
  );
end;
$$;

create or replace function public.give_territory_undoable(
  territory_code text,
  person_name text,
  custom_date timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := public.require_authenticated();
  v_cong uuid := public.require_congregation();
  v_territory public.territories%rowtype;
  v_person public.persons%rowtype;
  v_transaction public.territory_transactions%rowtype;
  v_given_at timestamptz := coalesce(custom_date, now());
  v_last_picked_at timestamptz;
begin
  if custom_date is not null and custom_date > now() + interval '1 day' then
    raise exception 'INVALID_DATE' using errcode = '22007';
  end if;

  select * into v_territory
  from public.territories
  where code = territory_code::extensions.citext
    and congregation_id = v_cong
    and archived = false
  for update;

  if not found then
    raise exception 'TERRITORY_NOT_FOUND' using errcode = 'P0002';
  end if;

  if exists (
    select 1 from public.territory_transactions
    where territory_id = v_territory.id and picked_at is null
  ) then
    raise exception 'TERRITORY_ALREADY_IN_USE' using errcode = '23505';
  end if;

  select * into v_person
  from public.persons
  where lower(name) = lower(person_name)
    and congregation_id = v_cong
    and enabled = true;

  if not found then
    raise exception 'PERSON_NOT_FOUND' using errcode = 'P0002';
  end if;

  select max(picked_at) into v_last_picked_at
  from public.territory_transactions
  where territory_id = v_territory.id;

  if v_last_picked_at is not null and v_given_at < v_last_picked_at then
    raise exception 'GIVEN_DATE_BEFORE_LAST_PICKED_DATE' using errcode = '22007';
  end if;

  insert into public.territory_transactions (
    territory_id,
    person_id,
    given_by,
    given_at,
    is_automatic_given_date,
    congregation_id
  )
  values (
    v_territory.id,
    v_person.id,
    v_user_id,
    v_given_at,
    custom_date is null,
    v_cong
  )
  returning * into v_transaction;

  perform public.add_action_log(
    11,
    format('Given territory (%s) %s to %s. IsCustomDate: %s', v_territory.code, v_territory.name, v_person.name, custom_date is not null),
    v_user_id,
    true
  );

  return public.create_undoable_action(
    'give_territory',
    'territory_transaction',
    jsonb_build_object('transaction', to_jsonb(v_transaction)),
    v_user_id,
    v_cong
  );
end;
$$;

create or replace function public.pick_territory_undoable(
  territory_code text,
  custom_date timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_user_id uuid := public.require_authenticated();
  v_cong uuid := public.require_congregation();
  v_territory public.territories%rowtype;
  v_before public.territory_transactions%rowtype;
  v_after public.territory_transactions%rowtype;
  v_picked_at timestamptz := coalesce(custom_date, now());
begin
  select * into v_territory
  from public.territories
  where code = territory_code::extensions.citext
    and congregation_id = v_cong
    and archived = false
  for update;

  if not found then
    raise exception 'TERRITORY_NOT_FOUND' using errcode = 'P0002';
  end if;

  select * into v_before
  from public.territory_transactions
  where territory_id = v_territory.id
    and congregation_id = v_cong
    and picked_at is null
  for update;

  if not found then
    raise exception 'TERRITORY_NOT_IN_USE' using errcode = 'P0002';
  end if;

  if v_picked_at < v_before.given_at then
    raise exception 'PICKED_DATE_BEFORE_GIVEN_DATE' using errcode = '22007';
  end if;

  update public.territory_transactions
  set picked_by = v_user_id,
      picked_at = v_picked_at,
      is_automatic_picked_date = custom_date is null
  where id = v_before.id
  returning * into v_after;

  perform public.add_action_log(
    12,
    format('Picked territory (%s) %s. IsCustomDate: %s', v_territory.code, v_territory.name, custom_date is not null),
    v_user_id,
    true
  );

  return public.create_undoable_action(
    'pick_territory',
    'territory_transaction',
    jsonb_build_object('before', to_jsonb(v_before), 'after', to_jsonb(v_after)),
    v_user_id,
    v_cong
  );
end;
$$;

create or replace function public.add_person_undoable(name text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_result public.persons%rowtype;
begin
  if name is null or btrim(name) = '' then
    raise exception 'INVALID_PARAMETERS' using errcode = '22023';
  end if;

  insert into public.persons (name, congregation_id)
  values (btrim(name), v_cong)
  returning * into v_result;

  perform public.add_action_log(8, format('Person %s added', v_result.name), v_user_id, true);
  return public.create_undoable_action('add_person', 'person', jsonb_build_object('person', to_jsonb(v_result)), v_user_id, v_cong);
exception
  when unique_violation then
    raise exception 'PERSON_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

create or replace function public.update_person_undoable(
  person_id integer,
  name text,
  enabled boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_before public.persons%rowtype;
  v_after public.persons%rowtype;
begin
  if name is null or btrim(name) = '' or enabled is null then
    raise exception 'INVALID_PARAMETERS' using errcode = '22023';
  end if;

  select * into v_before
  from public.persons
  where id = person_id and congregation_id = v_cong
  for update;
  if not found then
    raise exception 'PERSON_NOT_FOUND' using errcode = 'P0002';
  end if;

  update public.persons
  set name = btrim(update_person_undoable.name),
      enabled = update_person_undoable.enabled
  where id = person_id
  returning * into v_after;

  perform public.add_action_log(9, format('Person %s updated to %s. Enabled: %s', v_before.name, v_after.name, v_after.enabled), v_user_id, true);
  return public.create_undoable_action('update_person', 'person', jsonb_build_object('before', to_jsonb(v_before), 'after', to_jsonb(v_after)), v_user_id, v_cong);
exception
  when unique_violation then
    raise exception 'PERSON_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

create or replace function public.delete_person_undoable(name text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_person public.persons%rowtype;
  v_mode text;
begin
  select * into v_person
  from public.persons
  where lower(persons.name) = lower(delete_person_undoable.name)
    and congregation_id = v_cong
  for update;
  if not found then
    raise exception 'PERSON_NOT_FOUND' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.territory_transactions where person_id = v_person.id) then
    update public.persons set enabled = false where id = v_person.id;
    v_mode := 'soft';
  else
    delete from public.persons where id = v_person.id;
    v_mode := 'hard';
  end if;

  perform public.add_action_log(10, format('Deleting person %s', v_person.name), v_user_id, true);
  return public.create_undoable_action('delete_person', 'person', jsonb_build_object('person', to_jsonb(v_person), 'mode', v_mode), v_user_id, v_cong);
end;
$$;

create or replace function public.add_territory_undoable(
  code text,
  name text,
  map_url text
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

  insert into public.territories (code, name, map_url, congregation_id)
  values (btrim(code), btrim(name), btrim(map_url), v_cong)
  returning * into v_result;

  perform public.add_action_log(1, format('Added territory %s %s', v_result.code, v_result.name), v_user_id, true);
  return public.create_undoable_action('add_territory', 'territory', jsonb_build_object('territory', to_jsonb(v_result)), v_user_id, v_cong);
exception
  when unique_violation then
    raise exception 'TERRITORY_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

create or replace function public.update_territory_undoable(
  territory_id integer,
  code text,
  name text,
  map_url text
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
  from public.territories
  where id = territory_id and congregation_id = v_cong
  for update;
  if not found then
    raise exception 'TERRITORY_NOT_FOUND' using errcode = 'P0002';
  end if;

  update public.territories
  set code = btrim(update_territory_undoable.code),
      name = btrim(update_territory_undoable.name),
      map_url = btrim(update_territory_undoable.map_url)
  where id = territory_id
  returning * into v_after;

  perform public.add_action_log(2, format('Edited territory ID %s to: Code (%s) Name (%s) MapURL (%s)', territory_id, v_after.code, v_after.name, v_after.map_url), v_user_id, true);
  return public.create_undoable_action('update_territory', 'territory', jsonb_build_object('before', to_jsonb(v_before), 'after', to_jsonb(v_after)), v_user_id, v_cong);
exception
  when unique_violation then
    raise exception 'TERRITORY_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

create or replace function public.delete_territory_undoable(territory_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_territory public.territories%rowtype;
  v_mode text;
begin
  select * into v_territory
  from public.territories
  where id = territory_id and congregation_id = v_cong
  for update;
  if not found then
    raise exception 'TERRITORY_NOT_FOUND' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.territory_transactions where territory_id = v_territory.id) then
    update public.territories set archived = true where id = v_territory.id;
    v_mode := 'soft';
  else
    delete from public.territories where id = v_territory.id;
    v_mode := 'hard';
  end if;

  perform public.add_action_log(3, format('Deleted territory id %s', territory_id), v_user_id, true);
  return public.create_undoable_action('delete_territory', 'territory', jsonb_build_object('territory', to_jsonb(v_territory), 'mode', v_mode), v_user_id, v_cong);
end;
$$;

create or replace function public.update_transaction_undoable(
  transaction_id integer,
  person_id integer,
  given_at timestamptz,
  picked_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_before public.territory_transactions%rowtype;
  v_after public.territory_transactions%rowtype;
begin
  if picked_at is not null and picked_at < given_at then
    raise exception 'INVALID_DATES' using errcode = '22007';
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
      is_automatic_picked_date = case when update_transaction_undoable.picked_at is null then null else coalesce(tt.is_automatic_picked_date, false) end
  where tt.id = update_transaction_undoable.transaction_id
  returning * into v_after;

  perform public.add_action_log(14, format('Transaction %s updated', transaction_id), v_user_id, true);
  return public.create_undoable_action('update_transaction', 'territory_transaction', jsonb_build_object('before', to_jsonb(v_before), 'after', to_jsonb(v_after)), v_user_id, v_cong);
end;
$$;

create or replace function public.delete_transaction_undoable(transaction_id integer)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_existing public.territory_transactions%rowtype;
begin
  select * into v_existing
  from public.territory_transactions
  where id = transaction_id
    and congregation_id = v_cong
  for update;

  if not found then
    raise exception 'TRANSACTION_NOT_FOUND' using errcode = 'P0002';
  end if;

  delete from public.territory_transactions where id = transaction_id;

  perform public.add_action_log(15, format('Transaction %s deleted', transaction_id), v_user_id, true);
  return public.create_undoable_action('delete_transaction', 'territory_transaction', jsonb_build_object('transaction', to_jsonb(v_existing)), v_user_id, v_cong);
end;
$$;

create or replace function public.undo_action(p_undo_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
      or v_current.picked_at is distinct from (v_after ->> 'picked_at')::timestamptz then
      raise exception 'UNDO_CONFLICT' using errcode = '40001';
    end if;
    update public.territory_transactions
    set person_id = (v_before ->> 'person_id')::integer,
        given_at = (v_before ->> 'given_at')::timestamptz,
        picked_at = (v_before ->> 'picked_at')::timestamptz,
        picked_by = (v_before ->> 'picked_by')::uuid,
        is_automatic_picked_date = (v_before ->> 'is_automatic_picked_date')::boolean,
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
      congregation_id
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
      (v_snapshot ->> 'congregation_id')::uuid
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
$$;

revoke all on function public.create_undoable_action(text, text, jsonb, uuid, uuid) from public;
revoke all on function public.undo_action(uuid) from public;
grant execute on function public.undo_action(uuid) to authenticated;

grant execute on function public.give_territory_undoable(text, text, timestamptz) to authenticated;
grant execute on function public.pick_territory_undoable(text, timestamptz) to authenticated;
grant execute on function public.add_person_undoable(text) to authenticated;
grant execute on function public.update_person_undoable(integer, text, boolean) to authenticated;
grant execute on function public.delete_person_undoable(text) to authenticated;
grant execute on function public.add_territory_undoable(text, text, text) to authenticated;
grant execute on function public.update_territory_undoable(integer, text, text, text) to authenticated;
grant execute on function public.delete_territory_undoable(integer) to authenticated;
grant execute on function public.update_transaction_undoable(integer, integer, timestamptz, timestamptz) to authenticated;
grant execute on function public.delete_transaction_undoable(integer) to authenticated;
