-- =====================================================================
-- schema_v7.sql — Paket B2: chat photo sharing (one-shot view + admin retain)
--
-- Photos live in the 'chat-photos' Storage bucket (PRIVATE — set up
-- once via dashboard, see notes at bottom). chat_photos rows track
-- ownership + view state.  Receivers see each photo exactly once;
-- admins/moderators can always read everything.
--
-- Idempotent. Safe to re-run.
-- =====================================================================

-- ── 1) table + indexes ───────────────────────────────────────────────
create table if not exists public.chat_photos (
  id           uuid        primary key default gen_random_uuid(),
  sender_id    uuid        not null references public.profiles(id) on delete cascade,
  receiver_id  uuid        not null references public.profiles(id) on delete cascade,
  storage_path text        not null,                       -- e.g. 'sender_uid/uuid.jpg'
  mime         text        default 'image/jpeg',
  size_bytes   integer,
  nsfw_score   float8      default 0.0,                    -- populated by B3 client-side moderation
  blocked      boolean     default false,                  -- true if NSFW rejected by moderation
  viewed_at    timestamptz,                                -- set when receiver opens; null = unread
  created_at   timestamptz default now(),
  expires_at   timestamptz default (now() + interval '30 days')
);

create index if not exists chat_photos_receiver_unread_idx
  on public.chat_photos (receiver_id, created_at desc)
  where viewed_at is null and not blocked;

create index if not exists chat_photos_sender_idx
  on public.chat_photos (sender_id, created_at desc);

create index if not exists chat_photos_expires_idx
  on public.chat_photos (expires_at);

-- ── 2) RLS ───────────────────────────────────────────────────────────
alter table public.chat_photos enable row level security;

drop policy if exists chat_photos_sel       on public.chat_photos;
drop policy if exists chat_photos_ins       on public.chat_photos;
drop policy if exists chat_photos_upd       on public.chat_photos;
drop policy if exists chat_photos_del_admin on public.chat_photos;

-- SELECT: sender, receiver, admin/moderator.
create policy chat_photos_sel on public.chat_photos
  for select to authenticated
  using (
    sender_id   = auth.uid()
    or receiver_id = auth.uid()
    or (select role from public.profiles where id = auth.uid()) in ('admin', 'moderator')
  );

-- INSERT: only the sender can insert their own row.
create policy chat_photos_ins on public.chat_photos
  for insert to authenticated
  with check (sender_id = auth.uid());

-- UPDATE: receiver (to mark viewed) or admin/mod (to set blocked).
create policy chat_photos_upd on public.chat_photos
  for update to authenticated
  using (
    receiver_id = auth.uid()
    or (select role from public.profiles where id = auth.uid()) in ('admin', 'moderator')
  );

-- DELETE: admin/mod only.
create policy chat_photos_del_admin on public.chat_photos
  for delete to authenticated
  using ((select role from public.profiles where id = auth.uid()) in ('admin', 'moderator'));

