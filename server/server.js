/**
 * azar_chat — signaling + matchmaking server
 *
 * Protocol (client -> server):
 *   { type: 'hello',   name?, gender?, peerGender? }
 *   { type: 'enqueue' }
 *   { type: 'signal',  to, payload }
 *   { type: 'next' }            // leave current pair, re-enqueue
 *   { type: 'leave' }           // leave current pair, idle
 *
 * Protocol (server -> client):
 *   { type: 'welcome',   selfId, iceServers }
 *   { type: 'searching' }
 *   { type: 'matched',   peerId, peerInfo, polite }
 *   { type: 'signal',    from, payload }
 *   { type: 'peer_left', reason }   // 'next' | 'disconnect' | 'leave'
 *   { type: 'error',     message }
 */

const http = require('http');
const crypto = require('crypto');
const { WebSocketServer, WebSocket } = require('ws');

const PORT = parseInt(process.env.PORT || '9090', 10);
const HOST = process.env.HOST || '0.0.0.0';

// Free public TURN — OpenRelay (Metered). MVP only. Replace with own creds for production.
const ICE_SERVERS = [
  { urls: 'stun:stun.l.google.com:19302' },
  { urls: 'stun:stun.relay.metered.ca:80' },
  {
    urls: 'turn:openrelay.metered.ca:80',
    username: 'openrelayproject',
    credential: 'openrelayproject',
  },
  {
    urls: 'turn:openrelay.metered.ca:443',
    username: 'openrelayproject',
    credential: 'openrelayproject',
  },
  {
    urls: 'turn:openrelay.metered.ca:443?transport=tcp',
    username: 'openrelayproject',
    credential: 'openrelayproject',
  },
];

/** @type {Map<string, Peer>} */
const peers = new Map();
/** FIFO queue of peer ids waiting for match */
const queue = [];

class Peer {
  constructor(ws) {
    this.id = crypto.randomUUID();
    this.ws = ws;
    this.name = 'Misafir';
    this.gender = 'X';      // 'M' | 'F' | 'X'
    this.peerGender = 'any'; // 'M' | 'F' | 'any'
    /** @type {'idle' | 'queued' | 'matched'} */
    this.status = 'idle';
    this.matchId = null;
  }

  send(msg) {
    if (this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(msg));
    }
  }

  publicInfo() {
    return { id: this.id, name: this.name, gender: this.gender };
  }
}

function compatible(a, b) {
  if (a.id === b.id) return false;
  if (a.peerGender !== 'any' && b.gender !== a.peerGender) return false;
  if (b.peerGender !== 'any' && a.gender !== b.peerGender) return false;
  return true;
}

function enqueue(peer) {
  if (peer.status === 'matched') return;
  // remove duplicates
  const ix = queue.indexOf(peer.id);
  if (ix >= 0) queue.splice(ix, 1);

  // try to find a compatible waiter
  for (let i = 0; i < queue.length; i++) {
    const other = peers.get(queue[i]);
    if (!other || other.status !== 'queued') {
      queue.splice(i, 1);
      i--;
      continue;
    }
    if (compatible(peer, other)) {
      queue.splice(i, 1);
      pair(peer, other);
      return;
    }
  }

  // no match yet — wait
  peer.status = 'queued';
  queue.push(peer.id);
  peer.send({ type: 'searching' });
}

function pair(a, b) {
  a.status = 'matched';
  b.status = 'matched';
  a.matchId = b.id;
  b.matchId = a.id;

  // polite/impolite: the one with the larger id is polite (perfect negotiation)
  const aPolite = a.id > b.id;
  a.send({ type: 'matched', peerId: b.id, peerInfo: b.publicInfo(), polite: aPolite });
  b.send({ type: 'matched', peerId: a.id, peerInfo: a.publicInfo(), polite: !aPolite });
  console.log(`[match] ${a.id.slice(0, 8)} <-> ${b.id.slice(0, 8)}`);
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
  return partner;
}

function removeFromQueue(peerId) {
  const ix = queue.indexOf(peerId);
  if (ix >= 0) queue.splice(ix, 1);
}

function handleHello(peer, msg) {
  if (typeof msg.name === 'string')        peer.name = msg.name.slice(0, 40) || 'Misafir';
  if (['M', 'F', 'X'].includes(msg.gender))             peer.gender = msg.gender;
  if (['M', 'F', 'any'].includes(msg.peerGender))       peer.peerGender = msg.peerGender;
}

function handleSignal(peer, msg) {
  if (peer.status !== 'matched' || peer.matchId !== msg.to) return;
  const target = peers.get(msg.to);
  if (!target) return;
  target.send({ type: 'signal', from: peer.id, payload: msg.payload });
}

function handleNext(peer) {
  unpair(peer, 'next');
  removeFromQueue(peer.id);
  enqueue(peer);
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

const httpServer = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, peers: peers.size, queue: queue.length }));
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocketServer({ server: httpServer });

wss.on('connection', (ws, req) => {
  const peer = new Peer(ws);
  peers.set(peer.id, peer);
  console.log(`[connect] ${peer.id.slice(0, 8)} from ${req.socket.remoteAddress} (active=${peers.size})`);

  peer.send({ type: 'welcome', selfId: peer.id, iceServers: ICE_SERVERS });

  ws.on('message', (raw) => {
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
  console.log(`azar_chat signaling server listening on ${HOST}:${PORT}`);
});
