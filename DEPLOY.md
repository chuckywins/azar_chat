# azar_chat — Deploy

Two services, both free tier:

| Service | Where | Why |
|---|---|---|
| Signaling + matchmaking | **Fly.io** (Frankfurt) | WebSocket-friendly, edge, free tier |
| Flutter Web (frontend) | **Netlify** | Static + global CDN + HTTPS |

Deploy in this order — Netlify build needs the Fly.io URL.

---

## 1. Deploy signaling server to Fly.io

### a. Install flyctl (Windows PowerShell, one-time)

```powershell
iwr https://fly.io/install.ps1 -useb | iex
# Restart PowerShell so $env:PATH picks up flyctl
```

### b. Login + launch

```powershell
cd c:\xampp\htdocs\azar_chat\server
fly auth signup    # or `fly auth login` if you already have an account
fly launch --no-deploy --copy-config --name azar-chat-server --region fra
fly deploy
```

`fly launch` will read the existing [fly.toml](server/fly.toml). Accept all defaults — no Postgres, no Redis (MVP is in-memory).

When `fly deploy` finishes you get a URL like:

```
https://azar-chat-server.fly.dev
```

Verify:

```powershell
curl https://azar-chat-server.fly.dev/health
# { "ok": true, "peers": 0, "queue": 0 }
```

Your WebSocket URL is `wss://azar-chat-server.fly.dev` — keep this handy.

---

## 2. Deploy Flutter web to Netlify

### a. Push the repo to GitHub (one-time)

```powershell
cd c:\xampp\htdocs\azar_chat
git init
git add .
git commit -m "Initial azar_chat scaffold"
gh repo create azar_chat --private --source=. --remote=origin --push
```

### b. Connect Netlify

1. Go to https://app.netlify.com/start
2. "Import from Git" → GitHub → pick `azar_chat`
3. Netlify reads [app/netlify.toml](app/netlify.toml) — leave build settings as auto-detected.
4. **Site settings → Environment variables → Add variable:**
   - Key: `AZAR_WS_URL`
   - Value: `wss://azar-chat-server.fly.dev` (from step 1)
5. Trigger deploy.

First build is slow (Flutter is cloned fresh — ~3-5 minutes). Subsequent builds reuse the cached Flutter SDK.

Once live: `https://<your-site>.netlify.app`

---

## 3. Test end-to-end

- You open `https://<your-site>.netlify.app` → grant camera/mic → "EŞLEŞMEYE BAŞLA"
- Friend opens the same URL on their phone or laptop → grants camera/mic → "EŞLEŞMEYE BAŞLA"
- Match should fire within 1-2 seconds. Video flows P2P (relayed through TURN if NAT can't punch).

---

## 4. Free-tier limits & when to upgrade

| Service | Free tier | Upgrade trigger |
|---|---|---|
| Fly.io | 3× shared-cpu-1x VMs, 160GB egress | When you have >100 concurrent matches |
| Netlify | 100GB bandwidth, 300 build minutes/mo | When you exceed bandwidth (Flutter web is ~2-3MB gzipped) |
| OpenRelay TURN | ~unmetered (public, best-effort) | When you want guaranteed bandwidth → metered.ca paid (~$15/mo for 50GB) or self-host coturn |

When you upgrade TURN, swap the `iceServers` array in [server/server.js](server/server.js) for the paid credentials.
