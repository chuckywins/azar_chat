-- =============================================================================
-- kerochat — schema v3
-- Adds: messages, coin_transactions, vip_subscriptions, announcements,
--       gifts (catalog), gift_transactions, presence tracking on profiles.
-- Idempotent. Run after schema_v2.sql in the SQL Editor.
-- =============================================================================

-- 1) profiles: coins + last_seen_at + is_online (denormalised for queries) ----
alter table public.profiles add column if not exists coins        integer     not null default 0;
alter table public.profiles add column if not exists last_seen_at timestamptz not null default now();
alter table public.profiles add column if not exists is_online    boolean     not null default false;

create index if not exists profiles_last_seen_idx on public.profiles(last_seen_at desc);
create index if not exists profiles_is_online_idx on public.profiles(is_online)  where is_online = true;


-- 2) messages (persistent chat between friends/users) ------------------------
create table if not exists public.messages (
  id           uuid primary key default gen_random_uuid(),
  sender_id    uuid not null references public.profiles(id) on delete cascade,
  receiver_id  uuid not null references public.profiles(id) on delete cascade,
  body         text not null,
  created_at   timestamptz not null default now(),
  read_at      timestamptz
);

create index if not exists messages_pair_idx     on public.messages(sender_id, receiver_id, created_at desc);
create index if not exists messages_inbox_idx    on public.messages(receiver_id, created_at desc);
create index if not exists messages_unread_idx   on public.messages(receiver_id) where read_at is null;


-- 3) coin_transactions (audit trail; balance derived & cached on profiles.coins) -
create table if not exists public.coin_transactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  delta       integer not null,                -- positive = grant, negative = spend
  reason      text not null check (reason in ('purchase','gift_sent','gift_received','admin_grant','referral_bonus','ad_reward','daily_bonus','refund')),
  related_id  uuid,
  note        text,
  created_at  timestamptz not null default now(),
  created_by  uuid references public.profiles(id) on delete set null
);

create index if not exists coin_tx_user_idx on public.coin_transactions(user_id, created_at desc);

-- Trigger keeps profiles.coins in sync with sum of deltas.
create or replace function public.apply_coin_delta() returns trigger
language plpgsql security definer as $$
begin
  update public.profiles set coins = greatest(0, coins + new.delta) where id = new.user_id;
  return new;
end $$;

drop trigger if exists coin_tx_after_insert on public.coin_transactions;
create trigger coin_tx_after_insert
  after insert on public.coin_transactions
  for each row execute function public.apply_coin_delta();


-- 4) vip_subscriptions -------------------------------------------------------
create table if not exists public.vip_subscriptions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  tier        text not null default 'vip' check (tier in ('vip', 'vip_plus')),
  starts_at   timestamptz not null default now(),
  expires_at  timestamptz,                     -- null = lifetime
  source      text not null default 'admin' check (source in ('stripe','admin','promo','referral')),
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  created_by  uuid references public.profiles(id) on delete set null
);

create index if not exists vip_active_idx on public.vip_subscriptions(user_id) where active = true;

-- profiles.is_vip live view
create or replace view public.user_vip_v as
  select p.id,
         coalesce((
           select v.tier from public.vip_subscriptions v
           where v.user_id = p.id and v.active = true
             and (v.expires_at is null or v.expires_at > now())
           order by v.created_at desc limit 1
         ), null) as tier
  from public.profiles p;


