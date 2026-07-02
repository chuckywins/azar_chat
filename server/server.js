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
// ── live-tunable settings (app_settings tablosu; webadmin'den yönetilir) ────
// Defaults below apply when Supabase is absent or a key is missing.
// refreshSettings() reloads every 60s and on POST /admin/refresh.
const CFG = {
  voiceCallMs:       2 * 60_000,   // voice_call_sec
  voiceExtMs:        150_000,      // voice_ext_sec
  voiceExtVipMs:     240_000,      // voice_ext_vip_sec
  roomVipMs:         7 * 60_000,   // room_vip_sec
  roomExtMs:         3 * 60_000,   // room_ext_sec
  roomMaxAheadMs:    30 * 60_000,  // room_max_ahead_sec
  systemRoomMs:      200_000,      // system_room_sec
  systemRoomMinOpen: 5,            // system_room_min_open
  systemRoomCapMin:  3,            // system_room_cap_min
  systemRoomCapMax:  4,            // system_room_cap_max
  filterCost:        5,            // filter_match_cost
};
const SYSTEM_ROOM_MAX = 40; // runaway guard (statik)

const DEFAULT_TOPICS = [
  ['Tanışalım', 'Tanışma'], ['Şarkını Söyle', 'Müzik'], ['Dertleşelim', 'Dertleşme'],
  ['İtiraf Saati', 'İtiraf'], ['Gece Sohbeti', 'Sohbet'], ['English Time', 'English'],
  ['Oyun & Eğlence', 'Oyun'], ['Müzik Keyfi', 'Müzik'], ['Felsefe Masası', 'Sohbet'],
];
let SYSTEM_TOPICS = [...DEFAULT_TOPICS];

const SETTING_MAP = {
  voice_call_sec:       ['voiceCallMs', 1000],
  voice_ext_sec:        ['voiceExtMs', 1000],
  voice_ext_vip_sec:    ['voiceExtVipMs', 1000],
  room_vip_sec:         ['roomVipMs', 1000],
  room_ext_sec:         ['roomExtMs', 1000],
  room_max_ahead_sec:   ['roomMaxAheadMs', 1000],
  system_room_sec:      ['systemRoomMs', 1000],
  system_room_min_open: ['systemRoomMinOpen', 1],
  system_room_cap_min:  ['systemRoomCapMin', 1],
  system_room_cap_max:  ['systemRoomCapMax', 1],
  filter_match_cost:    ['filterCost', 1],
};

async function refreshSettings() {
  if (!supabase) return;
  try {
    const { data, error } = await supabase.from('app_settings').select('key,value');
    if (!error && Array.isArray(data)) {
      for (const row of data) {
        const m = SETTING_MAP[row.key];
        if (!m) continue;
        const n = parseInt(row.value, 10);
        if (Number.isFinite(n) && n >= 0) CFG[m[0]] = n * m[1];
      }
    }
  } catch (e) { console.warn(`[settings] load failed: ${e.message}`); }

  try {
    const { data, error } = await supabase
      .from('system_room_topics')
      .select('title,topic')
      .eq('active', true)
      .order('sort', { ascending: true });
    if (!error && Array.isArray(data) && data.length > 0) {
      SYSTEM_TOPICS = data.map((r) => [r.title, r.topic]);
    } else if (!error) {
      SYSTEM_TOPICS = [...DEFAULT_TOPICS];
    }
  } catch (e) { console.warn(`[settings] topics load failed: ${e.message}`); }
}

// Region groups for the real country filter.
const REGIONS = {
  'TR':      new Set(['TR']),
  'Avrupa':  new Set(['DE','FR','GB','NL','ES','IT','PT','BE','AT','CH','SE','NO','DK',
                      'FI','PL','CZ','GR','RO','BG','HU','IE','UA','RS','HR','AZ','TR']),
  'Asya':    new Set(['JP','KR','CN','IN','ID','TH','VN','PH','MY','SG','PK','BD','KZ',
                      'UZ','SA','AE','QA','IQ','IR','IL','JO','LB','KW']),
  'Amerika': new Set(['US','CA','MX','BR','AR','CO','CL','PE','VE','EC','UY','BO','PY',
                      'CR','PA','DO','GT']),
};

/** @type {Map<string, Room>} */
const rooms = new Map();

