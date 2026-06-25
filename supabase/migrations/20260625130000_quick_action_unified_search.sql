-- Buscador unificado de Acción rápida: una sola función que devuelve territorios y
-- personas mezclados, con un `score` de relevancia por niveles, ya ordenado.
--
-- Scoring por niveles sobre cada campo (normalizado: sin acentos, minúsculas; el
-- código además sin guiones/espacios):
--   exacto = 1.0 · prefijo = 0.9 · contiene = 0.7 · fuzzy (word/trigram * 0.6)
-- El score de la fila es el máximo entre sus campos:
--   territorio -> nombre y código   ·   persona -> nombre
-- El fuzzy NO se aplica a términos "tipo código" (letras+dígitos, sin espacios), igual
-- que en `search_territories`, para que "AV005" no arrastre todo el rango por trigramas.
-- El código nunca usa fuzzy (solo exacto/prefijo/contiene).
--
-- Decisiones (acordadas): lista única, NO buscar personas por el territorio que tienen,
-- sin boost especial de código (el tiering ya lo cubre).
create or replace function public.search_quick_action(
  term text default null,
  take integer default 20
)
returns table(kind text, score real, data jsonb)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  with params as (
    select
      immutable_unaccent(lower(btrim(coalesce(term, '')))) as q,
      regexp_replace(immutable_unaccent(lower(btrim(coalesce(term, '')))), '[^[:alnum:]]', '', 'g') as qc,
      (
        btrim(coalesce(term, '')) ~ '[[:alpha:]]'
        and btrim(coalesce(term, '')) ~ '[[:digit:]]'
        and btrim(coalesce(term, '')) !~ '[[:space:]]'
      ) as is_code,
      (term is null or btrim(term) = '') as empty
  ),
  terr as (
    select
      'territory'::text as kind,
      greatest(
        -- nombre del territorio
        case
          when p.empty then 0
          when immutable_unaccent(lower(t.name)) = p.q then 1.0
          when starts_with(immutable_unaccent(lower(t.name)), p.q) then 0.9
          when strpos(immutable_unaccent(lower(t.name)), p.q) > 0 then 0.7
          when not p.is_code then greatest(
            word_similarity(p.q, immutable_unaccent(lower(t.name))),
            similarity(p.q, immutable_unaccent(lower(t.name)))
          ) * 0.6
          else 0
        end,
        -- código normalizado (sin fuzzy)
        case
          when p.empty or p.qc = '' then 0
          when regexp_replace(lower(t.code), '[^[:alnum:]]', '', 'g') = p.qc then 1.0
          when starts_with(regexp_replace(lower(t.code), '[^[:alnum:]]', '', 'g'), p.qc) then 0.9
          when strpos(regexp_replace(lower(t.code), '[^[:alnum:]]', '', 'g'), p.qc) > 0 then 0.7
          else 0
        end
      )::real as score,
      to_jsonb(t) as data,
      t.name as sort_name
    from public.territory_current_state t, params p
    where t.archived = false
  ),
  pers as (
    select
      'person'::text as kind,
      (case
         when pa.empty then 0
         when immutable_unaccent(lower(pp.name)) = pa.q then 1.0
         when starts_with(immutable_unaccent(lower(pp.name)), pa.q) then 0.9
         when strpos(immutable_unaccent(lower(pp.name)), pa.q) > 0 then 0.7
         when not pa.is_code then greatest(
           word_similarity(pa.q, immutable_unaccent(lower(pp.name))),
           similarity(pa.q, immutable_unaccent(lower(pp.name)))
         ) * 0.6
         else 0
       end)::real as score,
      jsonb_build_object(
        'id', pp.id,
        'name', pp.name,
        'enabled', pp.enabled,
        'territoriesInUse', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'territoryId', tt.territory_id,
              'territoryCode', tx.code,
              'territoryName', tx.name,
              'givenDate', tt.given_at
            ) order by tt.given_at asc
          )
          from public.territory_transactions tt
          join public.territories tx on tx.id = tt.territory_id and tx.archived = false
          where tt.person_id = pp.id
            and tt.picked_at is null
            and tt.congregation_id = public.current_congregation_id()
        ), '[]'::jsonb)
      ) as data,
      pp.name as sort_name
    from public.persons pp, params pa
    where pp.congregation_id = public.current_congregation_id()
      -- Habilitada, o deshabilitada pero con territorio activo (para poder gestionarlo).
      and (
        pp.enabled
        or exists (
          select 1 from public.territory_transactions tt2
          where tt2.person_id = pp.id
            and tt2.picked_at is null
            and tt2.congregation_id = public.current_congregation_id()
        )
      )
  )
  select u.kind, u.score, u.data
  from (
    select * from terr where score >= 0.3
    union all
    select * from pers where score >= 0.3
  ) u
  order by u.score desc, u.sort_name
  limit greatest(take, 0);
$$;

revoke all on function public.search_quick_action(text, integer) from public;
grant execute on function public.search_quick_action(text, integer) to authenticated;
