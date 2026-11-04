-- Fix: escanear cualquier QR devolvía siempre el primer territorio (AV001).
--
-- La versión anterior comparaba `split_part(map_url, '?', 1)`, es decir, la URL
-- SIN query string. Todas las URLs de Google My Maps comparten la misma ruta
-- (`https://www.google.com/maps/d/edit`) y el mapa se identifica sólo por el
-- parámetro `mid`, así que coincidían todos los territorios y `order by id
-- limit 1` devolvía siempre el primero.
--
-- Ahora: si el valor escaneado trae `mid`, se compara por `mid`; si no, se
-- compara la URL completa (sin `usp=sharing`) o el código del territorio.

create or replace function public.resolve_territory_selector(value text)
returns setof public.territory_current_state
language sql
stable
security invoker
set search_path = public
as $$
  with input as (
    select
      btrim(value) as raw,
      substring(btrim(value) from '[?&]mid=([^&#]+)') as mid,
      regexp_replace(btrim(value), '[?&]usp=sharing', '') as url
  )
  select t.*
  from public.territory_current_state t
  cross join input i
  where t.congregation_id = public.current_congregation_id()
    and t.archived = false
    and (
      lower(t.code::text) = lower(i.raw)
      or (
        i.mid is not null
        and substring(t.map_url from '[?&]mid=([^&#]+)') = i.mid
      )
      or (
        i.mid is null
        and i.url <> ''
        and regexp_replace(t.map_url, '[?&]usp=sharing', '') = i.url
      )
    )
  order by (lower(t.code::text) = lower(i.raw)) desc, t.id
  limit 1;
$$;

revoke all on function public.resolve_territory_selector(text) from public;
grant execute on function public.resolve_territory_selector(text) to authenticated;
