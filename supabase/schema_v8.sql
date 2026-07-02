-- ============================================================================
-- kerochat — schema v8
-- Anonimlik + oda ekonomisi paketi:
--   1. Random kullanıcı adı (ilk kayıtta otomatik) + maksimum 2 değiştirme hakkı
--   2. Arkadaş limiti: herkes için 20 (VIP ayrıcalığı sonra)
--   3. Şans çarkı: günde 1 ücretsiz çevirme (elmas / boş / süre kartı / 1 ay VIP)
--   4. Oda süre uzatma kartları (profiles.time_cards) + harcama RPC'si
--   5. Sinyal sunucusu için tek atımlık profil RPC'si (rol + vip + nickname)
-- Idempotent — tekrar çalıştırmak güvenli.
-- ============================================================================

-- ── 1) profiles: yeni kolonlar ──────────────────────────────────────────────
alter table public.profiles add column if not exists nickname_changes int not null default 0;
alter table public.profiles add column if not exists time_cards       int not null default 0;

-- ── 2) Random kullanıcı adı ─────────────────────────────────────────────────
create or replace function public.gen_random_nickname() returns text
language plpgsql volatile as $$
declare
  adjs  text[] := array['Mor','Gizli','Sessiz','Hızlı','Neşeli','Çılgın','Uykucu',
                        'Parlak','Gece','Altın','Gümüş','Mavi','Kızıl','Bulutlu',
                        'Yıldızlı','Rüzgarlı'];
  nouns text[] := array['Kedi','Baykuş','Panda','Tilki','Kurt','Martı','Kaplan',
                        'Yunus','Serçe','Aslan','Kirpi','Ceylan','Karga','Leylek',
                        'Vaşak','Sincap'];
begin
  return adjs[1 + floor(random() * array_length(adjs, 1))::int]
      || nouns[1 + floor(random() * array_length(nouns, 1))::int]
      || (10 + floor(random() * 90))::int::text;
end $$;

-- Yeni profil satırında nickname boşsa otomatik ata.
create or replace function public.assign_random_nickname() returns trigger
language plpgsql as $$
begin
  if new.nickname is null or trim(new.nickname) = '' then
    new.nickname := public.gen_random_nickname();
  end if;
  return new;
end $$;

drop trigger if exists profiles_assign_nickname on public.profiles;
create trigger profiles_assign_nickname
  before insert on public.profiles
  for each row execute function public.assign_random_nickname();

-- Mevcut boş nickname'leri doldur.
update public.profiles
   set nickname = public.gen_random_nickname()
 where nickname is null or trim(nickname) = '';

-- Nickname'i doğrudan UPDATE ile değiştirmeyi kilitle:
-- sadece change_nickname() RPC'si (GUC bayrağı), servis rolü (auth.uid() null)
-- veya moderatör/admin değiştirebilir.
create or replace function public.guard_nickname_change() returns trigger
language plpgsql as $$
begin
  if new.nickname is distinct from old.nickname then
    if coalesce(current_setting('app.allow_nick_change', true), '') = '1' then
      return new;
    end if;
    if auth.uid() is null then return new; end if;   -- service role / sunucu
    if exists (select 1 from public.profiles p
                where p.id = auth.uid() and p.role in ('moderator','admin')) then
      return new;
    end if;
    raise exception 'nickname_locked';
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard_nickname on public.profiles;
create trigger profiles_guard_nickname
  before update on public.profiles
  for each row execute function public.guard_nickname_change();

-- Kullanıcının kendi nickname değişikliği: maksimum 2 hak.
create or replace function public.change_nickname(p_nickname text) returns json
language plpgsql security definer as $$
declare
  v_uid     uuid := auth.uid();
  v_changes int;
  v_nick    text := trim(p_nickname);
begin
  if v_uid is null then raise exception 'not_authed'; end if;
  if length(v_nick) < 3 or length(v_nick) > 24 then raise exception 'nickname_invalid'; end if;

  select nickname_changes into v_changes from public.profiles where id = v_uid for update;
  if v_changes is null then raise exception 'no_profile'; end if;
  if v_changes >= 2 then raise exception 'nickname_limit'; end if;

  perform set_config('app.allow_nick_change', '1', true);
  update public.profiles
     set nickname = v_nick, nickname_changes = nickname_changes + 1
   where id = v_uid;

  return json_build_object('nickname', v_nick, 'remaining', 1 - v_changes);
end $$;

-- ── 3) Arkadaş limiti (20) ──────────────────────────────────────────────────
create or replace function public.friend_count(p_uid uuid) returns int
language sql stable as $$
  select count(*)::int
    from public.likes l1
    join public.likes l2
      on l2.liker_id = l1.liked_id and l2.liked_id = l1.liker_id
   where l1.liker_id = p_uid;
$$;

-- Karşılıklılığı tamamlayacak like, iki taraftan biri 20 arkadaşa ulaştıysa reddedilir.
create or replace function public.enforce_friend_limit() returns trigger
language plpgsql as $$
begin
  if exists (select 1 from public.likes
              where liker_id = new.liked_id and liked_id = new.liker_id) then
    if public.friend_count(new.liker_id) >= 20 then
      raise exception 'friend_limit';
    end if;
    if public.friend_count(new.liked_id) >= 20 then
      raise exception 'friend_limit_peer';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists likes_friend_limit on public.likes;
