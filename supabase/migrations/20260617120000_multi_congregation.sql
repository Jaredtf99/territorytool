-- Multi-congregation (multi-tenant) support.
--
-- Introduces congregations and per-congregation membership/roles, scopes all
-- domain data by congregation_id, makes territory code/map_url/name unique per
-- congregation, and rewrites auth helpers, the access-token hook, RLS and the
-- SECURITY DEFINER RPCs so every operation runs within the caller's active
-- congregation (carried as a JWT claim). SUPERADMIN stays a global role.

set check_function_bodies = off;

-- ---------------------------------------------------------------------------
-- 1. New tables
-- ---------------------------------------------------------------------------

create table if not exists public.congregations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint congregations_name_not_blank check (length(btrim(name)) > 0)
);

create unique index if not exists congregations_name_unique_ci
  on public.congregations (lower(name));

create table if not exists public.congregation_members (
  user_id uuid not null references public.profiles(id) on delete cascade,
  congregation_id uuid not null references public.congregations(id) on delete cascade,
  role public.app_role not null default 'USER',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, congregation_id),
  constraint congregation_members_role_not_superadmin check (role in ('ADMIN', 'USER'))
);

create index if not exists congregation_members_congregation_idx
  on public.congregation_members (congregation_id);

-- ---------------------------------------------------------------------------
-- 2. profiles: global superadmin flag + active congregation
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists is_superadmin boolean not null default false;

alter table public.profiles
  add column if not exists active_congregation_id uuid references public.congregations(id) on delete set null;

-- ---------------------------------------------------------------------------
-- 3. congregation_id on domain tables (added nullable, backfilled below)
-- ---------------------------------------------------------------------------

alter table public.persons
  add column if not exists congregation_id uuid references public.congregations(id) on delete cascade;

alter table public.territories
  add column if not exists congregation_id uuid references public.congregations(id) on delete cascade;

alter table public.territory_transactions
  add column if not exists congregation_id uuid references public.congregations(id) on delete cascade;

alter table public.action_logs
  add column if not exists congregation_id uuid references public.congregations(id) on delete set null;

-- ---------------------------------------------------------------------------
-- 4. Seed default congregation, backfill existing data, migrate roles
-- ---------------------------------------------------------------------------

-- Legacy transaction rows violate these NOT VALID checks; updating any row
-- re-evaluates them, so drop them around the backfill and re-add as NOT VALID
-- (tolerates pre-existing legacy data, enforces on future rows).
alter table public.territory_transactions drop constraint if exists picked_requires_user;
alter table public.territory_transactions drop constraint if exists picked_auto_requires_picked_at;
alter table public.territory_transactions drop constraint if exists picked_after_given;

do $$
declare
  v_cong uuid;
begin
  -- Only seed/backfill if there is data without a congregation yet.
  if exists (select 1 from public.persons where congregation_id is null)
     or exists (select 1 from public.territories where congregation_id is null)
     or exists (select 1 from public.profiles where active_congregation_id is null)
  then
    select id into v_cong from public.congregations order by created_at limit 1;
    if v_cong is null then
      insert into public.congregations (name) values ('Congregación principal')
      returning id into v_cong;
    end if;

    update public.persons set congregation_id = v_cong where congregation_id is null;
    update public.territories set congregation_id = v_cong where congregation_id is null;
    update public.territory_transactions set congregation_id = v_cong where congregation_id is null;
    update public.action_logs set congregation_id = v_cong where congregation_id is null;

    -- Per-congregation membership for every existing profile (superadmins join as ADMIN).
    insert into public.congregation_members (user_id, congregation_id, role)
    select p.id, v_cong,
           case when p.role = 'USER' then 'USER'::public.app_role else 'ADMIN'::public.app_role end
    from public.profiles p
    on conflict (user_id, congregation_id) do nothing;

    -- Promote legacy SUPERADMIN role to the global flag.
    update public.profiles set is_superadmin = true where role = 'SUPERADMIN';

    -- Everyone starts on the default congregation.
    update public.profiles set active_congregation_id = v_cong where active_congregation_id is null;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 5. Enforce NOT NULL after backfill
-- ---------------------------------------------------------------------------

alter table public.persons alter column congregation_id set not null;
alter table public.territories alter column congregation_id set not null;
alter table public.territory_transactions alter column congregation_id set not null;