class Room {
  constructor({ title, topic, ownerId, lifetimeMs, system = false, manual = false, cap = ROOM_CAP }) {
    this.id = crypto.randomBytes(4).toString('hex');
    this.title = title;
    this.topic = topic;
    this.ownerId = ownerId;          // peer id of current owner (null for system/manual rooms)
    this.system = system;            // server-generated pool room
    this.manual = manual;            // admin-created room (panel) — fixed timer, outside pool
    this.cap = cap;
    this.createdAt = Date.now();
    // system pool rooms: timer starts on first join; manual: fixed at creation
    // (lifetimeMs 0/undefined for manual = süresiz); user (VIP) rooms: timed now.
    if (system && !manual) {
      this.expiresAt = null;
    } else if (manual) {
      this.expiresAt = lifetimeMs ? Date.now() + lifetimeMs : null;
    } else {
      this.expiresAt = Date.now() + (lifetimeMs || CFG.roomVipMs);
    }
    /** @type {string[]} joins in order — first is oldest (owner succession) */
    this.memberIds = [];
  }

  get isFull() { return this.memberIds.length >= this.cap; }

  members() {
    return this.memberIds.map((id) => peers.get(id)).filter(Boolean);
  }

  memberInfo(p) {
    return { ...p.publicInfo(), muted: p.muted, isOwner: this.ownerId != null && p.id === this.ownerId };
  }

