-- ============================================================================
-- kerochat — schema v10
--   1. 18+ onayı (profiles.adult_confirmed_at) — misafir girişi kaldırıldı
--   2. FCM push token saklama (profiles.fcm_token)
--   3. Günlük 2 ücretsiz süre uzatma hakkı + use_call_extension() (sesli 1-1)
--   4. Arkadaşlık İSTEĞİ akışı: friend_requests + send/respond RPC'leri
--      (beğeni artık ayrı bir sosyal sinyal; arkadaşlık istek+onay ile kurulur)
--   5. Dürtme: poke_friend() (10 dk rate limit)
--   6. Eşleşme filtresi ücreti: charge_match_filter() (5 elmas, eşleşme başına;
--      sadece sinyal sunucusu çağırır)
--   7. notifications.kind: friend_request / poke / call eklendi
-- Idempotent — tekrar çalıştırmak güvenli.
-- ============================================================================

-- ── 1-2) profiles yeni kolonlar ─────────────────────────────────────────────
alter table public.profiles add column if not exists adult_confirmed_at timestamptz;
alter table public.profiles add column if not exists fcm_token          text;
alter table public.profiles add column if not exists daily_ext_used     int  not null default 0;
alter table public.profiles add column if not exists daily_ext_date     date;

-- ── 3) Sesli 1-1 süre uzatma: günde 2 ücretsiz, sonra süre kartı ───────────
-- Sadece sinyal sunucusu çağırır (service role). Dönen 'method': free | card
create or replace function public.use_call_extension(p_user_id uuid) returns json
language plpgsql security definer as $$
declare
  v_used int;
  v_date date;
  v_today date := (now() at time zone 'utc')::date;
begin
  select daily_ext_used, daily_ext_date into v_used, v_date
    from public.profiles where id = p_user_id for update;
  if v_used is null then raise exception 'no_profile'; end if;

  if v_date is distinct from v_today then
    v_used := 0;
  end if;

  if v_used < 2 then
    update public.profiles
       set daily_ext_used = v_used + 1, daily_ext_date = v_today
     where id = p_user_id;
    return json_build_object('method', 'free', 'free_left', 1 - v_used);
  end if;

  update public.profiles set time_cards = time_cards - 1
   where id = p_user_id and time_cards > 0;
  if not found then raise exception 'no_extension_left'; end if;
  return json_build_object('method', 'card', 'free_left', 0);
end $$;

revoke execute on function public.use_call_extension(uuid) from public, anon, authenticated;

-- Kalan hakları istemciye gösterebilmek için (kendi hakkı, güvenli):
create or replace function public.my_extension_status() returns json
language sql stable security definer as $$
  select json_build_object(
    'free_left', greatest(0, 2 - case when daily_ext_date = (now() at time zone 'utc')::date
                                      then daily_ext_used else 0 end),
    'time_cards', time_cards
  ) from public.profiles where id = auth.uid();
$$;

-- ── 7) bildirim türleri ─────────────────────────────────────────────────────
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('like','match','message','gift','system','admin','vip','coin',
                  'room_invite','friend_request','poke','call'));

-- ── 4) Arkadaşlık isteği akışı ──────────────────────────────────────────────
create table if not exists public.friend_requests (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  target_id    uuid not null references public.profiles(id) on delete cascade,
  status       text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  unique (requester_id, target_id)
);

create index if not exists freq_target_idx on public.friend_requests(target_id, status);

alter table public.friend_requests enable row level security;
drop policy if exists "freq: own rows" on public.friend_requests;
create policy "freq: own rows"
  on public.friend_requests for select
  using (requester_id = auth.uid() or target_id = auth.uid());

-- İstek gönder: arkadaş değillerse + bekleyen istek yoksa. Bildirim düşer.
create or replace function public.send_friend_request(p_target_id uuid) returns json
language plpgsql security definer as $$
declare
  v_uid  uuid := auth.uid();
  v_nick text;
  v_req  public.friend_requests;
begin
  if v_uid is null then raise exception 'not_authed'; end if;
  if p_target_id = v_uid then raise exception 'self_request'; end if;

  -- zaten arkadaşlar mı? (karşılıklı like = arkadaşlık)
  if exists (select 1 from public.likes where liker_id = v_uid and liked_id = p_target_id)
     and exists (select 1 from public.likes where liker_id = p_target_id and liked_id = v_uid) then
    raise exception 'already_friends';
  end if;

  -- limit kontrolü (istek atarken erken uyarı)
  if public.friend_count(v_uid) >= 20 then raise exception 'friend_limit'; end if;

  -- ters yönde bekleyen istek varsa doğrudan kabul et (iki taraf da istemiş)
  select * into v_req from public.friend_requests
   where requester_id = p_target_id and target_id = v_uid and status = 'pending';
  if found then
    return public.respond_friend_request(v_req.id, true);
  end if;

  insert into public.friend_requests (requester_id, target_id)
  values (v_uid, p_target_id)
  on conflict (requester_id, target_id)
  do update set status = 'pending', created_at = now(), responded_at = null
    where friend_requests.status = 'declined'  -- reddedilmişse yeniden istenebilir
  returning * into v_req;
  if v_req.id is null then raise exception 'request_pending'; end if;

  select nickname into v_nick from public.profiles where id = v_uid;

  insert into public.notifications (user_id, kind, title, body, related_id, payload)
  values (p_target_id, 'friend_request', '🤝 Arkadaşlık isteği',
          concat(coalesce(v_nick, 'Biri'), ' seninle arkadaş olmak istiyor'),
          v_uid,
          json_build_object('requestId', v_req.id, 'fromId', v_uid,
                            'fromName', v_nick)::jsonb);

  return json_build_object('ok', true, 'status', 'pending');
