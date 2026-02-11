# Roadmap - P2P Voice Channel

Roadmap completa delle funzionalita pianificate per trasformare l'app da prototipo minimale a voice channel gaming-oriented completo (stile Discord/TeamSpeak semplificato).

---

## Stato Attuale

- **1 schermata** (CallScreen): indicatore stato, bottone connetti/disconnetti, bottone mute
- **Nessuna navigazione** - app a schermata singola
- **Room hardcoded** (`gaming-voice-channel`)
- **Nessun username** - peer identificati solo da UUID
- **Nessun feedback audio** visivo
- **Nessuna statistica** connessione
- **Nessuna impostazione** - tutto hardcoded
- **Nessuna animazione**

---

## Tier 1 - Alta Priorita

Le funzionalita che trasformano l'app in un prodotto completo. Ordinate per dipendenze.

### Fase 1: Foundation

#### 1.1 Redesign UI Completo

Tema dark gaming-oriented con animazioni di transizione.

**Design:**
- Background: gradient `#0a0e27` -> `#1a1a3e`
- Accent color: `#7c4dff` (electric purple)
- Card surfaces: `#16213e` con bordo sottile `#1a2744`
- Testo primario: bianco, secondario: `#8892b0`
- Border radius: 16px, ombre sottili con accent a bassa opacita
- Animazioni: `AnimatedSwitcher` per transizioni stato, pulse per connecting, glow per connected

**File da creare:**
- `lib/theme/app_theme.dart` - Definizione tema centralizzata (colori, typography, componenti)
- `lib/widgets/animated_status_indicator.dart` - Indicatore stato con animazioni per ogni `CallState`

**File da modificare:**
- `lib/main.dart` - Sostituire `ThemeData.dark()` con `AppTheme.darkTheme`
- `lib/screens/call_screen.dart` - Ristrutturazione completa del layout

**Package opzionale:** `google_fonts: ^6.2.1`

**Nessuna modifica server.**

---

#### 1.2 Username / Nickname

Username persistente trasmesso ai peer via signaling.

**Design:**
- Al primo avvio (o se nessun username salvato): bottom sheet per inserimento nickname
- Validazione: 2-20 caratteri
- Visibile nella lobby, nel pannello partecipanti, trasmesso ai peer

**File da creare:**
- `lib/services/preferences_service.dart` - Wrapper SharedPreferences per username e future preferenze
- `lib/widgets/username_dialog.dart` - Dialog/bottom sheet per inserimento username

**File da modificare:**
- `lib/services/signaling_service.dart` - `joinRoom` include username nel payload
- `lib/providers/call_provider.dart` - Carica username da preferences, lo passa al signaling

**Modifiche server (`server/index.js`):**
- Struttura dati rooms: da `Set<peerId>` a `Map<peerId, {username, isMuted}>`
- `join-room` accetta campo `username`
- `peer-joined` e `peer-left` includono `username` nel payload
- `room-list` e `room-peers` includono usernames

**Nuovo package:** `shared_preferences: ^2.3.3`

---

#### 1.3 Timer Durata Chiamata

Contatore `MM:SS` visibile durante la connessione.

**Design:**
- Formato: `MM:SS` (o `HH:MM:SS` se > 1 ora)
- Visibile sotto la lista partecipanti o nella AppBar
- Si avvia quando `CallState.connected`, si resetta al disconnect
- Stile: testo secondario, font piccolo

**File da creare:**
- `lib/widgets/call_timer.dart` - Widget con `Timer.periodic(Duration(seconds: 1))`

**File da modificare:**
- `lib/models/call_state.dart` - Aggiungere campo `DateTime? connectedAt` a `CallStateModel`
- `lib/providers/call_provider.dart` - Settare `connectedAt` nelle transizioni di stato

**Nessuna modifica server.**

---

### Fase 2: Core UX

#### 2.1 Selezione Room / Canale (Lobby Screen)

Schermata home con lista canali vocali e possibilita di creare/unirsi a stanze.

**Design:**
- Lista canali con: icona cuffie, nome canale, badge conteggio partecipanti, freccia "Join"
- Campo testo per creare/unirsi a canale per nome
- Canale attivo evidenziato con bordo accent
- Empty state con icona e messaggio "Nessun canale - creane uno!"

**Struttura navigazione:**
```
App Launch -> Lobby Screen -> (tap canale) -> Voice Channel Screen
                  |
                  +-> Settings Screen (icona ingranaggio)
```

