-- ============================================================================
-- kerochat — schema v13
--   1. Referans linkiyle kayıt: profiles.referral_code (otomatik, benzersiz),
--      apply_referral_code() RPC — davet eden kişi başına elmas kazanır.
--      Bonus miktarları app_settings'ten (varsayılan: davet eden 20, gelen 10).
--   2. Ödüllü reklam altyapısı: claim_ad_reward() + ad_status() — günlük hak
--      ve ödül miktarı app_settings'ten (varsayılan: günde 5 reklam × 5 elmas).
--      (AdMob istemci entegrasyonu sonra; RPC'ler hazır, günlük tavan korumalı.)
-- Idempotent — tekrar çalıştırmak güvenli. Gerektirir: schema_v12 (app_settings).
-- ============================================================================

-- ── 0) yeni ayarlar ─────────────────────────────────────────────────────────
insert into public.app_settings (key, value, description) values
  ('referral_bonus_inviter',  '20', 'Davet eden: kayıt başına elmas'),
  ('referral_bonus_referred', '10', 'Davetle gelen: elmas'),
  ('ad_daily_limit',          '5',  'Günlük reklam izleme hakkı'),
  ('ad_reward_coins',         '5',  'Reklam başına elmas')
on conflict (key) do nothing;

-- ── 1) referans kodu ────────────────────────────────────────────────────────
alter table public.profiles add column if not exists referred_by   uuid references public.profiles(id) on delete set null;
alter table public.profiles add column if not exists referral_code text;

create or replace function public.gen_referral_code() returns text
language plpgsql volatile as $$
declare
  chars text := 'abcdefghjkmnpqrstuvwxyz23456789'; -- karışması kolay 0/o/1/l/i yok
  code  text := '';
  i int;
begin
  for i in 1..8 loop
    code := code || substr(chars, 1 + floor(random() * length(chars))::int, 1);
  end loop;
  return code;
end $$;

-- Yeni profillere otomatik kod
create or replace function public.assign_referral_code() returns trigger
language plpgsql as $$
begin
  if new.referral_code is null then
    loop
      new.referral_code := public.gen_referral_code();
      exit when not exists (select 1 from public.profiles where referral_code = new.referral_code);
    end loop;
  end if;
  return new;
end $$;

drop trigger if exists profiles_assign_refcode on public.profiles;
create trigger profiles_assign_refcode
  before insert on public.profiles
  for each row execute function public.assign_referral_code();

-- Mevcut kullanıcılara kod doldur
update public.profiles set referral_code = public.gen_referral_code()
 where referral_code is null;

create unique index if not exists profiles_referral_code_idx
  on public.profiles(referral_code);

-- ── 2) bonus trigger'ı artık ayarları okuyor ────────────────────────────────
create or replace function public.handle_referral_signup() returns trigger
language plpgsql security definer as $$
declare
  v_inv int := public.setting_int('referral_bonus_inviter', 20);
  v_ref int := public.setting_int('referral_bonus_referred', 10);
begin
  if new.referred_by is not null and old.referred_by is null then
    if v_inv > 0 then
      insert into public.coin_transactions (user_id, delta, reason, note, related_id)
      values (new.referred_by, v_inv, 'referral_bonus', 'referral signup', new.id);
      insert into public.notifications (user_id, kind, title, body, related_id)
      values (new.referred_by, 'coin', concat('+', v_inv, ' elmas'),
              'Davet linkinle biri kayıt oldu 🎉', new.id);
    end if;
    if v_ref > 0 then
      insert into public.coin_transactions (user_id, delta, reason, note, related_id)
      values (new.id, v_ref, 'referral_bonus', 'used referral code', new.referred_by);
      insert into public.notifications (user_id, kind, title, body, related_id)
      values (new.id, 'coin', concat('+', v_ref, ' elmas'),
              'Referans kodun işlendi 🎁', new.referred_by);
    end if;
  end if;
  return new;
end $$;

-- (profiles_referral_bonus trigger'ı v5'ten beri bu fonksiyona bağlı — aynen kalır)

-- ── 3) referans kodunu uygula ───────────────────────────────────────────────
create or replace function public.apply_referral_code(p_code text) returns json
language plpgsql security definer as $$
declare
  v_uid     uuid := auth.uid();
  v_code    text := lower(trim(p_code));
  v_inviter public.profiles;
  v_me      public.profiles;
begin
  if v_uid is null then raise exception 'not_authed'; end if;
  if v_code = '' then raise exception 'bad_code'; end if;

  select * into v_me from public.profiles where id = v_uid for update;
  if v_me.referred_by is not null then raise exception 'already_referred'; end if;
  -- sadece taze hesaplar (kötüye kullanım: eski hesaplarla bonus toplama)
  if v_me.created_at < now() - interval '7 days' then raise exception 'account_too_old'; end if;

  select * into v_inviter from public.profiles where referral_code = v_code;
  if not found then raise exception 'code_not_found'; end if;
  if v_inviter.id = v_uid then raise exception 'self_referral'; end if;

  -- bonus, handle_referral_signup trigger'ı ile işlenir
  update public.profiles set referred_by = v_inviter.id where id = v_uid;

  return json_build_object(
    'ok', true,
    'inviter', coalesce(v_inviter.nickname, 'Davet eden'),
    'bonus', public.setting_int('referral_bonus_referred', 10)
  );
end $$;

-- ── 4) ödüllü reklam ────────────────────────────────────────────────────────
create or replace function public.ad_status() returns json
language sql stable security definer as $$
  select json_build_object(
    'limit',  public.setting_int('ad_daily_limit', 5),
    'reward', public.setting_int('ad_reward_coins', 5),
    'used',   (select count(*)::int from public.coin_transactions
                where user_id = auth.uid() and reason = 'ad_reward'
                  and created_at >= date_trunc('day', now())),
    'remaining', greatest(0, public.setting_int('ad_daily_limit', 5) -
               (select count(*)::int from public.coin_transactions
                 where user_id = auth.uid() and reason = 'ad_reward'
                   and created_at >= date_trunc('day', now())))
  );
$$;

create or replace function public.claim_ad_reward() returns json
language plpgsql security definer as $$
declare
  v_uid    uuid := auth.uid();
  v_limit  int := public.setting_int('ad_daily_limit', 5);
  v_reward int := public.setting_int('ad_reward_coins', 5);
  v_used   int;
begin
  if v_uid is null then raise exception 'not_authed'; end if;

  select count(*) into v_used from public.coin_transactions
   where user_id = v_uid and reason = 'ad_reward'
     and created_at >= date_trunc('day', now());

  if v_used >= v_limit then raise exception 'ad_limit'; end if;

  insert into public.coin_transactions (user_id, delta, reason, note)
  values (v_uid, v_reward, 'ad_reward', 'rewarded ad');

  return json_build_object('coins', v_reward, 'remaining', v_limit - v_used - 1);
end $$;
