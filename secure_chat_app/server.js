/**
 * Serves the Flutter web app and a message relay API.
 * Messages are stored by roomId (opaque); only encrypted payloads are stored.
 * Run: node server.js
 * Then use ngrok: ngrok http 8080
 */
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const WEB_DIR = path.join(__dirname, 'build', 'web');

// roomId -> [{ encrypted, isMe, at, ratchetIndex, senderAlias, signature, expiresAt }, ...]
const messagesByRoom = new Map();
// roomId -> [{ alias, publicKey }, ...] (participants with Ed25519 public keys)
const participantsByRoom = new Map();

const MIME = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.ico': 'image/x-icon',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
};

function serveFile(filePath, res) {
  const ext = path.extname(filePath);
  const mime = MIME[ext] || 'application/octet-stream';
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end();
      return;
    }
    res.writeHead(200, { 'Content-Type': mime });
    res.end(data);
  });
}

function parseBody(req) {
  return new Promise((resolve) => {
    let body = '';
    req.on('data', (chunk) => { body += chunk; });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch {
        resolve({});
      }
    });
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || '/', `http://localhost:${PORT}`);
  const pathname = url.pathname;

  // API: POST /api/messages
  if (req.method === 'POST' && pathname === '/api/messages') {
    const body = await parseBody(req);
    const { roomId, encrypted, isMe, at, ratchetIndex, senderAlias, signature, expiresIn } = body;
    if (!roomId || encrypted == null) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'roomId and encrypted required' }));
      return;
    }
    const expiresAt = typeof expiresIn === 'number' && expiresIn > 0
      ? Date.now() + expiresIn * 1000
      : null;
    if (!messagesByRoom.has(roomId)) messagesByRoom.set(roomId, []);
    messagesByRoom.get(roomId).push({
      encrypted: String(encrypted),
      isMe: Boolean(isMe),
      at: at || new Date().toISOString(),
      ratchetIndex: ratchetIndex != null ? Number(ratchetIndex) : 0,
      senderAlias: senderAlias != null ? String(senderAlias) : '',
      signature: signature != null ? String(signature) : '',
      expiresAt,
    });
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true }));
    return;
  }

  // API: GET /api/messages?roomId=xxx (excludes expired)
  if (req.method === 'GET' && pathname === '/api/messages') {
    const roomId = url.searchParams.get('roomId');
    if (!roomId) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'roomId required' }));
      return;
    }
    const list = messagesByRoom.get(roomId) || [];
    const now = Date.now();
    const filtered = list.filter((m) => m.expiresAt == null || m.expiresAt > now);
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(JSON.stringify(filtered));
    return;
  }

  // API: POST /api/participants { roomId, alias, publicKey }
  if (req.method === 'POST' && pathname === '/api/participants') {
    const body = await parseBody(req);
    const { roomId, alias, publicKey } = body;
    if (!roomId || !alias || typeof alias !== 'string') {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'roomId and alias required' }));
      return;
    }
    if (!participantsByRoom.has(roomId)) participantsByRoom.set(roomId, []);
    const list = participantsByRoom.get(roomId);
    const a = String(alias).trim();
    const existing = list.find((p) => p.alias === a);
    if (existing) {
      existing.publicKey = publicKey != null ? String(publicKey) : existing.publicKey;
    } else if (a) {
      list.push({ alias: a, publicKey: publicKey != null ? String(publicKey) : '' });
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true }));
    return;
  }

  // API: GET /api/participants?roomId=xxx -> [{ alias, publicKey }, ...]
  if (req.method === 'GET' && pathname === '/api/participants') {
    const roomId = url.searchParams.get('roomId');
    if (!roomId) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'roomId required' }));
      return;
    }
    let list = participantsByRoom.get(roomId) || [];
    if (Array.isArray(list) && list.length > 0 && typeof list[0] === 'string') {
      list = list.map((alias) => ({ alias, publicKey: '' }));
    }
    res.writeHead(200, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    });
    res.end(JSON.stringify(list));
    return;
  }

  // API: POST /api/wipe { roomIds: [...] } - delete all messages and participants for those rooms
  if (req.method === 'POST' && pathname === '/api/wipe') {
    const body = await parseBody(req);
    const roomIds = Array.isArray(body.roomIds) ? body.roomIds : [];
    for (const rid of roomIds) {
      messagesByRoom.delete(rid);
      participantsByRoom.delete(rid);
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true }));
    return;
  }

  // Static files
  let filePath = path.join(WEB_DIR, pathname === '/' ? 'index.html' : pathname);
  if (!filePath.startsWith(WEB_DIR)) {
    res.writeHead(403);
    res.end();
    return;
  }
  if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
    serveFile(filePath, res);
    return;
  }
  // SPA fallback
  serveFile(path.join(WEB_DIR, 'index.html'), res);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running at http://localhost:${PORT}`);
  console.log(`API: POST/GET /api/messages (roomId, encrypted payloads only)`);
});
