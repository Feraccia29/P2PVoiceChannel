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

  Future<void> initialize() async {
    _peerConnection = await createPeerConnection(
      AppConstants.iceServers,
      {
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ],
      },
    );

    _peerConnection!.onTrack = (event) async {
      if (event.streams.isNotEmpty) {
        print('Remote stream received');
        _remoteStream = event.streams[0];

        // Inizializza renderer per riprodurre audio su web
        _remoteRenderer = RTCVideoRenderer();
        await _remoteRenderer!.initialize();
        _remoteRenderer!.srcObject = _remoteStream;

        onRemoteStream?.call(event.streams[0]);
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      print('Local ICE candidate generated');
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

  Future<void> dispose() async {
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _remoteStream?.getTracks().forEach((track) {
      track.stop();
    });

    _remoteRenderer?.srcObject = null;
    await _remoteRenderer?.dispose();

    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();

    _localStream = null;
    _remoteStream = null;
    _remoteRenderer = null;
    _peerConnection = null;
  }
}