**File da creare:**
- `lib/screens/lobby_screen.dart` - Nuova schermata home con `ListView.builder` di canali
- `lib/models/room_info.dart` - Modello dati room (`roomId`, `displayName`, `peerCount`)
- `lib/providers/lobby_provider.dart` - Gestisce connessione signaling per browsing rooms

**File da modificare:**
- `lib/services/signaling_service.dart`:
  - Separare `connect()` da `joinRoom()` (ora connect auto-joina)
  - Aggiungere `requestRoomList()` che emette `list-rooms`
  - Aggiungere `leaveRoom()` senza disconnettere il socket
  - Aggiungere callback `onRoomListReceived`
- `lib/providers/call_provider.dart` - `connect()` accetta `roomId` parametro dinamico
- `lib/main.dart` - Home cambia da `CallScreen` a `LobbyScreen`, `MultiProvider`

**Modifiche server (`server/index.js`):**
```javascript
// Nuovo evento: lista rooms
socket.on('list-rooms', () => {
  const roomList = [];
  rooms.forEach((peers, roomId) => {
    roomList.push({ roomId, peerCount: peers.size });
  });
  socket.emit('room-list', roomList);
});

// Broadcast aggiornamento rooms quando peers join/leave
io.emit('room-list-update', { roomId, peerCount: room.size });

// Invio lista partecipanti al join
socket.emit('room-peers', peerList);
```

---

#### 2.2 Indicatore Attivita Vocale

Feedback visivo quando un utente parla.

**Design:**
- Anelli concentrici che si espandono con fade attorno all'avatar
- Quando audio level > soglia: 2-3 cerchi in espansione con colore accent
- Per utente locale: basato su audio track locale
- Per utente remoto: basato su audio track in arrivo (WebRTC `getStats()`)
- Simile al ring verde di Discord

**File da creare:**
- `lib/services/audio_level_monitor.dart` - Polling `getStats()` ogni 100ms, stream di livelli audio normalizzati (0.0-1.0) per locale e remoto
- `lib/widgets/voice_activity_ring.dart` - Widget animato che renderizza ring in espansione attorno a un child

**File da modificare:**
- `lib/services/webrtc_service.dart` - Esporre metodo `getStats()`:
  ```dart
  Future<List<StatsReport>> getStats() async {
    return await _peerConnection?.getStats() ?? [];
  }
  ```
- `lib/providers/call_provider.dart` - Creare/gestire `AudioLevelMonitor`, esporre `Stream<double>` per audio levels

**Nessuna modifica server.**

---

### Fase 3: Integrazione

#### 3.1 Pannello Partecipanti

Lista partecipanti con avatar, username, indicatore voce e stato mute.

**Design:**
```
┌──────────────────────────────────┐
│  AppBar: Nome Room + Qualita     │
├──────────────────────────────────┤
│                                  │
│  Lista Partecipanti              │
│  ┌────────────────────────────┐  │
│  │ [A] Alice (Tu)        🎤  │  │
│  │ [B] Bob               🔊  │  │
│  │ [C] Charlie           🔇  │  │
│  └────────────────────────────┘  │
│                                  │
│  Timer: 05:23                    │
│                                  │
├──────────────────────────────────┤
│  [🎤 Mute]        [🔴 Esci]     │
└──────────────────────────────────┘
```

**File da creare:**
- `lib/models/peer_info.dart` - Modello peer (`peerId`, `username`, `isMuted`, `isSpeaking`, `isLocal`)
- `lib/widgets/participant_tile.dart` - Riga singolo partecipante (avatar cerchio con iniziale, nome, icone stato)
- `lib/widgets/participant_list.dart` - Lista scrollabile di `ParticipantTile`

**File da modificare:**
- `lib/providers/call_provider.dart`:
  - Aggiungere `List<PeerInfo> _peers`
  - Aggiornare in `_handlePeerJoined` / `_handlePeerLeft`
  - Tracciare stato mute remoto
- `lib/services/signaling_service.dart`:
  - Aggiungere `sendMuteStatus(roomId, isMuted)`
  - Listener per `peer-mute-status`
  - Callback `onPeerMuteStatusChanged`
- `lib/screens/call_screen.dart` (o rinominare `voice_channel_screen.dart`) - Layout completo come mockup sopra

**Modifiche server (`server/index.js`):**
```javascript
// Relay stato mute
socket.on('mute-status', ({ roomId, peerId, isMuted }) => {
  // Broadcast a tutti i peer nella room tranne il mittente
  io.to(existingPeerId).emit('peer-mute-status', { peerId, isMuted });
});
```

