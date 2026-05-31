-- =====================================================================
-- schema_v6.sql — Paket B1: IP geolocation + ban evasion
--
-- Adds country/last_ip/last_ua/device_fp tracking to profiles.
-- Extends bans table so an evaded account on the same IP/fingerprint
-- can be detected at signaling handshake.
--
-- Idempotent. Safe to re-run.
-- =====================================================================

-- ── 1) profiles: presence-tracking columns ────────────────────────────
alter table public.profiles
  add column if not exists country        text,
  add column if not exists last_ip        inet,
  add column if not exists last_ua        text,
  add column if not exists device_fp_hash text,
  add column if not exists last_seen      timestamptz default now();

create index if not exists profiles_country_idx        on public.profiles (country)        where country        is not null;
create index if not exists profiles_last_ip_idx        on public.profiles (last_ip)        where last_ip        is not null;
create index if not exists profiles_device_fp_idx      on public.profiles (device_fp_hash) where device_fp_hash is not null;

-- ── 2) bans: capture banned IP + device fingerprint ───────────────────
alter table public.bans
  add column if not exists banned_ip      inet,
  add column if not exists device_fp_hash text;

create index if not exists bans_banned_ip_idx      on public.bans (banned_ip)      where banned_ip      is not null;
create index if not exists bans_device_fp_idx      on public.bans (device_fp_hash) where device_fp_hash is not null;

-- ── 3) update_presence_info — called by signaling server on connect ───
-- Service role only; never call from client.
create or replace function public.update_presence_info(
  p_user_id        uuid,
  p_ip             inet,
  p_country        text,
  p_ua             text,
  p_device_fp_hash text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
     set last_ip        = coalesce(p_ip,             last_ip),
         country        = coalesce(p_country,        country),
         last_ua        = coalesce(p_ua,             last_ua),
         device_fp_hash = coalesce(p_device_fp_hash, device_fp_hash),
         last_seen      = now()
   where id = p_user_id;
end;
$$;

revoke all on function public.update_presence_info(uuid, inet, text, text, text) from public, anon, authenticated;
grant execute on function public.update_presence_info(uuid, inet, text, text, text) to service_role;

-- ── 4) check_ban_evasion — server gate, returns true if matched ───────
create or replace function public.check_ban_evasion(
  p_ip             inet,
  p_device_fp_hash text
) returns table (matched boolean, ban_id uuid, reason text)
language sql
security definer
set search_path = public
as $$
  select true,
         b.id,
         b.reason
    from public.bans b
   where (b.until is null or b.until > now())
     and (
       (p_ip is not null             and b.banned_ip      = p_ip)
       or
       (p_device_fp_hash is not null and b.device_fp_hash = p_device_fp_hash)
     )
   order by b.created_at desc
   limit 1;
$$;

revoke all on function public.check_ban_evasion(inet, text) from public, anon, authenticated;
grant execute on function public.check_ban_evasion(inet, text) to service_role;

-- ── 5) admin_ban_user_evasion — bans + captures current IP/FP ─────────
-- Use this from admin UI when banning. It records the user's last known
-- IP + device fingerprint into bans so future signups from the same
-- environment get rejected at handshake.
create or replace function public.admin_ban_user_evasion(
  p_user_id    uuid,
  p_reason     text         default null,
  p_expires_at timestamptz  default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor uuid := auth.uid();
  v_role  text;
  v_ip    inet;
  v_fp    text;
  v_ban_id uuid;
begin
  select role into v_role from public.profiles where id = v_actor;
  if v_role not in ('admin', 'moderator') then
    raise exception 'not authorized';
  end if;

  select last_ip, device_fp_hash into v_ip, v_fp
    from public.profiles where id = p_user_id;

  insert into public.bans (user_id, reason, until, created_by, source, banned_ip, device_fp_hash)
  values (p_user_id, p_reason, p_expires_at, v_actor, 'manual', v_ip, v_fp)
  returning id into v_ban_id;

  update public.profiles
     set is_banned    = true,
         banned_until = p_expires_at,
         ban_reason   = p_reason
   where id = p_user_id;

  -- Audit trail (v5)
  insert into public.audit_logs (actor_id, action, target_id, details)
  values (v_actor, 'ban_user_evasion', p_user_id,
          jsonb_build_object('reason', p_reason, 'until', p_expires_at,
                             'captured_ip', v_ip::text, 'captured_fp', v_fp));

  -- In-app notification (v5)
  insert into public.notifications (user_id, kind, title, body)
  values (p_user_id, 'admin', 'Hesabın askıya alındı',
          coalesce(p_reason, 'İhlal sebebiyle hesabın engellendi'));

  return v_ban_id;
end;
$$;

revoke all on function public.admin_ban_user_evasion(uuid, text, timestamptz) from public, anon;
grant execute on function public.admin_ban_user_evasion(uuid, text, timestamptz) to authenticated;

-- ── 6) admin_country_distribution — for B4 heatmap, defined now ───────
create or replace function public.admin_country_distribution()
returns table (country text, user_count bigint)
language sql
security definer
set search_path = public
as $$
  select coalesce(country, 'unknown') as country,
         count(*)::bigint              as user_count
    from public.profiles
   where (
     select role from public.profiles where id = auth.uid()
   ) in ('admin', 'moderator')
   group by coalesce(country, 'unknown')
   order by user_count desc;
$$;

revoke all on function public.admin_country_distribution() from public, anon;
grant execute on function public.admin_country_distribution() to authenticated;

-- =====================================================================
-- Done. Now signaling server must call update_presence_info + check_ban_evasion
-- on every WebSocket upgrade.
-- =====================================================================
