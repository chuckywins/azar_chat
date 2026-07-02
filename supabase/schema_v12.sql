-- ============================================================================
-- kerochat — schema v12
-- Canlı ayar sistemi: uygulamanın süre/limit/ücret değerleri artık koddan
-- değil app_settings tablosundan gelir. Web admin panelinden değiştirilir;
-- sinyal sunucusu ~60 sn'de bir (veya panelden "uygula" ile anında) yükler,
-- DB fonksiyonları her çağrıda okur.
--   1. app_settings (key/value) + varsayılanlar + setting_int()
--   2. system_room_topics: otomatik oda adı/konu havuzu (panelden CRUD)
--   3. Mevcut fonksiyonlar ayarları okuyacak şekilde güncellendi:
--      charge_match_filter, use_room_extension, use_call_extension,
--      enforce_friend_limit, change_nickname, send/respond_friend_request
-- Idempotent — tekrar çalıştırmak güvenli.
-- ============================================================================

-- ── 1) app_settings ─────────────────────────────────────────────────────────
create table if not exists public.app_settings (
  key         text primary key,
  value       text not null,
  description text,
  updated_at  timestamptz not null default now()
);

drop trigger if exists app_settings_touch on public.app_settings;
create trigger app_settings_touch
  before update on public.app_settings
  for each row execute function public.set_updated_at();

alter table public.app_settings enable row level security;
drop policy if exists "settings: admin all" on public.app_settings;
create policy "settings: admin all"
  on public.app_settings for all
  using (exists (select 1 from public.profiles p
                  where p.id = auth.uid() and p.role in ('moderator','admin')))
  with check (exists (select 1 from public.profiles p
                  where p.id = auth.uid() and p.role in ('moderator','admin')));

-- Varsayılanlar (varsa dokunma)
insert into public.app_settings (key, value, description) values
  ('voice_call_sec',        '120', 'Rastgele sesli eşleşme süresi (saniye)'),
  ('voice_ext_sec',         '150', 'Sesli görüşme uzatması — normal üye (saniye)'),
  ('voice_ext_vip_sec',     '240', 'Sesli görüşme uzatması — VIP (saniye)'),
  ('daily_free_extensions', '2',   'Günlük ücretsiz süre uzatma hakkı'),
  ('room_vip_sec',          '420', 'VIP kullanıcının kurduğu oda süresi (saniye)'),
  ('room_ext_sec',          '180', 'Oda uzatma miktarı (saniye)'),
  ('room_ext_coin_cost',    '20',  'Oda uzatma elmas bedeli'),
  ('room_max_ahead_sec',    '1800','Oda/görüşme süresi üst sınırı (şu andan itibaren, saniye)'),
  ('system_room_sec',       '200', 'Sistem odası süresi (saniye) — ilk katılımda başlar'),
  ('system_room_min_open',  '5',   'Her an açık tutulacak minimum sistem odası'),
  ('system_room_cap_min',   '3',   'Sistem odası minimum kapasite'),
  ('system_room_cap_max',   '4',   'Sistem odası maksimum kapasite'),
  ('filter_match_cost',     '5',   'Filtreli eşleşme bedeli (elmas / eşleşme)'),
  ('friend_limit',          '20',  'Maksimum arkadaş sayısı'),
  ('nickname_max_changes',  '2',   'Kullanıcı adı değiştirme hakkı')
on conflict (key) do nothing;

-- Tamsayı ayar okuyucu (yoksa varsayılan döner)
create or replace function public.setting_int(p_key text, p_default int) returns int
language sql stable security definer as $$
  select coalesce((select value::int from public.app_settings where key = p_key), p_default);
$$;

-- ── 2) system_room_topics ───────────────────────────────────────────────────
create table if not exists public.system_room_topics (
  id         uuid primary key default gen_random_uuid(),
  title      text not null,
  topic      text not null default 'Sohbet',
  active     boolean not null default true,
  sort       int not null default 0,
  created_at timestamptz not null default now()
);

