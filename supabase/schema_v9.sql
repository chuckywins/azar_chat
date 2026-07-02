-- ============================================================================
-- kerochat — schema v9
--   1. Admin-yönetimli şans çarkı: wheel_prizes tablosu (ağırlıklı olasılık,
--      kullanıcıdan tamamen gizli — RLS ile sadece admin okur/yazar)
--   2. wheel_prizes_public(): kullanıcıya sadece etiket listesi (oran YOK)
--   3. spin_wheel(): tablodaki ağırlıklara göre dinamik çekiliş
--   4. Odaya davet: notifications.kind += 'room_invite', payload jsonb,
--      invite_to_room() RPC (sadece arkadaşlar davet edilebilir)
--   5. get_signaling_profile(): avatar_url eklendi
-- Idempotent — tekrar çalıştırmak güvenli.
-- ============================================================================

-- ── 1) wheel_prizes ─────────────────────────────────────────────────────────
create table if not exists public.wheel_prizes (
  id         uuid primary key default gen_random_uuid(),
  label      text not null,                     -- "10 Elmas", "1 Ay VIP"...
  icon       text not null default '🎁',        -- dilimde gösterilen emoji
  prize_type text not null check (prize_type in ('none','coins','time_card','vip_days')),
  amount     int  not null default 0,           -- coins adedi / kart adedi / vip gün sayısı
  weight     int  not null default 1 check (weight > 0),  -- ağırlık (oran = weight/toplam)
  active     boolean not null default true,
  sort       int  not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists wheel_prizes_set_updated_at on public.wheel_prizes;
create trigger wheel_prizes_set_updated_at
  before update on public.wheel_prizes
  for each row execute function public.set_updated_at();

alter table public.wheel_prizes enable row level security;

-- Oranlar kullanıcıya SIZMAZ: tabloyu sadece admin/moderatör okuyup yazabilir.
drop policy if exists "wheel_prizes: admin all" on public.wheel_prizes;
create policy "wheel_prizes: admin all"
  on public.wheel_prizes for all
  using (exists (select 1 from public.profiles p
                  where p.id = auth.uid() and p.role in ('moderator','admin')))
  with check (exists (select 1 from public.profiles p
                  where p.id = auth.uid() and p.role in ('moderator','admin')));

-- Varsayılan ödüller (tablo boşsa bir kez ekilir).
insert into public.wheel_prizes (label, icon, prize_type, amount, weight, sort)
select * from (values
  ('Boş',        '😅', 'none',      0,  35, 0),
  ('10 Elmas',   '💎', 'coins',     10, 30, 1),
  ('25 Elmas',   '💎', 'coins',     25, 15, 2),
  ('50 Elmas',   '💎', 'coins',     50, 5,  3),
  ('Süre Kartı', '🎟', 'time_card', 1,  13, 4),
  ('1 Ay VIP',   '👑', 'vip_days',  30, 2,  5)
) as seed(label, icon, prize_type, amount, weight, sort)
where not exists (select 1 from public.wheel_prizes);

-- wheel_spins: eski check'i esnet + hangi ödül satırı çıktığını logla.
alter table public.wheel_spins drop constraint if exists wheel_spins_prize_check;
alter table public.wheel_spins add constraint wheel_spins_prize_check
  check (prize in ('none','coins','time_card','vip30','vip_days'));
alter table public.wheel_spins add column if not exists prize_id uuid references public.wheel_prizes(id) on delete set null;

-- Admin çark istatistiği okuyabilsin.
drop policy if exists "wheel: admin read" on public.wheel_spins;
create policy "wheel: admin read"
  on public.wheel_spins for select
  using (exists (select 1 from public.profiles p
                  where p.id = auth.uid() and p.role in ('moderator','admin')));

-- ── 2) Kullanıcıya görünen dilim listesi (oran içermez) ────────────────────
create or replace function public.wheel_prizes_public() returns json
language sql stable security definer as $$
  select coalesce(json_agg(json_build_object(
           'id', id, 'label', label, 'icon', icon
         ) order by sort, created_at), '[]'::json)
    from public.wheel_prizes
   where active = true;
$$;

