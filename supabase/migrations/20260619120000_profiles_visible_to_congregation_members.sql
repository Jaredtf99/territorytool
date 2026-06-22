-- Allow every authenticated member to resolve the names of users in their
-- active congregation. Keep profiles from unrelated congregations private.

create or replace function public.can_read_profile_in_active_congregation(
  p_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
set row_security = off
as $$
  select
    (select auth.uid()) is not null
    and (
      p_profile_id = (select auth.uid())
      or exists (
        select 1
        from public.profiles actor
        where actor.id = (select auth.uid())
          and actor.is_superadmin
      )
      or exists (
        select 1
        from public.profiles actor
        join public.congregation_members actor_membership
          on actor_membership.user_id = actor.id
         and actor_membership.congregation_id = actor.active_congregation_id
        join public.congregation_members target_membership
          on target_membership.congregation_id = actor_membership.congregation_id
         and target_membership.user_id = p_profile_id
        where actor.id = (select auth.uid())
      )
    )
$$;

revoke all on function public.can_read_profile_in_active_congregation(uuid) from public;
grant execute on function public.can_read_profile_in_active_congregation(uuid) to authenticated;
grant execute on function public.can_read_profile_in_active_congregation(uuid) to service_role;

drop policy if exists "profiles self read" on public.profiles;
drop policy if exists "profiles congregation read" on public.profiles;

create policy "profiles congregation read"
on public.profiles for select
to authenticated
using (public.can_read_profile_in_active_congregation(id));
