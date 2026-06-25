-- Ensure PostgREST/Supabase sees the newly added undoable RPCs immediately.
-- Without this, clients can receive PGRST202/"could not find the function"
-- until the schema cache refreshes.

do $$
begin
  if to_regprocedure('public.update_territory_undoable(integer,text,text,text)') is null then
    raise exception 'UNDOABLE_ACTIONS_MIGRATION_MISSING';
  end if;
end;
$$;

select pg_notify('pgrst', 'reload schema');