end $$;

-- İsteğe cevap: kabul → iki yönlü like (arkadaşlık) + karşı tarafa bildirim.
create or replace function public.respond_friend_request(p_request_id uuid, p_accept boolean) returns json
language plpgsql security definer as $$
declare
  v_uid  uuid := auth.uid();
  v_req  public.friend_requests;
  v_nick text;
begin
  if v_uid is null then raise exception 'not_authed'; end if;

  select * into v_req from public.friend_requests
   where id = p_request_id and status = 'pending' for update;
  if not found then raise exception 'request_gone'; end if;
  -- kabul/red yalnızca hedefin hakkı; (send tarafındaki oto-kabulde hedef=çağıran olur)
  if v_req.target_id <> v_uid and v_req.requester_id <> v_uid then
    raise exception 'not_yours';
  end if;

  if not p_accept then
    update public.friend_requests
       set status = 'declined', responded_at = now() where id = p_request_id;
    return json_build_object('ok', true, 'status', 'declined');
  end if;

  -- arkadaşlık limiti iki taraf için de (likes trigger'ı da ayrıca korur)
  if public.friend_count(v_req.requester_id) >= 20 then raise exception 'friend_limit_peer'; end if;
  if public.friend_count(v_req.target_id) >= 20 then raise exception 'friend_limit'; end if;

  insert into public.likes (liker_id, liked_id)
  values (v_req.requester_id, v_req.target_id)
  on conflict (liker_id, liked_id) do nothing;
  insert into public.likes (liker_id, liked_id)
  values (v_req.target_id, v_req.requester_id)
  on conflict (liker_id, liked_id) do nothing;

  update public.friend_requests
     set status = 'accepted', responded_at = now() where id = p_request_id;

  select nickname into v_nick from public.profiles where id = v_req.target_id;
  insert into public.notifications (user_id, kind, title, body, related_id)
  values (v_req.requester_id, 'match', '🎉 Arkadaş oldunuz!',
          concat(coalesce(v_nick, 'Biri'), ' arkadaşlık isteğini kabul etti'),
          v_req.target_id);

  return json_build_object('ok', true, 'status', 'accepted');
end $$;

-- ── 5) Dürtme ───────────────────────────────────────────────────────────────
create or replace function public.poke_friend(p_friend_id uuid) returns json
language plpgsql security definer as $$
declare
  v_uid  uuid := auth.uid();
  v_nick text;
begin
  if v_uid is null then raise exception 'not_authed'; end if;

  if not exists (select 1 from public.likes where liker_id = v_uid and liked_id = p_friend_id)
     or not exists (select 1 from public.likes where liker_id = p_friend_id and liked_id = v_uid) then
    raise exception 'not_friends';
  end if;

  if exists (select 1 from public.notifications
              where user_id = p_friend_id and kind = 'poke' and related_id = v_uid
                and created_at > now() - interval '10 minutes') then
    raise exception 'poke_too_soon';
  end if;

  select nickname into v_nick from public.profiles where id = v_uid;
  insert into public.notifications (user_id, kind, title, body, related_id)
  values (p_friend_id, 'poke', '👉 Dürtüldün!',
          concat(coalesce(v_nick, 'Bir arkadaşın'), ' seni dürttü — hadi gel!'), v_uid);
  return json_build_object('ok', true);
end $$;

-- ── 6) Eşleşme filtresi ücreti (5 elmas / eşleşme) ─────────────────────────
alter table public.coin_transactions drop constraint if exists coin_transactions_reason_check;
alter table public.coin_transactions add constraint coin_transactions_reason_check
  check (reason in ('purchase','gift_sent','gift_received','admin_grant',
                    'referral_bonus','ad_reward','daily_bonus','refund',
                    'wheel','room_extend','filter_match'));

-- Sadece sinyal sunucusu çağırır. Bakiye yetersizse false döner (eşleşme yine olur).
create or replace function public.charge_match_filter(p_user_id uuid) returns json
language plpgsql security definer as $$
declare
  v_coins int;
begin
  select coins into v_coins from public.profiles where id = p_user_id for update;
  if v_coins is null or v_coins < 5 then
    return json_build_object('charged', false);
  end if;
  insert into public.coin_transactions (user_id, delta, reason, created_by)
  values (p_user_id, -5, 'filter_match', p_user_id);
  return json_build_object('charged', true);
end $$;

revoke execute on function public.charge_match_filter(uuid) from public, anon, authenticated;
