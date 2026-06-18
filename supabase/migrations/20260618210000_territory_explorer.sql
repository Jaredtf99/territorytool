create or replace function public.search_territory_explorer(
  term text default null,
  status text default 'all',
  attention_days integer default 120,
  take integer default 1000
)
returns setof public.territory_current_state
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select t.*
  from public.territory_current_state t
  where t.archived = false
    and (
      status = 'all'
      or (status = 'available' and t.person_id is null)
      or (status = 'assigned' and t.person_id is not null)
      or (
        status = 'attention'
        and t.person_id is not null
        and t.given_at <= now() - make_interval(days => greatest(attention_days, 0))
      )
    )
    and (
      term is null
      or btrim(term) = ''
      or public.immutable_unaccent(lower(t.name)) % public.immutable_unaccent(lower(term))
      or public.immutable_unaccent(lower(t.code::text)) % public.immutable_unaccent(lower(term))
      or public.immutable_unaccent(lower(coalesce(t.person_name, ''))) % public.immutable_unaccent(lower(term))
      or public.immutable_unaccent(lower(t.name)) like '%' || public.immutable_unaccent(lower(term)) || '%'
      or public.immutable_unaccent(lower(t.code::text)) like '%' || public.immutable_unaccent(lower(term)) || '%'
      or public.immutable_unaccent(lower(coalesce(t.person_name, ''))) like '%' || public.immutable_unaccent(lower(term)) || '%'
    )
  order by
    case
      when t.person_id is not null
       and t.given_at <= now() - make_interval(days => greatest(attention_days, 0))
      then 0
      when t.person_id is null then 1
      else 2
    end,
    case when t.person_id is not null then t.given_at end asc nulls last,
    case when t.person_id is null then t.last_picked_at end asc nulls first,
    case when term is null or btrim(term) = '' then 0 else greatest(
      similarity(public.immutable_unaccent(lower(t.name)), public.immutable_unaccent(lower(term))),
      similarity(public.immutable_unaccent(lower(t.code::text)), public.immutable_unaccent(lower(term))),
      similarity(public.immutable_unaccent(lower(coalesce(t.person_name, ''))), public.immutable_unaccent(lower(term)))
    ) end desc,
    t.name
  limit greatest(take, 0);
$$;

revoke all on function public.search_territory_explorer(text, text, integer, integer) from public;
grant execute on function public.search_territory_explorer(text, text, integer, integer) to authenticated;