-- Restore legacy transaction checks as NOT VALID (future rows enforced).
alter table public.territory_transactions
  add constraint picked_requires_user check (picked_at is null or picked_by is not null) not valid;
alter table public.territory_transactions
  add constraint picked_auto_requires_picked_at check (
    (picked_at is null and is_automatic_picked_date is null)
    or (picked_at is not null and is_automatic_picked_date is not null)
  ) not valid;
alter table public.territory_transactions
  add constraint picked_after_given check (picked_at is null or picked_at >= given_at) not valid;

-- ---------------------------------------------------------------------------
-- 6. Uniqueness becomes per-congregation
-- ---------------------------------------------------------------------------

alter table public.territories drop constraint if exists territories_code_key;
alter table public.territories drop constraint if exists territories_map_url_key;
drop index if exists public.territories_name_unique_ci;
drop index if exists public.persons_name_unique_ci;

create unique index if not exists territories_code_per_cong_unique
  on public.territories (congregation_id, code);
create unique index if not exists territories_map_url_per_cong_unique
  on public.territories (congregation_id, map_url);
create unique index if not exists territories_name_per_cong_unique_ci
  on public.territories (congregation_id, lower(name));
create unique index if not exists persons_name_per_cong_unique_ci
  on public.persons (congregation_id, lower(name));

-- Helpful indexes for tenant filtering.
create index if not exists persons_congregation_idx on public.persons (congregation_id);
create index if not exists territories_congregation_idx on public.territories (congregation_id);
create index if not exists territory_transactions_congregation_idx on public.territory_transactions (congregation_id);
create index if not exists action_logs_congregation_idx on public.action_logs (congregation_id);

-- ---------------------------------------------------------------------------
-- 7. updated_at triggers for new tables
-- ---------------------------------------------------------------------------

drop trigger if exists congregations_touch_updated_at on public.congregations;
create trigger congregations_touch_updated_at
  before update on public.congregations
  for each row execute function public.touch_updated_at();

drop trigger if exists congregation_members_touch_updated_at on public.congregation_members;
create trigger congregation_members_touch_updated_at
  before update on public.congregation_members
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 8. Auth helpers (congregation-aware)
-- ---------------------------------------------------------------------------

create or replace function public.current_congregation_id()
returns uuid
language sql
stable
security invoker
set search_path = public
as $$
  select nullif(auth.jwt() ->> 'congregation_id', '')::uuid
$$;

create or replace function public.is_superadmin()
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce((select p.is_superadmin from public.profiles p where p.id = (select auth.uid())), false)
$$;

create or replace function public.current_app_role()
returns public.app_role
language sql
stable
security invoker
set search_path = public
as $$
  select case
    when public.is_superadmin() then 'SUPERADMIN'::public.app_role
    else (
      select cm.role
      from public.congregation_members cm
      where cm.user_id = (select auth.uid())
        and cm.congregation_id = public.current_congregation_id()
    )
  end
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(public.current_app_role() in ('SUPERADMIN', 'ADMIN'), false)
$$;

create or replace function public.is_member_of(p_congregation_id uuid)
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select public.is_superadmin() or exists (
    select 1 from public.congregation_members cm
    where cm.user_id = (select auth.uid())
      and cm.congregation_id = p_congregation_id
  )
$$;

create or replace function public.require_congregation()
returns uuid
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_cong uuid := public.current_congregation_id();
begin
  if v_cong is null then
    raise exception 'NO_ACTIVE_CONGREGATION' using errcode = '42501';
  end if;
  return v_cong;
end;
$$;

-- require_admin / require_superadmin / require_authenticated keep their bodies;
-- is_admin/is_superadmin are now congregation-aware so they need no edits.

-- ---------------------------------------------------------------------------
-- 9. Access-token hook: inject congregation_id, app_role (active), is_superadmin
-- ---------------------------------------------------------------------------

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_claims jsonb;
  v_user_id uuid := (event->>'user_id')::uuid;
  v_username text;
  v_is_superadmin boolean;
  v_active uuid;
  v_role text;
