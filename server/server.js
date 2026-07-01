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
const { createRemoteJWKSet, jwtVerify } = require('jose');
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

// JWKS for ES256/RS256 Supabase tokens (new projects). Falls back to HS256 with JWT secret.
const jwks = SUPABASE_URL
  ? createRemoteJWKSet(new URL(`${SUPABASE_URL}/auth/v1/.well-known/jwks.json`))
  : null;

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

// ------------------------------------------------------------------ rooms
// In-memory Clubhouse-style voice rooms. Full-mesh audio: cap kept small.
const ROOM_CAP = 10;
const ROOM_TITLE_MAX = 60;
const ROOM_CHAT_MAX = 400;

/** @type {Map<string, Room>} */
const rooms = new Map();

class Room {
  constructor({ title, topic, ownerId }) {
    this.id = crypto.randomBytes(4).toString('hex');
    this.title = title;
    this.topic = topic;
    this.ownerId = ownerId;          // peer id of current owner
    this.createdAt = Date.now();
    /** @type {string[]} joins in order — first is oldest (owner succession) */
    this.memberIds = [];
  }

  members() {
    return this.memberIds.map((id) => peers.get(id)).filter(Boolean);
  }

  memberInfo(p) {
    return { ...p.publicInfo(), muted: p.muted, isOwner: p.id === this.ownerId };
  }

  summary() {
    const owner = peers.get(this.ownerId);
    return {
      id: this.id, title: this.title, topic: this.topic,
      count: this.memberIds.length, cap: ROOM_CAP,
      ownerName: owner ? owner.name : '—',
    };
  }

  broadcast(msg, exceptId = null) {
    for (const m of this.members()) {
      if (m.id !== exceptId) m.send(msg);
    }
  }
}

// IP → country cache (avoid hammering ipapi.co — free tier = 1000/day).
const GEO_TTL_MS = 6 * 60 * 60 * 1000; // 6h
/** @type {Map<string, {country: string|null, at: number}>} */
const geoCache = new Map();

class Peer {
  constructor(ws) {
    this.id = crypto.randomUUID();           // ephemeral socket id
    this.ws = ws;
    this.userId = null;                      // Supabase auth uid if signed in
    this.name = 'Misafir';
    this.gender = 'X';
    this.peerGender = 'any';
    /** @type {'video' | 'voice'} 1-1 matchmaking mode */
    this.mode = 'video';
    /** @type {'idle' | 'queued' | 'matched'} */
    this.status = 'idle';
    this.matchId = null;
    this.roomId = null;
    this.muted = false;
    this.ip = null;
    this.country = null;
    this.ua = null;
    this.deviceFp = null;       // client-computed SHA-256 of UA+screen+tz+lang
    this.presenceSynced = false;
  }

  send(msg) {
    if (this.ws.readyState === WebSocket.OPEN) this.ws.send(JSON.stringify(msg));
  }

  publicInfo() {
    return {
      id: this.id, userId: this.userId,
      name: this.name, gender: this.gender,
      country: this.country,
    };
  }
}

// ---------------------------------------------------------------------- helpers

async function verifyToken(token) {
  if (!supabaseEnabled || !token) return null;

  // Decode header to pick the right verification path (new projects use ES256, old HS256).
  let alg = null;
  try {
    const headerB64 = token.split('.')[0];
    const header = JSON.parse(Buffer.from(headerB64, 'base64url').toString('utf8'));
    alg = header.alg;
  } catch (_) {/* malformed token */}

  // ES256 / RS256 — use JWKS (public key).
  if (alg && alg !== 'HS256' && jwks) {
    try {
      const { payload } = await jwtVerify(token, jwks, {
        issuer: `${SUPABASE_URL}/auth/v1`,
      });
      return payload?.sub ? { sub: payload.sub, anonymous: payload.is_anonymous === true } : null;
    } catch (err) {
      console.warn(`[jwt] ${alg} verify failed: ${err.message}`);
      return null;
    }
  }

  // HS256 — legacy shared secret.
  try {
    const payload = jwt.verify(token, SUPABASE_JWT_SECRET, { algorithms: ['HS256'] });
    return payload?.sub ? { sub: payload.sub, anonymous: payload.is_anonymous === true } : null;
  } catch (err) {
    console.warn(`[jwt] HS256 verify failed: ${err.message}`);
    return null;
  }
}

