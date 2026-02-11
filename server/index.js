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

const io = new Server(port, {
  cors: {
    origin: '*',
  },
  allowEIO3: true,
});

const rooms = new Map();
const socketToPeer = new Map();

io.on('connection', (socket) => {
  console.log(`Client connected: ${socket.id}`);

  socket.on('join-room', ({ roomId, peerId }) => {
    socket.join(roomId);
    socket.join(peerId); // Join a room with peerId for direct messaging
    socketToPeer.set(socket.id, { roomId, peerId });

    // Invia credenziali TURN temporanee al client
    const turnCreds = generateTurnCredentials();
    socket.emit('turn-credentials', turnCreds);
    console.log(`TURN credentials sent to ${peerId} (expires in 24h)`);

    if (!rooms.has(roomId)) {
      rooms.set(roomId, new Set());
    }

    const room = rooms.get(roomId);

    // Notify existing peers about the new peer
    room.forEach((existingPeerId) => {
      if (existingPeerId !== peerId) {
        io.to(existingPeerId).emit('peer-joined', { peerId });
      }
    });

    room.add(peerId);
    console.log(`${peerId} joined room ${roomId} (${room.size} peers)`);
  });

  socket.on('offer', ({ to, from, offer }) => {
    console.log(`Offer from ${from} to ${to}`);
    io.to(to).emit('offer', { from, offer });
  });

  socket.on('answer', ({ to, from, answer }) => {
    console.log(`Answer from ${from} to ${to}`);
    io.to(to).emit('answer', { from, answer });
  });

  socket.on('ice-candidate', ({ to, from, candidate }) => {
    io.to(to).emit('ice-candidate', { from, candidate });
  });

  socket.on('disconnect', () => {
    const peerInfo = socketToPeer.get(socket.id);

    if (peerInfo) {
      const { roomId, peerId } = peerInfo;
      const room = rooms.get(roomId);

      if (room) {
        room.delete(peerId);

        // Notify remaining peers
        room.forEach((remainingPeerId) => {
          io.to(remainingPeerId).emit('peer-left', { peerId });
        });

        console.log(`${peerId} left room ${roomId} (${room.size} peers remaining)`);

        if (room.size === 0) {
          rooms.delete(roomId);
        }
      }

      socketToPeer.delete(socket.id);
    }

    console.log(`Client disconnected: ${socket.id}`);
  });
});

console.log(`Signaling server listening on port ${port}`);
