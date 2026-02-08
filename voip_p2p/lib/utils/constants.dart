class AppConstants {
  // URL signaling server (configurabile via app_config.json)
  static const String signalingServerUrl = String.fromEnvironment(
    'SIGNALING_SERVER_URL',
    defaultValue: 'http://localhost:3000',
  );

  // Room ID fisso per semplicità
  static const String defaultRoomId = 'gaming-voice-channel';

  // Configurazione ICE servers
  static const Map<String, dynamic> iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  // Configurazione media constraints per audio-only
  static const Map<String, dynamic> mediaConstraints = {
    'audio': {
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
      'sampleRate': 16000,
    },
    'video': false,
  };

  // Configurazione Opus per bassa latenza
  static const Map<String, dynamic> opusParams = {
    'ptime': 20,
    'maxaveragebitrate': 32000,
    'stereo': 0,
    'useinbandfec': 1,
    'usedtx': 1,
  };
}
