-- Teen Patti P2: Hardened profile privacy, unexposed analytics schema,
-- server-only bot pool & heartbeat, matchmaking rooms, atomic SKIP LOCKED RPCs,
-- 30-second pg_cron safety net, and private Realtime channel RLS policies.

create schema if not exists analytics;
create schema if not exists private;

revoke all on schema analytics from public, anon, authenticated;
grant usage on schema analytics to service_role;

revoke all on schema private from public, anon;
grant usage on schema private to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 1. Harden public.tp_profiles (remove bot markers, lock server fields)
-- ---------------------------------------------------------------------------
alter table public.tp_profiles
  drop column if exists participant_kind,
  drop column if exists persona_tag;

create or replace function public.tp_enforce_profile_server_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated') then
    if tg_op = 'INSERT' then
      new.chips := 25000;
      new.rating := 1000;
      new.games_played := 0;
      new.wins := 0;
      new.current_win_streak := 0;
      new.best_streak := 0;
      new.total_rewards_earned := 6200;
    elsif tg_op = 'UPDATE' then
      if new.chips is distinct from old.chips
         or new.rating is distinct from old.rating
         or new.games_played is distinct from old.games_played
         or new.wins is distinct from old.wins
         or new.current_win_streak is distinct from old.current_win_streak
         or new.best_streak is distinct from old.best_streak
         or new.total_rewards_earned is distinct from old.total_rewards_earned
      then
        raise exception 'Server-managed balance and statistics cannot be modified by client.'
          using errcode = '42501';
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_tp_protect_profile_server_fields on public.tp_profiles;
create trigger trg_tp_protect_profile_server_fields
before insert or update on public.tp_profiles
for each row execute function public.tp_enforce_profile_server_fields();

-- Tighten wallet & history writes to server-only (clients read their own rows).
drop policy if exists tp_wallet_insert_own on public.tp_wallet_transactions;
drop policy if exists tp_wallet_select_own on public.tp_wallet_transactions;
create policy tp_wallet_select_own
  on public.tp_wallet_transactions
  for select
  to authenticated
  using (profile_id = (select auth.uid()));