-- ── 3) Mark-as-viewed RPC (atomic, returns storage_path) ─────────────
-- Receivers call this to claim the one-shot view. Sets viewed_at and
-- returns the storage_path so client can create a signed URL.
-- Admins use it to peek at any photo without flipping viewed_at.
create or replace function public.claim_chat_photo(p_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_path     text;
  v_receiver uuid;
  v_blocked  boolean;
  v_viewed   timestamptz;
  v_role     text;
begin
  select storage_path, receiver_id, blocked, viewed_at
    into v_path, v_receiver, v_blocked, v_viewed
    from public.chat_photos where id = p_id;

  if v_path is null then raise exception 'not_found'; end if;
  if v_blocked then raise exception 'blocked_nsfw'; end if;

  select role into v_role from public.profiles where id = auth.uid();

  if v_role in ('admin', 'moderator') then
    -- admins always get the path, no view flip
    return v_path;
  end if;

  if v_receiver <> auth.uid() then
    raise exception 'not_authorized';
  end if;

  if v_viewed is not null then
    raise exception 'already_viewed';
  end if;

  update public.chat_photos set viewed_at = now() where id = p_id;

  return v_path;
end;
$$;

revoke all on function public.claim_chat_photo(uuid) from public, anon;
grant execute on function public.claim_chat_photo(uuid) to authenticated;

-- ── 3b) purge_chat_photo — deletes storage object + DB row ───────────
-- Called by receiver right after viewing (PhotoViewer dispose) so the
-- file does not sit on Storage past its one-shot lifetime.
-- Admins/mods can purge anything (e.g. illegal content). Senders cannot
-- purge — only the receiver after they viewed, or an admin.
create or replace function public.purge_chat_photo(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_path     text;
  v_receiver uuid;
  v_viewed   timestamptz;
  v_role     text;
begin
  select storage_path, receiver_id, viewed_at
    into v_path, v_receiver, v_viewed
    from public.chat_photos where id = p_id;

  if v_path is null then return; end if;  -- already gone, idempotent

  select role into v_role from public.profiles where id = auth.uid();
  if not (
    (v_receiver = auth.uid() and v_viewed is not null)
    or v_role in ('admin', 'moderator')
  ) then
    raise exception 'not_authorized';
  end if;

  -- Wipe storage object (SECURITY DEFINER bypasses storage RLS).
  delete from storage.objects
    where bucket_id = 'chat-photos' and name = v_path;

  -- Wipe DB row.
  delete from public.chat_photos where id = p_id;
end;
$$;

revoke all on function public.purge_chat_photo(uuid) from public, anon;
grant execute on function public.purge_chat_photo(uuid) to authenticated;

-- ── 4) Admin-only listing RPC for the moderation gallery ─────────────
create or replace function public.admin_list_chat_photos(p_limit int default 100)
returns table (
  id           uuid,
  sender_id    uuid,
  sender_nick  text,
  receiver_id  uuid,
  receiver_nick text,
  storage_path text,
  nsfw_score   float8,
  blocked      boolean,
  viewed_at    timestamptz,
  created_at   timestamptz
)
language sql
security definer
set search_path = public
as $$
  select cp.id, cp.sender_id, sp.nickname, cp.receiver_id, rp.nickname,
         cp.storage_path, cp.nsfw_score, cp.blocked, cp.viewed_at, cp.created_at
    from public.chat_photos cp
    left join public.profiles sp on sp.id = cp.sender_id
    left join public.profiles rp on rp.id = cp.receiver_id
   where (select role from public.profiles where id = auth.uid()) in ('admin', 'moderator')
   order by cp.created_at desc
   limit p_limit;
$$;

revoke all on function public.admin_list_chat_photos(int) from public, anon;
grant execute on function public.admin_list_chat_photos(int) to authenticated;

-- ── 5) Realtime publication for receiver notifications ───────────────
do $$ begin
  alter publication supabase_realtime add table public.chat_photos;
exception when duplicate_object then null;
end $$;

-- =====================================================================
-- STORAGE BUCKET SETUP — RUN ONCE FROM DASHBOARD, NOT VIA SQL
-- =====================================================================
-- 1. Storage → New bucket
--    Name: chat-photos
--    Public: OFF (private)
--    File size limit: 5 MB
--    Allowed MIME types: image/jpeg, image/png, image/webp
--
-- 2. Policies tab → New policy on 'chat-photos' bucket:
--
--    Policy name:  chat-photos object read
--    Allowed ops:  SELECT
--    Target roles: authenticated
--    USING:
--      bucket_id = 'chat-photos' and (
--        (select role from public.profiles where id = auth.uid()) in ('admin','moderator')
--        or exists(
--          select 1 from public.chat_photos cp
--           where cp.storage_path = storage.objects.name
--             and (cp.sender_id = auth.uid() or cp.receiver_id = auth.uid())
--        )
--      )
--
--    Policy name:  chat-photos object insert
--    Allowed ops:  INSERT
--    Target roles: authenticated
--    WITH CHECK:
--      bucket_id = 'chat-photos'
--      and (storage.foldername(name))[1] = auth.uid()::text
--      and octet_length(name) < 200
--
--    Policy name:  chat-photos object delete (admin)
--    Allowed ops:  DELETE
--    Target roles: authenticated
--    USING:
--      bucket_id = 'chat-photos'
--      and (select role from public.profiles where id = auth.uid()) in ('admin','moderator')
-- =====================================================================