function getClientIp(req) {
  // Behind OLS reverse proxy: trust X-Forwarded-For (first hop).
  const xff = req.headers['x-forwarded-for'];
  if (typeof xff === 'string' && xff.length > 0) {
    const first = xff.split(',')[0].trim();
    if (first) return first;
  }
  const real = req.headers['x-real-ip'];
  if (typeof real === 'string' && real.length > 0) return real.trim();
  return req.socket.remoteAddress || null;
}

function normalizeIp(ip) {
  if (!ip) return null;
  // strip IPv6-mapped IPv4 prefix and brackets
  let s = ip.replace(/^::ffff:/i, '').replace(/^\[|\]$/g, '');
  // strip any port suffix (e.g. ":54321")
  const lastColon = s.lastIndexOf(':');
  if (s.indexOf(':') === lastColon && lastColon > -1 && /^\d+$/.test(s.slice(lastColon + 1))) {
    s = s.slice(0, lastColon);
  }
  return s || null;
}

async function geoLookup(ip) {
  if (!ip) return null;
  // Skip private / loopback ranges — they would resolve to null anyway.
  if (/^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[0-1])\.|::1|fe80:)/i.test(ip)) return null;

  const hit = geoCache.get(ip);
  if (hit && Date.now() - hit.at < GEO_TTL_MS) return hit.country;

  try {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), 2000);
    const res = await fetch(`https://ipapi.co/${encodeURIComponent(ip)}/country/`, {
      signal: ctl.signal,
      headers: { 'User-Agent': 'kerochat-signaling/1.0' },
    });
    clearTimeout(timer);
    if (!res.ok) {
      console.warn(`[geo] ipapi ${ip} → HTTP ${res.status}`);
      geoCache.set(ip, { country: null, at: Date.now() });
      return null;
    }
    const text = (await res.text()).trim();
    // Body is just a 2-letter country code, e.g. "TR", or "Undefined" on failure.
    const country = /^[A-Z]{2}$/.test(text) ? text : null;
    geoCache.set(ip, { country, at: Date.now() });
    return country;
  } catch (e) {
    console.warn(`[geo] lookup failed for ${ip}: ${e.message}`);
    geoCache.set(ip, { country: null, at: Date.now() });
    return null;
  }
}

async function checkBanEvasion(ip, deviceFp) {
  if (!supabase) return null;
  if (!ip && !deviceFp) return null;
  try {
    const { data, error } = await supabase.rpc('check_ban_evasion', {
      p_ip: ip,
      p_device_fp_hash: deviceFp,
    });
    if (error) {
      console.error(`[ban-evasion] RPC error: ${error.message}`);
      return null;
    }
    if (Array.isArray(data) && data.length > 0) {
      const row = data[0];
      console.log(`[ban-evasion] MATCH ip=${ip} fp=${deviceFp?.slice(0,8)} reason=${row.reason || 'n/a'}`);
      return row;
    }
    return null;
  } catch (e) {
    console.error(`[ban-evasion] EXCEPTION: ${e.message}`);
    return null;
  }
}

async function syncPresence(peer) {
  if (!supabase || !peer.userId || peer.presenceSynced) return;
  try {
    const { error } = await supabase.rpc('update_presence_info', {
      p_user_id:        peer.userId,
      p_ip:             peer.ip,
      p_country:        peer.country,
      p_ua:             peer.ua,
      p_device_fp_hash: peer.deviceFp,
    });
    if (error) console.warn(`[presence] update failed for ${peer.userId.slice(0,8)}: ${error.message}`);
    else peer.presenceSynced = true;
  } catch (e) {
    console.error(`[presence] EXCEPTION: ${e.message}`);
  }
}