begin
  select p.username::text, p.is_superadmin, p.active_congregation_id
  into v_username, v_is_superadmin, v_active
  from public.profiles p
  where p.id = v_user_id;

  -- Resolve a valid active congregation, falling back to the first available.
  if coalesce(v_is_superadmin, false) then
    if v_active is null or not exists (select 1 from public.congregations c where c.id = v_active) then
      select c.id into v_active from public.congregations c order by c.created_at limit 1;
    end if;
    v_role := 'SUPERADMIN';
  else
    if v_active is null or not exists (
      select 1 from public.congregation_members cm
      where cm.user_id = v_user_id and cm.congregation_id = v_active
    ) then
      select cm.congregation_id into v_active
      from public.congregation_members cm
      where cm.user_id = v_user_id
      order by cm.created_at
      limit 1;
    end if;

    select cm.role::text into v_role
    from public.congregation_members cm
    where cm.user_id = v_user_id and cm.congregation_id = v_active;
  end if;

  v_claims := event->'claims';

  if v_role is not null then
    v_claims := jsonb_set(v_claims, '{app_role}', to_jsonb(v_role));
  end if;
  if v_username is not null then
    v_claims := jsonb_set(v_claims, '{UserName}', to_jsonb(v_username));
  end if;
  v_claims := jsonb_set(v_claims, '{is_superadmin}', to_jsonb(coalesce(v_is_superadmin, false)));
  if v_active is not null then
    v_claims := jsonb_set(v_claims, '{congregation_id}', to_jsonb(v_active::text));
  end if;

  return jsonb_set(event, '{claims}', v_claims);
end;
$$;

-- ---------------------------------------------------------------------------
-- 10. Views: expose congregation_id
-- ---------------------------------------------------------------------------

create or replace view public.territory_current_state
with (security_invoker = true)
as
select
  t.id,
  t.code,
  t.name,
  t.map_url,
  t.image_path,
  t.archived,
  open_tx.id as active_transaction_id,
  open_tx.person_id,
  p.name as person_name,
  open_tx.given_at,
  last_picked.last_picked_at,
  t.congregation_id
from public.territories t
left join public.territory_transactions open_tx
  on open_tx.territory_id = t.id
 and open_tx.picked_at is null
left join public.persons p
  on p.id = open_tx.person_id
left join lateral (
  select max(tt.picked_at) as last_picked_at
  from public.territory_transactions tt
  where tt.territory_id = t.id
) last_picked on true;

create or replace view public.territory_details
with (security_invoker = true)
as
select
  t.id as territory_id,
  t.code,
  t.name,
  t.map_url,
  t.image_path,
  t.archived,
  tt.id as transaction_id,
  tt.person_id,
  p.name as person_name,
  tt.given_at,
  tt.picked_at,
  tt.is_automatic_given_date,
  tt.is_automatic_picked_date,
  given.username as given_by_username,
  picked.username as picked_by_username,
  t.congregation_id
from public.territories t
left join public.territory_transactions tt on tt.territory_id = t.id
left join public.persons p on p.id = tt.person_id
left join public.profiles given on given.id = tt.given_by
left join public.profiles picked on picked.id = tt.picked_by;

create or replace view public.recent_transactions
with (security_invoker = true)
as
select
  tt.id as transaction_id,
  tt.territory_id,
  t.name as territory_name,
  t.code as territory_code,
  tt.person_id,
  p.name as person_name,
  tt.given_at,
  tt.picked_at,
  tt.is_automatic_given_date,
  tt.is_automatic_picked_date,
  given.username as given_by_username,
  picked.username as picked_by_username,
  tt.congregation_id
from public.territory_transactions tt
join public.territories t on t.id = tt.territory_id
join public.persons p on p.id = tt.person_id
join public.profiles given on given.id = tt.given_by
left join public.profiles picked on picked.id = tt.picked_by
where tt.given_at >= now() - interval '3 days'
   or tt.picked_at >= now() - interval '3 days';

-- ---------------------------------------------------------------------------
-- 11. RLS — scope everything to the active congregation
-- ---------------------------------------------------------------------------

alter table public.congregations enable row level security;
alter table public.congregation_members enable row level security;

drop policy if exists "congregations member read" on public.congregations;
create policy "congregations member read"
on public.congregations for select
to authenticated
using (public.is_member_of(id));

drop policy if exists "congregation members read" on public.congregation_members;
create policy "congregation members read"
on public.congregation_members for select
to authenticated
using (
  user_id = (select auth.uid())
  or public.is_superadmin()
  or (public.is_admin() and congregation_id = public.current_congregation_id())
);