-- ── 3) Dinamik çekiliş ──────────────────────────────────────────────────────
create or replace function public.spin_wheel() returns json
language plpgsql security definer as $$
declare
  v_uid   uuid := auth.uid();
  v_total int;
  v_roll  numeric;
  v_acc   int := 0;
  v_row   public.wheel_prizes;
begin
  if v_uid is null then raise exception 'not_authed'; end if;

  if exists (select 1 from public.wheel_spins
              where user_id = v_uid and created_at >= date_trunc('day', now())) then
    raise exception 'already_spun';
  end if;

  select sum(weight) into v_total from public.wheel_prizes where active = true;
  if v_total is null or v_total = 0 then raise exception 'wheel_empty'; end if;

  v_roll := random() * v_total;
  for v_row in
    select * from public.wheel_prizes where active = true order by sort, created_at
  loop
    v_acc := v_acc + v_row.weight;
    if v_roll < v_acc then exit; end if;
  end loop;

  if v_row.prize_type = 'coins' and v_row.amount > 0 then
    insert into public.coin_transactions (user_id, delta, reason, created_by)
    values (v_uid, v_row.amount, 'wheel', v_uid);
  elsif v_row.prize_type = 'time_card' and v_row.amount > 0 then
    update public.profiles set time_cards = time_cards + v_row.amount where id = v_uid;
  elsif v_row.prize_type = 'vip_days' and v_row.amount > 0 then
    update public.vip_subscriptions set active = false
     where user_id = v_uid and active = true;
    insert into public.vip_subscriptions (user_id, tier, expires_at, source, created_by)
    values (v_uid, 'vip', now() + make_interval(days => v_row.amount), 'wheel', v_uid);
  end if;

  insert into public.wheel_spins (user_id, prize, amount, prize_id)
  values (v_uid, v_row.prize_type, v_row.amount, v_row.id);

  return json_build_object(
    'prize_id', v_row.id,
    'prize',    v_row.prize_type,
    'amount',   v_row.amount,
    'label',    v_row.label
  );
end $$;

-- ── 4) Odaya davet ──────────────────────────────────────────────────────────
alter table public.notifications add column if not exists payload jsonb;

alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check
  check (kind in ('like','match','message','gift','system','admin','vip','coin','room_invite'));

-- Sadece karşılıklı arkadaşlar davet edebilir; bildirim security definer ile yazılır.
create or replace function public.invite_to_room(
  p_friend_id  uuid,
  p_room_id    text,
  p_room_title text
) returns json
language plpgsql security definer as $$
declare
  v_uid  uuid := auth.uid();
  v_nick text;
begin
  if v_uid is null then raise exception 'not_authed'; end if;
  if p_friend_id = v_uid then raise exception 'self_invite'; end if;

  -- mutual-like arkadaşlık kontrolü
  if not exists (select 1 from public.likes where liker_id = v_uid and liked_id = p_friend_id)
     or not exists (select 1 from public.likes where liker_id = p_friend_id and liked_id = v_uid) then
    raise exception 'not_friends';
  end if;

  -- flood koruması: aynı kişiye 2 dakikada 1 davet
  if exists (select 1 from public.notifications
              where user_id = p_friend_id and kind = 'room_invite'
                and related_id = v_uid
                and created_at > now() - interval '2 minutes') then
    raise exception 'invite_too_soon';
  end if;

  select nickname into v_nick from public.profiles where id = v_uid;

  insert into public.notifications (user_id, kind, title, body, related_id, payload)
  values (
    p_friend_id,
    'room_invite',
    '🎙 Oda daveti',
    concat(coalesce(v_nick, 'Bir arkadaşın'), ' seni "', left(coalesce(p_room_title, 'Oda'), 60), '" odasına davet etti'),
    v_uid,
    json_build_object('roomId', p_room_id, 'roomTitle', p_room_title)::jsonb
  );

  return json_build_object('ok', true);
end $$;

-- ── 5) get_signaling_profile: avatar_url ────────────────────────────────────
create or replace function public.get_signaling_profile(p_user_id uuid) returns json
language sql stable security definer as $$
  select json_build_object(
    'role',       p.role,
    'nickname',   p.nickname,
    'avatar_url', p.avatar_url,
    'vip',        public.is_vip(p_user_id)
  )
  from public.profiles p where p.id = p_user_id;
$$;

revoke execute on function public.get_signaling_profile(uuid) from public, anon, authenticated;
