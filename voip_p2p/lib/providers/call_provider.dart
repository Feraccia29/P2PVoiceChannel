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

  void _handlePeerLeft(String peerId) {
    if (_remotePeerId == peerId) {
      print('Remote peer disconnected');
      _remotePeerId = null;
      _updateState(CallState.connecting);
    }
  }

  Future<void> _handleOfferReceived(Map<String, dynamic> data) async {
    try {
      final remotePeerId = data['from'] as String;
      _remotePeerId = remotePeerId;

      final offer = RTCSessionDescription(
        data['offer']['sdp'],
        data['offer']['type'],
      );

      await _webrtcService.setRemoteDescription(offer);

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
      final answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );

      await _webrtcService.setRemoteDescription(answer);
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

      await _webrtcService.addIceCandidate(candidate);
    } catch (e) {
      print('Error adding ICE candidate: $e');
    }
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
    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _updateState(CallState.connected);
    } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
        state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
      if (_callState.state == CallState.connected) {
        _updateState(CallState.connecting);
      }
    }
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
