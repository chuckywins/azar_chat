# Supabase setup — kerochat

## 1. Create project

1. https://supabase.com → Sign in → **New Project**
2. Name: `kerochat`, Region: **eu-central-1 (Frankfurt)**, generate strong DB password, save it.
3. Wait ~2 min for provisioning.

## 2. Run schema

1. Sidebar → **SQL Editor** → **New query**
2. Paste the full content of [`schema.sql`](schema.sql).
3. Click **Run** (Ctrl+Enter). Should report `Success. No rows returned`.

Re-running is safe — every statement is idempotent.

## 3. Google OAuth provider

1. Google Cloud Console → new project → **Credentials → OAuth client ID → Web application**.
2. **Authorized redirect URI**: `https://<your-project-id>.supabase.co/auth/v1/callback`
3. Copy **Client ID** and **Client Secret**.
4. Supabase → **Authentication → Providers → Google** → Enable, paste credentials, **Save**.

## 4. Anonymous sign-in (optional)

Supabase → **Authentication → Providers → Anonymous Sign-Ins** → Enable.

## 5. Promote yourself to admin

After your first login (via the app), grab your auth user ID:

Supabase → **Authentication → Users** → copy the UUID of your user.

Then in **SQL Editor**:

```sql
update public.profiles set role = 'admin' where id = '<your-uuid>';
```

## 6. Build-time secrets

The Flutter app needs three values at build time:

| Env var | Where to find |
|---|---|
| `AZAR_WS_URL` | already set: `wss://ws.klslog.com` |
| `SUPABASE_URL` | Project Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | Project Settings → API → anon / public key |

For Netlify: **Site settings → Environment variables → add all three.**
For local dev:

```bash
flutter run -d chrome \
  --dart-define=AZAR_WS_URL=ws://localhost:9090 \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

The `service_role` key is **server-only** — put it on the VPS as `SUPABASE_SERVICE_ROLE_KEY` env var for the Node signaling server, never bundle into the Flutter build.
