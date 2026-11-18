-- Fix public.tp_claim_bots return column 4 (chips) to match public.tp_profiles.chips (bigint).

drop function if exists public.tp_claim_bots(uuid, integer, integer);

create or replace function public.tp_claim_bots(
  p_table_id uuid,
  p_count integer,
  p_min_chips integer
)
returns table (
  profile_id uuid,
  display_name text,
  avatar_asset text,
  chips bigint,
  rating integer,
  archetype text,
  params jsonb,
  think_mean_ms integer,
  think_sigma double precision
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  return query
  with picked as (
    select b.profile_id
    from public.tp_bot_pool b
    join public.tp_profiles p on p.id = b.profile_id
    where b.active_table_id is null
      and b.available_at <= now()
      and p.chips >= greatest(0, p_min_chips)
    order by b.last_active_at asc nulls first, b.profile_id
    limit greatest(0, p_count)
    for update of b skip locked
  ),
  claimed as (
    update public.tp_bot_pool b
    set active_table_id = p_table_id,
        seated_at = now(),
        last_active_at = now()
    from picked
    where b.profile_id = picked.profile_id
    returning b.*
  )
  select
    c.profile_id,
    p.display_name,
    p.avatar_asset,
    p.chips,
    p.rating,
    c.archetype,
    c.params,
    c.think_mean_ms,
    c.think_sigma
  from claimed c
  join public.tp_profiles p on p.id = c.profile_id;
end;
$$;

revoke all on function public.tp_claim_bots(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.tp_claim_bots(uuid, integer, integer) to service_role;
