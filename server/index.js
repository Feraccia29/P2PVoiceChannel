const { Server } = require('socket.io');
const crypto = require('crypto');
const port = 16429;
const TURN_SECRET = process.env.TURN_AUTH_SECRET || 'default-secret';

function generateTurnCredentials() {
  const unixTimestamp = Math.floor(Date.now() / 1000) + 86400; // scade tra 24h
  const username = `${unixTimestamp}:voipuser`;
  const hmac = crypto.createHmac('sha1', TURN_SECRET);
  hmac.update(username);
  const credential = hmac.digest('base64');
  return { username, credential };
}

function buildRoomList() {
  const roomList = [];
  rooms.forEach((peers, roomId) => {
    const peerList = [];
    peers.forEach((peerInfo, peerId) => {
      peerList.push({ peerId, username: peerInfo.username, isMuted: peerInfo.isMuted });
    });
    roomList.push({
      roomId,
      peerCount: peers.size,
      peers: peerList,
    });
  });
  return roomList;
}

const io = new Server(port, {
  cors: {
    origin: '*',
  },
  allowEIO3: true,
});

const rooms = new Map(); // Map<roomId, Map<peerId, {username, isMuted}>>
const socketToPeer = new Map();

io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id}`);

  socket.on('join-room', ({ roomId, peerId, username }) => {
    const peerUsername = username || 'Anonymous';
    socket.join(roomId);
    socket.join(peerId); // Join a room with peerId for direct messaging
    socketToPeer.set(socket.id, { roomId, peerId, username: peerUsername });

    // Invia credenziali TURN temporanee al client
    const turnCreds = generateTurnCredentials();
    socket.emit('turn-credentials', turnCreds);
    console.log(`TURN credentials sent to ${peerUsername} (${peerId}) (expires in 24h)`);

    if (!rooms.has(roomId)) {
      rooms.set(roomId, new Map());
    }

    const room = rooms.get(roomId);

    // Send existing room members info to the new peer
    const existingPeers = [];
    room.forEach((peerInfo, existingPeerId) => {
      if (existingPeerId !== peerId) {
        existingPeers.push({ peerId: existingPeerId, username: peerInfo.username, isMuted: peerInfo.isMuted });
      }
    });
    if (existingPeers.length > 0) {
      socket.emit('room-peers', existingPeers);
    }

    // Notify existing peers about the new peer
    room.forEach((peerInfo, existingPeerId) => {
      if (existingPeerId !== peerId) {
        io.to(existingPeerId).emit('peer-joined', { peerId, username: peerUsername });
      }
    });

    room.set(peerId, { username: peerUsername, isMuted: false });
    console.log(`${peerUsername} (${peerId}) joined room ${roomId} (${room.size} peers)`);

    // Broadcast updated room list to all connected clients
    io.emit('room-list-update', buildRoomList());
  });

  socket.on('list-rooms', () => {
    socket.emit('room-list', buildRoomList());
  });

  socket.on('leave-room', () => {
    const peerInfo = socketToPeer.get(socket.id);
    if (!peerInfo) return;

    const { roomId, peerId, username } = peerInfo;
    const room = rooms.get(roomId);

    if (room) {
      room.delete(peerId);

      // Notify remaining peers in the room
      room.forEach((_, remainingPeerId) => {
        io.to(remainingPeerId).emit('peer-left', { peerId });
      });

      console.log(`${username} (${peerId}) left room ${roomId} (${room.size} peers remaining)`);

      if (room.size === 0) {
        rooms.delete(roomId);
      }
    }

    // Leave Socket.io rooms but keep socket connected
    socket.leave(roomId);
    socket.leave(peerId);
    socketToPeer.delete(socket.id);

    // Broadcast updated room list to all connected clients
    io.emit('room-list-update', buildRoomList());
  });

  socket.on('offer', ({ to, from, offer }) => {
    const senderInfo = socketToPeer.get(socket.id);
    const senderUsername = senderInfo?.username || 'Anonymous';
    console.log(`Offer from ${senderUsername} (${from}) to ${to}`);
    io.to(to).emit('offer', { from, offer, username: senderUsername });
  });

  socket.on('answer', ({ to, from, answer }) => {
    const senderInfo = socketToPeer.get(socket.id);
    const senderUsername = senderInfo?.username || 'Anonymous';
    console.log(`Answer from ${senderUsername} (${from}) to ${to}`);
    io.to(to).emit('answer', { from, answer, username: senderUsername });
  });

  socket.on('ice-candidate', ({ to, from, candidate }) => {
    io.to(to).emit('ice-candidate', { from, candidate });
  });

  socket.on('mute-status', ({ isMuted }) => {
    const peerInfo = socketToPeer.get(socket.id);
    if (!peerInfo) return;

    const { roomId, peerId, username } = peerInfo;
    const room = rooms.get(roomId);
    if (!room) return;

    const existingInfo = room.get(peerId);
    if (existingInfo) {
      existingInfo.isMuted = isMuted;
    }

    room.forEach((_, otherPeerId) => {
      if (otherPeerId !== peerId) {
        io.to(otherPeerId).emit('peer-mute-status', { peerId, isMuted });
      }
    });

    console.log(`${username} (${peerId}) mute status: ${isMuted}`);
  });

  socket.on('disconnect', () => {
    const peerInfo = socketToPeer.get(socket.id);

    if (peerInfo) {
      const { roomId, peerId, username } = peerInfo;
      const room = rooms.get(roomId);

      if (room) {
        room.delete(peerId);

        // Notify remaining peers
        room.forEach((_, remainingPeerId) => {
          io.to(remainingPeerId).emit('peer-left', { peerId });
        });

        console.log(`${username} (${peerId}) left room ${roomId} (${room.size} peers remaining)`);

        if (room.size === 0) {
          rooms.delete(roomId);
        }
      }

      socketToPeer.delete(socket.id);
    }

    console.log(`Client disconnected: ${socket.id}`);

    // Broadcast updated room list to all connected clients
    io.emit('room-list-update', buildRoomList());
  });
});

console.log(`Signaling server listening on port ${port}`);