async function isBanned(userId) {
  if (!supabase) {
    console.log('[ban-check] no supabase client (open mode) — allowing');
    return false;
  }
  if (!userId) {
    console.log('[ban-check] no userId on peer (anonymous guest, no token) — allowing');
    return false;
  }
  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('is_banned, banned_until')
      .eq('id', userId)
      .maybeSingle();
    if (error) {
      console.error(`[ban-check] DB error for ${userId.slice(0,8)}: ${error.message} — failing OPEN`);
      return false;
    }
    if (!data) {
      console.log(`[ban-check] no profile row for ${userId.slice(0,8)} — allowing (auto-trigger may not have fired)`);
      return false;
    }
    console.log(`[ban-check] ${userId.slice(0,8)} is_banned=${data.is_banned} until=${data.banned_until ?? 'null'}`);
    if (!data.is_banned) return false;
    if (data.banned_until && new Date(data.banned_until) < new Date()) {
      console.log(`[ban-check] ${userId.slice(0,8)} ban expired — clearing`);
      supabase.from('profiles')
        .update({ is_banned: false, banned_until: null, ban_reason: null })
        .eq('id', userId)
        .then(() => {}, () => {});
      return false;
    }
    console.log(`[ban-check] ${userId.slice(0,8)} ACTIVELY BANNED — kicking`);
    return true;
  } catch (e) {
    console.error(`[ban-check] EXCEPTION for ${userId?.slice(0,8)}: ${e.message} — failing OPEN`);
    return false;
  }
}

function compatible(a, b) {
  if (a.id === b.id) return false;
  // Same authenticated user with two sockets — don't match with self.
  if (a.userId && b.userId && a.userId === b.userId) return false;
  if (a.mode !== b.mode) return false;
  if (a.peerGender !== 'any' && b.gender !== a.peerGender) return false;
  if (b.peerGender !== 'any' && a.gender !== b.peerGender) return false;
  return true;
}

function pair(a, b) {
  a.status = 'matched'; b.status = 'matched';
  a.matchId = b.id;     b.matchId = a.id;
  const aPolite = a.id > b.id;
  a.send({ type: 'matched', peerId: b.id, peerInfo: b.publicInfo(), polite:  aPolite, mode: a.mode });
  b.send({ type: 'matched', peerId: a.id, peerInfo: a.publicInfo(), polite: !aPolite, mode: b.mode });
  console.log(`[match] ${a.id.slice(0, 8)}(${a.userId?.slice(0,8) || 'guest'}) <-> ${b.id.slice(0, 8)}(${b.userId?.slice(0,8) || 'guest'})`);
}

