const { Server } = require('socket.io');

const io = new Server(3000, {
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

console.log('Signaling server listening on port 3000');
