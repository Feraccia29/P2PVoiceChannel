import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/constants.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  RTCVideoRenderer? _remoteRenderer;

  // Callbacks
  Function(MediaStream)? onRemoteStream;
  Function(RTCIceCandidate)? onIceCandidate;
  Function(RTCPeerConnectionState)? onConnectionStateChange;

  RTCPeerConnectionState? get connectionState => _peerConnection?.connectionState;
  RTCSignalingState? get signalingState => _peerConnection?.signalingState;

  Future<List<StatsReport>> getStats() async {
    if (_peerConnection == null) return [];
    return await _peerConnection!.getStats();
  }

  Future<void> initialize({String? turnUsername, String? turnCredential}) async {
    final config = {
      ...AppConstants.iceServers(turnUser: turnUsername, turnCred: turnCredential),
      'iceTransportPolicy': 'all',
    };

    _peerConnection = await createPeerConnection(
      config,
      {
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ],
      },
    );

    _peerConnection!.onTrack = (event) async {
      try {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];

          final audioTracks = _remoteStream!.getAudioTracks();
          print('Remote stream received: ${audioTracks.length} audio tracks');
          for (final track in audioTracks) {
            print('  Audio track: id=${track.id}, enabled=${track.enabled}, muted=${track.muted}');
          }

          _remoteRenderer = RTCVideoRenderer();
          await _remoteRenderer!.initialize();
          _remoteRenderer!.srcObject = _remoteStream;
          print('Renderer initialized and attached to remote stream');

          onRemoteStream?.call(event.streams[0]);
        }
      } catch (e) {
        print('Error handling remote track: $e');
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      final candidateStr = candidate.candidate ?? '';
      String type = 'unknown';
      if (candidateStr.contains('typ relay')) {
        type = 'relay (TURN)';
      } else if (candidateStr.contains('typ srflx')) {
        type = 'srflx (STUN)';
      } else if (candidateStr.contains('typ host')) {
        type = 'host (local)';
      }
      print('ICE candidate: $type - $candidateStr');
      onIceCandidate?.call(candidate);
    };

    _peerConnection!.onConnectionState = (state) {
      print('Connection state: $state');
      onConnectionStateChange?.call(state);
    };

    _peerConnection!.onIceConnectionState = (state) {
      print('ICE connection state: $state');
    };
  }

  Future<void> startLocalStream() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia(
        AppConstants.mediaConstraints,
      );

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      print('Local stream started');
    } catch (e) {
      print('Error starting local stream: $e');
      rethrow;
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });

    final modifiedSdp = _modifySdpForOpus(offer.sdp!);
    final modifiedOffer = RTCSessionDescription(modifiedSdp, offer.type);

    await _peerConnection!.setLocalDescription(modifiedOffer);
    return modifiedOffer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });

    final modifiedSdp = _modifySdpForOpus(answer.sdp!);
    final modifiedAnswer = RTCSessionDescription(modifiedSdp, answer.type);

    await _peerConnection!.setLocalDescription(modifiedAnswer);
    return modifiedAnswer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  Future<RTCSessionDescription> createOfferWithIceRestart() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
      'iceRestart': true,
    });

    final modifiedSdp = _modifySdpForOpus(offer.sdp!);
    final modifiedOffer = RTCSessionDescription(modifiedSdp, offer.type);

    await _peerConnection!.setLocalDescription(modifiedOffer);
    return modifiedOffer;
  }

  void toggleMute() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
    }
  }

  bool isMuted() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      return !_localStream!.getAudioTracks().first.enabled;
    }
    return false;
  }

  String _modifySdpForOpus(String sdp) {
    final lines = sdp.split('\r\n');
    final newLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      newLines.add(line);

      if (line.contains('a=rtpmap:') && line.contains('opus')) {
        final payloadType = line.split(':')[1].split(' ')[0];
        final hasFmtp = lines.any((l) => l.startsWith('a=fmtp:$payloadType'));

        if (!hasFmtp) {
          final params = AppConstants.opusParams;
          newLines.add(
            'a=fmtp:$payloadType '
            'ptime=${params['ptime']};'
            'maxaveragebitrate=${params['maxaveragebitrate']};'
            'stereo=${params['stereo']};'
            'useinbandfec=${params['useinbandfec']};'
            'usedtx=${params['usedtx']}',
          );
        }
      }
    }

    return newLines.join('\r\n');
  }

  Future<void> setAudioOutputDevice(String deviceId) async {
    await Helper.selectAudioOutput(deviceId);
  }

  Future<void> dispose() async {
    try {
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
    } catch (e) {
      print('Error stopping local tracks: $e');
    }

    try {
      _remoteStream?.getTracks().forEach((track) {
        track.stop();
      });
    } catch (e) {
      print('Error stopping remote tracks: $e');
    }

    try {
      _remoteRenderer?.srcObject = null;
      await _remoteRenderer?.dispose();
    } catch (e) {
      print('Error disposing renderer: $e');
    }

    try {
      await _localStream?.dispose();
    } catch (e) {
      print('Error disposing local stream: $e');
    }

    try {
      await _remoteStream?.dispose();
    } catch (e) {
      print('Error disposing remote stream: $e');
    }

    try {
      await _peerConnection?.close();
    } catch (e) {
      print('Error closing peer connection: $e');
    }

    _localStream = null;
    _remoteStream = null;
    _remoteRenderer = null;
    _peerConnection = null;
  }
}