async function enqueue(peer) {
  if (peer.status === 'matched') return;
  leaveRoom(peer); // matchmaking and rooms are mutually exclusive

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

async function handleHello(peer, msg) {
  if (typeof msg.name === 'string')               peer.name = msg.name.slice(0, 40) || 'Misafir';
  if (['M','F','X'].includes(msg.gender))         peer.gender = msg.gender;
  if (['M','F','any'].includes(msg.peerGender))   peer.peerGender = msg.peerGender;
  if (['video','voice'].includes(msg.mode))       peer.mode = msg.mode;

  // Optional in-message token (fallback if connect URL didn't carry one).
  if (typeof msg.token === 'string' && !peer.userId) {
    const v = await verifyToken(msg.token);
    if (v) peer.userId = v.sub;
  }

  // Client-supplied device fingerprint (already hashed). 64-char hex expected.
  if (typeof msg.deviceFp === 'string' && /^[a-f0-9]{16,128}$/i.test(msg.deviceFp)) {
    peer.deviceFp = msg.deviceFp.toLowerCase();
  }

  // Now that we know the user + fingerprint, run ban-evasion gate.
  const evasion = await checkBanEvasion(peer.ip, peer.deviceFp);
  if (evasion) {
    peer.send({ type: 'error', code: 'ban_evasion', message: 'Bu cihaz/IP yasaklı bir hesapla ilişkili.' });
    try { peer.ws.close(1008, 'ban_evasion'); } catch (_) {}
    return;
  }

  // Backfill profile presence (country, ip, ua, fp) for the signed-in user.
  await syncPresence(peer);
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

// ---------------------------------------------------------------------- room handlers

function leaveRoom(peer, { silent = false } = {}) {
  if (!peer.roomId) return;
  const room = rooms.get(peer.roomId);
  peer.roomId = null;
  peer.muted = false;
  if (!room) return;

  const ix = room.memberIds.indexOf(peer.id);
  if (ix >= 0) room.memberIds.splice(ix, 1);

  if (room.memberIds.length === 0) {
    rooms.delete(room.id);
    console.log(`[room] ${room.id} closed (empty)`);
    return;
  }

  // Owner succession: oldest remaining member takes over.
  let newOwnerId = null;
  if (room.ownerId === peer.id) {
    room.ownerId = room.memberIds[0];
    newOwnerId = room.ownerId;
    console.log(`[room] ${room.id} owner -> ${room.ownerId.slice(0, 8)}`);
  }

  if (!silent) {
    room.broadcast({ type: 'room_peer_left', peerId: peer.id, newOwnerId });
  }
}

async function handleRoomCreate(peer, msg) {
  if (await isBanned(peer.userId)) {
    peer.send({ type: 'error', code: 'banned', message: 'Yasaklısın.' });
    try { peer.ws.close(1008, 'banned'); } catch (_) {}
    return;
  }
  // A peer can be in exactly one context: leave queue/match/old room first.
  unpair(peer, 'leave');
  removeFromQueue(peer.id);
  leaveRoom(peer);

  const title = (typeof msg.title === 'string' ? msg.title.trim() : '').slice(0, ROOM_TITLE_MAX);
  if (!title) return peer.send({ type: 'error', code: 'room_title', message: 'Oda adı gerekli.' });
  const topic = (typeof msg.topic === 'string' ? msg.topic.trim() : '').slice(0, 30);

  const room = new Room({ title, topic, ownerId: peer.id });
  rooms.set(room.id, room);
  room.memberIds.push(peer.id);
  peer.roomId = room.id;
  peer.muted = false; // creator starts live on stage

  console.log(`[room] ${room.id} created "${title}" by ${peer.id.slice(0, 8)}`);
  peer.send({
    type: 'room_joined',
    room: room.summary(),
    ownerId: room.ownerId,
    members: room.members().map((m) => room.memberInfo(m)),
  });
}

async function handleRoomJoin(peer, msg) {
  if (await isBanned(peer.userId)) {
    peer.send({ type: 'error', code: 'banned', message: 'Yasaklısın.' });
    try { peer.ws.close(1008, 'banned'); } catch (_) {}
    return;
  }
  const room = rooms.get(typeof msg.roomId === 'string' ? msg.roomId : '');
  if (!room) return peer.send({ type: 'error', code: 'room_gone', message: 'Oda bulunamadı veya kapandı.' });
  if (room.memberIds.includes(peer.id)) return;
  if (room.memberIds.length >= ROOM_CAP) {
    return peer.send({ type: 'error', code: 'room_full', message: 'Oda dolu.' });
  }

  unpair(peer, 'leave');
  removeFromQueue(peer.id);
  leaveRoom(peer);

  peer.roomId = room.id;
  peer.muted = true; // joiners land muted (listener) — unmute to speak

  // Tell existing members BEFORE adding, so the list they hold stays consistent.
  room.broadcast({ type: 'room_peer_joined', member: room.memberInfo(peer) });
  room.memberIds.push(peer.id);

  console.log(`[room] ${room.id} join ${peer.id.slice(0, 8)} (${room.memberIds.length}/${ROOM_CAP})`);
  peer.send({
    type: 'room_joined',
    room: room.summary(),
    ownerId: room.ownerId,
    members: room.members().map((m) => room.memberInfo(m)),
  });
}

function handleRoomLeave(peer) {
  leaveRoom(peer);
}

function handleRoomList(peer) {
  const list = [...rooms.values()]
    .sort((a, b) => b.memberIds.length - a.memberIds.length)
    .slice(0, 50)
    .map((r) => r.summary());
  peer.send({ type: 'room_list', rooms: list });
}

function handleRoomSignal(peer, msg) {
  if (!peer.roomId) return;
  const room = rooms.get(peer.roomId);
  if (!room) return;
  const target = peers.get(typeof msg.to === 'string' ? msg.to : '');
  if (!target || target.roomId !== room.id) return;
  target.send({ type: 'room_signal', from: peer.id, payload: msg.payload });
}

function handleRoomChat(peer, msg) {
  if (!peer.roomId) return;
  const room = rooms.get(peer.roomId);
  if (!room) return;
  const text = (typeof msg.text === 'string' ? msg.text.trim() : '').slice(0, ROOM_CHAT_MAX);
  if (!text) return;
  room.broadcast({ type: 'room_chat', from: room.memberInfo(peer), text, at: Date.now() });
}

function handleRoomState(peer, msg) {
  if (!peer.roomId) return;
  const room = rooms.get(peer.roomId);
  if (!room) return;
  if (typeof msg.muted === 'boolean') peer.muted = msg.muted;
  room.broadcast({ type: 'room_member_state', peerId: peer.id, muted: peer.muted }, peer.id);
}

function handleRoomKick(peer, msg) {
  if (!peer.roomId) return;
  const room = rooms.get(peer.roomId);
  if (!room || room.ownerId !== peer.id) return;
  const target = peers.get(typeof msg.peerId === 'string' ? msg.peerId : '');
  if (!target || target.roomId !== room.id || target.id === peer.id) return;
  target.send({ type: 'room_kicked' });
  leaveRoom(target);
}

function handleRoomMute(peer, msg) {
  if (!peer.roomId) return;
  const room = rooms.get(peer.roomId);
  if (!room || room.ownerId !== peer.id) return;
  const target = peers.get(typeof msg.peerId === 'string' ? msg.peerId : '');
  if (!target || target.roomId !== room.id || target.id === peer.id) return;
  target.muted = true;
  target.send({ type: 'room_force_muted' });
  room.broadcast({ type: 'room_member_state', peerId: target.id, muted: true }, target.id);
}

function handleDisconnect(peer) {
  unpair(peer, 'disconnect');
  removeFromQueue(peer.id);
  leaveRoom(peer);
  peers.delete(peer.id);
  console.log(`[disconnect] ${peer.id.slice(0, 8)} (active=${peers.size}, queue=${queue.length}, rooms=${rooms.size})`);
}

// ---------------------------------------------------------------------- server

const httpServer = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      ok: true,
      peers: peers.size,
      queue: queue.length,
      rooms: rooms.size,
      authMode: supabaseEnabled ? 'supabase' : 'open',
    }));
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server: httpServer });

