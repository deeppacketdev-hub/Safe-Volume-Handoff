const http = require('http');
const { WebSocketServer, WebSocket } = require('ws');

const PORT = process.env.PORT || 80;

// Device state store per room: Map<roomId, Map<deviceId, { ws, info }>>
const rooms = new Map();

function getRoom(roomId = 'default') {
  if (!rooms.has(roomId)) {
    rooms.set(roomId, new Map());
  }
  return rooms.get(roomId);
}

function broadcastToRoom(roomId, message, excludeWs = null) {
  const room = rooms.get(roomId);
  if (!room) return;
  const payload = typeof message === 'string' ? message : JSON.stringify(message);

  for (const [_, client] of room.entries()) {
    if (client.ws !== excludeWs && client.ws.readyState === WebSocket.OPEN) {
      try {
        client.ws.send(payload);
      } catch (err) {
        console.error(`[Broadcast Error] Failed to send to ${client.info?.deviceId}:`, err.message);
      }
    }
  }
}

// 1. HTTP Server for Healthchecks & Status
const server = http.createServer((req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.url === '/health' || req.url === '/api/health') {
    let totalDevices = 0;
    rooms.forEach(room => totalDevices += room.size);

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      service: 'Castlie Connect Relay',
      uptimeSeconds: Math.floor(process.uptime()),
      activeRooms: rooms.size,
      connectedDevices: totalDevices,
      timestamp: new Date().toISOString()
    }));
    return;
  }

  if (req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      name: 'Castlie Connect Server',
      domain: 'castlie.dron.lol',
      status: 'online',
      protocol: 'WebSocket (WSS)',
      path: '/ws'
    }));
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not Found');
});

