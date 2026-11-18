-- Teen Patti (Ace Society) P0 Schema: Unified Profiles (Human + Online AI Agents),
-- Wallet Ledger, and Game History with Row-Level Security.

create extension if not exists pgcrypto;

create table if not exists public.tp_profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  player_code text unique not null,
  display_name text not null,
  avatar_asset text not null,
  participant_kind text not null default 'human'
    check (participant_kind in ('human', 'client_bot', 'online_agent')),
  persona_tag text,
  linked_provider text,
  chips bigint not null default 25000,
  rating integer not null default 1000,
  games_played integer not null default 0,
  wins integer not null default 0,
  current_win_streak integer not null default 0,
  best_streak integer not null default 0,
  daily_streak integer not null default 1,
  best_daily_streak integer not null default 1,
  total_rewards_earned bigint not null default 0,
  last_daily_claim_date text,
  sound_effects boolean not null default true,
  background_music boolean not null default true,
  vibration boolean not null default true,
  weekly_games_won integer[] not null default '{0,0,0,0,0,0,0}',
  weekly_chips_won integer[] not null default '{0,0,0,0,0,0,0}',
  weekly_win_rate integer[] not null default '{0,0,0,0,0,0,0}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tp_wallet_transactions (
  id text primary key,
  profile_id uuid not null references public.tp_profiles(id) on delete cascade,
  type text not null check (type in ('dailyReward', 'gameWin', 'chipPurchase', 'gameEntry')),
  title text not null,
  subtitle text not null,
  amount bigint not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_tp_wallet_tx_profile_created
  on public.tp_wallet_transactions(profile_id, created_at desc);

create table if not exists public.tp_game_history (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.tp_profiles(id) on delete cascade,
  table_name text not null,
  variant text not null default 'Classic',
  boot_amount integer not null,
  pot_amount bigint not null,
  net_chips bigint not null,
  won boolean not null,
  hand_label text not null,
  win_reason text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_tp_game_history_profile_created
  on public.tp_game_history(profile_id, created_at desc);

create or replace function public.tp_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_tp_profiles_updated_at on public.tp_profiles;
create trigger trg_tp_profiles_updated_at
  before update on public.tp_profiles
  for each row execute function public.tp_touch_updated_at();

alter table public.tp_profiles enable row level security;
alter table public.tp_wallet_transactions enable row level security;
alter table public.tp_game_history enable row level security;

-- Public player cards/profiles are readable by authenticated/anonymous table peers.
create policy "tp_profiles_select_all"
  on public.tp_profiles for select
  using (true);

create policy "tp_profiles_insert_own"
  on public.tp_profiles for insert
  with check (auth.uid() is not null and (auth_user_id = auth.uid() or id = auth.uid()));

create policy "tp_profiles_update_own"
  on public.tp_profiles for update
  using (auth.uid() is not null and (auth_user_id = auth.uid() or id = auth.uid()))
  with check (auth.uid() is not null and (auth_user_id = auth.uid() or id = auth.uid()));

create policy "tp_wallet_tx_select_own"
  on public.tp_wallet_transactions for select
  using (
    exists (
      select 1 from public.tp_profiles p
      where p.id = profile_id and (p.auth_user_id = auth.uid() or p.id = auth.uid())
    )
  );

create policy "tp_wallet_tx_insert_own"
  on public.tp_wallet_transactions for insert
  with check (
    exists (
      select 1 from public.tp_profiles p
      where p.id = profile_id and (p.auth_user_id = auth.uid() or p.id = auth.uid())
    )
  );

create policy "tp_game_history_select_own"
  on public.tp_game_history for select
  using (
    exists (
      select 1 from public.tp_profiles p
      where p.id = profile_id and (p.auth_user_id = auth.uid() or p.id = auth.uid())
    )
  );

create policy "tp_game_history_insert_own"
  on public.tp_game_history for insert
  with check (
    exists (
      select 1 from public.tp_profiles p
      where p.id = profile_id and (p.auth_user_id = auth.uid() or p.id = auth.uid())
    )
  );
