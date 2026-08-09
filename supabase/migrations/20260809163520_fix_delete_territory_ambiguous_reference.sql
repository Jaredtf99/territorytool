-- `territory_id` is both the public RPC parameter and a column on
-- `territory_transactions`. PL/pgSQL rejects the unqualified reference as
-- ambiguous, so keep the API contract and qualify both sides explicitly.

create or replace function public.delete_territory(territory_id integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_territory public.territories%rowtype;
begin
  select t.* into v_territory
  from public.territories as t
  where t.id = delete_territory.territory_id
    and t.congregation_id = v_cong
  for update;

  if not found then
    raise exception 'TERRITORY_NOT_FOUND' using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from public.territory_transactions as tt
    where tt.territory_id = v_territory.id
  ) then
    update public.territories as t
    set archived = true
    where t.id = v_territory.id;
  else
    delete from public.territories as t
    where t.id = v_territory.id;
  end if;

  perform public.add_action_log(
    3,
    format('Deleted territory id %s', delete_territory.territory_id),
    v_user_id,
    true
  );
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
  select t.* into v_territory
  from public.territories as t
  where t.id = delete_territory_undoable.territory_id
    and t.congregation_id = v_cong
  for update;

  if not found then
    raise exception 'TERRITORY_NOT_FOUND' using errcode = 'P0002';
  end if;

  if exists (
    select 1
    from public.territory_transactions as tt
    where tt.territory_id = v_territory.id
  ) then
    update public.territories as t
    set archived = true
    where t.id = v_territory.id;
    v_mode := 'soft';
  else
    delete from public.territories as t
    where t.id = v_territory.id;
    v_mode := 'hard';
  end if;

  perform public.add_action_log(
    3,
    format('Deleted territory id %s', delete_territory_undoable.territory_id),
    v_user_id,
    true
  );

  return public.create_undoable_action(
    'delete_territory',
    'territory',
    jsonb_build_object('territory', to_jsonb(v_territory), 'mode', v_mode),
    v_user_id,
    v_cong
  );
end;
$$;

revoke all on function public.delete_territory(integer) from public;
revoke all on function public.delete_territory_undoable(integer) from public;
grant execute on function public.delete_territory(integer) to authenticated;
grant execute on function public.delete_territory_undoable(integer) to authenticated;

select pg_notify('pgrst', 'reload schema');