---

#### 3.2 Indicatore Qualita Connessione

Indicatore visivo della salute della connessione.

**Design:**
- Icona signal bars nella AppBar o accanto ai nomi partecipanti
- 3 stati: verde (buona), giallo (degradata), rosso (scarsa)
- Soglie: verde < 100ms RTT / <1% loss, giallo < 250ms / <5%, rosso >= 250ms / >=5%
- Tap per espandere: latenza (ms), packet loss (%), jitter (ms), codec, bitrate

**File da creare:**
- `lib/models/connection_stats.dart` - Modello stats (`roundTripTime`, `packetLoss`, `jitter`, `codec`, `bitrate`, `quality` enum)
- `lib/services/stats_monitor.dart` - Polling `getStats()` ogni 2 secondi, parsing `RTCStatsReport` per candidate-pair, inbound-rtp, outbound-rtp
- `lib/widgets/connection_quality_badge.dart` - Widget icona signal bars colorata

**File da modificare:**
- `lib/providers/call_provider.dart` - Creare `StatsMonitor` quando connesso, esporre `ConnectionStats?`

**Nessuna modifica server.**

---

### Fase 4: Polish

#### 4.1 Schermata Impostazioni

Schermata per personalizzare username e preferenze audio.

**Design:**
- Accessibile via icona ingranaggio nella lobby
- Sezioni:
  - **Profilo**: campo username con salvataggio
  - **Audio**: selezione dispositivo input (se piattaforma lo supporta), toggle push-to-talk (UI only, "Coming soon")
  - **Info**: versione app, URL server (read-only), licenze

**File da creare:**
- `lib/screens/settings_screen.dart` - Schermata settings con `ListTile` e `SwitchListTile`
- `lib/services/audio_device_service.dart` (opzionale) - Wrapper per enumerazione dispositivi audio

**File da modificare:**
- `lib/screens/lobby_screen.dart` - Aggiungere icona settings nella AppBar

**Nessuna modifica server.**

---

## Riepilogo Modifiche Server (tutte le feature Tier 1)

Modifiche a `server/index.js`:

| Modifica | Feature |
|----------|---------|
| Struttura rooms: `Set<peerId>` -> `Map<peerId, {username, isMuted}>` | 1.2, 3.1 |
| `join-room` accetta `username` | 1.2 |
| `peer-joined`/`peer-left` includono `username` | 1.2 |
| Nuovo evento `list-rooms` -> `room-list` | 2.1 |
| Broadcast `room-list-update` su join/leave | 2.1 |
| Invio `room-peers` al join (lista partecipanti correnti) | 2.1 |
| Evento `mute-status` -> `peer-mute-status` relay | 3.1 |

## Riepilogo Nuovi Package Flutter

| Package | Feature | Note |
|---------|---------|------|
| `shared_preferences: ^2.3.3` | 1.2 | Persistenza username |
| `google_fonts: ^6.2.1` | 1.1 | Opzionale, typography moderna |

## Riepilogo Nuovi File Flutter

```
voip_p2p/lib/
├── theme/
│   └── app_theme.dart                      # 1.1
├── models/
│   ├── room_info.dart                      # 2.1
│   ├── peer_info.dart                      # 3.1
│   └── connection_stats.dart               # 3.2
├── services/
│   ├── preferences_service.dart            # 1.2
│   ├── audio_level_monitor.dart            # 2.2
│   ├── stats_monitor.dart                  # 3.2
│   └── audio_device_service.dart           # 4.1 (opzionale)
├── providers/
│   └── lobby_provider.dart                 # 2.1
├── screens/
│   ├── lobby_screen.dart                   # 2.1
│   ├── voice_channel_screen.dart           # 1.1 (rename di call_screen)
│   └── settings_screen.dart                # 4.1
└── widgets/
    ├── animated_status_indicator.dart       # 1.1
    ├── username_dialog.dart                 # 1.2
    ├── call_timer.dart                      # 1.3
    ├── voice_activity_ring.dart             # 2.2
    ├── participant_tile.dart                # 3.1
    ├── participant_list.dart                # 3.1
    └── connection_quality_badge.dart        # 3.2
```

---

## Tier 2 - Media Priorita

Funzionalita nice-to-have che migliorano l'esperienza ma non sono essenziali.

