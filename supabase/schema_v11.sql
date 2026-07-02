-- ============================================================================
-- kerochat — schema v11
-- Arkadaş listesinde çevrimiçi durumu: my_friends() artık is_online +
-- last_seen_at döner. "Çevrimiçi" = is_online bayrağı + son 2 dk içinde
-- kalp atışı (uygulama kapatılınca bayrak kalsa bile taze olmayan yeşil yanmaz).
-- Idempotent — tekrar çalıştırmak güvenli.
-- ============================================================================

drop function if exists public.my_friends();

create or replace function public.my_friends() returns table(
  user_id uuid,
  nickname text,
  gender text,
  avatar_url text,
  trust_score int,
  became_friends_at timestamptz,
  is_online boolean,
  last_seen_at timestamptz
) language sql stable as $$
  select f.friend_id,
         p.nickname,
         p.gender,
         p.avatar_url,
         t.trust_score,
         f.became_friends_at,
         (p.is_online and p.last_seen_at > now() - interval '2 minutes') as is_online,
         p.last_seen_at
    from public.friends_v f
    join public.profiles p on p.id = f.friend_id
    join public.trust_score_v t on t.id = f.friend_id
   where f.user_id = auth.uid()
   order by (p.is_online and p.last_seen_at > now() - interval '2 minutes') desc,
            p.last_seen_at desc;
$$;
