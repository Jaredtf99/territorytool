-- Keep the iOS visible undo window at 5 seconds, but allow the backend a
-- two-second grace period for network latency and schema/API overhead.

alter table public.undoable_actions
  alter column expires_at set default (now() + interval '7 seconds');

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

revoke all on function public.create_undoable_action(text, text, jsonb, uuid, uuid) from public;
select pg_notify('pgrst', 'reload schema');
