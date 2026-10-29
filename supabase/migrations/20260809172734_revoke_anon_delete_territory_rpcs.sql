-- These functions had a legacy direct EXECUTE grant to `anon`. Revoking from
-- PUBLIC alone does not remove privileges granted directly to the role.
revoke execute on function public.delete_territory(integer) from anon;
revoke execute on function public.delete_territory_undoable(integer) from anon;

select pg_notify('pgrst', 'reload schema');
