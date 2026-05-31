-- =============================================================================
-- kerochat / azar_chat — Supabase schema
-- Run inside Supabase SQL Editor.  Idempotent: safe to re-run.
-- =============================================================================

-- 1) profiles ---------------------------------------------------------------
-- One row per authenticated user.  Mirrors auth.users.id.

create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  nickname      text,
  gender        text check (gender in ('M', 'F', 'X')),
  country       text,
  avatar_url    text,
  role          text not null default 'user' check (role in ('user', 'moderator', 'admin')),
  is_banned     boolean not null default false,
  banned_until  timestamptz,
  ban_reason    text,
  device_id     text,                   -- last seen device fingerprint
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists profiles_role_idx       on public.profiles(role);
create index if not exists profiles_is_banned_idx  on public.profiles(is_banned) where is_banned = true;
create index if not exists profiles_device_id_idx  on public.profiles(device_id);

-- Auto-update updated_at
create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();


-- 2) sessions ---------------------------------------------------------------
-- One row per matched pair.  Used for reports and analytics.

create table if not exists public.sessions (
  id            uuid primary key default gen_random_uuid(),
  peer_a        uuid references public.profiles(id) on delete set null,
  peer_b        uuid references public.profiles(id) on delete set null,
  device_a      text,                   -- fallback when peer is anonymous
  device_b      text,
  started_at    timestamptz not null default now(),
  ended_at      timestamptz,
  end_reason    text                    -- 'next' | 'leave' | 'disconnect' | 'reported'
);

create index if not exists sessions_peer_a_idx   on public.sessions(peer_a);
create index if not exists sessions_peer_b_idx   on public.sessions(peer_b);
create index if not exists sessions_started_idx  on public.sessions(started_at desc);


-- 3) reports ----------------------------------------------------------------
-- User-filed reports.  Triggers automatic ban after threshold.

create table if not exists public.reports (
  id             uuid primary key default gen_random_uuid(),
  reporter_id    uuid references public.profiles(id) on delete set null,
  reporter_device text,
  reported_id    uuid references public.profiles(id) on delete cascade,
  reported_device text,
  session_id     uuid references public.sessions(id) on delete set null,
  reason         text not null check (reason in ('nsfw', 'harassment', 'spam', 'minor', 'other')),
  note           text,
  status         text not null default 'pending' check (status in ('pending', 'reviewed', 'dismissed', 'actioned')),
  created_at     timestamptz not null default now(),
  reviewed_at    timestamptz,
  reviewed_by    uuid references public.profiles(id) on delete set null
);

create index if not exists reports_reported_id_idx on public.reports(reported_id);
create index if not exists reports_status_idx      on public.reports(status) where status = 'pending';
create index if not exists reports_created_idx     on public.reports(created_at desc);


-- 4) bans -------------------------------------------------------------------
-- Active and historical bans.  Profile is_banned + banned_until is the live state.

create table if not exists public.bans (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid references public.profiles(id) on delete cascade,
  device_id    text,
  reason       text not null,
  until        timestamptz,             -- null = permanent
  created_at   timestamptz not null default now(),
  created_by   uuid references public.profiles(id) on delete set null,
  source       text not null default 'manual' check (source in ('manual', 'auto_reports', 'ai_moderation')),
  active       boolean not null default true
);

create index if not exists bans_user_id_idx   on public.bans(user_id) where active = true;
create index if not exists bans_device_id_idx on public.bans(device_id) where active = true;


-- 5) Auto-ban trigger -------------------------------------------------------
-- If a user gets 3 pending reports within 24h, auto-ban them for 24h.

create or replace function public.maybe_auto_ban() returns trigger
language plpgsql security definer as $$
declare
  recent_reports int;
  target_user_id uuid;
begin
  target_user_id := new.reported_id;
  if target_user_id is null then return new; end if;

  select count(*) into recent_reports
    from public.reports
   where reported_id = target_user_id
     and created_at > now() - interval '24 hours'
     and status = 'pending';

  if recent_reports >= 3 then
    update public.profiles
       set is_banned    = true,
           banned_until = now() + interval '24 hours',
           ban_reason   = 'auto: 3+ reports in 24h'
     where id = target_user_id
       and is_banned = false;

    insert into public.bans (user_id, reason, until, source)
    values (target_user_id, 'auto: 3+ reports in 24h', now() + interval '24 hours', 'auto_reports');
  end if;

  return new;
end $$;

drop trigger if exists reports_after_insert on public.reports;
create trigger reports_after_insert
  after insert on public.reports
  for each row execute function public.maybe_auto_ban();


-- 6) Auto-create profile on signup -----------------------------------------
-- Whenever a new auth.users row appears, mirror it into profiles.

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer as $$
begin
  insert into public.profiles (id, nickname)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', 'Misafir'))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- 7) Row Level Security -----------------------------------------------------

alter table public.profiles enable row level security;
alter table public.sessions enable row level security;
alter table public.reports  enable row level security;
alter table public.bans     enable row level security;

-- profiles
drop policy if exists "profiles: read own + public fields of others" on public.profiles;
create policy "profiles: read own + public fields of others"
  on public.profiles for select
  using (true);  -- public read for nickname/gender; sensitive cols masked at app layer

drop policy if exists "profiles: update own" on public.profiles;
create policy "profiles: update own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- reports: anyone authenticated can insert; only admins can read
drop policy if exists "reports: insert by authed user" on public.reports;
create policy "reports: insert by authed user"
  on public.reports for insert
  with check (auth.uid() is not null);

drop policy if exists "reports: admin read" on public.reports;
create policy "reports: admin read"
  on public.reports for select
  using (exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('moderator', 'admin')
  ));

-- bans: admin-only
drop policy if exists "bans: admin all" on public.bans;
create policy "bans: admin all"
  on public.bans for all
  using (exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role in ('moderator', 'admin')
  ));

-- sessions: only the participants or admins can read
drop policy if exists "sessions: participant or admin read" on public.sessions;
create policy "sessions: participant or admin read"
  on public.sessions for select
  using (
    auth.uid() in (peer_a, peer_b)
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator', 'admin'))
  );


-- =============================================================================
-- POST-DEPLOY:  Promote yourself to admin
--   update public.profiles set role = 'admin' where id = '<your-auth-uid>';
-- Find your auth uid via Supabase dashboard → Authentication → Users.
-- =============================================================================
