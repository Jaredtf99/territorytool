BEGIN;
SELECT plan(20);

SELECT has_type('public', 'app_role', 'app_role enum exists');
SELECT has_table('public', 'profiles', 'profiles exists');
SELECT has_table('public', 'persons', 'persons exists');
SELECT has_table('public', 'territories', 'territories exists');
SELECT has_table('public', 'territory_transactions', 'territory_transactions exists');
SELECT has_table('public', 'action_logs', 'action_logs exists');

SELECT col_is_pk('public', 'profiles', 'id', 'profiles id is primary key');
SELECT col_is_unique('public', 'territories', 'code', 'territory code is unique');
SELECT col_is_unique('public', 'territories', 'map_url', 'territory map_url is unique');

SELECT has_index(
  'public',
  'territory_transactions',
  'territory_transactions_one_open_per_territory',
  'partial unique index for one open transaction per territory exists'
);

SELECT isnt_empty(
  $$ select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' $$,
  'profiles has RLS policies'
);

SELECT isnt_empty(
  $$ select 1 from pg_policies where schemaname = 'public' and tablename = 'territory_transactions' $$,
  'territory_transactions has RLS policies'
);

SELECT isnt_empty(
  $$ select 1
     from pg_constraint
     where conrelid = 'public.territory_transactions'::regclass
       and conname = 'picked_after_given' $$,
  'picked_at cannot be before given_at constraint exists'
);

SELECT has_view('public', 'territory_current_state', 'territory_current_state view exists');
SELECT has_view('public', 'territory_details', 'territory_details view exists');
SELECT has_view('public', 'recent_transactions', 'recent_transactions view exists');

SELECT has_function(
  'public',
  'get_dashboard_snapshot',
  ARRAY['timestamp with time zone', 'text', 'integer'],
  'dashboard snapshot RPC exists'
);

SELECT has_function(
  'public',
  'search_persons_with_assignments',
  ARRAY['text', 'integer'],
  'person quick-action search RPC exists'
);

SELECT has_function(
  'public',
  'resolve_territory_selector',
  ARRAY['text'],
  'territory selector resolver RPC exists'
);

SELECT has_function(
  'public',
  'search_territory_explorer',
  ARRAY['text', 'text', 'integer', 'integer'],
  'territory explorer RPC exists without changing the legacy search contract'
);

SELECT * FROM finish();
ROLLBACK;
