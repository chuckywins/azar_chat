-- =============================================================================
-- kerochat — schema v2: friends, likes, referrals, trust score, verified flags
-- Idempotent. Run in Supabase SQL Editor after the base schema.
-- =============================================================================

-- 1) profiles: add verification + referral + match counters ------------------
alter table public.profiles add column if not exists verified_photo boolean not null default false;
alter table public.profiles add column if not exists verified_phone boolean not null default false;
alter table public.profiles add column if not exists age_confirmed  boolean not null default false;
alter table public.profiles add column if not exists referral_code  text;
alter table public.profiles add column if not exists referred_by    uuid references public.profiles(id) on delete set null;
alter table public.profiles add column if not exists matches_count  integer not null default 0;

create unique index if not exists profiles_referral_code_idx on public.profiles(referral_code) where referral_code is not null;

-- Auto-generate a unique 8-char referral code on insert (and backfill).
create or replace function public.gen_referral_code() returns text language plpgsql as $$
declare
  alphabet text := 'abcdefghjkmnpqrstuvwxyz23456789';
  code text;
  i int;
begin
  for attempt in 1..5 loop
    code := '';
    for i in 1..8 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    if not exists (select 1 from public.profiles where referral_code = code) then
      return code;
    end if;
  end loop;
  return code;
end $$;

create or replace function public.profiles_set_referral_code() returns trigger language plpgsql as $$
begin
  if new.referral_code is null then
    new.referral_code := public.gen_referral_code();
  end if;
  return new;
end $$;

drop trigger if exists profiles_set_referral_code on public.profiles;
create trigger profiles_set_referral_code
  before insert on public.profiles
  for each row execute function public.profiles_set_referral_code();

-- backfill existing rows
update public.profiles set referral_code = public.gen_referral_code() where referral_code is null;


-- 2) likes -------------------------------------------------------------------
-- One row per "I liked X".  When both directions exist, friendship is implied.
create table if not exists public.likes (
  id           uuid primary key default gen_random_uuid(),
  liker_id     uuid not null references public.profiles(id) on delete cascade,
  liked_id     uuid not null references public.profiles(id) on delete cascade,
  session_id   uuid references public.sessions(id) on delete set null,
  created_at   timestamptz not null default now(),
  unique (liker_id, liked_id)
);

create index if not exists likes_liked_id_idx on public.likes(liked_id);
create index if not exists likes_liker_id_idx on public.likes(liker_id);


-- 3) friends_v ---------------------------------------------------------------
-- A view: mutual likes = friendship.  Each pair appears twice (a,b) and (b,a).
create or replace view public.friends_v as
  select l1.liker_id as user_id,
         l1.liked_id as friend_id,
         greatest(l1.created_at, l2.created_at) as became_friends_at
    from public.likes l1
    join public.likes l2
      on l1.liker_id = l2.liked_id
     and l1.liked_id = l2.liker_id;


-- 4) referrals (denormalised counters) ---------------------------------------
create or replace view public.referral_stats_v as
  select
    p.id           as inviter_id,
    p.referral_code,
    count(r.id)    as invited_count,
    count(case when r.matches_count > 0 then 1 end) as active_count
  from public.profiles p
  left join public.profiles r on r.referred_by = p.id
  group by p.id, p.referral_code;


-- 5) trust score (view + helper) ---------------------------------------------
-- Range 0..100.  Anyone with role>=user starts at 50 baseline.
create or replace view public.trust_score_v as
  with base as (
    select
      p.id,
      50
        + least(30, extract(day from (now() - p.created_at))::int)            as age_pts
        - 10 * coalesce((select count(*) from public.reports where reported_id = p.id and status in ('pending','actioned')), 0) as report_pts
        + least(20, p.matches_count / 10)                                     as match_pts
        + case when p.verified_phone then 15 else 0 end                       as phone_pts
        + case when p.verified_photo then 15 else 0 end                       as photo_pts
    from public.profiles p
  )
  select id,
         greatest(0, least(100,
           50
           + age_pts - 50           -- age contributes above baseline
           + report_pts             -- already negative
           + (match_pts - 50)       -- adjust baseline offset
           + phone_pts
           + photo_pts
         ))::int as trust_score
  from base;

-- Simpler & correct version: drop the offset hacks above, return clean score.
drop view if exists public.trust_score_v;
create or replace view public.trust_score_v as
  select
    p.id,
    greatest(0, least(100,
      50
      + least(20, extract(day from (now() - p.created_at))::int * 2 / 3)            -- account age: ~+1 every 1.5 day, capped 20
      - 12 * coalesce((select count(*) from public.reports r
                       where r.reported_id = p.id and r.status in ('pending','actioned')), 0)
      + least(15, p.matches_count / 5)                                              -- matches: +1 per 5, capped 15
      + case when p.verified_phone then 10 else 0 end
      + case when p.verified_photo then 15 else 0 end
    ))::int as trust_score
  from public.profiles p;


-- 6) Sessions: bump matches_count when a session row is written --------------
create or replace function public.bump_match_count() returns trigger
language plpgsql security definer as $$
begin
  if new.peer_a is not null then
    update public.profiles set matches_count = matches_count + 1 where id = new.peer_a;
  end if;
  if new.peer_b is not null and new.peer_b <> new.peer_a then
    update public.profiles set matches_count = matches_count + 1 where id = new.peer_b;
  end if;
  return new;
end $$;

drop trigger if exists sessions_bump_matches on public.sessions;
create trigger sessions_bump_matches
  after insert on public.sessions
  for each row execute function public.bump_match_count();


-- 7) RLS for new tables ------------------------------------------------------
alter table public.likes enable row level security;

drop policy if exists "likes: insert by authed user" on public.likes;
create policy "likes: insert by authed user"
  on public.likes for insert
  with check (auth.uid() = liker_id);

drop policy if exists "likes: read own + admin read" on public.likes;
create policy "likes: read own + admin read"
  on public.likes for select
  using (
    auth.uid() = liker_id
    or auth.uid() = liked_id
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin'))
  );

drop policy if exists "likes: delete own" on public.likes;
create policy "likes: delete own"
  on public.likes for delete
  using (auth.uid() = liker_id);


-- 8) Helpful RPCs (called from app) ------------------------------------------
-- Get friend list for current user with profile data.
create or replace function public.my_friends() returns table(
  user_id uuid,
  nickname text,
  gender text,
  trust_score int,
  became_friends_at timestamptz
) language sql stable as $$
  select f.friend_id, p.nickname, p.gender, t.trust_score, f.became_friends_at
    from public.friends_v f
    join public.profiles p on p.id = f.friend_id
    join public.trust_score_v t on t.id = f.friend_id
   where f.user_id = auth.uid()
   order by f.became_friends_at desc;
$$;

-- Trust score for a single user.
create or replace function public.get_trust_score(uid uuid) returns int
language sql stable as $$
  select trust_score from public.trust_score_v where id = uid;
$$;
