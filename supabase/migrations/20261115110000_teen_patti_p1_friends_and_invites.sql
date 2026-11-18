-- Teen Patti P1: Real Friends Graph (tp_friendships), Live Presence (last_seen_at),
-- In-App Table Invites (tp_room_invites), and Server-Authoritative Social RPCs.

-- ---------------------------------------------------------------------------
-- 1. Live Presence Timestamp & Player Code Index on public.tp_profiles
-- ---------------------------------------------------------------------------
alter table public.tp_profiles
  add column if not exists last_seen_at timestamptz not null default timezone('utc', now());

create index if not exists idx_tp_profiles_upper_player_code
  on public.tp_profiles (upper(player_code));

create index if not exists idx_tp_profiles_last_seen
  on public.tp_profiles (last_seen_at desc);

-- ---------------------------------------------------------------------------
-- 2. Friends Graph Table (public.tp_friendships)
-- ---------------------------------------------------------------------------
create table if not exists public.tp_friendships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.tp_profiles(id) on delete cascade,
  friend_id uuid not null references public.tp_profiles(id) on delete cascade,
  status text not null default 'accepted' check (status in ('pending', 'accepted')),
  requested_by uuid not null references public.tp_profiles(id) on delete cascade,
  last_played_together_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint tp_friendships_no_self check (user_id <> friend_id),
  constraint tp_friendships_unique_pair unique (user_id, friend_id)
);

create index if not exists idx_tp_friendships_user_status
  on public.tp_friendships (user_id, status);

create index if not exists idx_tp_friendships_friend_status
  on public.tp_friendships (friend_id, status);

create index if not exists idx_tp_friendships_requested_by
  on public.tp_friendships (requested_by);

drop trigger if exists trg_tp_friendships_touch on public.tp_friendships;
create trigger trg_tp_friendships_touch
before update on public.tp_friendships
for each row execute function public.tp_touch_updated_at();

alter table public.tp_friendships enable row level security;

drop policy if exists tp_friendships_select_own on public.tp_friendships;
create policy tp_friendships_select_own
  on public.tp_friendships
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or friend_id = (select auth.uid())
  );

drop policy if exists tp_friendships_delete_own on public.tp_friendships;
create policy tp_friendships_delete_own
  on public.tp_friendships
  for delete
  to authenticated
  using (
    user_id = (select auth.uid())
    or friend_id = (select auth.uid())
  );

-- ---------------------------------------------------------------------------
-- 3. In-App Room Invites Table (public.tp_room_invites)
-- ---------------------------------------------------------------------------
create table if not exists public.tp_room_invites (
  id uuid primary key default gen_random_uuid(),
  room_id uuid references public.tp_rooms(id) on delete cascade,
  room_code text not null,
  table_name text not null default 'Private Club',
  variant text not null default 'Classic',
  min_stake integer not null default 100 check (min_stake > 0),
  sender_id uuid not null references public.tp_profiles(id) on delete cascade,
  recipient_id uuid not null references public.tp_profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'expired')),
  created_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null default (timezone('utc', now()) + interval '15 minutes')
);

create index if not exists idx_tp_room_invites_recipient_pending
  on public.tp_room_invites (recipient_id, created_at desc)
  where status = 'pending';

create index if not exists idx_tp_room_invites_sender
  on public.tp_room_invites (sender_id);

create index if not exists idx_tp_room_invites_room
  on public.tp_room_invites (room_id);

alter table public.tp_room_invites enable row level security;

drop policy if exists tp_room_invites_select_own on public.tp_room_invites;
create policy tp_room_invites_select_own
  on public.tp_room_invites
  for select
  to authenticated
  using (
    sender_id = (select auth.uid())
    or recipient_id = (select auth.uid())
  );

drop policy if exists tp_room_invites_update_own on public.tp_room_invites;
create policy tp_room_invites_update_own
  on public.tp_room_invites
  for update
  to authenticated
  using (
    recipient_id = (select auth.uid())
    or sender_id = (select auth.uid())
  )
  with check (
    recipient_id = (select auth.uid())
    or sender_id = (select auth.uid())
  );

-- ---------------------------------------------------------------------------
-- 4. Social & Presence SECURITY DEFINER RPCs
-- ---------------------------------------------------------------------------

-- 4.1 Touch Presence: updates caller's last_seen_at timestamp
create or replace function public.tp_touch_presence()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    return;
  end if;
  update public.tp_profiles
  set last_seen_at = timezone('utc', now())
  where id = v_uid;
end;
$$;

