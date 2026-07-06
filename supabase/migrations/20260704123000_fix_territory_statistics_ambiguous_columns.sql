create or replace function public.get_territory_statistics(territory_id integer)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_exists boolean;
  v_total integer;
  v_usage_rank integer;
  v_usage_count integer;
  v_assigned_percentage numeric := 0;
  v_global_assigned_percentage numeric := 0;
  v_avg_reassignment numeric := 0;
  v_global_avg_reassignment numeric := 0;
  v_avg_holding numeric := 0;
  v_global_avg_holding numeric := 0;
  v_current_unassigned numeric := 0;
  v_unique_persons integer := 0;
  v_global_unique_persons numeric := 0;
begin
  perform public.require_authenticated();

  select exists(
    select 1
    from public.territories t
    where t.id = $1
      and t.archived = false
  ) into v_exists;

  if not v_exists then
    raise exception 'TERRITORY_NOT_FOUND' using errcode = 'P0002';
  end if;

  select count(*) into v_total
  from public.territories
  where archived = false;

  with usage as (
    select
      t.id,
      count(tt.id)::integer as usage_count,
      (row_number() over (order by count(tt.id) desc, t.id asc))::integer as usage_rank
    from public.territories t
    left join public.territory_transactions tt on tt.territory_id = t.id
    where t.archived = false
    group by t.id
  )
  select u.usage_rank, u.usage_count
  into v_usage_rank, v_usage_count
  from usage u
  where u.id = $1;

  with ordered_transactions as (
    select
      tt.territory_id,
      tt.person_id,
      tt.given_at,
      tt.picked_at,
      lead(tt.given_at) over (
        partition by tt.territory_id
        order by tt.given_at asc, tt.id asc
      ) as next_given_at
    from public.territory_transactions tt
    join public.territories t on t.id = tt.territory_id
    where t.archived = false
  ),
  territory_rollup as (
    select
      t.id as territory_id,
      min(ot.given_at) as first_given_at,
      count(ot.given_at) as transaction_count,
      count(ot.picked_at) as picked_count,
      count(*) filter (where ot.picked_at is null and ot.given_at is not null) as open_count,
      max(ot.picked_at) as last_picked_at,
      coalesce(
        sum(greatest(extract(epoch from (coalesce(ot.picked_at, now()) - ot.given_at)) / 86400.0, 0)),
        0
      ) as assigned_days,
      coalesce(
        avg(greatest(extract(epoch from (ot.picked_at - ot.given_at)) / 86400.0, 0))
          filter (where ot.picked_at is not null),
        0
      ) as avg_holding_days,
      count(distinct ot.person_id) filter (where ot.person_id is not null) as unique_persons
    from public.territories t
    left join ordered_transactions ot on ot.territory_id = t.id
    where t.archived = false
    group by t.id
  ),
  reassignment_periods as (
    select
      ot.territory_id,
      greatest(extract(epoch from (ot.next_given_at - ot.picked_at)) / 86400.0, 0) as days
    from ordered_transactions ot
    where ot.picked_at is not null
      and ot.next_given_at is not null
  ),
  territory_stats as (
    select
      tr.territory_id,
      case
        when tr.first_given_at is null then 0
        when extract(epoch from (now() - tr.first_given_at)) <= 0 then 0
        else tr.assigned_days / (extract(epoch from (now() - tr.first_given_at)) / 86400.0) * 100
      end as assigned_percentage,
      coalesce(avg(rp.days), 0) as avg_reassignment_days,
      tr.avg_holding_days,
      case
        when tr.transaction_count > 0
          and tr.open_count = 0
          and tr.last_picked_at is not null
          then greatest(extract(epoch from (now() - tr.last_picked_at)) / 86400.0, 0)
        else 0
      end as current_unassigned_days,
      tr.unique_persons
    from territory_rollup tr
    left join reassignment_periods rp on rp.territory_id = tr.territory_id
    group by
      tr.territory_id,
      tr.first_given_at,
      tr.assigned_days,
      tr.avg_holding_days,
      tr.transaction_count,
      tr.open_count,
      tr.last_picked_at,
      tr.unique_persons
  )
  select
    coalesce(max(ts.assigned_percentage) filter (where ts.territory_id = $1), 0),
    coalesce(avg(ts.assigned_percentage), 0),
    coalesce(max(ts.avg_reassignment_days) filter (where ts.territory_id = $1), 0),
    coalesce(avg(ts.avg_reassignment_days), 0),
    coalesce(max(ts.avg_holding_days) filter (where ts.territory_id = $1), 0),
    coalesce(avg(ts.avg_holding_days), 0),
    coalesce(max(ts.current_unassigned_days) filter (where ts.territory_id = $1), 0),
    coalesce(max(ts.unique_persons) filter (where ts.territory_id = $1), 0),
    coalesce(avg(ts.unique_persons), 0)
  into
    v_assigned_percentage,
    v_global_assigned_percentage,
    v_avg_reassignment,
    v_global_avg_reassignment,
    v_avg_holding,
    v_global_avg_holding,
    v_current_unassigned,
    v_unique_persons,
    v_global_unique_persons
  from territory_stats ts;

  return jsonb_build_object(
    'totalTerritories', v_total,
    'usageRank', coalesce(v_usage_rank, v_total),
    'usageCount', coalesce(v_usage_count, 0),
    'isHighUsage', coalesce(v_usage_rank, v_total) <= greatest(1, ceil(v_total * 0.25)),
    'isLowUsage', coalesce(v_usage_rank, v_total) > ceil(v_total * 0.75),
    'assignedTimePercentage', v_assigned_percentage,
    'globalAverageAssignedTimePercentage', v_global_assigned_percentage,
    'averageReassignmentTime', v_avg_reassignment,
    'globalAverageReassignmentTime', v_global_avg_reassignment,
    'averageHoldingTime', v_avg_holding,
    'globalAverageHoldingTime', v_global_avg_holding,
    'currentUnassignedTime', v_current_unassigned,
    'uniqueUsersCount', v_unique_persons,
    'globalAverageUniqueUsersCount', v_global_unique_persons
  );
end;
$$;