-- 5) gifts (catalog — editable from admin) -----------------------------------
create table if not exists public.gifts (
  id          text primary key,        -- e.g. 'rose'
  name        text not null,
  glyph       text not null,           -- emoji
  cost        integer not null check (cost >= 0),
  sort_order  integer not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- seed default gifts (won't overwrite existing rows)
insert into public.gifts (id, name, glyph, cost, sort_order, active) values
  ('rose',   'Gül',    '🌹',    9, 10, true),
  ('heart',  'Kalp',   '💖',   19, 20, true),
  ('star',   'Yıldız', '⭐',   29, 30, true),
  ('crown',  'Taç',    '👑',   99, 40, true),
  ('rocket', 'Roket',  '🚀',  149, 50, true),
  ('ring',   'Yüzük',  '💍',  299, 60, true)
on conflict (id) do nothing;


-- 6) gift_transactions -------------------------------------------------------
create table if not exists public.gift_transactions (
  id           uuid primary key default gen_random_uuid(),
  gift_id      text not null references public.gifts(id) on delete set null,
  sender_id    uuid not null references public.profiles(id) on delete cascade,
  receiver_id  uuid not null references public.profiles(id) on delete cascade,
  session_id   uuid references public.sessions(id) on delete set null,
  cost         integer not null,
  created_at   timestamptz not null default now()
);

create index if not exists gift_tx_sender_idx   on public.gift_transactions(sender_id, created_at desc);
create index if not exists gift_tx_receiver_idx on public.gift_transactions(receiver_id, created_at desc);


-- 7) announcements (admin-managed campaigns) ---------------------------------
create table if not exists public.announcements (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  body        text,
  icon        text default 'campaign',     -- material icon name hint
  cta_label   text,
  cta_url     text,
  active      boolean not null default true,
  starts_at   timestamptz not null default now(),
  ends_at     timestamptz,
  created_at  timestamptz not null default now(),
  created_by  uuid references public.profiles(id) on delete set null
);

create index if not exists ann_active_idx on public.announcements(active, starts_at desc) where active = true;


-- 8) live_stats (singleton row, signaling server updates periodically) -------
create table if not exists public.live_stats (
  id           int primary key default 1,
  online_users integer not null default 0,
  queue        integer not null default 0,
  updated_at   timestamptz not null default now(),
  check (id = 1)
);
insert into public.live_stats (id) values (1) on conflict (id) do nothing;


-- 9) RLS ---------------------------------------------------------------------

-- messages: only sender or receiver can read/insert
alter table public.messages enable row level security;
drop policy if exists "messages: read own" on public.messages;
create policy "messages: read own"
  on public.messages for select
  using (auth.uid() in (sender_id, receiver_id));

drop policy if exists "messages: insert as sender" on public.messages;
create policy "messages: insert as sender"
  on public.messages for insert
  with check (auth.uid() = sender_id);

drop policy if exists "messages: update as receiver" on public.messages;
create policy "messages: update as receiver"
  on public.messages for update
  using (auth.uid() = receiver_id)
  with check (auth.uid() = receiver_id);