-- 4.2 Add Friend by Player Code: connects two club profiles bidirectionally
create or replace function public.tp_add_friend_by_code(p_player_code text)
returns table (
  friend_id uuid,
  player_code text,
  display_name text,
  avatar_asset text,
  rating integer,
  is_online boolean,
  status_text text,
  is_recently_played boolean
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_clean_code text := upper(trim(coalesce(p_player_code, '')));
  v_target public.tp_profiles%rowtype;
  v_now timestamptz := timezone('utc', now());
  v_online boolean;
  v_status text;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_clean_code = '' then
    raise exception 'Enter a valid Player ID or Invite Code.' using errcode = 'P0001';
  end if;

  update public.tp_profiles
  set last_seen_at = v_now
  where id = v_uid;

  select * into v_target
  from public.tp_profiles p
  where upper(p.player_code) = v_clean_code
     or upper(p.player_code) = 'TP' || v_clean_code
     or upper(substr(replace(p.id::text, '-', ''), 1, 8)) = replace(v_clean_code, 'TP', '')
  order by p.created_at asc
  limit 1;

  if not found then
    raise exception 'No player found with code %', v_clean_code using errcode = 'P0002';
  end if;

  if v_target.id = v_uid then
    raise exception 'You cannot add your own Player ID.' using errcode = 'P0001';
  end if;

  insert into public.tp_friendships (user_id, friend_id, status, requested_by)
  values (v_uid, v_target.id, 'accepted', v_uid)
  on conflict (user_id, friend_id) do update
    set status = 'accepted',
        updated_at = v_now;

  insert into public.tp_friendships (user_id, friend_id, status, requested_by)
  values (v_target.id, v_uid, 'accepted', v_uid)
  on conflict (user_id, friend_id) do update
    set status = 'accepted',
        updated_at = v_now;

  v_online := (v_target.last_seen_at > v_now - interval '2 minutes')
    or exists (
      select 1
      from public.tp_room_players rp
      join public.tp_rooms r on r.id = rp.room_id
      where rp.profile_id = v_target.id
        and r.status in ('waiting', 'playing')
    );

  v_status := case
    when v_online then 'Online'
    else 'Added to circle'
  end;

  return query select
    v_target.id,
    v_target.player_code,
    v_target.display_name,
    v_target.avatar_asset,
    v_target.rating,
    v_online,
    v_status,
    false;
end;
$$;

-- 4.3 Remove Friend: deletes both directions of friendship
create or replace function public.tp_remove_friend(p_friend_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  delete from public.tp_friendships
  where (user_id = v_uid and friend_id = p_friend_id)
     or (user_id = p_friend_id and friend_id = v_uid);

  return true;
end;
$$;

-- 4.4 Get Friends Directory: returns caller's friends with live room/online presence
create or replace function public.tp_get_friends_directory()
returns table (
  friend_id uuid,
  player_code text,
  display_name text,
  avatar_asset text,
  rating integer,
  is_online boolean,
  status_text text,
  is_recently_played boolean,
  active_room_code text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  update public.tp_profiles
  set last_seen_at = v_now
  where id = v_uid;

  return query
  select
    p.id as friend_id,
    p.player_code,
    p.display_name,
    p.avatar_asset,
    p.rating,
    (
      p.last_seen_at > v_now - interval '2 minutes'
      or active_rm.room_id is not null
      or exists (select 1 from public.tp_bot_pool bp where bp.profile_id = p.id)
    ) as is_online,
    case
      when active_rm.table_name is not null then 'Playing • ' || active_rm.table_name
      when p.last_seen_at > v_now - interval '2 minutes'
        or exists (select 1 from public.tp_bot_pool bp where bp.profile_id = p.id)
      then 'Online'
      when p.last_seen_at > v_now - interval '1 hour' then
        'Last seen ' || greatest(1, extract(minute from (v_now - p.last_seen_at))::integer)::text || ' min ago'
      else 'Offline'
    end as status_text,
    (f.last_played_together_at is not null) as is_recently_played,
    active_rm.room_code as active_room_code
  from public.tp_friendships f
  join public.tp_profiles p on p.id = f.friend_id
  left join lateral (
    select r.id as room_id, r.table_name, r.room_code
    from public.tp_room_players rp
    join public.tp_rooms r on r.id = rp.room_id
    where rp.profile_id = p.id
      and r.status in ('waiting', 'playing')
    order by rp.joined_at desc
    limit 1
  ) active_rm on true
  where f.user_id = v_uid
    and f.status = 'accepted'
  order by
    (p.last_seen_at > v_now - interval '2 minutes' or active_rm.room_id is not null) desc,
    p.display_name asc;
end;
$$;

-- 4.5 Send Room Invite: creates an in-app table invite notification for a friend
create or replace function public.tp_send_room_invite(
  p_friend_id uuid,
  p_room_code text,
  p_room_id uuid default null,
  p_table_name text default 'Private Club',
  p_variant text default 'Classic',
  p_min_stake integer default 100
)
returns table (
  invite_id uuid,
  room_code text,
  recipient_name text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_clean_code text := upper(trim(coalesce(p_room_code, '')));
  v_friend public.tp_profiles%rowtype;
  v_inv public.tp_room_invites%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if v_clean_code = '' then
    raise exception 'Room code is required' using errcode = 'P0001';
  end if;

  select * into v_friend
  from public.tp_profiles p
  where p.id = p_friend_id;

  if not found then
    raise exception 'Recipient profile not found' using errcode = 'P0002';
  end if;

  -- Expire any older pending invite from same sender to same recipient for this room code
  update public.tp_room_invites
  set status = 'expired'
  where sender_id = v_uid
    and recipient_id = p_friend_id
    and upper(room_code) = v_clean_code
    and status = 'pending';

  insert into public.tp_room_invites (
    room_id, room_code, table_name, variant, min_stake, sender_id, recipient_id, status
  )
  values (
    p_room_id,
    v_clean_code,
    coalesce(nullif(trim(p_table_name), ''), 'Private Club'),
    coalesce(nullif(trim(p_variant), ''), 'Classic'),
    greatest(10, coalesce(p_min_stake, 100)),
    v_uid,
    p_friend_id,
    'pending'
  )
  returning * into v_inv;

  return query select
    v_inv.id,
    v_inv.room_code,
    v_friend.display_name,
    v_inv.created_at;
end;
$$;

-- 4.6 Get Pending Room Invites: fetches active invites for the authenticated user
create or replace function public.tp_get_pending_room_invites()
returns table (
  invite_id uuid,
  room_id uuid,
  room_code text,
  table_name text,
  variant text,
  min_stake integer,
  sender_id uuid,
  sender_name text,
  sender_avatar text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  return query
  select
    i.id as invite_id,
    i.room_id,
    i.room_code,
    i.table_name,
    i.variant,
    i.min_stake,
    i.sender_id,
    s.display_name as sender_name,
    s.avatar_asset as sender_avatar,
    i.created_at
  from public.tp_room_invites i
  join public.tp_profiles s on s.id = i.sender_id
  where i.recipient_id = v_uid
    and i.status = 'pending'
    and i.expires_at > v_now
  order by i.created_at desc
  limit 10;
end;
$$;

-- 4.7 Respond to Room Invite: marks invite accepted/declined and returns room_code
create or replace function public.tp_respond_room_invite(
  p_invite_id uuid,
  p_accept boolean default true
)
returns table (
  invite_id uuid,
  room_code text,
  status text
)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_uid uuid := (select auth.uid());
  v_inv public.tp_room_invites%rowtype;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  update public.tp_room_invites i
  set status = case when coalesce(p_accept, true) then 'accepted' else 'declined' end
  where i.id = p_invite_id
    and i.recipient_id = v_uid
  returning * into v_inv;

  if not found then
    raise exception 'Invite not found or already handled' using errcode = 'P0002';
  end if;

  return query select v_inv.id, v_inv.room_code, v_inv.status;
end;
$$;

revoke all on function public.tp_touch_presence() from public, anon;
grant execute on function public.tp_touch_presence() to authenticated, service_role;

revoke all on function public.tp_add_friend_by_code(text) from public, anon;
grant execute on function public.tp_add_friend_by_code(text) to authenticated, service_role;

revoke all on function public.tp_remove_friend(uuid) from public, anon;
grant execute on function public.tp_remove_friend(uuid) to authenticated, service_role;

revoke all on function public.tp_get_friends_directory() from public, anon;
grant execute on function public.tp_get_friends_directory() to authenticated, service_role;

revoke all on function public.tp_send_room_invite(uuid, text, uuid, text, text, integer) from public, anon;
grant execute on function public.tp_send_room_invite(uuid, text, uuid, text, text, integer) to authenticated, service_role;

revoke all on function public.tp_get_pending_room_invites() from public, anon;
grant execute on function public.tp_get_pending_room_invites() to authenticated, service_role;

revoke all on function public.tp_respond_room_invite(uuid, boolean) from public, anon;
grant execute on function public.tp_respond_room_invite(uuid, boolean) to authenticated, service_role;