// 2. WebSocket Server
const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (ws, req) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const roomId = url.searchParams.get('roomId') || 'default';
  
  let currentDeviceId = null;
  let currentRole = 'sender'; // 'receiver' (Mac) or 'sender' (iPhone)
  let currentRoomId = roomId;

  ws.isAlive = true;
  ws.on('pong', () => {
    ws.isAlive = true;
  });

  console.log(`[Connect] New client connected to room: ${roomId}`);

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data.toString());
      handleMessage(ws, msg);
    } catch (err) {
      console.error('[WS Parse Error] Invalid JSON:', err.message);
    }
  });

  function handleMessage(clientWs, msg) {
    const type = msg.type;

    switch (type) {
      // 1. Device Registration (Mac or iPhone)
      case 'register': {
        currentDeviceId = msg.deviceId || `device_${Date.now()}`;
        currentRole = msg.role || 'sender';
        currentRoomId = msg.roomId || roomId;

        const room = getRoom(currentRoomId);

        const deviceInfo = {
          deviceId: currentDeviceId,
          name: msg.name || (currentRole === 'receiver' ? 'MacBook Pro' : 'iPhone'),
          role: currentRole,
          volume: typeof msg.volume === 'number' ? msg.volume : 0.5,
          isPlaying: !!msg.isPlaying,
          currentTrack: msg.currentTrack || null,
          connectedUser: msg.connectedUser || null,
          lastSeen: Date.now()
        };

        room.set(currentDeviceId, { ws: clientWs, info: deviceInfo });

        console.log(`[Register] ${currentRole.toUpperCase()}: "${deviceInfo.name}" (ID: ${currentDeviceId}) in room: ${currentRoomId}`);

        // Acknowledge registration to sender
        clientWs.send(JSON.stringify({
          type: 'registered',
          deviceId: currentDeviceId,
          roomId: currentRoomId
        }));

        // Send full list of active receivers to this client
        sendDevicesList(clientWs, currentRoomId);

        // Notify other clients about this new/updated device
        broadcastToRoom(currentRoomId, {
          type: 'device_joined',
          device: deviceInfo
        }, clientWs);
        break;
      }

      // 2. Request devices list
      case 'get_devices': {
        sendDevicesList(clientWs, currentRoomId);
        break;
      }

      // 3. Live Volume Update (from Mac CoreAudio or iPhone slider)
      case 'volume_update': {
        const targetDeviceId = msg.targetDeviceId || currentDeviceId;
        const volume = Math.max(0, Math.min(1, Number(msg.volume)));

        const room = getRoom(currentRoomId);
        const deviceEntry = room.get(targetDeviceId);
        if (deviceEntry) {
          deviceEntry.info.volume = volume;
        }

        console.log(`[Volume] Device ${targetDeviceId} volume set to ${Math.round(volume * 100)}%`);

        // Broadcast to all clients in room
        broadcastToRoom(currentRoomId, {
          type: 'volume_changed',
          deviceId: targetDeviceId,
          volume: volume
        });
        break;
      }

      // 4. Safe Handoff Command (iPhone -> Mac)
      case 'handoff': {
        const targetDeviceId = msg.targetDeviceId;
        const room = getRoom(currentRoomId);
        const target = room.get(targetDeviceId);

        console.log(`[Handoff] Initiating handoff to: ${targetDeviceId} (Track: "${msg.track?.name}", TargetVol: ${msg.targetVolume}, FadeIn: ${msg.fadeInDuration}s)`);

        if (target && target.ws.readyState === WebSocket.OPEN) {
          target.ws.send(JSON.stringify({
            type: 'perform_handoff',
            senderDeviceId: currentDeviceId,
            senderName: msg.senderName || 'iPhone',
            track: msg.track,
            targetVolume: msg.targetVolume,
            fadeInDuration: msg.fadeInDuration || 2.0
          }));

          // Notify sender of dispatch
          clientWs.send(JSON.stringify({
            type: 'handoff_dispatched',
            targetDeviceId: targetDeviceId,
            status: 'sent'
          }));
        } else {
          clientWs.send(JSON.stringify({
            type: 'handoff_error',
            targetDeviceId: targetDeviceId,
            error: 'Target device offline or not found'
          }));
        }
        break;
      }

      // 5. Playback Controls (play/pause/seek)
      case 'playback_command': {
        const targetDeviceId = msg.targetDeviceId;
        const room = getRoom(currentRoomId);
        const target = room.get(targetDeviceId);

        if (target && target.ws.readyState === WebSocket.OPEN) {
          target.ws.send(JSON.stringify({
            type: 'remote_playback_command',
            action: msg.action,
            value: msg.value
          }));
        }
        break;
      }

      // 6. Playback State Broadcast (Mac -> iPhone)
      case 'playback_state': {
        const room = getRoom(currentRoomId);
        const deviceEntry = room.get(currentDeviceId);
        if (deviceEntry) {
          deviceEntry.info.isPlaying = !!msg.isPlaying;
          deviceEntry.info.currentTrack = msg.currentTrack || deviceEntry.info.currentTrack;
          deviceEntry.info.connectedUser = msg.connectedUser || deviceEntry.info.connectedUser;
        }

        broadcastToRoom(currentRoomId, {
          type: 'playback_state_updated',
          deviceId: currentDeviceId,
          isPlaying: !!msg.isPlaying,
          currentTrack: msg.currentTrack,
          connectedUser: msg.connectedUser,
          currentTime: msg.currentTime,
          duration: msg.duration
        }, clientWs);
        break;
      }

      // 7. Ping / Heartbeat
      case 'ping': {
        clientWs.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
        break;
      }

      default:
        console.log(`[WS] Unknown message type: ${type}`);
    }
  }

  function sendDevicesList(clientWs, rId) {
    const room = getRoom(rId);
    const devices = [];
    for (const [_, client] of room.entries()) {
      devices.push(client.info);
    }
    clientWs.send(JSON.stringify({
      type: 'devices_list',
      devices: devices
    }));
  }

  // Handle client disconnect
  ws.on('close', () => {
    console.log(`[Disconnect] Client disconnected: ${currentDeviceId || 'unregistered'}`);
    if (currentDeviceId && currentRoomId) {
      const room = rooms.get(currentRoomId);
      if (room) {
        room.delete(currentDeviceId);
        broadcastToRoom(currentRoomId, {
          type: 'device_left',
          deviceId: currentDeviceId
        });
      }
    }
  });

  ws.on('error', (err) => {
    console.error(`[WS Client Error] ${currentDeviceId}:`, err.message);
  });
});

// Periodic ping/pong to clean up dead sockets (every 25 seconds)
const heartbeatInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) {
      return ws.terminate();
    }
    ws.isAlive = false;
    ws.ping();
  });
}, 25000);

wss.on('close', () => {
  clearInterval(heartbeatInterval);
});

// Start Server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`===============================================`);
  console.log(`  Castlie Connect Relay Server Running        `);
  console.log(`  Domain: castlie.dron.lol                    `);
  console.log(`  Port: ${PORT}                               `);
  console.log(`  WebSocket Path: /ws                         `);
  console.log(`  Healthcheck: http://0.0.0.0:${PORT}/health  `);
  console.log(`===============================================`);
});
