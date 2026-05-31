-- kerochat — schema v4: coin_packs catalog (admin editable) + gift realtime
-- Run after schema_v3 + schema_v3_realtime.

-- 1) coin_packs catalog ------------------------------------------------------
create table if not exists public.coin_packs (
  id          text primary key,
  coins       integer not null check (coins > 0),
  price_text  text not null,                  -- e.g. '₺29'
  bonus_text  text,                            -- e.g. '+50' or null
  sort_order  integer not null default 0,
  popular     boolean not null default false,
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

insert into public.coin_packs (id, coins, price_text, bonus_text, sort_order, popular, active) values
  ('p1',   100, '₺29',  null,    10, false, true),
  ('p2',   550, '₺99',  '+50',   20, false, true),
  ('p3',  1200, '₺199', '+200',  30, true,  true),
  ('p4',  3000, '₺449', '+750',  40, false, true)
on conflict (id) do nothing;

alter table public.coin_packs enable row level security;

drop policy if exists "coin_packs: read all" on public.coin_packs;
create policy "coin_packs: read all"
  on public.coin_packs for select using (true);

drop policy if exists "coin_packs: admin write" on public.coin_packs;
create policy "coin_packs: admin write"
  on public.coin_packs for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role in ('moderator','admin')));


-- 2) Realtime publication additions ------------------------------------------
-- (idempotent: add only if missing)
do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'coin_packs') then
    alter publication supabase_realtime add table public.coin_packs;
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'gift_transactions') then
    alter publication supabase_realtime add table public.gift_transactions;
  end if;
end $$;

-- Verify what's published:
select tablename from pg_publication_tables
 where pubname = 'supabase_realtime'
 order by tablename;
