# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

P2P VoIP application for real-time voice communication, optimized for gaming. Uses Flutter for cross-platform clients (Android, iOS, Windows, macOS, Linux, Web) and a Node.js signaling server for peer discovery. UI has a gaming-oriented dark theme (electric purple accent on dark blue gradients).

## Build & Run Commands

### Flutter App (in voip_p2p/)
```bash
flutter pub get

# All run/build commands require the config file
flutter run --dart-define-from-file=app_config.json
flutter build apk --release --dart-define-from-file=app_config.json
flutter build windows --release --dart-define-from-file=app_config.json

flutter analyze
```

`app_config.json` defines `SIGNALING_SERVER_URL` and `TURN_SERVER_URL`. These are read at compile time via `--dart-define-from-file`.

### Signaling Server (in server/)
```bash
# Local development
npm install && npm start   # Port 3000

# Production (Docker Compose with coturn TURN server)
podman compose up          # Signaling: 16429, TURN: 16430/UDP
```

## Architecture

```
┌─────────────────┐  ┌──────────────┐  ┌─────────────────┐
│  LobbyScreen    │  │  CallScreen  │  │ SettingsScreen  │
│  Room selection  │  │  Active call │  │ Audio devices   │
└───────┬─────────┘  └──────┬───────┘  └─────────────────┘
        │                   │
┌───────▼─────────┐  ┌─────▼──────────────────────────────┐
│ LobbyProvider   │  │ CallProvider (667 lines)            │
│ Room list,      │  │ - Owns WebRTC + Signaling services  │
│ server connect  │  │ - Pending event buffering           │
└─────────────────┘  │ - ICE restart (max 3, offerer only) │
                     │ - Glare handling (lower peerId wins)│
                     │ - App lifecycle (WidgetsBinding)     │
                     └──┬──────────────┬───────────────────┘
                        │              │
┌───────────────────────▼──┐  ┌───────▼──────────────────┐
│ SignalingService          │  │ WebRTCService            │
│ Socket.io client          │  │ RTCPeerConnection        │
│ SDP/ICE relay + rooms     │  │ Audio stream + Opus SDP  │
└──────────────────────────┘  └──────────────────────────┘
```

### Key Files

**Providers:**
- `lib/providers/call_provider.dart` — Central orchestrator, owns all services, handles state machine (idle → connecting → connected → error)
- `lib/providers/lobby_provider.dart` — Room list, server connection, saved rooms

**Services:**
- `lib/services/signaling_service.dart` — Socket.io signaling (join-room, offer/answer, ICE, mute-status)
- `lib/services/webrtc_service.dart` — WebRTC peer connection, local/remote streams, Opus SDP modification
- `lib/services/audio_level_monitor.dart` — Polls WebRTC stats every 100ms for voice activity
- `lib/services/stats_monitor.dart` — Connection quality (RTT, jitter, packet loss) polled every 2s
- `lib/services/audio_device_service.dart` — Input/output device selection
- `lib/services/foreground_service_manager.dart` — Android/iOS background audio via foreground task
- `lib/services/audio_session_manager.dart` — Audio session config (communication mode)

**Models:**
- `lib/models/call_state.dart` — Immutable state model with status enum
- `lib/models/connection_stats.dart` — Quality calculation from WebRTC stats
- `lib/models/peer_info.dart` — Peer with speaking state tracking
- `lib/models/room_info.dart` — Room and peer data for lobby

**Server:**
- `server/index.js` — Socket.io signaling, room management, TURN credential generation (HMAC-SHA1, 24h expiry)
- `server/docker-compose.yml` — Signaling + coturn TURN server
- `server/turnserver.conf` — TURN config (realm: voip-p2p, relay all IPs)

## Socket.io Protocol

Client → Server: `join-room {roomId, peerId, username}`, `leave-room`, `list-rooms`, `offer {to, from, offer}`, `answer {to, from, answer}`, `ice-candidate {to, from, candidate}`, `mute-status {isMuted}`

Server → Client: `turn-credentials {username, credential}`, `room-peers [{peerId, username, isMuted}]`, `peer-joined {peerId, username}`, `peer-left {peerId}`, `room-list [...]`, `room-list-update [...]`, `peer-mute-status {peerId, isMuted}`

## Critical Patterns

**Pending event buffering:** Offers, answers, and ICE candidates received before `_webrtcReady` is true are queued and flushed once WebRTC initializes. This prevents race conditions during TURN credential fetching.

**TURN credential flow:** Server sends `turn-credentials` immediately on `join-room`. Client waits for credentials before initializing `RTCPeerConnection` with the TURN server in the ICE config.

**Glare resolution:** When both peers send offers simultaneously, the peer with the lexicographically lower `peerId` becomes the offerer; the other rolls back and waits.

**Speaking detection:** Audio level > 0.02 threshold triggers speaking state on `PeerInfo`.

## Key Dependencies

- `flutter_webrtc` — WebRTC P2P audio
- `provider` — State management
- `socket_io_client` — Signaling transport
- `permission_handler` — Microphone permissions
- `flutter_foreground_task` — Background audio (Android/iOS)
- `wakelock_plus` — CPU wake lock during calls
- `window_manager` — Desktop window control (custom title bar)
- `shared_preferences` — Persists username, audio devices, saved rooms

## Documentation

- `flutter-voip-specs.md` — Detailed Italian specs (architecture, implementation, optimization)
- `voip_p2p/ROADMAP.md` — Feature roadmap (Tier 1-3 priorities)
