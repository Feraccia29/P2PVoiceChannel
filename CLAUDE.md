# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

P2P VoIP application for real-time voice communication, optimized for gaming. Uses Flutter for cross-platform clients (Android, iOS, Windows, macOS, Linux, Web) and a Node.js signaling server for peer discovery.

## Build & Run Commands

### Flutter App (in voip_p2p/)
```bash
# Get dependencies
flutter pub get

# Run debug (with config)
flutter run --dart-define-from-file=app_config.json

# Build Android APK (release)
flutter build apk --release --dart-define-from-file=app_config.json

# Build Windows
flutter build windows --release --dart-define-from-file=app_config.json

# Analyze code
flutter analyze
```

### Signaling Server (in server/)
```bash
npm install
npm start   # Runs on port 3000
```

## Architecture

```
┌──────────────────────────────────────┐
│  CallScreen (UI)                     │
│  - Status indicator, connect/mute    │
└────────────────┬─────────────────────┘
                 │
┌────────────────▼─────────────────────┐
│  CallProvider (State Orchestrator)   │
│  - Manages CallStateModel            │
│  - Coordinates services              │
└──┬─────────────┬─────────────────────┘
   │             │
┌──▼──────────┐ ┌▼───────────────────┐
│ Signaling   │ │ WebRTCService      │
│ Service     │ │ - RTCPeerConnection│
│ (Socket.io) │ │ - Audio streams    │
│ - SDP/ICE   │ │ - Opus codec       │
└─────────────┘ └────────────────────┘
```

**Key files:**
- `lib/providers/call_provider.dart` - Central orchestrator, owns all services
- `lib/services/signaling_service.dart` - WebSocket signaling (join-room, offer/answer, ICE)
- `lib/services/webrtc_service.dart` - WebRTC connection and audio stream management
- `lib/models/call_state.dart` - Immutable state model with idle/connecting/connected/error states
- `server/index.js` - Socket.io signaling server, room-based peer management

## Technical Details

**Audio:** Opus codec at 16kHz, 32kbps, 20ms frames, mono with FEC and DTX enabled

**Signaling flow:**
1. Client joins room via Socket.io
2. When second peer joins, first peer sends SDP offer
3. Peers exchange ICE candidates
4. WebRTC P2P connection established with DTLS-SRTP encryption

**STUN servers:** Google's stun.l.google.com:19302

## Key Dependencies

- `flutter_webrtc` - WebRTC implementation
- `provider` - State management
- `socket_io_client` - Signaling client
- `permission_handler` - Microphone permissions

## Documentation

Detailed Italian specifications are in `flutter-voip-specs.md` (architecture diagrams, implementation details, optimization suggestions).