drop policy if exists "profiles self read" on public.profiles;
create policy "profiles self read"
on public.profiles for select
to authenticated
using (
  (select auth.uid()) = id
  or public.is_superadmin()
  or (
    public.is_admin() and exists (
      select 1 from public.congregation_members cm
      where cm.user_id = profiles.id
        and cm.congregation_id = public.current_congregation_id()
    )
  )
);

drop policy if exists "persons authenticated read" on public.persons;
create policy "persons authenticated read"
on public.persons for select
to authenticated
using (
  congregation_id = public.current_congregation_id()
  and (enabled or public.is_admin())
);

drop policy if exists "territories authenticated read" on public.territories;
create policy "territories authenticated read"
on public.territories for select
to authenticated
using (
  congregation_id = public.current_congregation_id()
  and (not archived or public.is_admin())
);

drop policy if exists "transactions authenticated read" on public.territory_transactions;
create policy "transactions authenticated read"
on public.territory_transactions for select
to authenticated
using (congregation_id = public.current_congregation_id());

drop policy if exists "action logs superadmin read" on public.action_logs;
drop policy if exists "action logs admin read" on public.action_logs;
create policy "action logs admin read"
on public.action_logs for select
to authenticated
using (
  congregation_id = public.current_congregation_id()
  and public.is_admin()
);

-- ---------------------------------------------------------------------------
-- 12. Congregation selection RPCs
-- ---------------------------------------------------------------------------

create or replace function public.set_active_congregation(p_congregation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_authenticated();
begin
  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.congregation_members cm
      where cm.user_id = v_user_id and cm.congregation_id = p_congregation_id
    )
  ) then
    raise exception 'FORBIDDEN' using errcode = '42501';
  end if;

  update public.profiles
  set active_congregation_id = p_congregation_id
  where id = v_user_id;
end;
$$;

-- Congregations the caller can operate in (all of them for superadmins), with
-- the caller's role and which one is currently active.
create or replace function public.get_my_congregations()
returns table (
  id uuid,
  name text,
  role text,
  is_active boolean
)
language sql
stable
security definer
set search_path = public
as $$
  with me as (
    select p.id as user_id, p.is_superadmin, p.active_congregation_id
    from public.profiles p
    where p.id = (select auth.uid())
  )
  select
    c.id,
    c.name,
    case when me.is_superadmin then 'SUPERADMIN' else cm.role::text end as role,
    (c.id = me.active_congregation_id) as is_active
  from me
  join public.congregations c
    on me.is_superadmin
    or exists (
      select 1 from public.congregation_members cm2
      where cm2.user_id = me.user_id and cm2.congregation_id = c.id
    )
  left join public.congregation_members cm
    on cm.user_id = me.user_id and cm.congregation_id = c.id
  order by c.name;
$$;

-- ---------------------------------------------------------------------------
-- 13. SECURITY DEFINER RPCs — scope by active congregation
--     (these bypass RLS, so congregation filtering is enforced explicitly)
-- ---------------------------------------------------------------------------

