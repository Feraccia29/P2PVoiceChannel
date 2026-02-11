import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../utils/constants.dart';

class SignalingService {
  IO.Socket? _socket;
  String? _peerId;

  // Callbacks
  Function(Map<String, dynamic>)? onOfferReceived;
  Function(Map<String, dynamic>)? onAnswerReceived;
  Function(Map<String, dynamic>)? onIceCandidateReceived;
  Function(String)? onPeerJoined;
  Function(String)? onPeerLeft;
  Function()? onConnected;
  Function(String username, String credential)? onTurnCredentials;

  void connect(String peerId) {
    _peerId = peerId;

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
      joinRoom(AppConstants.defaultRoomId);
      onConnected?.call();
    });

    _socket!.on('turn-credentials', (data) {
      final username = data['username'] as String;
      final credential = data['credential'] as String;
      print('Received TURN credentials (username: $username)');
      onTurnCredentials?.call(username, credential);
    });

    _socket!.on('peer-joined', (data) {
      final remotePeerId = data['peerId'] as String;
      print('Peer joined: $remotePeerId');
      onPeerJoined?.call(remotePeerId);
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

    _socket!.on('reconnect', (_) {
      print('Socket.io reconnected, re-joining room');
      joinRoom(AppConstants.defaultRoomId);
      onConnected?.call();
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
  void ensureConnected(String peerId) {
    if (_socket == null || _socket!.disconnected) {
      print('Socket disconnected during background, reconnecting...');
      connect(peerId);
    }
  }

  void joinRoom(String roomId) {
    _socket?.emit('join-room', {
      'roomId': roomId,
      'peerId': _peerId,
    });
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

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
