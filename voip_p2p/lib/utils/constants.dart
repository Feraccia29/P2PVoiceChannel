class AppConstants {
  // URL signaling server (configurabile via app_config.json)
  static const String signalingServerUrl = String.fromEnvironment(
    'SIGNALING_SERVER_URL',
    defaultValue: 'http://localhost:3000',
  );

  // TURN server (configurabile via app_config.json)
  static const String turnServerUrl = String.fromEnvironment(
    'TURN_SERVER_URL',
    defaultValue: 'turn:localhost:3478',
  );
  static const String turnUsername = String.fromEnvironment(
    'TURN_USERNAME',
    defaultValue: 'voipuser',
  );
  static const String turnPassword = String.fromEnvironment(
    'TURN_PASSWORD',
    defaultValue: 'voippass123',
  );

  // Room ID fisso per semplicità
  static const String defaultRoomId = 'gaming-voice-channel';

  // Configurazione ICE servers (STUN + TURN)
  static Map<String, dynamic> iceServers({String? turnUser, String? turnCred}) => {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': [
          turnServerUrl,
          '$turnServerUrl?transport=tcp',
        ],
        'username': turnUser ?? turnUsername,
        'credential': turnCred ?? turnPassword,
      },
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
    'stereo': 1,
    'useinbandfec': 1,
    'usedtx': 1,
  };
}