create trigger likes_friend_limit
  before insert on public.likes
  for each row execute function public.enforce_friend_limit();

-- ── 4) Çark + süre kartları için check kısıtlarını genişlet ────────────────
alter table public.coin_transactions drop constraint if exists coin_transactions_reason_check;
alter table public.coin_transactions add constraint coin_transactions_reason_check
  check (reason in ('purchase','gift_sent','gift_received','admin_grant',
                    'referral_bonus','ad_reward','daily_bonus','refund',
                    'wheel','room_extend'));

alter table public.vip_subscriptions drop constraint if exists vip_subscriptions_source_check;
alter table public.vip_subscriptions add constraint vip_subscriptions_source_check
  check (source in ('stripe','admin','promo','referral','wheel'));

-- ── 5) Şans çarkı ───────────────────────────────────────────────────────────
create table if not exists public.wheel_spins (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  prize      text not null check (prize in ('none','coins','time_card','vip30')),
  amount     int  not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists wheel_spins_user_idx on public.wheel_spins(user_id, created_at desc);

alter table public.wheel_spins enable row level security;
drop policy if exists "wheel: own rows" on public.wheel_spins;
create policy "wheel: own rows"
  on public.wheel_spins for select
  using (user_id = auth.uid());

-- Günde 1 ücretsiz çevirme. Dağılım:
--   %35 boş · %30 10 elmas · %15 25 elmas · %5 50 elmas · %13 süre kartı · %2 1 ay VIP
create or replace function public.spin_wheel() returns json
language plpgsql security definer as $$
declare
  v_uid    uuid := auth.uid();
  v_roll   numeric := random() * 100;
  v_prize  text;
  v_amount int := 0;
begin
  if v_uid is null then raise exception 'not_authed'; end if;

  if exists (select 1 from public.wheel_spins
              where user_id = v_uid and created_at >= date_trunc('day', now())) then
    raise exception 'already_spun';
  end if;

  if v_roll < 35 then
    v_prize := 'none';
  elsif v_roll < 65 then
    v_prize := 'coins'; v_amount := 10;
  elsif v_roll < 80 then
    v_prize := 'coins'; v_amount := 25;
  elsif v_roll < 85 then
    v_prize := 'coins'; v_amount := 50;
  elsif v_roll < 98 then
    v_prize := 'time_card'; v_amount := 1;
  else
    v_prize := 'vip30'; v_amount := 30;
  end if;

  if v_prize = 'coins' then
    insert into public.coin_transactions (user_id, delta, reason, created_by)
    values (v_uid, v_amount, 'wheel', v_uid);
  elsif v_prize = 'time_card' then
    update public.profiles set time_cards = time_cards + 1 where id = v_uid;
  elsif v_prize = 'vip30' then
    update public.vip_subscriptions set active = false
     where user_id = v_uid and active = true;
    insert into public.vip_subscriptions (user_id, tier, expires_at, source, created_by)
    values (v_uid, 'vip', now() + interval '30 days', 'wheel', v_uid);
  end if;

  insert into public.wheel_spins (user_id, prize, amount) values (v_uid, v_prize, v_amount);

  return json_build_object('prize', v_prize, 'amount', v_amount);
end $$;

-- ── 6) Oda süre uzatma harcaması (sadece sinyal sunucusu çağırır) ──────────
create or replace function public.use_room_extension(p_user_id uuid, p_method text) returns json
language plpgsql security definer as $$
declare
  v_coins int;
begin
  if p_method = 'card' then
    update public.profiles set time_cards = time_cards - 1
     where id = p_user_id and time_cards > 0;
    if not found then raise exception 'no_time_card'; end if;
  elsif p_method = 'coins' then
    select coins into v_coins from public.profiles where id = p_user_id for update;
    if v_coins is null or v_coins < 20 then raise exception 'insufficient_coins'; end if;
    insert into public.coin_transactions (user_id, delta, reason, created_by)
    values (p_user_id, -20, 'room_extend', p_user_id);
  else
    raise exception 'bad_method';
  end if;
  return json_build_object('ok', true);
end $$;

-- İstemciler doğrudan çağıramasın — sadece service role.
revoke execute on function public.use_room_extension(uuid, text) from public, anon, authenticated;

-- ── 7) Sinyal sunucusu profil özeti (tek çağrı: rol + vip + nickname) ──────
create or replace function public.is_vip(p_user_id uuid) returns boolean
language sql stable security definer as $$
  select exists (
    select 1 from public.vip_subscriptions
     where user_id = p_user_id and active = true
       and (expires_at is null or expires_at > now())
  );
$$;

create or replace function public.get_signaling_profile(p_user_id uuid) returns json
language sql stable security definer as $$
  select json_build_object(
    'role',     p.role,
    'nickname', p.nickname,
    'vip',      public.is_vip(p_user_id)
  )
  from public.profiles p where p.id = p_user_id;
$$;

revoke execute on function public.get_signaling_profile(uuid) from public, anon, authenticated;
