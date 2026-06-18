-- Superadmin-only RPCs to manage congregations from the UI.

set check_function_bodies = off;

create or replace function public.create_congregation(p_name text)
returns public.congregations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_superadmin();
  v_result public.congregations%rowtype;
begin
  if p_name is null or btrim(p_name) = '' then
    raise exception 'INVALID_PARAMETERS' using errcode = '22023';
  end if;

  insert into public.congregations (name)
  values (btrim(p_name))
  returning * into v_result;

  return v_result;
exception
  when unique_violation then
    raise exception 'CONGREGATION_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

create or replace function public.rename_congregation(p_congregation_id uuid, p_name text)
returns public.congregations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_superadmin();
  v_result public.congregations%rowtype;
begin
  if p_name is null or btrim(p_name) = '' then
    raise exception 'INVALID_PARAMETERS' using errcode = '22023';
  end if;

  update public.congregations
  set name = btrim(p_name)
  where id = p_congregation_id
  returning * into v_result;

  if not found then
    raise exception 'CONGREGATION_NOT_FOUND' using errcode = 'P0002';
  end if;

  return v_result;
exception
  when unique_violation then
    raise exception 'CONGREGATION_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

-- Deletes a congregation only when it holds no territories or persons, to avoid
-- cascading away real data.
create or replace function public.delete_congregation(p_congregation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_superadmin();
begin
  if exists (select 1 from public.territories where congregation_id = p_congregation_id)
     or exists (select 1 from public.persons where congregation_id = p_congregation_id) then
    raise exception 'CONGREGATION_NOT_EMPTY' using errcode = '2BP01';
  end if;

  delete from public.congregations where id = p_congregation_id;
  if not found then
    raise exception 'CONGREGATION_NOT_FOUND' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.create_congregation(text) from public;
revoke all on function public.rename_congregation(uuid, text) from public;
revoke all on function public.delete_congregation(uuid) from public;

grant execute on function public.create_congregation(text) to authenticated;
grant execute on function public.rename_congregation(uuid, text) to authenticated;
grant execute on function public.delete_congregation(uuid) to authenticated;
