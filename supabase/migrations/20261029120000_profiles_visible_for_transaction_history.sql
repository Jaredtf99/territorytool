-- Removing a user from a congregation only deletes their membership, but their
-- territory transactions stay. Keep their username readable by members of that
-- congregation so history views and RPCs (which join profiles under RLS) still
-- show who gave or picked each territory.

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
      or exists (
        select 1
        from public.profiles actor
        join public.congregation_members actor_membership
          on actor_membership.user_id = actor.id
         and actor_membership.congregation_id = actor.active_congregation_id
        join public.territory_transactions tt
          on tt.congregation_id = actor_membership.congregation_id
         and tt.given_by = p_profile_id
        where actor.id = (select auth.uid())
      )
      or exists (
        select 1
        from public.profiles actor
        join public.congregation_members actor_membership
          on actor_membership.user_id = actor.id
         and actor_membership.congregation_id = actor.active_congregation_id
        join public.territory_transactions tt
          on tt.congregation_id = actor_membership.congregation_id
         and tt.picked_by = p_profile_id
        where actor.id = (select auth.uid())
      )
    )
$$;

revoke all on function public.can_read_profile_in_active_congregation(uuid) from public;
grant execute on function public.can_read_profile_in_active_congregation(uuid) to authenticated;
grant execute on function public.can_read_profile_in_active_congregation(uuid) to service_role;
