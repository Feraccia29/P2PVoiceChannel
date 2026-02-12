import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/call_state.dart';
import '../models/peer_info.dart';
import '../models/connection_stats.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../services/permission_service.dart';
import '../services/foreground_service_manager.dart';
import '../services/audio_session_manager.dart';
import '../services/audio_level_monitor.dart';
import '../services/stats_monitor.dart';
import '../services/audio_device_service.dart';

class CallProvider with ChangeNotifier, WidgetsBindingObserver {
  final SignalingService _signalingService;
  final WebRTCService _webrtcService = WebRTCService();
  final ForegroundServiceManager _foregroundService = ForegroundServiceManager();
  final AudioSessionManager _audioSessionManager = AudioSessionManager();

  CallStateModel _callState = CallStateModel();
  String? _localPeerId;
  String? _remotePeerId;

  // Username
  String? _localUsername;
  String? _remoteUsername;

  // Room
  String? _currentRoomId;

  // Credenziali TURN temporanee ricevute dal signaling server
  String? _turnUsername;
  String? _turnCredential;
  bool _webrtcReady = false;

  // Buffering peer-joined e offer ricevuti prima che WebRTC sia pronto
  String? _pendingPeerJoined;
  String? _pendingPeerUsername;
  Map<String, dynamic>? _pendingOffer;

  // Buffering ICE candidates ricevuti prima della remote description
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _remoteDescriptionSet = false;

  // ICE restart (solo l'offerer lo fa)
  int _iceRestartAttempts = 0;
  static const int _maxIceRestartAttempts = 3;
  bool _isOfferer = false;

  // Lifecycle tracking
  bool _wasConnectedBeforePause = false;

  // Audio level monitoring
  AudioLevelMonitor? _audioLevelMonitor;

  // Participant list
  List<PeerInfo> _peers = [];

  // Connection stats monitoring
  StatsMonitor? _statsMonitor;

  // Speaking threshold for audio level
  static const double _speakingThreshold = 0.02;

  // Subscriptions for tracking speaking state
  StreamSubscription<double>? _localSpeakingSub;
  StreamSubscription<double>? _remoteSpeakingSub;

  CallStateModel get callState => _callState;
  bool get isConnected => _callState.state == CallState.connected;
  bool get isConnecting => _callState.state == CallState.connecting;
  bool get isIdle => _callState.state == CallState.idle;
  String? get localUsername => _localUsername;
  String? get remoteUsername => _remoteUsername;
  String? get currentRoomId => _currentRoomId;

  Stream<double> get localAudioLevel =>
      _audioLevelMonitor?.localAudioLevel ?? const Stream.empty();
  Stream<double> get remoteAudioLevel =>
      _audioLevelMonitor?.remoteAudioLevel ?? const Stream.empty();

  List<PeerInfo> get peers => List.unmodifiable(_peers);

  Stream<ConnectionStats> get connectionStatsStream =>
      _statsMonitor?.statsStream ?? const Stream.empty();

  ConnectionStats? get lastConnectionStats => _statsMonitor?.lastStats;

  CallProvider({
    required SignalingService signalingService,
    required String localPeerId,
    required String localUsername,
  }) : _signalingService = signalingService {
    _localPeerId = localPeerId;
    _localUsername = localUsername;
    _callState = CallStateModel(localUsername: localUsername);
    _setupCallbacks();
    WidgetsBinding.instance.addObserver(this);
    _foregroundService.initialize();
  }

  void _setupCallbacks() {
    _signalingService.onPeerJoined = _handlePeerJoined;
    _signalingService.onPeerLeft = _handlePeerLeft;
    _signalingService.onOfferReceived = _handleOfferReceived;
    _signalingService.onAnswerReceived = _handleAnswerReceived;
    _signalingService.onIceCandidateReceived = _handleIceCandidateReceived;
    _signalingService.onTurnCredentials = _handleTurnCredentials;
    _signalingService.onRoomPeers = _handleRoomPeers;
    _signalingService.onPeerMuteStatusChanged = _handlePeerMuteStatusChanged;

    _webrtcService.onRemoteStream = _handleRemoteStream;
    _webrtcService.onIceCandidate = _handleLocalIceCandidate;
    _webrtcService.onConnectionStateChange = _handleConnectionStateChange;
  }