### Push-to-Talk
- Modalita "premi per parlare" attivabile nelle impostazioni
- `GestureDetector` long-press sul bottone o hotkey desktop
- Modifica `WebRTCService.toggleMute()` per attivare solo durante pressione
- **Effort:** Medio

### Controllo Volume Per-Peer
- Slider volume per ogni partecipante nel pannello
- Usa `RTCRTPReceiver.setVolume()` o Web Audio API
- **Effort:** Medio

### Routing Output Audio
- Selezione speaker / auricolare / bluetooth
- Usa package `audio_session` per route selection
- Platform-dependent (funziona meglio su mobile)
- **Effort:** Basso-Medio

### Suoni Join/Leave
- Effetto sonoro breve quando un peer entra o esce
- Package `audioplayers` per riproduzione audio
- Suoni personalizzabili nelle impostazioni
- **Effort:** Basso

### Chat Testuale via DataChannel
- `RTCDataChannel` accanto all'audio per messaggi testo
- UI chat con input e lista messaggi
- Modello messaggio, keyboard handling
- **Effort:** Medio-Alto

### Noise Gate
- Soglia regolabile per attivazione microfono
- Monitoraggio audio level client-side, auto-mute sotto soglia
- Slider nelle impostazioni
- **Effort:** Medio

### Dettagli Stats Connessione
- Bottom sheet con dump completo `getStats()`
- Riusa `StatsMonitor` dalla feature 3.2
- Grafici temporali di latenza/jitter
- **Effort:** Basso

### Temi / Colori Accent Personalizzabili
- Color picker nelle impostazioni
- Salvataggio in SharedPreferences
- Rebuild `AppTheme` dinamico
- **Effort:** Basso

---

## Tier 3 - Bassa Priorita (Avanzato)

Funzionalita ambiziose che richiedono refactoring significativo o nuove architetture.

### Supporto Multi-Peer (3+ partecipanti)
- Architettura attuale e 1:1 P2P
- Topologia mesh: N-1 `RTCPeerConnection` per client
- Refactor maggiore di `CallProvider` e `WebRTCService`
- Limite pratico: 4-6 peer in mesh
- **Effort:** Molto Alto

### Screen Sharing
- Track video via `getDisplayMedia()`
- `RTCPeerConnection` separata o rinegoziazione
- UI per visualizzare lo schermo condiviso
- **Effort:** Alto

### Registrazione Chiamate
- Cattura stream audio su file
- Considerazioni legali/privacy
- Storage locale o cloud
- **Effort:** Alto

### Overlay Flottante per Gaming
- Android: overlay permission + `flutter_foreground_task` overlay
- Finestra mini sempre in primo piano durante i giochi
- Non disponibile su iOS
- **Effort:** Medio

### Hotkey Desktop
- Scorciatoie tastiera globali (push-to-talk, mute toggle)
- Package `hotkey_manager` per Windows/macOS/Linux
- **Effort:** Medio

### Server Browser / Discovery
- mDNS o registro centrale
- Server si annuncia sulla rete locale
- Lista server disponibili nella lobby
- **Effort:** Medio

### Indicatori Crittografia E2E
- WebRTC usa gia DTLS-SRTP
- Mostrare verifica fingerprint certificato
- UI per conferma sicurezza
- **Effort:** Basso-Medio

### Audio Spaziale
- Output stereo con HRTF processing
- Posizionamento 3D degli utenti
- Tracking posizione
- **Effort:** Molto Alto

---

## Note Architetturali

### Struttura Provider
Con l'aggiunta della lobby, il provider si divide:
- `LobbyProvider` - Gestisce connessione signaling per browsing rooms (leggero, no WebRTC)
- `CallProvider` - Gestisce la sessione vocale attiva (esistente, da estendere)

Un singolo `SignalingService` condiviso tra i provider: `LobbyProvider` lo usa solo per listing rooms, `CallProvider` per il flusso signaling completo.

### Refactoring SignalingService
Attualmente `connect()` auto-joina una room. Va separato:
- `connect(peerId)` - Connessione socket only
- `joinRoom(roomId, {username})` - Join room specifica
- `leaveRoom()` - Lascia room senza disconnettere socket

### Estensione CallStateModel
Opzioni:
1. Estendere con `connectedAt`, `roomId`, `peers`, `connectionStats`
2. Mantenere lean e esporre come getter separati su `CallProvider`

Opzione 2 consigliata: usa `Selector<CallProvider, T>` per rebuild mirati dei widget.
