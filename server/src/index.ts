import http from 'http';
import express from 'express';
import cors from 'cors';
import { WebSocketServer, WebSocket } from 'ws';
import { Server } from 'colyseus';
import { WebSocketTransport } from '@colyseus/ws-transport';
import { ArenaRoom } from './rooms/ArenaRoom';
import { ArenaEngine, ClientConnection } from './rooms/ArenaEngine';
import { MAPS } from './shared/MapConfigs';
import { BLADE_CATALOG } from './shared/BladeCatalog';

const port = Number(process.env.PORT || 2567);
const app = express();

app.use(cors());
app.use(express.json());

// HTTP Endpoints for metadata & healthchecks
app.get('/', (_req, res) => {
  res.json({
    status: 'online',
    game: 'OrbitBlade.io Real-Time Authoritative Server',
    version: '1.0.0',
    rooms: ['arena'],
  });
});

app.get('/health', (_req, res) => {
  res.status(200).send('OK');
});

app.get('/api/maps', (_req, res) => {
  res.json(Object.values(MAPS));
});

app.get('/api/blades', (_req, res) => {
  res.json(BLADE_CATALOG);
});

const server = http.createServer(app);

// 1. Authoritative Game Engine Instance
export const globalArenaEngine = new ArenaEngine('temple');

// 2. Direct WebSocket Server on /arena
const wss = new WebSocketServer({ noServer: true });

wss.on('connection', (ws: WebSocket) => {
  const sessionId = 'cli_' + Math.random().toString(36).substring(2, 9);

  const clientConn: ClientConnection = {
    sessionId,
    send: (type: string, data: any) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type, data }));
      }
    },
    sendRaw: (payload: string) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(payload);
      }
    },
    isOpen: () => ws.readyState === WebSocket.OPEN,
  };

  globalArenaEngine.registerClient(clientConn);

  ws.on('message', (raw) => {
    try {
      const parsed = JSON.parse(raw.toString());
      if (parsed?.type) {
        globalArenaEngine.handleMessage(sessionId, parsed.type, parsed.data);
      }
    } catch (_) {}
  });

  ws.on('close', () => {
    globalArenaEngine.removeClient(sessionId);
  });

  ws.on('error', () => {
    globalArenaEngine.removeClient(sessionId);
  });
});

// 3. Colyseus Game Server Setup with noServer transport
const transport = new WebSocketTransport({
  noServer: true,
  pingInterval: 5000,
  pingMaxRetries: 3,
});

const gameServer = new Server({
  transport,
});

gameServer.define('arena', ArenaRoom as any).enableRealtimeListing();

// Single upgrade dispatcher to prevent double handleUpgrade
server.on('upgrade', (request, socket, head) => {
  const url = request.url || '';
  if (url.startsWith('/arena')) {
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit('connection', ws, request);
    });
  } else {
    try {
      const colyseusWss = (transport as any).wss;
      if (colyseusWss) {
        colyseusWss.handleUpgrade(request, socket, head, (ws: any) => {
          colyseusWss.emit('connection', ws, request);
        });
      }
    } catch (_) {}
  }
});

server.listen(port, () => {
  console.log(`⚔️ [OrbitBlade.io Server] Listening on http://localhost:${port}`);
  console.log(`📡 WebSocket direct endpoint available at ws://localhost:${port}/arena`);
  console.log(`🗺️ Loaded maps: ${Object.keys(MAPS).join(', ')}`);
  console.log(`🗡️ Loaded blades: ${BLADE_CATALOG.map((b) => b.name).join(', ')}`);
});