  Future<void> connect(String roomId) async {
    try {
      if (_localUsername == null || _localUsername!.isEmpty) {
        throw Exception('Username non impostato.');
      }

      _currentRoomId = roomId;
      _updateState(CallState.connecting);

      // Initialize local peer in participants list
      _peers = [
        PeerInfo(
          peerId: _localPeerId!,
          username: _localUsername!,
          isMuted: _callState.isMuted,
          isLocal: true,
        ),
      ];

      final hasPermission = await PermissionService.requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      // Configura audio session PRIMA di WebRTC per impostare il contesto audio corretto
      await _audioSessionManager.configure();

      // Socket gia' connesso dal LobbyProvider, join room
      _signalingService.joinRoom(roomId);

      // Avvia foreground service e wake lock per mantenere audio in background
      await _foregroundService.startService();
      await WakelockPlus.enable();

      print('Joined room $roomId, waiting for TURN credentials...');
    } catch (e) {
      _updateState(CallState.error, errorMessage: e.toString());
      print('Connection error: $e');
    }
  }

  void _handleTurnCredentials(String username, String credential) async {
    _turnUsername = username;
    _turnCredential = credential;
    print('TURN credentials received, initializing WebRTC...');

    try {
      await _webrtcService.initialize(
        turnUsername: _turnUsername,
        turnCredential: _turnCredential,
      );
      await _webrtcService.startLocalStream();
      await _applyOutputDevicePreference();
      _webrtcReady = true;

      // Initialize audio level monitor
      _audioLevelMonitor = AudioLevelMonitor(_webrtcService);

      // Initialize stats monitor
      _statsMonitor = StatsMonitor(_webrtcService);

      // Subscribe to audio levels for speaking state tracking
      _localSpeakingSub = _audioLevelMonitor!.localAudioLevel.listen((level) {
        _updateSpeakingState(_localPeerId!, level > _speakingThreshold);
      });
      _remoteSpeakingSub = _audioLevelMonitor!.remoteAudioLevel.listen((level) {
        if (_remotePeerId != null) {
          _updateSpeakingState(_remotePeerId!, level > _speakingThreshold);
        }
      });

      print('WebRTC ready');

      // Flush eventi bufferizzati arrivati prima che WebRTC fosse pronto
      if (_pendingOffer != null) {
        final offer = _pendingOffer!;
        _pendingOffer = null;
        print('Flushing pending offer');
        _handleOfferReceived(offer);
      } else if (_pendingPeerJoined != null) {
        final peerId = _pendingPeerJoined!;
        final peerUsername = _pendingPeerUsername ?? 'Unknown';
        _pendingPeerJoined = null;
        _pendingPeerUsername = null;
        print('Flushing pending peer-joined: $peerId');
        _handlePeerJoined(peerId, peerUsername);
      }
    } catch (e) {
      _updateState(CallState.error, errorMessage: e.toString());
      print('Error initializing WebRTC: $e');
    }
  }

  void _handleRoomPeers(List<Map<String, dynamic>> peers) {
    for (final peerData in peers) {
      final peerId = peerData['peerId'] as String;
      final username = peerData['username'] as String? ?? 'Unknown';
      final isMuted = peerData['isMuted'] as bool? ?? false;

      // Add to peers list if not already present
      if (!_peers.any((p) => p.peerId == peerId)) {
        _peers.add(PeerInfo(
          peerId: peerId,
          username: username,
          isMuted: isMuted,
        ));
      }

      // Keep the existing single-remote-peer tracking
      if (_remoteUsername == null) {
        _remoteUsername = username;
        _callState = _callState.copyWith(remoteUsername: username);
      }
    }
    notifyListeners();
    if (peers.isNotEmpty) {
      print('Room peers received: ${peers.length} existing peers');
    }
  }

