/**
 * azar_chat / kerochat — signaling + matchmaking server
 *
 * Auth & ban checks are enforced server-side using a Supabase JWT passed
 * either as ?token= in the connect URL or in the hello message.
 *
 * Required env vars:
 *   PORT, HOST                      — defaults 9090 / 0.0.0.0
 *   SUPABASE_URL                    — https://xxx.supabase.co
 *   SUPABASE_SERVICE_ROLE_KEY       — server-only, secret
 *   SUPABASE_JWT_SECRET             — used to verify user JWTs (HS256)
 */

const http = require('http');
const crypto = require('crypto');
const { WebSocketServer, WebSocket } = require('ws');
const jwt = require('jsonwebtoken');
const { createClient } = require('@supabase/supabase-js');

const PORT = parseInt(process.env.PORT || '9090', 10);
const HOST = process.env.HOST || '0.0.0.0';

const SUPABASE_URL              = process.env.SUPABASE_URL              || '';
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const SUPABASE_JWT_SECRET       = process.env.SUPABASE_JWT_SECRET       || '';

const supabaseEnabled = SUPABASE_URL && SUPABASE_SERVICE_ROLE_KEY && SUPABASE_JWT_SECRET;
const supabase = supabaseEnabled
  ? createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
      // Node 20 has no native WebSocket; supabase-js v2 realtime needs one.
      realtime: { transport: WebSocket },
    })
  : null;

if (!supabaseEnabled) {
  console.warn('[warn] Supabase env vars missing — running in OPEN MODE (no auth, no ban check)');
}

// Free public TURN — replace with own credentials in production.
const ICE_SERVERS = [
  { urls: 'stun:stun.l.google.com:19302' },
  { urls: 'stun:stun.relay.metered.ca:80' },
  { urls: 'turn:openrelay.metered.ca:80',  username: 'openrelayproject', credential: 'openrelayproject' },
  { urls: 'turn:openrelay.metered.ca:443', username: 'openrelayproject', credential: 'openrelayproject' },
  { urls: 'turn:openrelay.metered.ca:443?transport=tcp', username: 'openrelayproject', credential: 'openrelayproject' },
];

/** @type {Map<string, Peer>} */
const peers = new Map();
const queue = [];

class Peer {
  constructor(ws) {
    this.id = crypto.randomUUID();           // ephemeral socket id
    this.ws = ws;
    this.userId = null;                      // Supabase auth uid if signed in
    this.name = 'Misafir';
    this.gender = 'X';
    this.peerGender = 'any';
    /** @type {'idle' | 'queued' | 'matched'} */
    this.status = 'idle';
    this.matchId = null;
  }

  send(msg) {
    if (this.ws.readyState === WebSocket.OPEN) this.ws.send(JSON.stringify(msg));
  }

  publicInfo() {
    return { id: this.id, userId: this.userId, name: this.name, gender: this.gender };
  }
}

// ---------------------------------------------------------------------- helpers

function verifyToken(token) {
  if (!supabaseEnabled || !token) return null;
  try {
    const payload = jwt.verify(token, SUPABASE_JWT_SECRET, { algorithms: ['HS256'] });
    return payload?.sub ? { sub: payload.sub, anonymous: payload.is_anonymous === true } : null;
  } catch (err) {
    console.warn('[jwt] invalid token:', err.message);
    return null;
  }
}

async function isBanned(userId) {
  if (!supabase || !userId) return false;
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('is_banned, banned_until')
      .eq('id', userId)
      .maybeSingle();
    if (error || !data || !data.is_banned) return false;
    if (data.banned_until && new Date(data.banned_until) < new Date()) {
      // expired auto-ban — clear it (best-effort, ignore failure)
      supabase.from('profiles')
        .update({ is_banned: false, banned_until: null, ban_reason: null })
        .eq('id', userId)
        .then(() => {}, () => {});
      return false;
    }
    return true;
  } catch (e) {
    console.error('[ban-check] error:', e.message);
    return false; // fail-open: do not block on infra error
  }
}

function compatible(a, b) {
  if (a.id === b.id) return false;
  if (a.peerGender !== 'any' && b.gender !== a.peerGender) return false;
  if (b.peerGender !== 'any' && a.gender !== b.peerGender) return false;
  return true;
}

function pair(a, b) {
  a.status = 'matched'; b.status = 'matched';
  a.matchId = b.id;     b.matchId = a.id;
  const aPolite = a.id > b.id;
  a.send({ type: 'matched', peerId: b.id, peerInfo: b.publicInfo(), polite:  aPolite });
  b.send({ type: 'matched', peerId: a.id, peerInfo: a.publicInfo(), polite: !aPolite });
  console.log(`[match] ${a.id.slice(0, 8)}(${a.userId?.slice(0,8) || 'guest'}) <-> ${b.id.slice(0, 8)}(${b.userId?.slice(0,8) || 'guest'})`);
}

