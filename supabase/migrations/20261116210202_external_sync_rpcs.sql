-- Edición de los identificadores externos (NW Scheduler) desde las apps.
--
-- - set_person_external(p_person_id, p_external_id, p_external_name)
-- - set_territory_external(p_territory_id, p_external_id)
--
-- Solo administradores de la congregación activa. Un valor vacío o en blanco se
-- guarda como null. external_name NO se recorta: NW Scheduler compara el
-- DisplayName exacto, espacios incluidos. external_id sí se recorta.
-- La lectura va directa a las tablas (las políticas RLS ya filtran por congregación).

create or replace function public.set_person_external(
  p_person_id integer,
  p_external_id text,
  p_external_name text
)
returns public.persons
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_existing public.persons%rowtype;
  v_result public.persons%rowtype;
  v_external_id text := nullif(btrim(coalesce(p_external_id, '')), '');
  v_external_name text := case
    when p_external_name is null or btrim(p_external_name) = '' then null
    else p_external_name
  end;
begin
  if p_person_id is null then
    raise exception 'INVALID_PARAMETERS' using errcode = '22023';
  end if;

  select * into v_existing
  from public.persons
  where id = p_person_id and congregation_id = v_cong
  for update;
  if not found then
    raise exception 'PERSON_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_external_id is not null and exists (
    select 1 from public.persons
    where congregation_id = v_cong and external_id = v_external_id and id <> p_person_id
  ) then
    raise exception 'EXTERNAL_ID_ALREADY_USED' using errcode = '23505';
  end if;

  if v_external_name is not null and exists (
    select 1 from public.persons
    where congregation_id = v_cong and external_name = v_external_name and id <> p_person_id
  ) then
    raise exception 'EXTERNAL_NAME_ALREADY_USED' using errcode = '23505';
  end if;

  update public.persons
  set external_id = v_external_id,
      external_name = v_external_name,
      updated_at = now()
  where id = p_person_id
  returning * into v_result;

  if v_existing.external_id is distinct from v_result.external_id
     or v_existing.external_name is distinct from v_result.external_name then
    perform public.add_action_log(
      9,
      format(
        'Person %s external data updated. External id: %s. External name: %s',
        v_result.name,
        coalesce(v_result.external_id, '-'),
        coalesce('"' || v_result.external_name || '"', '-')
      ),
      v_user_id,
      true
    );
  end if;

  return v_result;
end;
$$;

create or replace function public.set_territory_external(
  p_territory_id integer,
  p_external_id text
)
returns public.territories
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_existing public.territories%rowtype;
  v_result public.territories%rowtype;
  v_external_id text := nullif(btrim(coalesce(p_external_id, '')), '');
begin
  if p_territory_id is null then
    raise exception 'INVALID_PARAMETERS' using errcode = '22023';
  end if;

  select * into v_existing
  from public.territories
  where id = p_territory_id and congregation_id = v_cong
  for update;
  if not found then
    raise exception 'TERRITORY_NOT_FOUND' using errcode = 'P0002';
  end if;

  if v_external_id is not null and exists (
    select 1 from public.territories
    where congregation_id = v_cong and external_id = v_external_id and id <> p_territory_id
  ) then
    raise exception 'EXTERNAL_ID_ALREADY_USED' using errcode = '23505';
  end if;

  update public.territories
  set external_id = v_external_id,
      updated_at = now()
  where id = p_territory_id
  returning * into v_result;

  if v_existing.external_id is distinct from v_result.external_id then
    perform public.add_action_log(
      2,
      format(
        'Territory %s external id updated: %s',
        v_result.code,
        coalesce(v_result.external_id, '-')
      ),
      v_user_id,
      true
    );
  end if;

  return v_result;
end;
$$;

revoke all on function public.set_person_external(integer, text, text) from public, anon;
revoke all on function public.set_territory_external(integer, text) from public, anon;
grant execute on function public.set_person_external(integer, text, text) to authenticated;
grant execute on function public.set_territory_external(integer, text) to authenticated;

notify pgrst, 'reload schema';
