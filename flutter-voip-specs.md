# Specifiche tecniche: App VoIP P2P con Flutter

## Panoramica del progetto

Creare un'applicazione di voice chat peer-to-peer cross-platform (Android e Windows) usando Flutter e WebRTC. L'app deve avere:

- Interfaccia minimalista con un solo pulsante per connessione/disconnessione
- Microfono sempre acceso durante la chiamata
- Crittografia end-to-end tramite DTLS-SRTP (integrata in WebRTC)
- Latenza minima per gaming (target: <150ms)
- Compilabile come APK per Android e EXE per Windows da un singolo codebase

## Architettura generale

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   Flutter App   │         │ Signaling Server │         │   Flutter App   │
│   (Android/Win) │ ←──────→│   (Socket.io)    │←──────→ │   (Android/Win) │
│                 │  SDP/ICE│                  │ SDP/ICE │                 │
└────────┬────────┘         └──────────────────┘         └────────┬────────┘
         │                                                         │
         │                  WebRTC P2P Audio Stream                │
         └─────────────────────────────────────────────────────────┘
```

### Componenti principali

1. **Flutter App** - Client VoIP con flutter_webrtc
2. **Signaling Server** - Node.js + Socket.io per scambio SDP/ICE
3. **STUN Server** - Google STUN per NAT traversal (gratuito)
4. **TURN Server** (opzionale) - Open Relay Project per NAT simmetrico

## Stack tecnologico

### Dipendenze Flutter (pubspec.yaml)

```yaml
name: voip_p2p
description: Voice chat P2P minimale
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # WebRTC per Flutter (supporta Android, iOS, Windows, macOS, Linux, Web)
  flutter_webrtc: ^0.12.3
  
  # State management leggero
  provider: ^6.1.2
  
  # Socket.io client per signaling
  socket_io_client: ^2.0.3+1
  
  # Gestione permessi cross-platform
  permission_handler: ^11.3.1
  
  # UUID per identificatori univoci
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
```

### Versioni e compatibilità

- **Flutter SDK**: 3.24+ (stable channel)
- **Dart**: 3.0+
- **flutter_webrtc**: v0.12.3 (basato su libwebrtc m137)
- **Piattaforme supportate**: Android 21+, Windows 10+

## Struttura del progetto

```
voip_p2p/
├── lib/
│   ├── main.dart                      # Entry point
│   ├── models/
│   │   ├── call_state.dart           # Stati della chiamata (idle, connecting, connected)
│   │   └── peer_connection_config.dart
│   ├── services/
│   │   ├── signaling_service.dart    # Socket.io + scambio SDP/ICE
│   │   ├── webrtc_service.dart       # Gestione RTCPeerConnection
│   │   └── permission_service.dart    # Richiesta permessi microfono
│   ├── providers/
│   │   └── call_provider.dart        # State management con Provider
│   ├── screens/
│   │   └── call_screen.dart          # UI principale
│   └── utils/
│       └── constants.dart            # Config server, ice servers, codec params
├── android/
│   └── app/src/main/AndroidManifest.xml  # Permessi Android
├── windows/
│   └── runner/
│       └── main.cpp                   # Entry point Windows
├── server/                            # Signaling server (separato)
│   ├── package.json
│   └── index.js                       # Node.js + Socket.io
└── pubspec.yaml
```

## Implementazione dettagliata

### 1. Configurazione e costanti (lib/utils/constants.dart)

```dart
class AppConstants {
  // URL signaling server (cambiare con il proprio server)
  static const String signalingServerUrl = 'http://localhost:3000';
  
  // Room ID fisso per semplicità (può essere parametrizzato)
  static const String defaultRoomId = 'gaming-voice-channel';
  
  // Configurazione ICE servers
  static const Map<String, dynamic> iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // Aggiungere TURN se necessario:
      // {
      //   'urls': 'turn:openrelay.metered.ca:80',
      //   'username': 'openrelayproject',
      //   'credential': 'openrelayproject'
      // }
    ]
  };
  
  // Configurazione media constraints per audio-only
  static const Map<String, dynamic> mediaConstraints = {
    'audio': {
      'echoCancellation': true,     // Echo cancellation attivo
      'noiseSuppression': true,     // Noise suppression attivo
      'autoGainControl': true,      // Gain automatico
      'sampleRate': 16000,          // 16kHz wideband per voce
    },
    'video': false,                 // NO video
  };
  
  // Configurazione Opus per bassa latenza
  static const Map<String, dynamic> opusParams = {
    'ptime': 20,                    // Frame size 20ms
    'maxaveragebitrate': 32000,     // 32kbps
    'stereo': 0,                    // Mono
    'useinbandfec': 1,              // Forward error correction
    'usedtx': 1,                    // Discontinuous transmission
  };
}
```

### 2. Modello dello stato chiamata (lib/models/call_state.dart)

```dart
enum CallState {
  idle,           // Non connesso
  connecting,     // Connessione in corso
  connected,      // Chiamata attiva
  disconnecting,  // Disconnessione in corso
  error,          // Errore
}