drop policy if exists tp_history_insert_own on public.tp_game_history;
drop policy if exists tp_history_select_own on public.tp_game_history;
create policy tp_history_select_own
  on public.tp_game_history
  for select
  to authenticated
  using (profile_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- 2. Server-only Bot Pool, Worker Heartbeat & Hand Escrow
-- ---------------------------------------------------------------------------
create table if not exists public.tp_bot_pool (
  profile_id uuid primary key references public.tp_profiles(id) on delete cascade,
  archetype text not null,
  params jsonb not null default '{}'::jsonb,
  think_mean_ms integer not null default 1900 check (think_mean_ms between 400 and 10000),
  think_sigma double precision not null default 0.35 check (think_sigma between 0.05 and 1.2),
  active_table_id uuid,
  available_at timestamptz not null default now(),
  seated_at timestamptz,
  min_bankroll integer not null default 5000 check (min_bankroll >= 0),
  target_bankroll integer not null default 25000 check (target_bankroll >= min_bankroll),
  human_pots_played integer not null default 0,
  human_net_chips bigint not null default 0,
  last_active_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists idx_tp_bot_pool_claim
  on public.tp_bot_pool (available_at, last_active_at)
  where active_table_id is null;

create index if not exists idx_tp_bot_pool_active_table
  on public.tp_bot_pool (active_table_id)
  where active_table_id is not null;

alter table public.tp_bot_pool enable row level security;
revoke all on table public.tp_bot_pool from public, anon, authenticated;
grant all on table public.tp_bot_pool to service_role;

create table if not exists public.tp_worker_heartbeat (
  worker_id text primary key,
  last_seen_at timestamptz not null default now(),
  active_rooms integer not null default 0,
  started_at timestamptz not null default now()
);

alter table public.tp_worker_heartbeat enable row level security;
revoke all on table public.tp_worker_heartbeat from public, anon, authenticated;
grant all on table public.tp_worker_heartbeat to service_role;

create table if not exists public.tp_hand_escrows (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null,
  round_number integer not null,
  profile_id uuid not null references public.tp_profiles(id) on delete cascade,
  boot_amount integer not null check (boot_amount >= 0),
  status text not null default 'held' check (status in ('held', 'settled', 'refunded')),
  created_at timestamptz not null default now(),
  settled_at timestamptz
);

create index if not exists idx_tp_hand_escrows_profile
  on public.tp_hand_escrows (profile_id);

create index if not exists idx_tp_hand_escrows_held
  on public.tp_hand_escrows (room_id, round_number)
  where status = 'held';

alter table public.tp_hand_escrows enable row level security;
revoke all on table public.tp_hand_escrows from public, anon, authenticated;
grant all on table public.tp_hand_escrows to service_role;

-- ---------------------------------------------------------------------------
-- 3. Unexposed analytics schema view (bots excluded server-side)
-- ---------------------------------------------------------------------------
create or replace view analytics.human_profiles
with (security_invoker = true) as
select p.*
from public.tp_profiles p
left join public.tp_bot_pool b on b.profile_id = p.id
where b.profile_id is null;

revoke all on analytics.human_profiles from public, anon, authenticated;
grant select on analytics.human_profiles to service_role;

-- ---------------------------------------------------------------------------
-- 4. Online Rooms & Room Seats (zero distinguishing bot columns)
-- ---------------------------------------------------------------------------
create table if not exists public.tp_rooms (
  id uuid primary key default gen_random_uuid(),
  room_code text unique,
  table_name text not null,
  variant text not null default 'Classic',
  min_stake integer not null default 100 check (min_stake > 0),
  max_stake integer not null default 3200 check (max_stake >= min_stake),
  max_players smallint not null default 5 check (max_players between 2 and 7),
  is_private boolean not null default false,
  fill_with_ai boolean not null default true,
  host_profile_id uuid references public.tp_profiles(id) on delete set null,
  status text not null default 'waiting' check (status in ('waiting', 'playing', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_tp_rooms_host
  on public.tp_rooms (host_profile_id);

create index if not exists idx_tp_rooms_matchmaking
  on public.tp_rooms (min_stake, variant, created_at)
  where is_private = false and status in ('waiting', 'playing');

drop trigger if exists trg_tp_rooms_touch on public.tp_rooms;
create trigger trg_tp_rooms_touch
before update on public.tp_rooms
for each row execute function public.tp_touch_updated_at();

create table if not exists public.tp_room_players (
  room_id uuid not null references public.tp_rooms(id) on delete cascade,
  profile_id uuid not null references public.tp_profiles(id) on delete cascade,
  seat_index smallint not null check (seat_index >= 0 and seat_index < 7),
  joined_at timestamptz not null default now(),
  primary key (room_id, profile_id),
  unique (room_id, seat_index)
);

create index if not exists idx_tp_room_players_profile
  on public.tp_room_players (profile_id);

-- Non-recursive SECURITY DEFINER helpers scoped safely inside unexposed private schema.
create or replace function private.is_room_member(p_room_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tp_room_players rp
    where rp.room_id = p_room_id
      and rp.profile_id = (select auth.uid())
  );
$$;

create or replace function private.shares_room_with(p_other_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.tp_room_players me
    join public.tp_room_players mate on me.room_id = mate.room_id
    where me.profile_id = (select auth.uid())
      and mate.profile_id = p_other_profile_id
  );
$$;

revoke all on function private.is_room_member(uuid) from public, anon;
grant execute on function private.is_room_member(uuid) to authenticated, service_role;

revoke all on function private.shares_room_with(uuid) from public, anon;
grant execute on function private.shares_room_with(uuid) to authenticated, service_role;

-- Update tp_profiles RLS: see own profile OR active tablemates only (cannot crawl bot pool).
drop policy if exists tp_profiles_select_own on public.tp_profiles;
drop policy if exists tp_profiles_select_tablemates on public.tp_profiles;
create policy tp_profiles_select_tablemates
  on public.tp_profiles
  for select
  to authenticated
  using (
    id = (select auth.uid())
    or private.shares_room_with(id)
  );

drop policy if exists tp_profiles_insert_own on public.tp_profiles;
create policy tp_profiles_insert_own
  on public.tp_profiles
  for insert
  to authenticated
  with check (id = (select auth.uid()));

drop policy if exists tp_profiles_update_own on public.tp_profiles;
create policy tp_profiles_update_own
  on public.tp_profiles
  for update
  to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

alter table public.tp_rooms enable row level security;
drop policy if exists tp_rooms_select_visible on public.tp_rooms;
create policy tp_rooms_select_visible
  on public.tp_rooms
  for select
  to authenticated
  using (
    (not is_private and status <> 'closed')
    or host_profile_id = (select auth.uid())
    or private.is_room_member(id)
  );

drop policy if exists tp_rooms_insert_host on public.tp_rooms;
create policy tp_rooms_insert_host
  on public.tp_rooms
  for insert
  to authenticated
  with check (host_profile_id = (select auth.uid()));

alter table public.tp_room_players enable row level security;
drop policy if exists tp_room_players_select_members on public.tp_room_players;
create policy tp_room_players_select_members
  on public.tp_room_players
  for select
  to authenticated
  using (
    profile_id = (select auth.uid())
    or private.is_room_member(room_id)
  );

drop policy if exists tp_room_players_insert_own on public.tp_room_players;
create policy tp_room_players_insert_own
  on public.tp_room_players
  for insert
  to authenticated
  with check (profile_id = (select auth.uid()));

drop policy if exists tp_room_players_delete_own on public.tp_room_players;
create policy tp_room_players_delete_own
  on public.tp_room_players
  for delete
  to authenticated
  using (profile_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- 5. Authenticated Matchmaking & Private Room RPCs (single-seat atomic claim)
-- ---------------------------------------------------------------------------
create or replace function private.pick_free_seat(p_room_id uuid, p_max_players int)
returns smallint
language sql
volatile
set search_path = ''
as $$
  select s.idx::smallint
  from generate_series(0, greatest(0, p_max_players - 1)) as s(idx)
  where not exists (
    select 1
    from public.tp_room_players rp
    where rp.room_id = p_room_id
      and rp.seat_index = s.idx
  )
  order by s.idx
  limit 1;
$$;

revoke all on function private.pick_free_seat(uuid, int) from public, anon, authenticated;
grant execute on function private.pick_free_seat(uuid, int) to service_role;

create or replace function public.tp_join_or_create_public_room(
  p_min_stake integer default 100,
  p_max_stake integer default 3200,
  p_max_players integer default 5,
  p_variant text default 'Classic',
  p_table_name text default 'Classic Club'
)
returns table (
  room_id uuid,
  seat_index smallint,
  table_name text,
  variant text,
  min_stake integer,
  max_stake integer,
  max_players smallint,
  fill_with_ai boolean,
  status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_chips integer;
  v_room public.tp_rooms%rowtype;
  v_seat smallint;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select p.chips into v_chips
  from public.tp_profiles p
  where p.id = v_uid;

  if v_chips is null or v_chips < p_min_stake then
    raise exception 'Insufficient chips to join stake %', p_min_stake using errcode = 'P0001';
  end if;

  -- If already seated in a matching active public room, return existing seat cleanly.
  select r.* into v_room
  from public.tp_rooms r
  join public.tp_room_players rp on rp.room_id = r.id
  where rp.profile_id = v_uid
    and r.is_private = false
    and r.status in ('waiting', 'playing')
    and r.min_stake = p_min_stake
    and r.variant = p_variant
  limit 1;

  if found then
    select rp.seat_index into v_seat
    from public.tp_room_players rp
    where rp.room_id = v_room.id and rp.profile_id = v_uid;
    return query select v_room.id, v_seat, v_room.table_name, v_room.variant,
      v_room.min_stake, v_room.max_stake, v_room.max_players, v_room.fill_with_ai, v_room.status;
    return;
  end if;

  -- Find an open public room with free capacity (including a bot slot that can vacate).
  select r.* into v_room
  from public.tp_rooms r
  where r.is_private = false
    and r.status in ('waiting', 'playing')
    and r.min_stake = p_min_stake
    and r.variant = p_variant
    and (
      select count(*) from public.tp_room_players rp where rp.room_id = r.id
    ) < r.max_players
  order by r.created_at asc
  for update of r skip locked
  limit 1;

  if not found then
    insert into public.tp_rooms (
      table_name, variant, min_stake, max_stake, max_players,
      is_private, fill_with_ai, host_profile_id, status
    )
    values (
      coalesce(nullif(trim(p_table_name), ''), 'Classic Club'),
      p_variant,
      p_min_stake,
      greatest(p_min_stake, p_max_stake),
      greatest(2, least(7, p_max_players))::smallint,
      false,
      true,
      v_uid,
      'waiting'
    )
    returning * into v_room;
    v_seat := 0;
  else
    v_seat := private.pick_free_seat(v_room.id, v_room.max_players);
    if v_seat is null then
      raise exception 'No open seats available' using errcode = 'P0002';
    end if;
  end if;

  insert into public.tp_room_players (room_id, profile_id, seat_index)
  values (v_room.id, v_uid, v_seat)
  on conflict (room_id, profile_id) do nothing;

  return query select v_room.id, v_seat, v_room.table_name, v_room.variant,
    v_room.min_stake, v_room.max_stake, v_room.max_players, v_room.fill_with_ai, v_room.status;
end;
$$;

create or replace function public.tp_create_private_room(
  p_table_name text default 'Royal Private Room',
  p_variant text default 'Classic',
  p_min_stake integer default 250,
  p_max_stake integer default 8000,
  p_max_players integer default 5,
  p_fill_with_ai boolean default false
)
returns table (
  room_id uuid,
  room_code text,
  seat_index smallint,
  table_name text,
  variant text,
  min_stake integer,
  max_stake integer,
  max_players smallint,
  fill_with_ai boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_code text;
  v_room public.tp_rooms%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    exit when not exists (select 1 from public.tp_rooms where public.tp_rooms.room_code = v_code);
  end loop;

  insert into public.tp_rooms (
    room_code, table_name, variant, min_stake, max_stake, max_players,
    is_private, fill_with_ai, host_profile_id, status
  )
  values (
    v_code,
    coalesce(nullif(trim(p_table_name), ''), 'Private Club'),
    p_variant,
    p_min_stake,
    greatest(p_min_stake, p_max_stake),
    greatest(2, least(7, p_max_players))::smallint,
    true,
    coalesce(p_fill_with_ai, false),
    v_uid,
    'waiting'
  )
  returning * into v_room;

  insert into public.tp_room_players (room_id, profile_id, seat_index)
  values (v_room.id, v_uid, 0);

  return query select v_room.id, v_room.room_code, 0::smallint, v_room.table_name,
    v_room.variant, v_room.min_stake, v_room.max_stake, v_room.max_players, v_room.fill_with_ai;
end;
$$;

create or replace function public.tp_join_room_by_code(p_room_code text)
returns table (
  room_id uuid,
  room_code text,
  seat_index smallint,
  table_name text,
  variant text,
  min_stake integer,
  max_stake integer,
  max_players smallint,
  fill_with_ai boolean,
  status text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_room public.tp_rooms%rowtype;
  v_seat smallint;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_room
  from public.tp_rooms r
  where upper(r.room_code) = upper(trim(p_room_code))
    and r.status <> 'closed'
  for update of r;

  if not found then
    raise exception 'Private room not found or closed' using errcode = 'P0002';
  end if;

  select rp.seat_index into v_seat
  from public.tp_room_players rp
  where rp.room_id = v_room.id and rp.profile_id = v_uid;

  if not found then
    v_seat := private.pick_free_seat(v_room.id, v_room.max_players);
    if v_seat is null then
      raise exception 'Room is full' using errcode = 'P0002';
    end if;
    insert into public.tp_room_players (room_id, profile_id, seat_index)
    values (v_room.id, v_uid, v_seat);
  end if;

  return query select v_room.id, v_room.room_code, v_seat, v_room.table_name,
    v_room.variant, v_room.min_stake, v_room.max_stake, v_room.max_players,
    v_room.fill_with_ai, v_room.status;
end;
$$;

revoke all on function public.tp_join_or_create_public_room(integer, integer, integer, text, text) from public, anon;
grant execute on function public.tp_join_or_create_public_room(integer, integer, integer, text, text) to authenticated, service_role;

revoke all on function public.tp_create_private_room(text, text, integer, integer, integer, boolean) from public, anon;
grant execute on function public.tp_create_private_room(text, text, integer, integer, integer, boolean) to authenticated, service_role;

revoke all on function public.tp_join_room_by_code(text) from public, anon;
grant execute on function public.tp_join_room_by_code(text) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 6. Server-Only Bot Claim, Release & Stale-Lock Recovery RPCs
-- ---------------------------------------------------------------------------
create or replace function public.tp_claim_bots(
  p_table_id uuid,
  p_count integer,
  p_min_chips integer
)
returns table (
  profile_id uuid,
  display_name text,
  avatar_asset text,
  chips integer,
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

create or replace function public.tp_release_bot(
  p_profile_id uuid,
  p_cooldown_min_sec integer default 60,
  p_cooldown_max_sec integer default 300
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_min integer := greatest(0, coalesce(p_cooldown_min_sec, 60));
  v_max integer := greatest(v_min, coalesce(p_cooldown_max_sec, 300));
  v_jitter integer := v_min + floor(random() * (v_max - v_min + 1))::integer;
begin
  update public.tp_bot_pool
  set active_table_id = null,
      seated_at = null,
      available_at = now() + make_interval(secs => v_jitter),
      last_active_at = now()
  where profile_id = p_profile_id;
end;
$$;

create or replace function public.tp_release_stale_bots()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_worker_alive boolean;
  v_released integer := 0;
begin
  select exists (
    select 1
    from public.tp_worker_heartbeat
    where last_seen_at > now() - interval '2 minutes'
  ) into v_worker_alive;

  if not v_worker_alive then
    update public.tp_bot_pool
    set active_table_id = null,
        seated_at = null,
        available_at = now()
    where active_table_id is not null;

    get diagnostics v_released = row_count;
  end if;

  return v_released;
end;
$$;

revoke all on function public.tp_claim_bots(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.tp_claim_bots(uuid, integer, integer) to service_role;

revoke all on function public.tp_release_bot(uuid, integer, integer) from public, anon, authenticated;
grant execute on function public.tp_release_bot(uuid, integer, integer) to service_role;

revoke all on function public.tp_release_stale_bots() from public, anon, authenticated;
grant execute on function public.tp_release_stale_bots() to service_role;

-- ---------------------------------------------------------------------------
-- 7. Single pg_cron Safety Net (30 seconds stale lock cleanup)
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'bot-stale-release') then
    perform cron.unschedule('bot-stale-release');
  end if;
  perform cron.schedule(
    'bot-stale-release',
    '30 seconds',
    $job$select public.tp_release_stale_bots();$job$
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Private Realtime Channel RLS Policies (realtime.messages)
-- ---------------------------------------------------------------------------
create or replace function private.parse_room_uuid(p_topic text)
returns uuid
language sql
immutable
set search_path = ''
as $$
  select case
    when split_part(p_topic, ':', 1) = 'room'
     and split_part(p_topic, ':', 2) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then split_part(p_topic, ':', 2)::uuid
    else null::uuid
  end;
$$;

revoke all on function private.parse_room_uuid(text) from public, anon;
grant execute on function private.parse_room_uuid(text) to authenticated, service_role;

drop policy if exists "tp_rt_public_select" on realtime.messages;
create policy "tp_rt_public_select"
  on realtime.messages
  for select
  to authenticated
  using (
    extension in ('broadcast', 'presence')
    and split_part(realtime.topic(), ':', 3) = 'public'
    and private.is_room_member(private.parse_room_uuid(realtime.topic()))
  );

drop policy if exists "tp_rt_public_presence_insert" on realtime.messages;
create policy "tp_rt_public_presence_insert"
  on realtime.messages
  for insert
  to authenticated
  with check (
    extension = 'presence'
    and split_part(realtime.topic(), ':', 3) = 'public'
    and private.is_room_member(private.parse_room_uuid(realtime.topic()))
  );

drop policy if exists "tp_rt_seat_select" on realtime.messages;
create policy "tp_rt_seat_select"
  on realtime.messages
  for select
  to authenticated
  using (
    extension = 'broadcast'
    and split_part(realtime.topic(), ':', 3) = 'seat'
    and split_part(realtime.topic(), ':', 4) = ((select auth.uid()))::text
    and private.is_room_member(private.parse_room_uuid(realtime.topic()))
  );

drop policy if exists "tp_rt_actions_insert" on realtime.messages;
create policy "tp_rt_actions_insert"
  on realtime.messages
  for insert
  to authenticated
  with check (
    extension = 'broadcast'
    and split_part(realtime.topic(), ':', 3) = 'actions'
    and private.is_room_member(private.parse_room_uuid(realtime.topic()))
  );