  void _handlePeerJoined(String peerId, String username) async {
    if (_remotePeerId != null) {
      print('Peer already connected, ignoring new peer');
      return;
    }

    // Se WebRTC non e' ancora pronto, bufferizza il peer
    if (!_webrtcReady) {
      print('WebRTC not ready yet, buffering peer-joined: $peerId');
      _pendingPeerJoined = peerId;
      _pendingPeerUsername = username;
      return;
    }

    _remotePeerId = peerId;
    _remoteUsername = username;
    _callState = _callState.copyWith(remoteUsername: username, clearErrorMessage: true);

    // Add to peers list
    if (!_peers.any((p) => p.peerId == peerId)) {
      _peers.add(PeerInfo(peerId: peerId, username: username));
    }

    notifyListeners();
    _isOfferer = true;
    _resetIceState();

    try {
      final offer = await _webrtcService.createOffer();
      _signalingService.sendOffer(peerId, {
        'sdp': offer.sdp,
        'type': offer.type,
      });
      print('Offer sent to $peerId ($username)');
    } catch (e) {
      print('Error creating offer: $e');
      _updateState(CallState.error, errorMessage: e.toString());
    }
  }

  void _handlePeerLeft(String peerId) async {
    if (_remotePeerId == peerId) {
      final leftUsername = _remoteUsername ?? 'L\'altro utente';
      print('Remote peer disconnected: $leftUsername');
      _remotePeerId = null;
      _remoteUsername = null;
      _isOfferer = false;
      _resetIceState();

      // Remove from peers list
      _peers.removeWhere((p) => p.peerId == peerId);

      _audioLevelMonitor?.stop();
      _statsMonitor?.stop();

      // Cleanup e reinizializza il peer connection con le credenziali TURN correnti
      await _webrtcService.dispose();

      try {
        await _webrtcService.initialize(
          turnUsername: _turnUsername,
          turnCredential: _turnCredential,
        );
        await _webrtcService.startLocalStream();
        await _applyOutputDevicePreference();
      } catch (e) {
        print('Error reinitializing after peer left: $e');
      }

      _callState = _callState.copyWith(
        state: CallState.connecting,
        clearConnectedAt: true,
        clearRemoteUsername: true,
        errorMessage: '$leftUsername ha lasciato la room',
      );
      notifyListeners();
    }
  }

  Future<void> _handleOfferReceived(Map<String, dynamic> data) async {
    // Se WebRTC non e' ancora pronto, bufferizza l'offer
    if (!_webrtcReady) {
      print('WebRTC not ready yet, buffering offer from ${data['from']}');
      _pendingOffer = data;
      return;
    }

    try {
      final remotePeerId = data['from'] as String;
      final signalingState = _webrtcService.signalingState;

      // Gestione glare: abbiamo già inviato una offer
      if (signalingState == RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        // Tiebreaker: il peer con ID "minore" vince come offerer
        if (_localPeerId!.compareTo(remotePeerId) < 0) {
          print('Glare detected: we win tiebreak, ignoring remote offer');
          return;
        }
        // Noi perdiamo: accettiamo l'offer remota (rollback implicito)
        print('Glare detected: we lose tiebreak, accepting remote offer');
        _isOfferer = false;
      }

      _remotePeerId = remotePeerId;

      // Estrai username dell'offerer dal messaggio (iniettato dal server)
      final offerUsername = data['username'] as String? ?? 'Unknown';
      if (_remoteUsername == null) {
        _remoteUsername = offerUsername;
        _callState = _callState.copyWith(remoteUsername: offerUsername);
        notifyListeners();
      }

      if (signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        _isOfferer = false;
      }
      _remoteDescriptionSet = false;
      _pendingIceCandidates.clear();

      final offer = RTCSessionDescription(
        data['offer']['sdp'],
        data['offer']['type'],
      );

      await _webrtcService.setRemoteDescription(offer);
      _remoteDescriptionSet = true;

      // Applica candidati bufferizzati
      await _flushPendingIceCandidates();

      final answer = await _webrtcService.createAnswer();
      _signalingService.sendAnswer(remotePeerId, {
        'sdp': answer.sdp,
        'type': answer.type,
      });

      print('Answer sent to $remotePeerId');
    } catch (e) {
      print('Error handling offer: $e');
      _updateState(CallState.error, errorMessage: e.toString());
    }
  }