  summary() {
    const owner = this.ownerId ? peers.get(this.ownerId) : null;
    // First 4 members power the swipe-deck slot preview on the client.
    const preview = this.memberIds.slice(0, 4)
      .map((id) => peers.get(id))
      .filter(Boolean)
      .map((p) => ({ id: p.id, userId: p.userId, name: p.name, avatarUrl: p.avatarUrl }));
    return {
      id: this.id, title: this.title, topic: this.topic,
      count: this.memberIds.length, cap: this.cap,
      ownerName: (this.system || this.manual) ? 'kerochat' : (owner ? owner.name : '—'),
      system: this.system,
      manual: this.manual,
      expiresAt: this.expiresAt,
      preview,
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
    this.role = 'user';                      // profiles.role — 'admin' shows a tag
    this.isVip = false;
    this.avatarUrl = null;                   // profiles.avatar_url (DiceBear etc.)
    this.nameLocked = false;                 // true once profile nickname is authoritative
    this.gender = 'X';
    this.peerGender = 'any';
    /** @type {'video' | 'voice'} 1-1 matchmaking mode */
    this.mode = 'video';
    /** Voice-mode topic ('random' matches anything, BlindID-style). */
    this.topic = 'random';
    /** Own language + paid filters (region/language; 'any' = free). */
    this.lang = 'TR';
    this.countrySel = 'any';
    this.langSel = 'any';
    /** @type {'idle' | 'queued' | 'matched'} */
    this.status = 'idle';
    this.matchId = null;
    /** Epoch ms — set for timed (random voice) matches. */
    this.callExpiresAt = null;
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
      avatarUrl: this.avatarUrl,
      isAdmin: this.role === 'admin',
      isVip: this.isVip,
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

/// One-shot profile summary for a signed-in peer: role + vip + nickname.
/// Nickname becomes the authoritative display name (anonymity: server-generated
/// random handles, no client-chosen real names for signed-in users).
async function fetchSignalingProfile(peer) {
  if (!supabase || !peer.userId) return;
  try {
    const { data, error } = await supabase.rpc('get_signaling_profile', { p_user_id: peer.userId });
    if (error) {
      console.warn(`[profile] fetch failed for ${peer.userId.slice(0,8)}: ${error.message}`);
      return;
    }
    if (data && typeof data === 'object') {
      if (typeof data.role === 'string') peer.role = data.role;
      peer.isVip = data.vip === true;
      if (typeof data.avatar_url === 'string' && data.avatar_url.trim()) {
        peer.avatarUrl = data.avatar_url.trim().slice(0, 300);
      }
      if (typeof data.nickname === 'string' && data.nickname.trim()) {
        peer.name = data.nickname.trim().slice(0, 40);
        peer.nameLocked = true;
      }
    }
  } catch (e) {
    console.error(`[profile] EXCEPTION: ${e.message}`);
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

function regionOk(sel, country) {
  if (sel === 'any') return true;
  const set = REGIONS[sel];
  return !!(set && country && set.has(country));
}

/** Any paid (non-'any') filter selected? Charged 5 coins per successful match. */
function hasPaidFilters(p) {
  return p.peerGender !== 'any' || p.countrySel !== 'any' || p.langSel !== 'any';
}

function compatible(a, b) {
  if (a.id === b.id) return false;
  // Same authenticated user with two sockets — don't match with self.
  if (a.userId && b.userId && a.userId === b.userId) return false;
  if (a.mode !== b.mode) return false;
  // Voice: topic gate — 'random' pairs with anyone, otherwise topics must match.
  if (a.mode === 'voice' && a.topic !== 'random' && b.topic !== 'random' && a.topic !== b.topic) {
    return false;
  }
  if (a.peerGender !== 'any' && b.gender !== a.peerGender) return false;
  if (b.peerGender !== 'any' && a.gender !== b.peerGender) return false;
  if (!regionOk(a.countrySel, b.country)) return false;
  if (!regionOk(b.countrySel, a.country)) return false;
  if (a.langSel !== 'any' && b.lang !== a.langSel) return false;
  if (b.langSel !== 'any' && a.lang !== b.langSel) return false;
  return true;
}

/** Topic shown to both sides of a voice match: the specific one wins over 'random'. */
function matchTopic(a, b) {
  if (a.mode !== 'voice') return null;
  if (a.topic !== 'random') return a.topic;
  if (b.topic !== 'random') return b.topic;
  return null;
}

function pair(a, b, { timed = false } = {}) {
  a.status = 'matched'; b.status = 'matched';
  a.matchId = b.id;     b.matchId = a.id;
  const aPolite = a.id > b.id;
  const topic = matchTopic(a, b);

  // Random voice matches are time-boxed (2 min); friend calls are not.
  let callExpiresAt = null;
  if (timed) {
    callExpiresAt = Date.now() + CFG.voiceCallMs;
    a.callExpiresAt = callExpiresAt;
    b.callExpiresAt = callExpiresAt;
  }

  a.send({ type: 'matched', peerId: b.id, peerInfo: b.publicInfo(), polite:  aPolite, mode: a.mode, topic, callExpiresAt });
  b.send({ type: 'matched', peerId: a.id, peerInfo: a.publicInfo(), polite: !aPolite, mode: b.mode, topic, callExpiresAt });

  // Paid filters: 5 coins per successful match, charged per selecting side.
  if (supabase) {
    for (const p of [a, b]) {
      if (p.userId && hasPaidFilters(p)) {
        supabase.rpc('charge_match_filter', { p_user_id: p.userId }).then(
          ({ data, error }) => {
            if (error) console.warn(`[filter-charge] ${p.userId.slice(0,8)}: ${error.message}`);
            else if (data && data.charged === false) console.warn(`[filter-charge] ${p.userId.slice(0,8)}: insufficient at match time`);
          },
          () => {},
        );
      }
    }
  }

  console.log(`[match] ${a.id.slice(0, 8)}(${a.userId?.slice(0,8) || 'guest'}) <-> ${b.id.slice(0, 8)}(${b.userId?.slice(0,8) || 'guest'})${timed ? ' [2dk]' : ''}`);
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

  // Paid filters need a signed-in user with at least 5 coins up-front.
  if (hasPaidFilters(peer) && supabase) {
    if (!peer.userId) {
      peer.peerGender = 'any'; peer.countrySel = 'any'; peer.langSel = 'any';
    } else {
      try {
        const { data } = await supabase.from('profiles').select('coins').eq('id', peer.userId).maybeSingle();
        if (!data || (data.coins ?? 0) < CFG.filterCost) {
          return peer.send({ type: 'error', code: 'filter_coins',
            message: `Filtreli eşleşme için en az ${CFG.filterCost} elmas gerekli.` });
        }
      } catch (_) {/* fail open */}
    }
  }

  const ix = queue.indexOf(peer.id);
  if (ix >= 0) queue.splice(ix, 1);

  for (let i = 0; i < queue.length; i++) {
    const other = peers.get(queue[i]);
    if (!other || other.status !== 'queued') { queue.splice(i, 1); i--; continue; }
    if (compatible(peer, other)) {
      queue.splice(i, 1);
      pair(peer, other, { timed: peer.mode === 'voice' });
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
    partner.callExpiresAt = null;
    partner.send({ type: 'peer_left', reason });
  }
  peer.status = 'idle';
  peer.matchId = null;
  peer.callExpiresAt = null;
}

// ── timed voice calls: expiry sweep + extension ─────────────────────────────

setInterval(() => {
  const now = Date.now();
  for (const p of peers.values()) {
    if (p.status !== 'matched' || !p.callExpiresAt || p.callExpiresAt > now) continue;
    const partner = p.matchId ? peers.get(p.matchId) : null;
    p.send({ type: 'call_expired' });
    if (partner) partner.send({ type: 'call_expired' });
    // silent unpair — both already notified with call_expired
    p.status = 'idle'; p.matchId = null; p.callExpiresAt = null;
    if (partner) { partner.status = 'idle'; partner.matchId = null; partner.callExpiresAt = null; }
    console.log(`[call] expired ${p.id.slice(0, 8)} <-> ${partner ? partner.id.slice(0, 8) : '?'}`);
  }
}, 5_000);

async function handleCallExtend(peer) {
  if (peer.status !== 'matched' || !peer.callExpiresAt) return;
  const partner = peer.matchId ? peers.get(peer.matchId) : null;
  if (!partner) return;

  const extMs = peer.isVip ? CFG.voiceExtVipMs : CFG.voiceExtMs;
  if (peer.callExpiresAt - Date.now() + extMs > CFG.roomMaxAheadMs) {
    return peer.send({ type: 'error', code: 'call_max', message: 'Görüşme süresi üst sınırda.' });
  }

  let method = 'free';
  let freeLeft = null;
  if (supabase) {
    if (!peer.userId) {
      return peer.send({ type: 'error', code: 'not_authed', message: 'Süre uzatmak için giriş yapmalısın.' });
    }
    const { data, error } = await supabase.rpc('use_call_extension', { p_user_id: peer.userId });
    if (error) {
      if ((error.message || '').includes('no_extension_left')) {
        return peer.send({ type: 'error', code: 'no_extension_left',
          message: 'Bugünkü ücretsiz hakların ve süre kartların bitti.' });
      }
      console.error(`[call-extend] RPC error: ${error.message}`);
      return peer.send({ type: 'error', code: 'extend_failed', message: 'Süre uzatılamadı.' });
    }
    method = data?.method || 'free';
    freeLeft = data?.free_left ?? null;
  }

  const newExpiry = peer.callExpiresAt + extMs;
  peer.callExpiresAt = newExpiry;
  partner.callExpiresAt = newExpiry;
  peer.send({ type: 'call_extended', expiresAt: newExpiry, byName: peer.name, method, freeLeft, self: true });
  partner.send({ type: 'call_extended', expiresAt: newExpiry, byName: peer.name, method, self: false });
  console.log(`[call] extend +${Math.round(extMs / 1000)}s by ${peer.id.slice(0, 8)} (${method})`);
}

function removeFromQueue(peerId) {
  const ix = queue.indexOf(peerId);
  if (ix >= 0) queue.splice(ix, 1);
}

// ---------------------------------------------------------------------- handlers

async function handleHello(peer, msg) {
  if (typeof msg.name === 'string' && !peer.nameLocked) peer.name = msg.name.slice(0, 40) || 'Misafir';
  if (['M','F','X'].includes(msg.gender))         peer.gender = msg.gender;
  if (['M','F','any'].includes(msg.peerGender))   peer.peerGender = msg.peerGender;
  if (['video','voice'].includes(msg.mode))       peer.mode = msg.mode;
  if (typeof msg.topic === 'string' && msg.topic.trim()) peer.topic = msg.topic.trim().slice(0, 30);
  if (typeof msg.lang === 'string' && /^[A-Z]{2}$/i.test(msg.lang)) peer.lang = msg.lang.toUpperCase();
  if (typeof msg.countrySel === 'string' && (msg.countrySel === 'any' || REGIONS[msg.countrySel])) {
    peer.countrySel = msg.countrySel;
  }
  if (typeof msg.langSel === 'string' && (msg.langSel === 'any' || /^[A-Z]{2}$/i.test(msg.langSel))) {
    peer.langSel = msg.langSel === 'any' ? 'any' : msg.langSel.toUpperCase();
  }

  // Optional in-message token (fallback if connect URL didn't carry one).
  if (typeof msg.token === 'string' && !peer.userId) {
    const v = await verifyToken(msg.token);
    if (v) {
      peer.userId = v.sub;
      await fetchSignalingProfile(peer);
    }
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
    if (!room.system && !room.manual) {
      rooms.delete(room.id);
      console.log(`[room] ${room.id} closed (empty)`);
      return;
    }
    // Empty system pool room: stop the countdown so the next group gets the
    // full duration. (Manual rooms keep their fixed timer.)
    if (room.system && !room.manual) room.expiresAt = null;
  }

  // Owner succession (VIP rooms only): oldest remaining member takes over.
  let newOwnerId = null;
  if (!room.system && room.ownerId === peer.id && room.memberIds.length > 0) {
    room.ownerId = room.memberIds[0];
    newOwnerId = room.ownerId;
    console.log(`[room] ${room.id} owner -> ${room.ownerId.slice(0, 8)}`);
  }

  if (!silent && room.memberIds.length > 0) {
    room.broadcast({ type: 'room_peer_left', peerId: peer.id, newOwnerId });
  }
  ensureSystemRooms();
}

// ── system room pool: always keep small joinable rooms alive ────────────────
function ensureSystemRooms() {
  const poolRooms = [...rooms.values()].filter((r) => r.system && !r.manual);
  const open = poolRooms.filter((r) => !r.isFull);

  // prune surplus EMPTY system rooms (keep the pool tidy)
  const empties = open.filter((r) => r.memberIds.length === 0);
  let surplus = open.length - CFG.systemRoomMinOpen;
  for (const r of empties) {
    if (surplus <= 0) break;
    rooms.delete(r.id);
    surplus--;
  }

  let openCount = [...rooms.values()].filter((r) => r.system && !r.manual && !r.isFull).length;
  let total = [...rooms.values()].filter((r) => r.system && !r.manual).length;
  while (openCount < CFG.systemRoomMinOpen && total < SYSTEM_ROOM_MAX) {
    const [title, topic] = SYSTEM_TOPICS[Math.floor(Math.random() * SYSTEM_TOPICS.length)];
    const lo = Math.max(2, CFG.systemRoomCapMin);
    const hi = Math.max(lo, CFG.systemRoomCapMax);
    const cap = lo + Math.floor(Math.random() * (hi - lo + 1));
    const room = new Room({ title, topic, ownerId: null, system: true, cap });
    rooms.set(room.id, room);
    openCount++; total++;
    console.log(`[room] system ${room.id} "${title}" (cap=${cap})`);
  }
}

async function handleRoomCreate(peer, msg) {
  if (await isBanned(peer.userId)) {
    peer.send({ type: 'error', code: 'banned', message: 'Yasaklısın.' });
    try { peer.ws.close(1008, 'banned'); } catch (_) {}
    return;
  }
  // Room creation is a VIP privilege (system rooms cover everyone else).
  if (supabase && !peer.isVip && peer.role !== 'admin') {
    return peer.send({ type: 'error', code: 'room_vip_only',
      message: 'Oda kurmak VIP üyelere özel. Sistem odalarına katılabilirsin!' });
  }
  // A peer can be in exactly one context: leave queue/match/old room first.
  unpair(peer, 'leave');
  removeFromQueue(peer.id);
  leaveRoom(peer);

  const title = (typeof msg.title === 'string' ? msg.title.trim() : '').slice(0, ROOM_TITLE_MAX);
  if (!title) return peer.send({ type: 'error', code: 'room_title', message: 'Oda adı gerekli.' });
  const topic = (typeof msg.topic === 'string' ? msg.topic.trim() : '').slice(0, 30);

  const room = new Room({
    title, topic, ownerId: peer.id,
    lifetimeMs: CFG.roomVipMs,
  });
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
  if (room.isFull) {
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
  // System pool room countdown starts with the first occupant.
  if (room.system && !room.manual && room.memberIds.length === 1) {
    room.expiresAt = Date.now() + CFG.systemRoomMs;
  }
  ensureSystemRooms(); // room may be full now — keep the open pool stocked

  console.log(`[room] ${room.id} join ${peer.id.slice(0, 8)} (${room.memberIds.length}/${room.cap})`);
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
  // Full rooms are hidden — users can only see rooms they can actually join.
  const list = [...rooms.values()]
    .filter((r) => !r.isFull)
    .sort((a, b) => b.memberIds.length - a.memberIds.length)
    .slice(0, 50)
    .map((r) => r.summary());
  peer.send({ type: 'room_list', rooms: list });
}

// Anyone in the room can "like" a member — visible to the WHOLE room.
function handleRoomLike(peer, msg) {
  if (!peer.roomId) return;
  const room = rooms.get(peer.roomId);
  if (!room) return;
  const target = peers.get(typeof msg.peerId === 'string' ? msg.peerId : '');
  if (!target || target.roomId !== room.id || target.id === peer.id) return;
  room.broadcast({
    type: 'room_like',
    fromId: peer.id, fromName: peer.name,
    targetId: target.id, targetName: target.name,
  });
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

async function handleRoomExtend(peer, msg) {
  if (!peer.roomId) return;
  const room = rooms.get(peer.roomId);
  if (!room) return;
  if (room.expiresAt == null) {
    return peer.send({ type: 'error', code: 'room_no_timer', message: 'Bu odanın süre sayacı henüz başlamadı.' });
  }

  const method = msg.method === 'card' ? 'card' : 'coins';

  if (room.expiresAt - Date.now() + CFG.roomExtMs > CFG.roomMaxAheadMs) {
    return peer.send({ type: 'error', code: 'room_max', message: 'Oda süresi üst sınırda (30 dk).' });
  }

  if (supabase) {
    if (!peer.userId) {
      return peer.send({ type: 'error', code: 'not_authed', message: 'Süre uzatmak için giriş yapmalısın.' });
    }
    const { error } = await supabase.rpc('use_room_extension', {
      p_user_id: peer.userId, p_method: method,
    });
    if (error) {
      const m = error.message || '';
      if (m.includes('no_time_card')) {
        return peer.send({ type: 'error', code: 'no_time_card', message: 'Süre uzatma kartın yok.' });
      }
      if (m.includes('insufficient_coins')) {
        return peer.send({ type: 'error', code: 'insufficient_coins', message: 'Yeterli elmasın yok (20 gerekli).' });
      }
      console.error(`[room-extend] RPC error: ${m}`);
      return peer.send({ type: 'error', code: 'extend_failed', message: 'Süre uzatılamadı.' });
    }
  }

  room.expiresAt += CFG.roomExtMs;
  console.log(`[room] ${room.id} extended +3dk by ${peer.id.slice(0, 8)} (${method})`);
  room.broadcast({ type: 'room_extended', expiresAt: room.expiresAt, byName: peer.name, method });
}

// Sweep expired rooms every 10s (empty system rooms have no ticking timer).
setInterval(() => {
  const now = Date.now();
  let closedAny = false;
  for (const room of [...rooms.values()]) {
    if (room.expiresAt == null || room.expiresAt > now) continue;
    console.log(`[room] ${room.id} expired${room.system ? ' (system)' : ''}`);
    for (const m of room.members()) {
      m.send({ type: 'room_expired' });
      m.roomId = null;
      m.muted = false;
    }
    rooms.delete(room.id);
    closedAny = true;
  }
  if (closedAny) ensureSystemRooms();
}, 10_000);

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

// ── direct friend calls ─────────────────────────────────────────────────────
// Caller connects a socket and sends call_create → we drop a realtime 'call'
// notification to the callee (Supabase) → callee's app opens a socket and
// sends call_join → the two are paired exactly like a match (untimed).
const CALL_TTL_MS = 45_000;
/** @type {Map<string, {callerId: string, mode: string, at: number}>} */
const pendingCalls = new Map();

async function handleCallCreate(peer, msg) {
  if (!supabase || !peer.userId) {
    return peer.send({ type: 'error', code: 'not_authed', message: 'Arama için giriş yapmalısın.' });
  }
  const toUserId = typeof msg.toUserId === 'string' ? msg.toUserId : null;
  const mode = msg.mode === 'voice' ? 'voice' : 'video';
  if (!toUserId) return;

  peer.mode = mode;
  const callId = crypto.randomBytes(6).toString('hex');
  pendingCalls.set(callId, { callerId: peer.id, mode, at: Date.now() });

  try {
    const { error } = await supabase.from('notifications').insert({
      user_id: toUserId,
      kind: 'call',
      title: mode === 'video' ? '📹 Görüntülü arama' : '📞 Sesli arama',
      body: `${peer.name} seni arıyor`,
      related_id: peer.userId,
      payload: { callId, mode, fromName: peer.name, fromId: peer.userId, fromAvatar: peer.avatarUrl },
    });
    if (error) throw new Error(error.message);
  } catch (e) {
    pendingCalls.delete(callId);
    console.error(`[call] ring failed: ${e.message}`);
    return peer.send({ type: 'error', code: 'call_failed', message: 'Arama başlatılamadı.' });
  }

  peer.send({ type: 'call_ringing', callId });
  console.log(`[call] ${peer.id.slice(0, 8)} rings ${toUserId.slice(0, 8)} (${mode})`);
}

function handleCallJoin(peer, msg) {
  const callId = typeof msg.callId === 'string' ? msg.callId : '';
  const pending = pendingCalls.get(callId);
  if (!pending) {
    return peer.send({ type: 'error', code: 'call_gone', message: 'Arama sonlanmış.' });
  }
  const caller = peers.get(pending.callerId);
  if (!caller || caller.status === 'matched') {
    pendingCalls.delete(callId);
    return peer.send({ type: 'error', code: 'call_gone', message: 'Arayan artık müsait değil.' });
  }
  pendingCalls.delete(callId);
  peer.mode = pending.mode;
  caller.mode = pending.mode;
  removeFromQueue(caller.id); removeFromQueue(peer.id);
  leaveRoom(caller); leaveRoom(peer);
  pair(caller, peer, { timed: false }); // friend calls are not time-boxed
}

function handleCallCancel(peer, msg) {
  const callId = typeof msg.callId === 'string' ? msg.callId : '';
  const pending = pendingCalls.get(callId);
  if (pending && pending.callerId === peer.id) pendingCalls.delete(callId);
}

setInterval(() => {
  const now = Date.now();
  for (const [id, c] of pendingCalls) {
    if (now - c.at > CALL_TTL_MS) {
      const caller = peers.get(c.callerId);
      if (caller) caller.send({ type: 'call_timeout' });
      pendingCalls.delete(id);
    }
  }
}, 5_000);

function handleDisconnect(peer) {
  unpair(peer, 'disconnect');
  removeFromQueue(peer.id);
  leaveRoom(peer);
  for (const [id, c] of pendingCalls) {
    if (c.callerId === peer.id) pendingCalls.delete(id);
  }
  peers.delete(peer.id);
  console.log(`[disconnect] ${peer.id.slice(0, 8)} (active=${peers.size}, queue=${queue.length}, rooms=${rooms.size})`);
}

// ---------------------------------------------------------------------- server

// ── admin HTTP API (webadmin paneli kullanır) ───────────────────────────────
// Auth: X-Admin-Key başlığı service role anahtarıyla eşleşmeli.
function readJsonBody(req) {
  return new Promise((resolve) => {
    let buf = '';
    req.on('data', (c) => { buf += c; if (buf.length > 65536) req.destroy(); });
    req.on('end', () => { try { resolve(JSON.parse(buf || '{}')); } catch { resolve({}); } });
  });
}

function sendJson(res, code, obj) {
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(obj));
}

async function handleAdminHttp(req, res) {
  if (!supabaseEnabled || req.headers['x-admin-key'] !== SUPABASE_SERVICE_ROLE_KEY) {
    return sendJson(res, 401, { error: 'unauthorized' });
  }

  if (req.method === 'GET' && req.url === '/admin/state') {
    return sendJson(res, 200, {
      settings: CFG,
      topics: SYSTEM_TOPICS.map(([title, topic]) => ({ title, topic })),
      peers: peers.size,
      queue: queue.length,
      rooms: [...rooms.values()].map((r) => ({
        ...r.summary(),
        members: r.members().map((m) => ({ name: m.name, muted: m.muted })),
        createdAt: r.createdAt,
      })),
    });
  }

  if (req.method === 'POST' && req.url === '/admin/refresh') {
    await refreshSettings();
    return sendJson(res, 200, { ok: true, settings: CFG, topicCount: SYSTEM_TOPICS.length });
  }

  if (req.method === 'POST' && req.url === '/admin/room') {
    const b = await readJsonBody(req);
    const title = (typeof b.title === 'string' ? b.title.trim() : '').slice(0, ROOM_TITLE_MAX);
    if (!title) return sendJson(res, 400, { error: 'title_required' });
    const topic = (typeof b.topic === 'string' ? b.topic.trim() : '').slice(0, 30);
    const cap = Math.min(ROOM_CAP, Math.max(2, parseInt(b.cap, 10) || 4));
    const lifetimeSec = Math.max(0, parseInt(b.lifetimeSec, 10) || 0);
    const room = new Room({
      title, topic, ownerId: null, system: true, manual: true, cap,
      lifetimeMs: lifetimeSec > 0 ? lifetimeSec * 1000 : 0,
    });
    rooms.set(room.id, room);
    console.log(`[room] manual ${room.id} "${title}" (cap=${cap}, ${lifetimeSec || '∞'}s) via admin`);
    return sendJson(res, 200, { ok: true, room: room.summary() });
  }

  if (req.method === 'POST' && req.url === '/admin/room/close') {
    const b = await readJsonBody(req);
    const room = rooms.get(typeof b.id === 'string' ? b.id : '');
    if (!room) return sendJson(res, 404, { error: 'room_not_found' });
    for (const m of room.members()) {
      m.send({ type: 'room_expired' });
      m.roomId = null;
      m.muted = false;
    }
    rooms.delete(room.id);
    console.log(`[room] ${room.id} closed via admin`);
    ensureSystemRooms();
    return sendJson(res, 200, { ok: true });
  }

  return sendJson(res, 404, { error: 'not_found' });
}

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
  if (req.url && req.url.startsWith('/admin/')) {
    handleAdminHttp(req, res).catch(() => sendJson(res, 500, { error: 'internal' }));
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server: httpServer });

wss.on('connection', async (ws, req) => {
  const peer = new Peer(ws);
  peers.set(peer.id, peer);

  // Attach the message listener IMMEDIATELY — async init below (geo, JWT,
  // profile fetch) takes 100ms+; clients send hello/room_list right after the
  // socket opens and those frames would otherwise be emitted with no listener
  // and silently lost. Until init completes we buffer, then replay in order.
  let ready = false;
  /** @type {any[]} */
  const backlog = [];

  const handleMessage = async (raw) => {
    let msg;
    try { msg = JSON.parse(raw.toString()); }
    catch { return peer.send({ type: 'error', message: 'bad_json' }); }

    switch (msg.type) {
      case 'hello':   return await handleHello(peer, msg);
      case 'enqueue':
        if (['video','voice'].includes(msg.mode)) peer.mode = msg.mode;
        if (typeof msg.topic === 'string' && msg.topic.trim()) peer.topic = msg.topic.trim().slice(0, 30);
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
      case 'room_mute':   return handleRoomMute(peer, msg);
      case 'room_extend': return await handleRoomExtend(peer, msg);
      case 'room_like':   return handleRoomLike(peer, msg);
      case 'call_extend': return await handleCallExtend(peer);
      case 'call_create': return await handleCallCreate(peer, msg);
      case 'call_join':   return handleCallJoin(peer, msg);
      case 'call_cancel': return handleCallCancel(peer, msg);
      default:        return peer.send({ type: 'error', message: 'unknown_type' });
    }
  };

  ws.on('message', (raw) => {
    if (!ready) { backlog.push(raw); return; }
    handleMessage(raw);
  });
  ws.on('close', () => handleDisconnect(peer));
  ws.on('error', (err) => console.error(`[ws-error] ${peer.id.slice(0, 8)}:`, err.message));

  // ── async init (geo + JWT + profile) — messages buffered meanwhile ────────
  peer.ip = normalizeIp(getClientIp(req));
  peer.ua = (req.headers['user-agent'] || '').slice(0, 300) || null;
  peer.country = await geoLookup(peer.ip);

  try {
    const url = new URL(req.url, 'http://x');
    const token = url.searchParams.get('token');
    if (token) {
      const v = await verifyToken(token);
      if (v) {
        peer.userId = v.sub;
        await fetchSignalingProfile(peer);
      }
    }
  } catch (_) {/* ignore */}

  console.log(`[connect] ${peer.id.slice(0, 8)} user=${peer.userId?.slice(0,8) || 'guest'} ip=${peer.ip} country=${peer.country || '?'} (active=${peers.size})`);

  peer.send({ type: 'welcome', selfId: peer.id, iceServers: ICE_SERVERS });

  ready = true;
  for (const raw of backlog.splice(0)) {
    await handleMessage(raw);
  }
});

setInterval(() => {
  if (peers.size > 0 || queue.length > 0 || rooms.size > 0) {
    console.log(`[stats] peers=${peers.size} queue=${queue.length} rooms=${rooms.size}`);
  }
}, 60_000);

// ── FCM push bridge (optional) ──────────────────────────────────────────────
// Set FIREBASE_SERVICE_ACCOUNT_JSON (the raw service-account JSON) to enable.
// Listens to new notification rows and pushes them to the user's device.
let fcmSA = null;
try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    fcmSA = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  }
} catch (e) {
  console.warn(`[fcm] bad FIREBASE_SERVICE_ACCOUNT_JSON: ${e.message}`);
}

let fcmToken = null;
let fcmTokenExp = 0;
async function fcmAccessToken() {
  if (fcmToken && Date.now() < fcmTokenExp - 60_000) return fcmToken;
  const now = Math.floor(Date.now() / 1000);
  const assertion = jwt.sign({
    iss: fcmSA.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now, exp: now + 3600,
  }, fcmSA.private_key, { algorithm: 'RS256' });
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${assertion}`,
  });
  const j = await res.json();
  if (!j.access_token) throw new Error('fcm token exchange failed');
  fcmToken = j.access_token;
  fcmTokenExp = Date.now() + (j.expires_in || 3600) * 1000;
  return fcmToken;
}

async function sendFcmPush(deviceToken, title, body, data) {
  const access = await fcmAccessToken();
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${fcmSA.project_id}/messages:send`, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${access}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message: {
        token: deviceToken,
        notification: { title, body: body || '' },
        data: Object.fromEntries(Object.entries(data || {}).map(([k, v]) => [k, String(v ?? '')])),
      },
    }),
  });
  if (!res.ok) console.warn(`[fcm] send ${res.status}: ${(await res.text()).slice(0, 200)}`);
}

if (supabase && fcmSA) {
  supabase
    .channel('fcm-bridge')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications' }, async (payload) => {
      try {
        const n = payload.new;
        if (!n || !n.user_id) return;
        const { data } = await supabase.from('profiles').select('fcm_token').eq('id', n.user_id).maybeSingle();
        const token = data?.fcm_token;
        if (!token) return;
        await sendFcmPush(token, n.title, n.body, { kind: n.kind, ...(n.payload || {}) });
      } catch (e) {
        console.warn(`[fcm] bridge error: ${e.message}`);
      }
    })
    .subscribe();
  console.log('[fcm] push bridge active');
} else {
  console.log('[fcm] disabled (set FIREBASE_SERVICE_ACCOUNT_JSON to enable)');
}

refreshSettings().finally(() => {
  ensureSystemRooms();
});
setInterval(refreshSettings, 60_000);
setInterval(ensureSystemRooms, 30_000);

httpServer.listen(PORT, HOST, () => {
  console.log(`kerochat signaling on ${HOST}:${PORT} (auth=${supabaseEnabled ? 'on' : 'off'})`);
});
