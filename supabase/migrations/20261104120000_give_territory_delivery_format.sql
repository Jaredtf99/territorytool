-- Entregar un territorio indicando si se hace en físico (por defecto) o en virtual.
-- `delivery_format` es opcional: los clientes que aún no lo envían siguen funcionando
-- y la entrega queda como 'physical'.
drop function if exists public.give_territory(text, text, timestamptz);
drop function if exists public.give_territory_undoable(text, text, timestamptz);

create or replace function public.give_territory(
  territory_code text,
  person_name text,
  custom_date timestamptz default null,
  delivery_format text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_authenticated();
  v_cong uuid := public.require_congregation();
  v_territory public.territories%rowtype;
  v_person public.persons%rowtype;
  v_given_at timestamptz := coalesce(custom_date, now());
  v_last_picked_at timestamptz;
  v_delivery_format text := coalesce(give_territory.delivery_format, 'physical');
begin
  if v_delivery_format not in ('physical', 'virtual') then
    raise exception 'INVALID_DELIVERY_FORMAT' using errcode = '22023';
  end if;

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
    congregation_id,
    delivery_format
  )
  values (
    v_territory.id,
    v_person.id,
    v_user_id,
    v_given_at,
    custom_date is null,
    v_cong,
    v_delivery_format
  );

  perform public.add_action_log(
    11,
    format('Given territory (%s) %s to %s. IsCustomDate: %s. DeliveryFormat: %s', v_territory.code, v_territory.name, v_person.name, custom_date is not null, v_delivery_format),
    v_user_id,
    true
  );
end;
$$;

create or replace function public.give_territory_undoable(
  territory_code text,
  person_name text,
  custom_date timestamptz default null,
  delivery_format text default null
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
  v_delivery_format text := coalesce(give_territory_undoable.delivery_format, 'physical');
begin
  if v_delivery_format not in ('physical', 'virtual') then
    raise exception 'INVALID_DELIVERY_FORMAT' using errcode = '22023';
  end if;

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
    congregation_id,
    delivery_format
  )
  values (
    v_territory.id,
    v_person.id,
    v_user_id,
    v_given_at,
    custom_date is null,
    v_cong,
    v_delivery_format
  )
  returning * into v_transaction;

  perform public.add_action_log(
    11,
    format('Given territory (%s) %s to %s. IsCustomDate: %s. DeliveryFormat: %s', v_territory.code, v_territory.name, v_person.name, custom_date is not null, v_delivery_format),
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

revoke all on function public.give_territory(text, text, timestamptz, text) from public, anon;
revoke all on function public.give_territory_undoable(text, text, timestamptz, text) from public, anon;
grant execute on function public.give_territory(text, text, timestamptz, text) to authenticated, service_role;
grant execute on function public.give_territory_undoable(text, text, timestamptz, text) to authenticated, service_role;

select pg_notify('pgrst', 'reload schema');
