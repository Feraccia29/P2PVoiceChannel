import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/constants.dart';

class SignalingService {
  IO.Socket? _socket;
  String? _peerId;
  String? _username;
  String? _currentRoomId;

  bool get isConnected => _socket?.connected ?? false;
  String? get currentRoomId => _currentRoomId;

  // Callbacks - call signaling
  Function(Map<String, dynamic>)? onOfferReceived;
  Function(Map<String, dynamic>)? onAnswerReceived;
  Function(Map<String, dynamic>)? onIceCandidateReceived;
  Function(String peerId, String username)? onPeerJoined;
  Function(String)? onPeerLeft;
  Function()? onConnected;
  Function(String username, String credential)? onTurnCredentials;
  Function(List<Map<String, dynamic>>)? onRoomPeers;
  Function(String peerId, bool isMuted)? onPeerMuteStatusChanged;

  // Callbacks - lobby
  Function(List<Map<String, dynamic>>)? onRoomListReceived;
  Function(List<Map<String, dynamic>>)? onRoomListUpdate;

  void connect(String peerId, {required String username}) {
    _peerId = peerId;
    _username = username;

    _socket = IO.io(
      AppConstants.signalingServerUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );

    _socket!.connect();

    _socket!.on('connect', (_) {
      print('Connected to signaling server');
      onConnected?.call();
      // Re-join room if we were in one before reconnect
      if (_currentRoomId != null) {
        joinRoom(_currentRoomId!);
      }
    });

    _socket!.on('turn-credentials', (data) {
      final username = data['username'] as String;
      final credential = data['credential'] as String;
      print('Received TURN credentials (username: $username)');
      onTurnCredentials?.call(username, credential);
    });

    _socket!.on('room-peers', (data) {
      if (data is List) {
        final peers = data
            .map((p) => Map<String, dynamic>.from(p as Map))
            .toList();
        print('Received room-peers: ${peers.length} existing peers');
        onRoomPeers?.call(peers);
      }
    });

    _socket!.on('peer-joined', (data) {
      final remotePeerId = data['peerId'] as String;
      final peerUsername = data['username'] as String? ?? 'Anonymous';
      print('Peer joined: $remotePeerId ($peerUsername)');
      onPeerJoined?.call(remotePeerId, peerUsername);
    });

    _socket!.on('peer-left', (data) {
      final remotePeerId = data['peerId'] as String;
      print('Peer left: $remotePeerId');
      onPeerLeft?.call(remotePeerId);
    });

    _socket!.on('offer', (data) {
      print('Received offer from ${data['from']}');
      onOfferReceived?.call(data);
    });

    _socket!.on('answer', (data) {
      print('Received answer from ${data['from']}');
      onAnswerReceived?.call(data);
    });

    _socket!.on('ice-candidate', (data) {
      print('Received ICE candidate from ${data['from']}');
      onIceCandidateReceived?.call(data);
    });

    _socket!.on('peer-mute-status', (data) {
      final peerId = data['peerId'] as String;
      final isMuted = data['isMuted'] as bool;
      print('Peer mute status changed: $peerId -> $isMuted');
      onPeerMuteStatusChanged?.call(peerId, isMuted);
    });

    _socket!.on('room-list', (data) {
      if (data is List) {
        final rooms = data
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        print('Received room-list: ${rooms.length} rooms');
        onRoomListReceived?.call(rooms);
      }
    });

    _socket!.on('room-list-update', (data) {
      if (data is List) {
        final rooms = data
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        onRoomListUpdate?.call(rooms);
      }
    });

    _socket!.on('reconnect', (_) {
      print('Socket.io reconnected');
      onConnected?.call();
      if (_currentRoomId != null) {
        joinRoom(_currentRoomId!);
      }
    });

    _socket!.on('disconnect', (_) {
      print('Disconnected from signaling server');
    });

    _socket!.on('connect_error', (error) {
      print('Connection error: $error');
    });
  }

  /// Verifica che il socket sia connesso, altrimenti riconnette.
  /// Chiamato al resume dell'app dopo essere stata in background.
  void ensureConnected(String peerId, {required String username}) {
    if (_socket == null || _socket!.disconnected) {
      print('Socket disconnected during background, reconnecting...');
      connect(peerId, username: username);
    }
  }

  void joinRoom(String roomId) {
    _currentRoomId = roomId;
    _socket?.emit('join-room', {
      'roomId': roomId,
      'peerId': _peerId,
      'username': _username,
    });
  }

  void leaveRoom() {
    if (_currentRoomId != null) {
      _socket?.emit('leave-room');
      _currentRoomId = null;
    }
  }

  void requestRoomList() {
    _socket?.emit('list-rooms');
  }

  void sendOffer(String targetPeerId, Map<String, dynamic> offer) {
    _socket?.emit('offer', {
      'to': targetPeerId,
      'from': _peerId,
      'offer': offer,
    });
  }

  void sendAnswer(String targetPeerId, Map<String, dynamic> answer) {
    _socket?.emit('answer', {
      'to': targetPeerId,
      'from': _peerId,
      'answer': answer,
    });
  }

  void sendIceCandidate(String targetPeerId, Map<String, dynamic> candidate) {
    _socket?.emit('ice-candidate', {
      'to': targetPeerId,
      'from': _peerId,
      'candidate': candidate,
    });
  }

  void sendMuteStatus(bool isMuted) {
    _socket?.emit('mute-status', {'isMuted': isMuted});
  }

  void disconnect() {
    _currentRoomId = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
