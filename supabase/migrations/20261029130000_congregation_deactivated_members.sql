-- Removing a user from the users screen deactivates their membership: the
-- congregation_members row is deleted (so every membership check keeps working
-- unchanged) and the former role is remembered here so the account can be
-- reactivated later. Only the admin-users edge function (service role) touches it.

create table if not exists public.congregation_deactivated_members (
  user_id uuid not null references public.profiles(id) on delete cascade,
  congregation_id uuid not null references public.congregations(id) on delete cascade,
  role public.app_role not null default 'USER',
  deactivated_at timestamptz not null default now(),
  deactivated_by uuid references public.profiles(id) on delete set null,
  primary key (user_id, congregation_id),
  constraint congregation_deactivated_members_role_not_superadmin check (role in ('ADMIN', 'USER'))
);

create index if not exists congregation_deactivated_members_congregation_idx
  on public.congregation_deactivated_members (congregation_id);

create index if not exists congregation_deactivated_members_deactivated_by_idx
  on public.congregation_deactivated_members (deactivated_by);

alter table public.congregation_deactivated_members enable row level security;

revoke all on public.congregation_deactivated_members from public, anon, authenticated;
grant all on public.congregation_deactivated_members to service_role;
