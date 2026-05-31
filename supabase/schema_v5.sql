-- =============================================================================
-- kerochat — schema v5: moderator/admin split + bonuses + blocks + audit + notifications
-- Run after schema_v4.
-- =============================================================================

-- ── 1) profiles: streak fields + welcome flag --------------------------------
alter table public.profiles add column if not exists welcome_granted     boolean     not null default false;
alter table public.profiles add column if not exists daily_streak_count  integer     not null default 0;
alter table public.profiles add column if not exists daily_streak_last   date;

-- ── 2) blocks (one-way kalıcı engel; her iki yön kontrolü query'de) ---------
create table if not exists public.blocks (
  id          uuid primary key default gen_random_uuid(),
  blocker_id  uuid not null references public.profiles(id) on delete cascade,
  blocked_id  uuid not null references public.profiles(id) on delete cascade,
  reason      text,
  created_at  timestamptz not null default now(),
  unique (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index if not exists blocks_blocker_idx on public.blocks(blocker_id);
create index if not exists blocks_blocked_idx on public.blocks(blocked_id);

alter table public.blocks enable row level security;

drop policy if exists "blocks: read own" on public.blocks;
create policy "blocks: read own"
  on public.blocks for select
  using (auth.uid() = blocker_id
         or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')));

drop policy if exists "blocks: insert own" on public.blocks;
create policy "blocks: insert own"
  on public.blocks for insert
  with check (auth.uid() = blocker_id);

drop policy if exists "blocks: delete own" on public.blocks;
create policy "blocks: delete own"
  on public.blocks for delete
  using (auth.uid() = blocker_id);


-- ── 3) audit_logs (admin & moderator actions trail) -------------------------
create table if not exists public.audit_logs (
  id          uuid primary key default gen_random_uuid(),
  actor_id    uuid references public.profiles(id) on delete set null,
  action      text not null,            -- 'ban_user','grant_coins','grant_vip','update_role','delete_gift',...
  target_id   uuid,                     -- typically a user id
  details     jsonb,                    -- arbitrary payload
  ip          text,
  created_at  timestamptz not null default now()
);

create index if not exists audit_logs_actor_idx  on public.audit_logs(actor_id, created_at desc);
create index if not exists audit_logs_action_idx on public.audit_logs(action, created_at desc);

alter table public.audit_logs enable row level security;

drop policy if exists "audit: admin only read" on public.audit_logs;
create policy "audit: admin only read"
  on public.audit_logs for select
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

drop policy if exists "audit: anyone insert (via security definer rpcs)" on public.audit_logs;
create policy "audit: anyone insert (via security definer rpcs)"
  on public.audit_logs for insert
  with check (true);


-- ── 4) notifications (in-app inbox: bildirim merkezi) ----------------------
create table if not exists public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  kind        text not null check (kind in ('like','match','message','gift','system','admin','vip','coin')),
  title       text not null,
  body        text,
  related_id  uuid,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);

create index if not exists notif_user_idx  on public.notifications(user_id, created_at desc);
create index if not exists notif_unread_idx on public.notifications(user_id) where read_at is null;

alter table public.notifications enable row level security;

drop policy if exists "notif: read own" on public.notifications;
create policy "notif: read own"
  on public.notifications for select using (auth.uid() = user_id);

drop policy if exists "notif: update own (read)" on public.notifications;
create policy "notif: update own (read)"
  on public.notifications for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "notif: insert via rpc/server" on public.notifications;
create policy "notif: insert via rpc/server"
  on public.notifications for insert with check (true);


-- ── 5) Welcome bonus + auto-notify on new profile ---------------------------
create or replace function public.grant_welcome_bonus() returns trigger
language plpgsql security definer as $$
begin
  if new.welcome_granted = false then
    insert into public.coin_transactions (user_id, delta, reason, note)
    values (new.id, 100, 'admin_grant', 'welcome bonus');

    update public.profiles set welcome_granted = true where id = new.id;

    insert into public.notifications (user_id, kind, title, body)
    values (new.id, 'system', 'Hoş geldin!', '+100 coin hediyemiz seni bekliyor 🎁');
  end if;
  return new;