-- coin_transactions: read own + admin all; insert via service_role only (server-side)
alter table public.coin_transactions enable row level security;
drop policy if exists "coin_tx: read own" on public.coin_transactions;
create policy "coin_tx: read own"
  on public.coin_transactions for select
  using (auth.uid() = user_id
         or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')));

drop policy if exists "coin_tx: admin insert" on public.coin_transactions;
create policy "coin_tx: admin insert"
  on public.coin_transactions for insert
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')));

-- vip_subscriptions: read own + admin all; admin manages
alter table public.vip_subscriptions enable row level security;
drop policy if exists "vip: read own" on public.vip_subscriptions;
create policy "vip: read own"
  on public.vip_subscriptions for select
  using (auth.uid() = user_id
         or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')));

drop policy if exists "vip: admin all" on public.vip_subscriptions;
create policy "vip: admin all"
  on public.vip_subscriptions for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')));

-- gifts (catalog): public read, admin write
alter table public.gifts enable row level security;
drop policy if exists "gifts: read all" on public.gifts;
create policy "gifts: read all"
  on public.gifts for select using (true);

drop policy if exists "gifts: admin write" on public.gifts;
create policy "gifts: admin write"
  on public.gifts for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')));

-- gift_transactions: read own (sender/receiver) + admin
alter table public.gift_transactions enable row level security;
drop policy if exists "gift_tx: read own" on public.gift_transactions;
create policy "gift_tx: read own"
  on public.gift_transactions for select
  using (auth.uid() in (sender_id, receiver_id)
         or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')));

drop policy if exists "gift_tx: insert as sender" on public.gift_transactions;
create policy "gift_tx: insert as sender"
  on public.gift_transactions for insert
  with check (auth.uid() = sender_id);

-- announcements: public read active, admin write
alter table public.announcements enable row level security;
drop policy if exists "ann: read active" on public.announcements;
create policy "ann: read active"
  on public.announcements for select
  using (active = true and starts_at <= now() and (ends_at is null or ends_at > now())
         or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')));

drop policy if exists "ann: admin write" on public.announcements;
create policy "ann: admin write"
  on public.announcements for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')));

-- live_stats: public read, service_role write
alter table public.live_stats enable row level security;
drop policy if exists "live_stats: read all" on public.live_stats;
create policy "live_stats: read all"
  on public.live_stats for select using (true);


-- 10) Helper RPCs ------------------------------------------------------------

-- Mark a conversation read (all msgs from peer to me).
create or replace function public.mark_conversation_read(peer uuid) returns void
language sql security definer as $$
  update public.messages
     set read_at = now()
   where receiver_id = auth.uid() and sender_id = peer and read_at is null;
$$;

-- Conversation list: latest message per friend + unread count.
create or replace function public.my_conversations() returns table (
  peer_id uuid,
  nickname text,
  gender text,
  country text,
  last_body text,
  last_at timestamptz,
  unread integer
) language sql stable as $$
  with my as (select auth.uid() as uid),
       last_msg as (
         select case when m.sender_id = (select uid from my) then m.receiver_id else m.sender_id end as peer_id,
                m.body, m.created_at,
                row_number() over (
                  partition by case when m.sender_id = (select uid from my) then m.receiver_id else m.sender_id end
                  order by m.created_at desc
                ) as rn
           from public.messages m
          where m.sender_id = (select uid from my) or m.receiver_id = (select uid from my)
       )
  select l.peer_id, p.nickname, p.gender, p.country, l.body, l.created_at,
         coalesce((select count(*)::int from public.messages u
                    where u.sender_id = l.peer_id and u.receiver_id = (select uid from my) and u.read_at is null), 0)
    from last_msg l
    join public.profiles p on p.id = l.peer_id
   where l.rn = 1
   order by l.created_at desc;
$$;

-- Send a gift atomically: insert tx, debit sender, credit receiver if positive cost.
create or replace function public.send_gift(p_gift_id text, p_receiver_id uuid, p_session_id uuid default null)
  returns gift_transactions
  language plpgsql security definer as $$
declare
  v_cost int;
  v_tx public.gift_transactions;
  v_sender_balance int;
begin
  select cost into v_cost from public.gifts where id = p_gift_id and active = true;
  if v_cost is null then raise exception 'gift_not_found'; end if;
  select coins into v_sender_balance from public.profiles where id = auth.uid();
  if v_sender_balance is null or v_sender_balance < v_cost then raise exception 'insufficient_coins'; end if;

  insert into public.gift_transactions (gift_id, sender_id, receiver_id, session_id, cost)
  values (p_gift_id, auth.uid(), p_receiver_id, p_session_id, v_cost)
  returning * into v_tx;

  insert into public.coin_transactions (user_id, delta, reason, related_id, created_by)
  values (auth.uid(), -v_cost, 'gift_sent', v_tx.id, auth.uid());

  return v_tx;
end $$;

-- Admin: grant coins to a user.
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
  return v_tx;
end $$;

-- Admin: grant VIP.
create or replace function public.admin_grant_vip(p_user_id uuid, p_days int default 30, p_tier text default 'vip')
  returns vip_subscriptions
  language plpgsql security definer as $$
declare
  v_caller_role text;
  v_row public.vip_subscriptions;
begin
  select role into v_caller_role from public.profiles where id = auth.uid();
  if v_caller_role not in ('moderator','admin') then raise exception 'not_admin'; end if;

  update public.vip_subscriptions set active = false where user_id = p_user_id and active = true;

  insert into public.vip_subscriptions (user_id, tier, expires_at, source, created_by)
  values (p_user_id, p_tier, case when p_days > 0 then now() + (p_days || ' days')::interval else null end, 'admin', auth.uid())
  returning * into v_row;
  return v_row;
end $$;