create or replace function public.add_action_log(
  p_action_type integer,
  p_message text,
  p_user_id uuid,
  p_successful boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_user_id is null then
    raise exception 'UNAUTHENTICATED' using errcode = '28000';
  end if;

  insert into public.action_logs (user_id, action_type, message, successful, congregation_id)
  values (p_user_id, p_action_type, p_message, p_successful, public.current_congregation_id());
end;
$$;

create or replace function public.give_territory(
  territory_code text,
  person_name text,
  custom_date timestamptz default null
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
  );

  perform public.add_action_log(
    11,
    format('Given territory (%s) %s to %s. IsCustomDate: %s', v_territory.code, v_territory.name, v_person.name, custom_date is not null),
    v_user_id,
    true
  );
end;
$$;

create or replace function public.pick_territory(
  territory_code text,
  custom_date timestamptz default null
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
  v_transaction public.territory_transactions%rowtype;
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

  select * into v_transaction
  from public.territory_transactions
  where territory_id = v_territory.id
    and picked_at is null
  for update;

  if not found then
    raise exception 'TERRITORY_NOT_IN_USE' using errcode = 'P0002';
  end if;

  if v_picked_at < v_transaction.given_at then
    raise exception 'PICKED_DATE_BEFORE_GIVEN_DATE' using errcode = '22007';
  end if;

  update public.territory_transactions
  set picked_by = v_user_id,
      picked_at = v_picked_at,
      is_automatic_picked_date = custom_date is null
  where id = v_transaction.id;

  perform public.add_action_log(
    12,
    format('Picked territory (%s) %s. IsCustomDate: %s', v_territory.code, v_territory.name, custom_date is not null),
    v_user_id,
    true
  );
end;
$$;

create or replace function public.update_transaction(
  transaction_id integer,
  person_id integer,
  given_at timestamptz,
  picked_at timestamptz default null
)
returns public.territory_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_existing public.territory_transactions%rowtype;
  v_result public.territory_transactions%rowtype;
begin
  if picked_at is not null and picked_at < given_at then
    raise exception 'INVALID_DATES' using errcode = '22007';
  end if;

  if not exists (
    select 1 from public.persons p
    where p.id = update_transaction.person_id
      and p.congregation_id = v_cong
      and p.enabled = true
  ) then
    raise exception 'PERSON_NOT_FOUND' using errcode = 'P0002';
  end if;

  select * into v_existing
  from public.territory_transactions tt
  where tt.id = update_transaction.transaction_id
    and tt.congregation_id = v_cong
  for update;

  if not found then
    raise exception 'TRANSACTION_NOT_FOUND' using errcode = 'P0002';
  end if;

  if picked_at is null and exists (
    select 1
    from public.territory_transactions tt
    where tt.territory_id = v_existing.territory_id
      and tt.picked_at is null
      and tt.id <> update_transaction.transaction_id
  ) then
    raise exception 'TERRITORY_ALREADY_IN_USE' using errcode = '23505';
  end if;

  update public.territory_transactions tt
  set person_id = update_transaction.person_id,
      given_at = update_transaction.given_at,
      picked_at = update_transaction.picked_at,
      picked_by = case when update_transaction.picked_at is null then null else coalesce(tt.picked_by, v_user_id) end,
      is_automatic_picked_date = case when update_transaction.picked_at is null then null else coalesce(tt.is_automatic_picked_date, false) end
  where tt.id = update_transaction.transaction_id
  returning * into v_result;

  perform public.add_action_log(
    14,
    format('Transaction %s updated', transaction_id),
    v_user_id,
    true
  );

  return v_result;
end;
$$;

create or replace function public.delete_transaction(transaction_id integer)
returns void
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

  perform public.add_action_log(
    15,
    format('Transaction %s deleted', transaction_id),
    v_user_id,
    true
  );
end;
$$;

create or replace function public.add_person(name text)
returns public.persons
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
  return v_result;
exception
  when unique_violation then
    raise exception 'PERSON_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

create or replace function public.update_person(
  person_id integer,
  name text,
  enabled boolean
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
begin
  if name is null or btrim(name) = '' or enabled is null then
    raise exception 'INVALID_PARAMETERS' using errcode = '22023';
  end if;

  select * into v_existing
  from public.persons
  where id = person_id and congregation_id = v_cong
  for update;
  if not found then
    raise exception 'PERSON_NOT_FOUND' using errcode = 'P0002';
  end if;

  update public.persons
  set name = btrim(update_person.name),
      enabled = update_person.enabled
  where id = person_id
  returning * into v_result;

  perform public.add_action_log(
    9,
    format('Person %s updated to %s. Enabled: %s', v_existing.name, v_result.name, v_result.enabled),
    v_user_id,
    true
  );

  return v_result;
exception
  when unique_violation then
    raise exception 'PERSON_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

create or replace function public.delete_person(name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := public.require_admin();
  v_cong uuid := public.require_congregation();
  v_person public.persons%rowtype;
begin
  select * into v_person
  from public.persons
  where lower(persons.name) = lower(delete_person.name)
    and congregation_id = v_cong
  for update;
  if not found then
    raise exception 'PERSON_NOT_FOUND' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.territory_transactions where person_id = v_person.id) then
    update public.persons set enabled = false where id = v_person.id;
  else
    delete from public.persons where id = v_person.id;
  end if;

  perform public.add_action_log(10, format('Deleting person %s', v_person.name), v_user_id, true);
end;
$$;

create or replace function public.add_territory(
  code text,
  name text,
  map_url text
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

  insert into public.territories (code, name, map_url, congregation_id)
  values (btrim(code), btrim(name), btrim(map_url), v_cong)
  returning * into v_result;

  perform public.add_action_log(1, format('Added territory %s %s', v_result.code, v_result.name), v_user_id, true);
  return v_result;
exception
  when unique_violation then
    raise exception 'TERRITORY_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

create or replace function public.update_territory(
  territory_id integer,
  code text,
  name text,
  map_url text
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

  update public.territories
  set code = btrim(update_territory.code),
      name = btrim(update_territory.name),
      map_url = btrim(update_territory.map_url)
  where id = territory_id
    and congregation_id = v_cong
  returning * into v_result;

  if not found then
    raise exception 'TERRITORY_NOT_FOUND' using errcode = 'P0002';
  end if;

  perform public.add_action_log(
    2,
    format('Edited territory ID %s to: Code (%s) Name (%s) MapURL (%s)', territory_id, v_result.code, v_result.name, v_result.map_url),
    v_user_id,
    true
  );

  return v_result;
exception
  when unique_violation then
    raise exception 'TERRITORY_ALREADY_EXISTS' using errcode = '23505';
end;
$$;

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
  select * into v_territory
  from public.territories
  where id = territory_id and congregation_id = v_cong
  for update;
  if not found then
    raise exception 'TERRITORY_NOT_FOUND' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.territory_transactions where territory_id = v_territory.id) then
    update public.territories set archived = true where id = v_territory.id;
  else
    delete from public.territories where id = v_territory.id;
  end if;

  perform public.add_action_log(3, format('Deleted territory id %s', territory_id), v_user_id, true);
end;
$$;

-- search_territories / search_persons / get_give_suggestions /
-- get_territory_statistics stay SECURITY INVOKER and are scoped automatically
-- by RLS on the underlying tables/views (active congregation).

-- get_action_logs: previously superadmin-only; now any admin sees their own
-- congregation's logs (RLS already scopes, but keep the role gate as admin).
create or replace function public.get_action_logs(
  page_number integer default 1,
  page_size integer default 20,
  sort_field text default 'DateUtc',
  sort_order text default 'desc'
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_total integer;
  v_cong uuid := public.require_congregation();
  v_offset integer := greatest(page_number - 1, 0) * greatest(page_size, 1);
  v_data jsonb;
begin
  perform public.require_admin();

  select count(*) into v_total
  from public.action_logs
  where congregation_id = v_cong;

  with rows as (
    select
      al.action_type as "actionType",
      al.created_at as "dateUtc",
      al.message as "message",
      p.username as "userName",
      al.successful as "successful"
    from public.action_logs al
    join public.profiles p on p.id = al.user_id
    where al.congregation_id = v_cong
    order by
      case when sort_field = 'ActionType' and lower(sort_order) = 'asc' then al.action_type end asc,
      case when sort_field = 'ActionType' and lower(sort_order) <> 'asc' then al.action_type end desc,
      case when sort_field = 'UserName' and lower(sort_order) = 'asc' then p.username end asc,
      case when sort_field = 'UserName' and lower(sort_order) <> 'asc' then p.username end desc,
      case when sort_field = 'Message' and lower(sort_order) = 'asc' then al.message end asc,
      case when sort_field = 'Message' and lower(sort_order) <> 'asc' then al.message end desc,
      case when sort_field = 'Successful' and lower(sort_order) = 'asc' then al.successful end asc,
      case when sort_field = 'Successful' and lower(sort_order) <> 'asc' then al.successful end desc,
      case when lower(sort_order) = 'asc' then al.created_at end asc,
      case when lower(sort_order) <> 'asc' then al.created_at end desc
    limit greatest(page_size, 1)
    offset v_offset
  )
  select coalesce(jsonb_agg(to_jsonb(rows)), '[]'::jsonb)
  into v_data
  from rows;

  return jsonb_build_object(
    'data', v_data,
    'totalCount', v_total,
    'pageNumber', page_number,
    'pageSize', page_size
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 14. Grants
-- ---------------------------------------------------------------------------

grant select on public.congregations to authenticated;
grant select on public.congregation_members to authenticated;
grant all on public.congregations to service_role;
grant all on public.congregation_members to service_role;

-- Access-token hook needs to read membership/congregations.
grant select on public.congregations to supabase_auth_admin;
grant select on public.congregation_members to supabase_auth_admin;

revoke all on function public.set_active_congregation(uuid) from public;
revoke all on function public.get_my_congregations() from public;
revoke all on function public.current_congregation_id() from public;
revoke all on function public.is_member_of(uuid) from public;
revoke all on function public.require_congregation() from public;

grant execute on function public.set_active_congregation(uuid) to authenticated;
grant execute on function public.get_my_congregations() to authenticated;
