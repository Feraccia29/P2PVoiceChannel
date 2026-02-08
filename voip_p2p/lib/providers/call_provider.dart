import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import '../models/call_state.dart';
import '../services/signaling_service.dart';
import '../services/webrtc_service.dart';
import '../services/permission_service.dart';

class CallProvider with ChangeNotifier {
  final SignalingService _signalingService = SignalingService();
  final WebRTCService _webrtcService = WebRTCService();

  CallStateModel _callState = CallStateModel();
  String? _localPeerId;
  String? _remotePeerId;

  // Buffering ICE candidates ricevuti prima della remote description
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  bool _remoteDescriptionSet = false;

  // ICE restart (solo l'offerer lo fa)
  int _iceRestartAttempts = 0;
  static const int _maxIceRestartAttempts = 3;
  bool _isOfferer = false;

  CallStateModel get callState => _callState;
  bool get isConnected => _callState.state == CallState.connected;
  bool get isConnecting => _callState.state == CallState.connecting;
  bool get isIdle => _callState.state == CallState.idle;

  CallProvider() {
    _localPeerId = const Uuid().v4();
    _setupCallbacks();
  }

  void _setupCallbacks() {
    _signalingService.onPeerJoined = _handlePeerJoined;
    _signalingService.onPeerLeft = _handlePeerLeft;
    _signalingService.onOfferReceived = _handleOfferReceived;
    _signalingService.onAnswerReceived = _handleAnswerReceived;
    _signalingService.onIceCandidateReceived = _handleIceCandidateReceived;

    _webrtcService.onRemoteStream = _handleRemoteStream;
    _webrtcService.onIceCandidate = _handleLocalIceCandidate;
    _webrtcService.onConnectionStateChange = _handleConnectionStateChange;
  }

  Future<void> connect() async {
    try {
      _updateState(CallState.connecting);

      final hasPermission = await PermissionService.requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }

      await _webrtcService.initialize();
      await _webrtcService.startLocalStream();

      _signalingService.connect(_localPeerId!);

      print('Ready to receive calls');
    } catch (e) {
      _updateState(CallState.error, errorMessage: e.toString());
      print('Connection error: $e');
    }
  }

  void _handlePeerJoined(String peerId) async {
    if (_remotePeerId != null) {
      print('Peer already connected, ignoring new peer');
      return;
    }

    _remotePeerId = peerId;
    _isOfferer = true;
    _resetIceState();

    try {
      final offer = await _webrtcService.createOffer();
      _signalingService.sendOffer(peerId, {
        'sdp': offer.sdp,
        'type': offer.type,
      });
      print('Offer sent to $peerId');
    } catch (e) {
      print('Error creating offer: $e');
      _updateState(CallState.error, errorMessage: e.toString());
    }
  }

  void _handlePeerLeft(String peerId) async {
    if (_remotePeerId == peerId) {
      print('Remote peer disconnected');
      _remotePeerId = null;
      _isOfferer = false;
      _resetIceState();

      try {
        // Cleanup e reinizializza il peer connection
        await _webrtcService.dispose();
        await _webrtcService.initialize();
        await _webrtcService.startLocalStream();

        _updateState(CallState.connecting);
      } catch (e) {
        print('Error reinitializing after peer left: $e');
        _updateState(CallState.error, errorMessage: e.toString());
      }
    }
  }

  Future<void> _handleOfferReceived(Map<String, dynamic> data) async {
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
    _updateState(CallState.connected);
  }

  void _handleConnectionStateChange(RTCPeerConnectionState state) {
    print('PeerConnection state: $state (isOfferer: $_isOfferer)');

    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _iceRestartAttempts = 0;
      _updateState(CallState.connected);
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

  void _resetIceState() {
    _remoteDescriptionSet = false;
    _pendingIceCandidates.clear();
    _iceRestartAttempts = 0;
  }

  void toggleMute() {
    _webrtcService.toggleMute();
    final isMuted = _webrtcService.isMuted();
    _callState = _callState.copyWith(isMuted: isMuted);
    notifyListeners();
  }

  void disconnect() {
    _webrtcService.dispose();
    _signalingService.disconnect();
    _remotePeerId = null;
    _isOfferer = false;
    _resetIceState();
    _updateState(CallState.idle);
  }

  void _updateState(CallState state, {String? errorMessage}) {
    _callState = CallStateModel(
      state: state,
      errorMessage: errorMessage,
      isMuted: _callState.isMuted,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
