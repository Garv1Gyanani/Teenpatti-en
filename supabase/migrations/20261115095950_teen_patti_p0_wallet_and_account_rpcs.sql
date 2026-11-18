-- Teen Patti P0: Server-authoritative Wallet & Economy RPCs
-- (Daily Streak Reward, Watch & Earn Cooldown Bonus, Low-Stack Bailout Relief,
-- and Validated Chip Pack Store Credit) with row locking and audit ledger entries.

-- 1. Daily Streak Reward RPC
create or replace function public.tp_claim_daily_reward()
returns table (
  reward_amount bigint,
  new_chips bigint,
  daily_streak integer,
  best_daily_streak integer,
  total_rewards_earned bigint,
  claim_date text,
  tx_id text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_profile public.tp_profiles%rowtype;
  v_today text := to_char(timezone('utc', now()), 'YYYY-MM-DD');
  v_yesterday text := to_char(timezone('utc', now() - interval '1 day'), 'YYYY-MM-DD');
  v_next_streak integer;
  v_best_streak integer;
  v_ladder integer[] := array[500, 800, 1000, 1200, 1500, 2000, 3000];
  v_idx integer;
  v_reward bigint;
  v_new_chips bigint;
  v_total_earned bigint;
  v_tx_id text;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_profile
  from public.tp_profiles p
  where p.id = v_uid
  for update;

  if not found then
    raise exception 'Player profile not found' using errcode = 'P0002';
  end if;

  if v_profile.last_daily_claim_date = v_today then
    raise exception 'Daily reward already claimed today' using errcode = 'P0001';
  end if;

  if v_profile.last_daily_claim_date is null then
    v_next_streak := greatest(1, coalesce(v_profile.daily_streak, 1));
  elsif v_profile.last_daily_claim_date = v_yesterday then
    v_next_streak := greatest(1, coalesce(v_profile.daily_streak, 1)) + 1;
  else
    v_next_streak := 1;
  end if;

  v_idx := ((v_next_streak - 1) % 7) + 1;
  v_reward := v_ladder[v_idx];
  v_best_streak := greatest(coalesce(v_profile.best_daily_streak, 1), v_next_streak);
  v_tx_id := 'tx_daily_' || substr(replace(v_uid::text, '-', ''), 1, 10) || '_' || v_today;

  update public.tp_profiles p
  set chips = p.chips + v_reward,
      daily_streak = v_next_streak,
      best_daily_streak = v_best_streak,
      total_rewards_earned = p.total_rewards_earned + v_reward,
      last_daily_claim_date = v_today
  where p.id = v_uid
  returning p.chips, p.total_rewards_earned
  into v_new_chips, v_total_earned;

  insert into public.tp_wallet_transactions (
    id, profile_id, type, title, subtitle, amount
  )
  values (
    v_tx_id,
    v_uid,
    'dailyReward',
    'Daily Reward',
    'Day ' || v_next_streak || ' Streak Bonus',
    v_reward
  )
  on conflict (id) do nothing;

  return query
  select
    v_reward,
    v_new_chips,
    v_next_streak,
    v_best_streak,
    v_total_earned,
    v_today,
    v_tx_id;
end;
$$;

revoke all on function public.tp_claim_daily_reward() from public, anon;
grant execute on function public.tp_claim_daily_reward() to authenticated, service_role;

-- 2. Watch & Earn Reward RPC (rate-limited server-side)
create or replace function public.tp_claim_watch_reward()
returns table (
  reward_amount bigint,
  new_chips bigint,
  total_rewards_earned bigint,
  tx_id text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_profile public.tp_profiles%rowtype;
  v_recent_count integer;
  v_daily_count integer;
  v_reward bigint := 1000;
  v_new_chips bigint;
  v_total_earned bigint;
  v_tx_id text;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_profile
  from public.tp_profiles p
  where p.id = v_uid
  for update;

  if not found then
    raise exception 'Player profile not found' using errcode = 'P0002';
  end if;

  select count(*)::integer into v_recent_count
  from public.tp_wallet_transactions wt
  where wt.profile_id = v_uid
    and wt.title = 'Watch & Earn'
    and wt.created_at > timezone('utc', now()) - interval '15 seconds';

  if v_recent_count > 0 then
    raise exception 'Please wait a few seconds before claiming another Watch & Earn bonus.'
      using errcode = 'P0001';
  end if;

  select count(*)::integer into v_daily_count
  from public.tp_wallet_transactions wt
  where wt.profile_id = v_uid
    and wt.title = 'Watch & Earn'
    and wt.created_at > timezone('utc', now()) - interval '24 hours';

  if v_daily_count >= 10 then
    raise exception 'Daily Watch & Earn limit (10 per day) reached.'
      using errcode = 'P0001';
  end if;

  v_tx_id := 'tx_watch_' || replace(gen_random_uuid()::text, '-', '');

  update public.tp_profiles p
  set chips = p.chips + v_reward,
      total_rewards_earned = p.total_rewards_earned + v_reward
  where p.id = v_uid
  returning p.chips, p.total_rewards_earned
  into v_new_chips, v_total_earned;

  insert into public.tp_wallet_transactions (
    id, profile_id, type, title, subtitle, amount
  )
  values (
    v_tx_id,
    v_uid,
    'dailyReward',
    'Watch & Earn',
    'Rewarded bonus • Verified',
    v_reward
  );

  return query
  select v_reward, v_new_chips, v_total_earned, v_tx_id;
end;
$$;

revoke all on function public.tp_claim_watch_reward() from public, anon;
grant execute on function public.tp_claim_watch_reward() to authenticated, service_role;

-- 3. Low-Stack Emergency Bailout Relief RPC
create or replace function public.tp_claim_bailout_chips(
  p_min_boot integer default 100
)
returns table (
  reward_amount bigint,
  new_chips bigint,
  total_rewards_earned bigint,
  tx_id text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_profile public.tp_profiles%rowtype;
  v_threshold integer := greatest(100, least(coalesce(p_min_boot, 100), 2500));
  v_reward bigint := 2500;
  v_new_chips bigint;
  v_total_earned bigint;
  v_tx_id text;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_profile
  from public.tp_profiles p
  where p.id = v_uid
  for update;

  if not found then
    raise exception 'Player profile not found' using errcode = 'P0002';
  end if;

  if v_profile.chips >= 2500 and v_profile.chips >= v_threshold then
    raise exception 'Club Relief Chips are only available when balance is below 2,500.'
      using errcode = 'P0001';
  end if;

  v_tx_id := 'tx_bailout_' || replace(gen_random_uuid()::text, '-', '');

  update public.tp_profiles p
  set chips = p.chips + v_reward,
      total_rewards_earned = p.total_rewards_earned + v_reward
  where p.id = v_uid
  returning p.chips, p.total_rewards_earned
  into v_new_chips, v_total_earned;

  insert into public.tp_wallet_transactions (
    id, profile_id, type, title, subtitle, amount
  )
  values (
    v_tx_id,
    v_uid,
    'dailyReward',
    'Club Relief Chips',
    'Low-stack table bailout',
    v_reward
  );

  return query
  select v_reward, v_new_chips, v_total_earned, v_tx_id;
end;
$$;

revoke all on function public.tp_claim_bailout_chips(integer) from public, anon;
grant execute on function public.tp_claim_bailout_chips(integer) to authenticated, service_role;

-- 4. Validated Chip Pack Store Credit RPC
create or replace function public.tp_claim_chip_pack(
  p_chip_amount integer,
  p_price_inr integer
)
returns table (
  credited_amount bigint,
  new_chips bigint,
  tx_id text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_profile public.tp_profiles%rowtype;
  v_valid boolean := false;
  v_new_chips bigint;
  v_tx_id text;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  v_valid := (p_chip_amount = 25000 and p_price_inr = 99)
          or (p_chip_amount = 75000 and p_price_inr = 249)
          or (p_chip_amount = 200000 and p_price_inr = 499)
          or (p_chip_amount = 500000 and p_price_inr = 999);

  if not v_valid then
    raise exception 'Invalid chip pack selection' using errcode = '22023';
  end if;

  select * into v_profile
  from public.tp_profiles p
  where p.id = v_uid
  for update;

  if not found then
    raise exception 'Player profile not found' using errcode = 'P0002';
  end if;

  v_tx_id := 'tx_buy_' || replace(gen_random_uuid()::text, '-', '');

  update public.tp_profiles p
  set chips = p.chips + p_chip_amount
  where p.id = v_uid
  returning p.chips into v_new_chips;

  insert into public.tp_wallet_transactions (
    id, profile_id, type, title, subtitle, amount
  )
  values (
    v_tx_id,
    v_uid,
    'chipPurchase',
    'Chip Purchase',
    '₹' || p_price_inr || ' • ' || p_chip_amount || ' Chips',
    p_chip_amount
  );

  return query
  select p_chip_amount::bigint, v_new_chips, v_tx_id;
end;
$$;

revoke all on function public.tp_claim_chip_pack(integer, integer) from public, anon;
grant execute on function public.tp_claim_chip_pack(integer, integer) to authenticated, service_role;
