-- Enable realtime replication for messages table.
-- Run AFTER schema_v3.sql in the SQL Editor.
-- This is what lets subscribeThread() receive INSERT events live.

alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.live_stats;
alter publication supabase_realtime add table public.coin_transactions;
alter publication supabase_realtime add table public.announcements;

-- Verify what's published:
select schemaname, tablename from pg_publication_tables
 where pubname = 'supabase_realtime'
 order by tablename;