  Future<void> _handleAnswerReceived(Map<String, dynamic> data) async {
    try {
      final signalingState = _webrtcService.signalingState;

      // Guard: accettare answer solo se siamo in have-local-offer
      if (signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        print('Ignoring stale answer (signaling state: $signalingState)');
        return;
      }

      // Aggiorna username remoto dall'answer (iniettato dal server)
      final answerUsername = data['username'] as String?;
      if (answerUsername != null && _remoteUsername == null) {
        _remoteUsername = answerUsername;
        _callState = _callState.copyWith(remoteUsername: answerUsername);
        notifyListeners();
      }

      final answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );

      await _webrtcService.setRemoteDescription(answer);
      _remoteDescriptionSet = true;

      // Applica candidati bufferizzati
      await _flushPendingIceCandidates();

      print('Answer received and applied');
    } catch (e) {
      print('Error handling answer: $e');
      _updateState(CallState.error, errorMessage: e.toString());
    }
  }

  Future<void> _handleIceCandidateReceived(Map<String, dynamic> data) async {
    try {
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );

      if (_remoteDescriptionSet) {
        await _webrtcService.addIceCandidate(candidate);
      } else {
        print('Buffering ICE candidate (remote description not set yet)');
        _pendingIceCandidates.add(candidate);
      }
    } catch (e) {
      print('Error adding ICE candidate: $e');
    }
  }

  Future<void> _flushPendingIceCandidates() async {
    if (_pendingIceCandidates.isEmpty) return;

    print('Flushing ${_pendingIceCandidates.length} buffered ICE candidates');
    for (final candidate in _pendingIceCandidates) {
      try {
        await _webrtcService.addIceCandidate(candidate);
      } catch (e) {
        print('Error adding buffered ICE candidate: $e');
      }
    }
    _pendingIceCandidates.clear();
  }

  void _handleLocalIceCandidate(RTCIceCandidate candidate) {
    if (_remotePeerId != null) {
      _signalingService.sendIceCandidate(_remotePeerId!, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    }
  }

  void _handleRemoteStream(MediaStream stream) {
    print('Remote stream received and playing');
    _audioLevelMonitor?.start();
    _statsMonitor?.start();
    _callState = _callState.copyWith(
      state: CallState.connected,
      connectedAt: DateTime.now(),
    );
    notifyListeners();
  }

  void _handleConnectionStateChange(RTCPeerConnectionState state) {
    print('PeerConnection state: $state (isOfferer: $_isOfferer)');

    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _iceRestartAttempts = 0;
      // Only set connectedAt if not already set (avoid overwriting on ICE restart)
      if (_callState.connectedAt == null) {
        _callState = _callState.copyWith(
          state: CallState.connected,
          connectedAt: DateTime.now(),
        );
      } else {
        _callState = _callState.copyWith(state: CallState.connected);
      }
      notifyListeners();
    } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
      if (_isOfferer) {
        _attemptIceRestart();
      } else {
        // Answerer aspetta che l'offerer faccia ICE restart
        _updateState(CallState.connecting);
      }
    } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
      if (_callState.state == CallState.connected) {
        _updateState(CallState.connecting);
        if (_isOfferer) {
          Future.delayed(const Duration(seconds: 3), () {
            if (_callState.state == CallState.connecting && _remotePeerId != null) {
              _attemptIceRestart();
            }
          });
        }
      }
    }
  }

  Future<void> _attemptIceRestart() async {
    if (_remotePeerId == null || !_isOfferer) return;

    if (_iceRestartAttempts >= _maxIceRestartAttempts) {
      print('Max ICE restart attempts reached');
      _updateState(CallState.error, errorMessage: 'Connection failed after $_maxIceRestartAttempts retries');
      return;
    }

    _iceRestartAttempts++;
    _updateState(CallState.connecting);
    print('Attempting ICE restart (attempt $_iceRestartAttempts/$_maxIceRestartAttempts)');

    try {
      _remoteDescriptionSet = false;
      _pendingIceCandidates.clear();

      final offer = await _webrtcService.createOfferWithIceRestart();
      _signalingService.sendOffer(_remotePeerId!, {
        'sdp': offer.sdp,
        'type': offer.type,
      });
    } catch (e) {
      print('Error during ICE restart: $e');
    }
  }

  Future<void> _applyOutputDevicePreference() async {
    try {
      final deviceId = await AudioDeviceService.getPreferredOutputDeviceId();
      if (deviceId != null) {
        await _webrtcService.setAudioOutputDevice(deviceId);
      }
    } catch (e) {
      print('Error applying output device preference: $e');
    }
  }

  void _resetIceState() {
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();
    _iceRestartAttempts = 0;
  }

  void _handlePeerMuteStatusChanged(String peerId, bool isMuted) {
    final index = _peers.indexWhere((p) => p.peerId == peerId);
    if (index != -1) {
      _peers[index] = _peers[index].copyWith(isMuted: isMuted);
      notifyListeners();
    }
  }

  void _updateSpeakingState(String peerId, bool isSpeaking) {
    final index = _peers.indexWhere((p) => p.peerId == peerId);
    if (index != -1 && _peers[index].isSpeaking != isSpeaking) {
      _peers[index] = _peers[index].copyWith(isSpeaking: isSpeaking);
      notifyListeners();
    }
  }

  void toggleMute() {
    _webrtcService.toggleMute();
    final isMuted = _webrtcService.isMuted();
    _callState = _callState.copyWith(isMuted: isMuted);

    // Update local peer in peers list
    final index = _peers.indexWhere((p) => p.isLocal);
    if (index != -1) {
      _peers[index] = _peers[index].copyWith(isMuted: isMuted);
    }

    // Notify remote peers via signaling
    _signalingService.sendMuteStatus(isMuted);

    notifyListeners();
  }

  Future<void> disconnect() async {
    _localSpeakingSub?.cancel();
    _localSpeakingSub = null;
    _remoteSpeakingSub?.cancel();
    _remoteSpeakingSub = null;

    _audioLevelMonitor?.dispose();
    _audioLevelMonitor = null;

    _statsMonitor?.dispose();
    _statsMonitor = null;

    _webrtcService.dispose();
    _signalingService.leaveRoom();
    _remotePeerId = null;
    _remoteUsername = null;
    _currentRoomId = null;
    _isOfferer = false;
    _webrtcReady = false;
    _pendingPeerJoined = null;
    _pendingPeerUsername = null;
    _pendingOffer = null;
    _turnUsername = null;
    _turnCredential = null;
    _peers.clear();
    _resetIceState();

    // Rilascia risorse background
    await _foregroundService.stopService();
    await _audioSessionManager.deactivate();
    await WakelockPlus.disable();

    _callState = CallStateModel(
      state: CallState.idle,
      isMuted: false,
      localUsername: _localUsername,
    );
    notifyListeners();
  }

  void _updateState(CallState state, {String? errorMessage}) {
    _callState = CallStateModel(
      state: state,
      errorMessage: errorMessage,
      isMuted: _callState.isMuted,
      localUsername: _callState.localUsername,
      remoteUsername: _callState.remoteUsername,
      connectedAt: state == CallState.idle ? null : _callState.connectedAt,
    );
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _wasConnectedBeforePause =
            _callState.state == CallState.connected ||
            _callState.state == CallState.connecting;
        print('App paused, call active: $_wasConnectedBeforePause');
        break;
      case AppLifecycleState.resumed:
        print('App resumed, was connected: $_wasConnectedBeforePause');
        if (_wasConnectedBeforePause && _callState.state != CallState.idle) {
          _signalingService.ensureConnected(
            _localPeerId!,
            username: _localUsername ?? 'Unknown',
          );
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disconnect();
    super.dispose();
  }
}