wss.on('connection', async (ws, req) => {
  const peer = new Peer(ws);
  peers.set(peer.id, peer);

  // Capture client environment up-front (used for ban-evasion + geo).
  peer.ip = normalizeIp(getClientIp(req));
  peer.ua = (req.headers['user-agent'] || '').slice(0, 300) || null;
  peer.country = await geoLookup(peer.ip);

  // Try to extract token from connect URL.
  try {
    const url = new URL(req.url, 'http://x');
    const token = url.searchParams.get('token');
    if (token) {
      const v = await verifyToken(token);
      if (v) peer.userId = v.sub;
    }
  } catch (_) {/* ignore */}

  console.log(`[connect] ${peer.id.slice(0, 8)} user=${peer.userId?.slice(0,8) || 'guest'} ip=${peer.ip} country=${peer.country || '?'} (active=${peers.size})`);

  peer.send({ type: 'welcome', selfId: peer.id, iceServers: ICE_SERVERS });

  ws.on('message', async (raw) => {
    let msg;
    try { msg = JSON.parse(raw.toString()); }
    catch { return peer.send({ type: 'error', message: 'bad_json' }); }

    switch (msg.type) {
      case 'hello':   return await handleHello(peer, msg);
      case 'enqueue':
        if (['video','voice'].includes(msg.mode)) peer.mode = msg.mode;
        return enqueue(peer);
      case 'signal':  return handleSignal(peer, msg);
      case 'next':    return handleNext(peer);
      case 'leave':   return handleLeave(peer);
      case 'room_create': return await handleRoomCreate(peer, msg);
      case 'room_join':   return await handleRoomJoin(peer, msg);
      case 'room_leave':  return handleRoomLeave(peer);
      case 'room_list':   return handleRoomList(peer);
      case 'room_signal': return handleRoomSignal(peer, msg);
      case 'room_chat':   return handleRoomChat(peer, msg);
      case 'room_state':  return handleRoomState(peer, msg);
      case 'room_kick':   return handleRoomKick(peer, msg);
      case 'room_mute':   return handleRoomMute(peer, msg);
      default:        return peer.send({ type: 'error', message: 'unknown_type' });
    }
  });

  ws.on('close', () => handleDisconnect(peer));
  ws.on('error', (err) => console.error(`[ws-error] ${peer.id.slice(0, 8)}:`, err.message));
});

setInterval(() => {
  if (peers.size > 0 || queue.length > 0 || rooms.size > 0) {
    console.log(`[stats] peers=${peers.size} queue=${queue.length} rooms=${rooms.size}`);
  }
}, 60_000);

httpServer.listen(PORT, HOST, () => {
  console.log(`kerochat signaling on ${HOST}:${PORT} (auth=${supabaseEnabled ? 'on' : 'off'})`);
});