alter table public.system_room_topics enable row level security;
drop policy if exists "topics: admin all" on public.system_room_topics;
create policy "topics: admin all"
  on public.system_room_topics for all
  using (exists (select 1 from public.profiles p
                  where p.id = auth.uid() and p.role in ('moderator','admin')))
  with check (exists (select 1 from public.profiles p
                  where p.id = auth.uid() and p.role in ('moderator','admin')));

insert into public.system_room_topics (title, topic, sort)
select * from (values
  ('Tanışalım',      'Tanışma',   0),
  ('Şarkını Söyle',  'Müzik',     1),
  ('Dertleşelim',    'Dertleşme', 2),
  ('İtiraf Saati',   'İtiraf',    3),
  ('Gece Sohbeti',   'Sohbet',    4),
  ('English Time',   'English',   5),
  ('Oyun & Eğlence', 'Oyun',      6),
  ('Müzik Keyfi',    'Müzik',     7),
  ('Felsefe Masası', 'Sohbet',    8)
) as seed(title, topic, sort)
where not exists (select 1 from public.system_room_topics);

-- ── 3) Fonksiyonlar artık ayarları okuyor ───────────────────────────────────

create or replace function public.charge_match_filter(p_user_id uuid) returns json
language plpgsql security definer as $$
declare
  v_coins int;
  v_cost  int := public.setting_int('filter_match_cost', 5);
begin
  if v_cost <= 0 then return json_build_object('charged', false); end if;
  select coins into v_coins from public.profiles where id = p_user_id for update;
  if v_coins is null or v_coins < v_cost then
    return json_build_object('charged', false);
  end if;
  insert into public.coin_transactions (user_id, delta, reason, created_by)
  values (p_user_id, -v_cost, 'filter_match', p_user_id);
  return json_build_object('charged', true);
end $$;
revoke execute on function public.charge_match_filter(uuid) from public, anon, authenticated;

create or replace function public.use_room_extension(p_user_id uuid, p_method text) returns json
language plpgsql security definer as $$
declare
  v_coins int;
  v_cost  int := public.setting_int('room_ext_coin_cost', 20);
begin
  if p_method = 'card' then
    update public.profiles set time_cards = time_cards - 1
     where id = p_user_id and time_cards > 0;
    if not found then raise exception 'no_time_card'; end if;
  elsif p_method = 'coins' then
    select coins into v_coins from public.profiles where id = p_user_id for update;
    if v_coins is null or v_coins < v_cost then raise exception 'insufficient_coins'; end if;
    insert into public.coin_transactions (user_id, delta, reason, created_by)
    values (p_user_id, -v_cost, 'room_extend', p_user_id);
  else
    raise exception 'bad_method';
  end if;
  return json_build_object('ok', true);
end $$;
revoke execute on function public.use_room_extension(uuid, text) from public, anon, authenticated;

create or replace function public.use_call_extension(p_user_id uuid) returns json
language plpgsql security definer as $$
declare
  v_used int;
  v_date date;
  v_free int := public.setting_int('daily_free_extensions', 2);
  v_today date := (now() at time zone 'utc')::date;
begin
  select daily_ext_used, daily_ext_date into v_used, v_date
    from public.profiles where id = p_user_id for update;
  if v_used is null then raise exception 'no_profile'; end if;

  if v_date is distinct from v_today then
    v_used := 0;
  end if;

  if v_used < v_free then
    update public.profiles
       set daily_ext_used = v_used + 1, daily_ext_date = v_today
     where id = p_user_id;
    return json_build_object('method', 'free', 'free_left', v_free - v_used - 1);
  end if;

  update public.profiles set time_cards = time_cards - 1
   where id = p_user_id and time_cards > 0;
  if not found then raise exception 'no_extension_left'; end if;
  return json_build_object('method', 'card', 'free_left', 0);