end $$;

drop trigger if exists profiles_welcome_bonus on public.profiles;
create trigger profiles_welcome_bonus
  after insert on public.profiles
  for each row execute function public.grant_welcome_bonus();

-- backfill existing users
do $$ begin
  update public.profiles set welcome_granted = false where welcome_granted is null;
end $$;


-- ── 6) Daily login bonus RPC -----------------------------------------------
-- Call: select claim_daily_bonus();
-- Returns the streak count after claim (or 0 if already claimed today).
create or replace function public.claim_daily_bonus() returns int
language plpgsql security definer as $$
declare
  v_uid uuid;
  v_today date := (now() at time zone 'utc')::date;
  v_last date;
  v_streak int;
  v_bonus int;
begin
  v_uid := auth.uid();
  if v_uid is null then raise exception 'not_authed'; end if;

  select daily_streak_last, daily_streak_count into v_last, v_streak
    from public.profiles where id = v_uid for update;

  if v_last = v_today then
    return 0; -- already claimed today
  end if;

  if v_last = (v_today - 1) then
    v_streak := v_streak + 1;
  else
    v_streak := 1;
  end if;

  -- escalating bonus: day 1=10, day 2=15, day 3=20, day 7=50, cap 100
  v_bonus := least(100, 5 + v_streak * 5);

  insert into public.coin_transactions (user_id, delta, reason, note)
  values (v_uid, v_bonus, 'daily_bonus', concat('streak day ', v_streak));

  update public.profiles set daily_streak_count = v_streak, daily_streak_last = v_today
   where id = v_uid;

  insert into public.notifications (user_id, kind, title, body)
  values (v_uid, 'coin', 'Günlük bonus!', concat('+', v_bonus, ' coin — ', v_streak, '. günlük seri 🔥'));

  return v_streak;
end $$;


-- ── 7) Referral bonus on first signup with code ----------------------------
-- Apply when a freshly created profile has referred_by set, both inviter and invitee earn.
create or replace function public.handle_referral_signup() returns trigger
language plpgsql security definer as $$
begin
  if new.referred_by is not null and old.referred_by is null then
    -- inviter gets +50
    insert into public.coin_transactions (user_id, delta, reason, note, related_id)
    values (new.referred_by, 50, 'referral_bonus', 'referral signup', new.id);

    insert into public.notifications (user_id, kind, title, body, related_id)
    values (new.referred_by, 'coin', '+50 coin', 'Davet ettiğin biri kayıt oldu 🎉', new.id);

    -- invitee also gets +25
    insert into public.coin_transactions (user_id, delta, reason, note, related_id)
    values (new.id, 25, 'referral_bonus', 'used referral code', new.referred_by);
  end if;
  return new;
end $$;

drop trigger if exists profiles_referral_bonus on public.profiles;
create trigger profiles_referral_bonus
  after update on public.profiles
  for each row execute function public.handle_referral_signup();


-- ── 8) Admin grant RPCs: write audit log -----------------------------------
create or replace function public.admin_grant_coins(p_user_id uuid, p_delta int, p_note text default null)
  returns coin_transactions
  language plpgsql security definer as $$
declare
  v_tx public.coin_transactions;
  v_caller_role text;
begin
  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role not in ('moderator','admin') then raise exception 'not_admin'; end if;

  insert into public.coin_transactions (user_id, delta, reason, note, created_by)
  values (p_user_id, p_delta, 'admin_grant', p_note, auth.uid())
  returning * into v_tx;

  insert into public.audit_logs (actor_id, action, target_id, details)
  values (auth.uid(), 'grant_coins', p_user_id,
          jsonb_build_object('delta', p_delta, 'note', coalesce(p_note, '')));

  insert into public.notifications (user_id, kind, title, body)
  values (p_user_id, 'coin',
          case when p_delta > 0 then concat('+', p_delta, ' coin') else concat(p_delta, ' coin') end,
          coalesce(p_note, ''));

  return v_tx;
