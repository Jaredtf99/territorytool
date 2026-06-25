-- Arregla la búsqueda por código en `search_territories` (la que usa el buscador de
-- Acción rápida y los selectores de entregar/recoger).
--
-- Problema: con un término "tipo código" como "AV005" la función usaba similitud por
-- trigramas (operador %), que casa por igual "AV005" con todo el rango AV001..AV008
-- (comparten "av0","v00",…), y el `LIKE '%av005%'` fallaba si el código guarda guion
-- ("AV-005"). Resultado: al buscar AV005 salían AV001..AV008.
--
-- Solución (misma lógica que `search_territory_explorer`): si el término tiene letras
-- Y dígitos y no tiene espacios, se trata como código y se casa SOLO contra el código
-- normalizado (sin guiones/espacios) con LIKE, sin trigramas. El resto de términos
-- (nombres, etc.) siguen usando trigramas + LIKE como antes.
create or replace function public.search_territories(
  term text default null,
  only_free boolean default false,
  only_given boolean default false,
  take integer default 2147483647
)
returns setof public.territory_current_state
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select *
  from public.territory_current_state t
  where t.archived = false
    and (not only_free or t.person_id is null)
    and (not only_given or t.person_id is not null)
    and (
      term is null
      or btrim(term) = ''
      -- Término tipo código: letras + dígitos, sin espacios -> match sobre el código
      -- normalizado (ignora guiones/espacios). Sin trigramas.
      or (
        btrim(term) ~ '[[:alpha:]]'
        and btrim(term) ~ '[[:digit:]]'
        and btrim(term) !~ '[[:space:]]'
        and regexp_replace(lower(t.code::text), '[^[:alnum:]]', '', 'g')
          like '%' || regexp_replace(lower(btrim(term)), '[^[:alnum:]]', '', 'g') || '%'
      )
      -- Resto de términos: nombre o código por similitud/contains, como antes.
      or (
        not (
          btrim(term) ~ '[[:alpha:]]'
          and btrim(term) ~ '[[:digit:]]'
          and btrim(term) !~ '[[:space:]]'
        )
        and (
          public.immutable_unaccent(lower(t.name)) % public.immutable_unaccent(lower(term))
          or public.immutable_unaccent(lower(t.code::text)) % public.immutable_unaccent(lower(term))
          or public.immutable_unaccent(lower(t.name)) like '%' || public.immutable_unaccent(lower(term)) || '%'
          or public.immutable_unaccent(lower(t.code::text)) like '%' || public.immutable_unaccent(lower(term)) || '%'
        )
      )
    )
  order by
    case when term is null or btrim(term) = '' then 0 else greatest(
      similarity(public.immutable_unaccent(lower(t.name)), public.immutable_unaccent(lower(term))),
      similarity(public.immutable_unaccent(lower(t.code::text)), public.immutable_unaccent(lower(term)))
    ) end desc,
    t.name
  limit greatest(take, 0);
$$;

revoke all on function public.search_territories(text, boolean, boolean, integer) from public;
grant execute on function public.search_territories(text, boolean, boolean, integer) to authenticated;