end $$;
revoke execute on function public.use_call_extension(uuid) from public, anon, authenticated;

create or replace function public.enforce_friend_limit() returns trigger
language plpgsql as $$
declare
  v_limit int := public.setting_int('friend_limit', 20);
begin
  if exists (select 1 from public.likes
              where liker_id = new.liked_id and liked_id = new.liker_id) then
    if public.friend_count(new.liker_id) >= v_limit then
      raise exception 'friend_limit';
    end if;
    if public.friend_count(new.liked_id) >= v_limit then
      raise exception 'friend_limit_peer';
    end if;
  end if;
  return new;
end $$;

create or replace function public.change_nickname(p_nickname text) returns json
language plpgsql security definer as $$
declare
  v_uid     uuid := auth.uid();
  v_changes int;
  v_max     int := public.setting_int('nickname_max_changes', 2);
  v_nick    text := trim(p_nickname);
begin
  if v_uid is null then raise exception 'not_authed'; end if;
  if length(v_nick) < 3 or length(v_nick) > 24 then raise exception 'nickname_invalid'; end if;

  select nickname_changes into v_changes from public.profiles where id = v_uid for update;
  if v_changes is null then raise exception 'no_profile'; end if;
  if v_changes >= v_max then raise exception 'nickname_limit'; end if;

  perform set_config('app.allow_nick_change', '1', true);
  update public.profiles
     set nickname = v_nick, nickname_changes = nickname_changes + 1
   where id = v_uid;

  return json_build_object('nickname', v_nick, 'remaining', v_max - v_changes - 1);
end $$;

-- Arkadaşlık isteği fonksiyonlarındaki limit de ayardan gelsin
create or replace function public.send_friend_request(p_target_id uuid) returns json
language plpgsql security definer as $$
declare
  v_uid   uuid := auth.uid();
  v_nick  text;
  v_req   public.friend_requests;
  v_limit int := public.setting_int('friend_limit', 20);
begin
  if v_uid is null then raise exception 'not_authed'; end if;
  if p_target_id = v_uid then raise exception 'self_request'; end if;

  if exists (select 1 from public.likes where liker_id = v_uid and liked_id = p_target_id)
     and exists (select 1 from public.likes where liker_id = p_target_id and liked_id = v_uid) then
    raise exception 'already_friends';
  end if;

  if public.friend_count(v_uid) >= v_limit then raise exception 'friend_limit'; end if;

  select * into v_req from public.friend_requests
   where requester_id = p_target_id and target_id = v_uid and status = 'pending';
  if found then
    return public.respond_friend_request(v_req.id, true);
  end if;

  insert into public.friend_requests (requester_id, target_id)
  values (v_uid, p_target_id)
  on conflict (requester_id, target_id)
  do update set status = 'pending', created_at = now(), responded_at = null
    where friend_requests.status = 'declined'
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

create or replace function public.respond_friend_request(p_request_id uuid, p_accept boolean) returns json
language plpgsql security definer as $$
declare
  v_uid   uuid := auth.uid();
  v_req   public.friend_requests;
  v_nick  text;
  v_limit int := public.setting_int('friend_limit', 20);
begin
  if v_uid is null then raise exception 'not_authed'; end if;

  select * into v_req from public.friend_requests
   where id = p_request_id and status = 'pending' for update;
  if not found then raise exception 'request_gone'; end if;
  if v_req.target_id <> v_uid and v_req.requester_id <> v_uid then
    raise exception 'not_yours';
  end if;

  if not p_accept then
    update public.friend_requests
       set status = 'declined', responded_at = now() where id = p_request_id;
    return json_build_object('ok', true, 'status', 'declined');
  end if;

  if public.friend_count(v_req.requester_id) >= v_limit then raise exception 'friend_limit_peer'; end if;
  if public.friend_count(v_req.target_id) >= v_limit then raise exception 'friend_limit'; end if;

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