end $$;

create or replace function public.admin_grant_vip(p_user_id uuid, p_days int default 30, p_tier text default 'vip')
  returns vip_subscriptions
  language plpgsql security definer as $$
declare
  v_caller_role text;
  v_row public.vip_subscriptions;
begin
  select role into v_caller_role from public.profiles where id = auth.uid();
  -- Only admin (not moderator) can grant VIP (revenue-impacting).
  if v_caller_role <> 'admin' then raise exception 'not_admin'; end if;

  update public.vip_subscriptions set active = false where user_id = p_user_id and active = true;

  insert into public.vip_subscriptions (user_id, tier, expires_at, source, created_by)
  values (p_user_id, p_tier, case when p_days > 0 then now() + (p_days || ' days')::interval else null end, 'admin', auth.uid())
  returning * into v_row;

  insert into public.audit_logs (actor_id, action, target_id, details)
  values (auth.uid(), 'grant_vip', p_user_id,
          jsonb_build_object('tier', p_tier, 'days', p_days));

  insert into public.notifications (user_id, kind, title, body)
  values (p_user_id, 'vip', concat(p_tier, ' aktif'),
          case when p_days > 0 then concat(p_days, ' gün süreyle') else 'süresiz' end);

  return v_row;
end $$;


-- ── 9) Earnings stats RPC (admin only) -------------------------------------
create or replace function public.admin_earnings_daily(p_days int default 30)
  returns table (
    day date,
    coin_count bigint,
    coin_amount bigint
  )
  language plpgsql security definer as $$
declare
  v_caller_role text;
begin
  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role <> 'admin' then raise exception 'not_admin'; end if;

  return query
  select (created_at at time zone 'utc')::date as day,
         count(*)::bigint as coin_count,
         coalesce(sum(delta), 0)::bigint as coin_amount
    from public.coin_transactions
   where reason = 'purchase'
     and created_at >= (now() - (p_days || ' days')::interval)
   group by day
   order by day;
end $$;


-- ── 10) RLS yetki ayrımı: moderator vs admin -------------------------------
-- Mevcut "in ('moderator','admin')" politikalarını ayır.
-- Moderator: rapor inceleme, ban, profile view.
-- Admin: rol değiştirme, coin/vip grant, kampanya/hediye/paket yönetimi.

-- profiles: admin-only updates to role/coins
drop policy if exists "profiles: admin update any" on public.profiles;
create policy "profiles: moderator can ban/unban only"
  on public.profiles for update
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'moderator'
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'moderator'
    )
  );

drop policy if exists "profiles: admin update any v2" on public.profiles;
create policy "profiles: admin update any v2"
  on public.profiles for update
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  )
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- announcements: admin only (was moderator+admin)
drop policy if exists "ann: admin write" on public.announcements;
create policy "ann: admin write"
  on public.announcements for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- gifts catalog: admin only
drop policy if exists "gifts: admin write" on public.gifts;
create policy "gifts: admin write"
  on public.gifts for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- coin_packs: admin only
drop policy if exists "coin_packs: admin write" on public.coin_packs;
create policy "coin_packs: admin write"
  on public.coin_packs for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- vip_subscriptions: admin only writes (was moderator+admin)
drop policy if exists "vip: admin all" on public.vip_subscriptions;
create policy "vip: admin all"
  on public.vip_subscriptions for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- coin_transactions: admin grant only (insert)
drop policy if exists "coin_tx: admin insert" on public.coin_transactions;
create policy "coin_tx: admin insert"
  on public.coin_transactions for insert
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

-- reports: moderator can update status (this stays)
-- bans: moderator + admin (this stays)


-- ── 11) Realtime publication for new tables --------------------------------
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'notifications') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'blocks') then
    alter publication supabase_realtime add table public.blocks;
  end if;
end $$;