async function enqueue(peer) {
  if (peer.status === 'matched') return;

  // ban gate
  if (await isBanned(peer.userId)) {
    peer.send({ type: 'error', code: 'banned', message: 'Yasaklısın. İtiraz için destek ekibiyle iletişime geç.' });
    try { peer.ws.close(1008, 'banned'); } catch (_) {}
    return;
  }

  const ix = queue.indexOf(peer.id);
  if (ix >= 0) queue.splice(ix, 1);

  for (let i = 0; i < queue.length; i++) {
    const other = peers.get(queue[i]);
    if (!other || other.status !== 'queued') { queue.splice(i, 1); i--; continue; }
    if (compatible(peer, other)) {
      queue.splice(i, 1);
      pair(peer, other);
      return;
    }
  }

  peer.status = 'queued';
  queue.push(peer.id);
  peer.send({ type: 'searching' });
}

function unpair(peer, reason) {
  const partner = peer.matchId ? peers.get(peer.matchId) : null;
  if (partner) {
    partner.status = 'idle';
    partner.matchId = null;
    partner.send({ type: 'peer_left', reason });
  }
  peer.status = 'idle';
  peer.matchId = null;
}

function removeFromQueue(peerId) {
  const ix = queue.indexOf(peerId);
  if (ix >= 0) queue.splice(ix, 1);
}

// ---------------------------------------------------------------------- handlers

function handleHello(peer, msg) {
  if (typeof msg.name === 'string')               peer.name = msg.name.slice(0, 40) || 'Misafir';
  if (['M','F','X'].includes(msg.gender))         peer.gender = msg.gender;
  if (['M','F','any'].includes(msg.peerGender))   peer.peerGender = msg.peerGender;

  // Optional in-message token (fallback if connect URL didn't carry one).
  if (typeof msg.token === 'string' && !peer.userId) {
    const v = verifyToken(msg.token);
    if (v) peer.userId = v.sub;
  }
}

function handleSignal(peer, msg) {
  if (peer.status !== 'matched' || peer.matchId !== msg.to) return;
  const target = peers.get(msg.to);
  if (!target) return;
  target.send({ type: 'signal', from: peer.id, payload: msg.payload });
}

async function handleNext(peer) {
  unpair(peer, 'next');
  removeFromQueue(peer.id);
  await enqueue(peer);
}

function handleLeave(peer) {
  unpair(peer, 'leave');
  removeFromQueue(peer.id);
}

function handleDisconnect(peer) {
  unpair(peer, 'disconnect');
  removeFromQueue(peer.id);
  peers.delete(peer.id);
  console.log(`[disconnect] ${peer.id.slice(0, 8)} (active=${peers.size}, queue=${queue.length})`);
}

// ---------------------------------------------------------------------- server

const httpServer = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      ok: true,
      peers: peers.size,
      queue: queue.length,
      authMode: supabaseEnabled ? 'supabase' : 'open',
    }));
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server: httpServer });

wss.on('connection', (ws, req) => {
  const peer = new Peer(ws);
  peers.set(peer.id, peer);

  // Try to extract token from connect URL.
  try {
    const url = new URL(req.url, 'http://x');
    const token = url.searchParams.get('token');
    if (token) {
      const v = verifyToken(token);
      if (v) peer.userId = v.sub;
    }
  } catch (_) {/* ignore */}

  console.log(`[connect] ${peer.id.slice(0, 8)} user=${peer.userId?.slice(0,8) || 'guest'} from ${req.socket.remoteAddress} (active=${peers.size})`);

  peer.send({ type: 'welcome', selfId: peer.id, iceServers: ICE_SERVERS });

  ws.on('message', async (raw) => {
    let msg;
    try { msg = JSON.parse(raw.toString()); }
    catch { return peer.send({ type: 'error', message: 'bad_json' }); }

    switch (msg.type) {
      case 'hello':   return handleHello(peer, msg);
      case 'enqueue': return enqueue(peer);
      case 'signal':  return handleSignal(peer, msg);
      case 'next':    return handleNext(peer);
      case 'leave':   return handleLeave(peer);
      default:        return peer.send({ type: 'error', message: 'unknown_type' });
    }
  });

  ws.on('close', () => handleDisconnect(peer));
  ws.on('error', (err) => console.error(`[ws-error] ${peer.id.slice(0, 8)}:`, err.message));
});

setInterval(() => {
  if (peers.size > 0 || queue.length > 0) {
    console.log(`[stats] peers=${peers.size} queue=${queue.length}`);
  }
}, 60_000);

httpServer.listen(PORT, HOST, () => {
  console.log(`kerochat signaling on ${HOST}:${PORT} (auth=${supabaseEnabled ? 'on' : 'off'})`);
});
