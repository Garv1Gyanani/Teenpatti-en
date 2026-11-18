-- Fix PL/pgSQL OUT parameter vs table column ambiguity in matchmaking RPCs.

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
#variable_conflict use_column
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
#variable_conflict use_column
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
#variable_conflict use_column
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
