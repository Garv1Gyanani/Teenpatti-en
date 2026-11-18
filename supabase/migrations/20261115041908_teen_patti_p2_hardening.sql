-- Cleanup legacy P0 permissive policies and harden search_path on touch trigger.

drop policy if exists tp_profiles_select_all on public.tp_profiles;
drop policy if exists tp_wallet_tx_insert_own on public.tp_wallet_transactions;
drop policy if exists tp_wallet_tx_select_own on public.tp_wallet_transactions;
drop policy if exists tp_game_history_insert_own on public.tp_game_history;
drop policy if exists tp_game_history_select_own on public.tp_game_history;

create or replace function public.tp_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

-- Allow waiting private room host to toggle fill_with_ai cleanly via SECURITY INVOKER update policy.
drop policy if exists tp_rooms_update_host_waiting on public.tp_rooms;
create policy tp_rooms_update_host_waiting
  on public.tp_rooms
  for update
  to authenticated
  using (
    host_profile_id = (select auth.uid())
    and status = 'waiting'
  )
  with check (
    host_profile_id = (select auth.uid())
    and status = 'waiting'
  );