class CallStateModel {
  final CallState state;
  final String? errorMessage;
  final bool isMuted;
  
  CallStateModel({
    this.state = CallState.idle,
    this.errorMessage,
    this.isMuted = false,
  });
  
  CallStateModel copyWith({
    CallState? state,
    String? errorMessage,
    bool? isMuted,
  }) {
    return CallStateModel(
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      isMuted: isMuted ?? this.isMuted,
    );
  }
}
```

### 3. Servizio permessi (lib/services/permission_service.dart)

```dart
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    
    if (status.isGranted) {
      return true;
    } else if (status.isDenied || status.isPermanentlyDenied) {
      // Su Android, aprire le impostazioni se permanentemente negato
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }
    
    return false;
  }
  
  static Future<bool> checkMicrophonePermission() async {
    return await Permission.microphone.isGranted;
  }
}
```

### 4. Signaling Service (lib/services/signaling_service.dart)

Questo servizio gestisce la comunicazione WebSocket con il signaling server per scambiare offer/answer SDP e candidati ICE.

```dart
import 'dart:convert';
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
  
  void connect(String peerId) {
    _peerId = peerId;
    
    _socket = IO.io(
      AppConstants.signalingServerUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );
    
    _socket!.connect();
    
    _socket!.on('connect', (_) {
      print('✅ Connesso al signaling server');
      joinRoom(AppConstants.defaultRoomId);
    });
    
    _socket!.on('peer-joined', (data) {
      final remotePeerId = data['peerId'] as String;
      print('👤 Peer entrato: $remotePeerId');
      onPeerJoined?.call(remotePeerId);
    });
    
    _socket!.on('peer-left', (data) {
      final remotePeerId = data['peerId'] as String;
      print('👋 Peer uscito: $remotePeerId');
      onPeerLeft?.call(remotePeerId);
    });
    
    _socket!.on('offer', (data) {
      print('📩 Ricevuta offer da ${data['from']}');
      onOfferReceived?.call(data);
    });
    
    _socket!.on('answer', (data) {
      print('📩 Ricevuta answer da ${data['from']}');
      onAnswerReceived?.call(data);
    });
    
    _socket!.on('ice-candidate', (data) {
      print('📩 Ricevuto ICE candidate da ${data['from']}');
      onIceCandidateReceived?.call(data);
    });
    
    _socket!.on('disconnect', (_) {
      print('❌ Disconnesso dal signaling server');
    });
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
  }
}
```

### 5. WebRTC Service (lib/services/webrtc_service.dart)

Gestisce la RTCPeerConnection, lo stream audio locale e remoto, e la configurazione Opus.

```dart
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../utils/constants.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  
  // Callbacks
  Function(MediaStream)? onRemoteStream;
  Function(RTCIceCandidate)? onIceCandidate;
  Function()? onConnectionStateChange;
  
  Future<void> initialize() async {
    // Configurazione peer connection
    _peerConnection = await createPeerConnection(
      AppConstants.iceServers,
      {
        'optional': [
          {'DtlsSrtpKeyAgreement': true},  // Forza DTLS-SRTP
        ],
      },
    );
    
    // Listener per stream remoto
    _peerConnection!.onAddStream = (stream) {
      print('🎵 Stream remoto ricevuto');
      onRemoteStream?.call(stream);
    };
    
    // Listener per ICE candidates
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        print('🧊 ICE candidate locale generato');
        onIceCandidate?.call(candidate);
      }
    };
    
    // Listener per stato connessione
    _peerConnection!.onConnectionState = (state) {
      print('🔌 Connection state: $state');
      onConnectionStateChange?.call();
    };
  }
  
  Future<void> startLocalStream() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia(
        AppConstants.mediaConstraints,
      );
      
      // Aggiungi stream locale alla peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });
      
      print('🎤 Stream locale avviato');
    } catch (e) {
      print('❌ Errore avvio stream locale: $e');
      rethrow;
    }
  }
  
  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    });
    
    // Modifica SDP per forzare parametri Opus
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
    if (_localStream != null) {
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
  
  // Modifica SDP per forzare parametri Opus ottimali
  String _modifySdpForOpus(String sdp) {
    // Trova la linea Opus (solitamente payload type 111)
    final lines = sdp.split('\r\n');
    final newLines = <String>[];
    
    for (var line in lines) {
      newLines.add(line);
      
      // Cerca la linea a=rtpmap per Opus
      if (line.contains('a=rtpmap:') && line.contains('opus')) {
        final payloadType = line.split(':')[1].split(' ')[0];
        
        // Aggiungi parametri fmtp per Opus se non esistono
        final hasFmtp = lines.any((l) => l.startsWith('a=fmtp:$payloadType'));
        
        if (!hasFmtp) {
          final params = AppConstants.opusParams;
          newLines.add(
            'a=fmtp:$payloadType '
            'ptime=${params['ptime']};'
            'maxaveragebitrate=${params['maxaveragebitrate']};'
            'stereo=${params['stereo']};'
            'useinbandfec=${params['useinbandfec']};'
            'usedtx=${params['usedtx']}'
          );
        }
      }
    }
    
    return newLines.join('\r\n');
  }
  
  Future<void> dispose() async {
    await _localStream?.dispose();
    await _peerConnection?.close();
    _localStream = null;
    _peerConnection = null;
  }
}
```

### 6. Call Provider (lib/providers/call_provider.dart)

State management che orchestra signaling e WebRTC.

```dart
import 'package:flutter/foundation.dart';
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
  
  CallProvider() {
    _localPeerId = const Uuid().v4();
    _setupCallbacks();
  }
  
  void _setupCallbacks() {
    // Signaling callbacks
    _signalingService.onPeerJoined = _handlePeerJoined;
    _signalingService.onPeerLeft = _handlePeerLeft;
    _signalingService.onOfferReceived = _handleOfferReceived;
    _signalingService.onAnswerReceived = _handleAnswerReceived;
    _signalingService.onIceCandidateReceived = _handleIceCandidateReceived;
    
    // WebRTC callbacks
    _webrtcService.onRemoteStream = _handleRemoteStream;
    _webrtcService.onIceCandidate = _handleLocalIceCandidate;
  }
  
  Future<void> connect() async {
    try {
      _updateState(CallState.connecting);
      
      // Richiedi permessi microfono
      final hasPermission = await PermissionService.requestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Permesso microfono negato');
      }
      
      // Inizializza WebRTC
      await _webrtcService.initialize();
      await _webrtcService.startLocalStream();
      
      // Connetti al signaling server
      _signalingService.connect(_localPeerId!);
      
      print('✅ Pronto per ricevere chiamate');
      
    } catch (e) {
      _updateState(CallState.error, errorMessage: e.toString());
      print('❌ Errore connessione: $e');
    }
  }
  
  void _handlePeerJoined(String peerId) async {
    if (_remotePeerId != null) {
      print('⚠️ Peer già connesso, ignorato nuovo peer');
      return;
    }
    
    _remotePeerId = peerId;
    
    // Inizia la chiamata creando un'offer
    try {
      final offer = await _webrtcService.createOffer();
      _signalingService.sendOffer(peerId, {
        'sdp': offer.sdp,
        'type': offer.type,
      });
      print('📤 Offer inviata a $peerId');
    } catch (e) {
      print('❌ Errore creazione offer: $e');
      _updateState(CallState.error, errorMessage: e.toString());
    }
  }
  
  void _handlePeerLeft(String peerId) {
    if (_remotePeerId == peerId) {
      print('👋 Peer remoto disconnesso');
      disconnect();
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
      
      // Crea answer
      final answer = await _webrtcService.createAnswer();
      _signalingService.sendAnswer(remotePeerId, {
        'sdp': answer.sdp,
        'type': answer.type,
      });
      
      print('📤 Answer inviata a $remotePeerId');
      
    } catch (e) {
      print('❌ Errore gestione offer: $e');
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
      print('✅ Answer ricevuta e applicata');
      
    } catch (e) {
      print('❌ Errore gestione answer: $e');
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
      print('❌ Errore aggiunta ICE candidate: $e');
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
    print('🎵 Stream remoto ricevuto e in riproduzione');
    _updateState(CallState.connected);
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
```

### 7. UI principale (lib/screens/call_screen.dart)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';
import '../models/call_state.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Consumer<CallProvider>(
        builder: (context, callProvider, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Indicatore stato
                _buildStatusIndicator(callProvider.callState.state),
                const SizedBox(height: 40),
                
                // Pulsante principale
                _buildMainButton(context, callProvider),
                const SizedBox(height: 20),
                
                // Pulsante mute (solo se connesso)
                if (callProvider.isConnected)
                  _buildMuteButton(callProvider),
                
                // Messaggio errore
                if (callProvider.callState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      callProvider.callState.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildStatusIndicator(CallState state) {
    String text;
    Color color;
    IconData icon;
    
    switch (state) {
      case CallState.idle:
        text = 'Disconnesso';
        color = Colors.grey;
        icon = Icons.radio_button_unchecked;
        break;
      case CallState.connecting:
        text = 'Connessione...';
        color = Colors.orange;
        icon = Icons.sync;
        break;
      case CallState.connected:
        text = 'Connesso';
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case CallState.disconnecting:
        text = 'Disconnessione...';
        color = Colors.orange;
        icon = Icons.sync;
        break;
      case CallState.error:
        text = 'Errore';
        color = Colors.red;
        icon = Icons.error;
        break;
    }
    
    return Column(
      children: [
        Icon(icon, size: 60, color: color),
        const SizedBox(height: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
  
  Widget _buildMainButton(BuildContext context, CallProvider provider) {
    final isIdle = provider.callState.state == CallState.idle;
    
    return ElevatedButton(
      onPressed: provider.isConnecting
          ? null
          : () {
              if (isIdle) {
                provider.connect();
              } else {
                provider.disconnect();
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isIdle ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: Text(
        isIdle ? 'CONNETTI' : 'DISCONNETTI',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
  
  Widget _buildMuteButton(CallProvider provider) {
    return IconButton(
      onPressed: provider.toggleMute,
      icon: Icon(
        provider.callState.isMuted ? Icons.mic_off : Icons.mic,
        color: provider.callState.isMuted ? Colors.red : Colors.white,
      ),
      iconSize: 40,
    );
  }
}
```

### 8. Main entry point (lib/main.dart)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/call_provider.dart';
import 'screens/call_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CallProvider(),
      child: MaterialApp(
        title: 'VoIP P2P',
        theme: ThemeData.dark(),
        home: const CallScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
```

## Configurazione piattaforme

### Android (android/app/src/main/AndroidManifest.xml)

Aggiungere questi permessi PRIMA del tag `<application>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Permessi necessari -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
    
    <!-- Feature hardware -->
    <uses-feature android:name="android.hardware.microphone" android:required="true" />
    
    <application ...>
        ...
    </application>
</manifest>
```

### Windows

Su Windows non serve configurazione speciale. Flutter desktop gestisce automaticamente i permessi del microfono.

## Signaling Server (Node.js + Socket.io)

Creare una cartella `server/` separata dal progetto Flutter.

**server/package.json:**
```json
{
  "name": "voip-signaling-server",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "socket.io": "^4.7.5"
  }
}
```

**server/index.js:**
```javascript
const { Server } = require('socket.io');

const io = new Server(3000, {
  cors: {
    origin: '*',  // In produzione, specificare origin preciso
  },
});

const rooms = new Map();

io.on('connection', (socket) => {
  console.log(`✅ Client connesso: ${socket.id}`);
  
  socket.on('join-room', ({ roomId, peerId }) => {
    socket.join(roomId);
    
    if (!rooms.has(roomId)) {
      rooms.set(roomId, new Set());
    }
    
    const room = rooms.get(roomId);
    
    // Notifica agli altri peer che un nuovo peer è entrato
    socket.to(roomId).emit('peer-joined', { peerId });
    
    room.add(peerId);
    console.log(`👤 ${peerId} entrato nella room ${roomId}`);
  });
  
  socket.on('offer', ({ to, from, offer }) => {
    console.log(`📤 Offer da ${from} a ${to}`);
    io.to(to).emit('offer', { from, offer });
  });
  
  socket.on('answer', ({ to, from, answer }) => {
    console.log(`📤 Answer da ${from} a ${to}`);
    io.to(to).emit('answer', { from, answer });
  });
  
  socket.on('ice-candidate', ({ to, from, candidate }) => {
    console.log(`📤 ICE candidate da ${from} a ${to}`);
    io.to(to).emit('ice-candidate', { from, candidate });
  });
  
  socket.on('disconnect', () => {
    // Notifica a tutti i room che questo peer è uscito
    rooms.forEach((peers, roomId) => {
      if (peers.has(socket.id)) {
        socket.to(roomId).emit('peer-left', { peerId: socket.id });
        peers.delete(socket.id);
        console.log(`👋 ${socket.id} uscito dalla room ${roomId}`);
      }
    });
    
    console.log(`❌ Client disconnesso: ${socket.id}`);
  });
});

console.log('🚀 Signaling server in ascolto sulla porta 3000');
```

**Avviare il server:**
```bash
cd server
npm install
npm start
```

## Build e deployment

### Build Android APK

```bash
# Debug APK
flutter build apk --debug

# Release APK (richiede keystore)
flutter build apk --release

# APK sarà in: build/app/outputs/flutter-apk/app-release.apk
```

Per firmare l'APK in release, seguire la guida ufficiale Flutter per creare un keystore.

### Build Windows EXE

```bash
# Release EXE
flutter build windows --release

# Eseguibile sarà in: build/windows/x64/runner/Release/
```

L'intera cartella `Release/` va distribuita insieme, contiene DLL e asset necessari.

Per creare un installer, si può usare **Inno Setup** o **MSIX** (packaging UWP).

## Testing e debugging

### Test su LAN locale

1. Avviare il signaling server: `cd server && npm start`
2. Assicurarsi che entrambi i dispositivi siano sulla stessa rete
3. Nel codice, modificare `signalingServerUrl` con l'IP del PC che esegue il server (es: `http://192.168.1.100:3000`)
4. Avviare l'app su entrambi i dispositivi

### Debug WebRTC

Attivare i log dettagliati di flutter_webrtc aggiungendo in `main.dart`:

```dart
void main() {
  // Log dettagliati WebRTC
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  
  runApp(const MyApp());
}
```

### Verifica connessione ICE

Verificare che i candidati ICE vengano scambiati correttamente. Nel log dovrebbero apparire:
- `type: host` (IP locale)
- `type: srflx` (IP pubblico tramite STUN)
- `type: relay` (se si usa TURN)

## Ottimizzazioni avanzate

### Foreground Service su Android (microfono sempre attivo)

Per mantenere il microfono attivo anche con schermo spento, serve un Foreground Service. Usare il pacchetto `flutter_foreground_task`:

```yaml
dependencies:
  flutter_foreground_task: ^8.14.0
```

### Riduzione latenza audio

Modificare `_modifySdpForOpus` per ptime=10ms invece di 20ms:

```dart
'ptime=10;'  // Frame size 10ms (latenza minore, overhead maggiore)
```

### Connection recovery

Aggiungere logica di riconnessione automatica nel `CallProvider`:

```dart
void _handleConnectionStateChange() {
  final state = _peerConnection?.connectionState;
  
  if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
    // Riconnessione automatica dopo 2 secondi
    Future.delayed(Duration(seconds: 2), () {
      if (_remotePeerId != null) {
        _reconnect();
      }
    });
  }
}
```

## Note finali e considerazioni

### Cosa fare prima di iniziare

1. Installare Flutter SDK 3.24+ e configurare Android SDK + JDK
2. Per Windows: abilitare Windows desktop support con `flutter config --enable-windows-desktop`
3. Testare che `flutter doctor` non dia errori critici
4. Creare il progetto: `flutter create --org com.tuodominio voip_p2p`

### Limitazioni note

- **Scalabilità**: l'architettura mesh P2P funziona bene per 2-4 partecipanti. Oltre, serve un SFU.
- **NAT simmetrico**: senza TURN, ~20-30% delle connessioni falliranno su reti restrittive.
- **Background su iOS**: richiede CallKit (non implementato qui, ma flutter_webrtc lo supporta).

### Risorse utili

- Documentazione flutter_webrtc: https://github.com/flutter-webrtc/flutter-webrtc
- WebRTC samples: https://webrtc.github.io/samples/
- Troubleshooting ICE: https://bloggeek.me/webrtc-ice-failures/

### Prossimi passi suggeriti

1. Implementare la logica base seguendo questa specifica
2. Testare su LAN con due dispositivi
3. Aggiungere TURN per NAT traversal
4. Implementare UI per selezione stanze/canali
5. Aggiungere persistenza dello stato con shared_preferences
6. Implementare notifiche push per chiamate in arrivo (Firebase)

---

**IMPORTANTE**: Cambiare `AppConstants.signalingServerUrl` con l'indirizzo del proprio server prima del deployment. Per test locali su LAN, usare l'IP del PC che esegue il signaling server (es: `http://192.168.1.100:3000`).
