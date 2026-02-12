import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/lobby_provider.dart';
import '../providers/call_provider.dart';
import '../models/room_info.dart';
import '../theme/app_theme.dart';
import '../widgets/username_dialog.dart';
import '../services/preferences_service.dart';
import 'call_screen.dart';
import 'settings_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _roomNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkUsername();
  }

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername() async {
    if (await PreferencesService.hasUsername()) return;
    if (mounted) {
      _showUsernameDialog();
    }
  }

  void _showUsernameDialog() {
    final lobby = Provider.of<LobbyProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UsernameDialog(
        initialUsername: lobby.localUsername,
        onUsernameSaved: (username) {
          lobby.setUsername(username);
        },
      ),
    );
  }

  void _joinRoom(String roomId) {
    final lobby = Provider.of<LobbyProvider>(context, listen: false);
    if (lobby.localUsername == null) {
      _showUsernameDialog();
      return;
    }

    lobby.addSavedRoom(roomId);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CallProvider(
            signalingService: lobby.signalingService,
            localPeerId: lobby.localPeerId!,
            localUsername: lobby.localUsername!,
          )..connect(roomId),
          child: const CallScreen(),
        ),
      ),
    ).then((_) {
      lobby.returnedToLobby();
    });
  }

  void _openSettings(LobbyProvider lobby) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          currentUsername: lobby.localUsername,
          onUsernameChanged: (username) {
            lobby.setUsername(username);
          },
        ),
      ),
    );
  }

  void _onCreateOrJoin() {
    final name = _roomNameController.text.trim();
    if (name.isEmpty) return;

    final roomId = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-');
    if (roomId.isEmpty) return;

    _joinRoom(roomId);
    _roomNameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppTheme.backgroundDark,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildCreateRoomBar(),
              const SizedBox(height: 8),
              Expanded(child: _buildRoomList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<LobbyProvider>(
      builder: (context, lobby, _) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Voice Channels',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentPurple,
                letterSpacing: 1.5,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  child: InkWell(
                    onTap: _showUsernameDialog,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person,
                            size: 20,
                            color: AppTheme.accentPurple,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lobby.localUsername ?? 'Set Username',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.settings, color: AppTheme.textSecondary),
                  onPressed: () => _openSettings(lobby),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateRoomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _roomNameController,
              decoration: const InputDecoration(
                hintText: 'Enter channel name...',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.add, color: AppTheme.accentPurple),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(color: Colors.white),
              onSubmitted: (_) => _onCreateOrJoin(),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _onCreateOrJoin,
            child: const Text('JOIN'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList() {
    return Consumer<LobbyProvider>(
      builder: (context, lobby, _) {
        if (!lobby.isConnected && !lobby.isConnecting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off,
                    size: 48, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text(
                  lobby.localUsername == null
                      ? 'Set a username to connect'
                      : 'Not connected to server',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ),
          );
        }

        if (lobby.isConnecting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.accentPurple),
                SizedBox(height: 16),
                Text(
                  'Connecting to server...',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          );
        }

        final rooms = lobby.rooms;

        if (rooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.headset,
                    size: 48, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text(
                  'No active channels',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create one using the field above!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return _buildRoomCard(room, isSaved: lobby.isRoomSaved(room.roomId));
          },
        );
      },
    );
  }

  Widget _buildRoomCard(RoomInfo room, {bool isSaved = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _joinRoom(room.roomId),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: room.peerCount > 0
                        ? AppTheme.accentGradient
                        : null,
                    color: room.peerCount == 0
                        ? AppTheme.borderColor
                        : null,
                  ),
                  child: Center(
                    child: room.peerCount > 0
                        ? Text(
                            '${room.peerCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : Icon(Icons.headset,
                            size: 20,
                            color: Colors.white.withValues(alpha: 0.4)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.headset,
                              size: 16, color: AppTheme.accentPurple),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              room.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (room.peers.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          room.peers.map((p) => p.username).join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ] else if (isSaved) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'Nessuno online',
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSaved) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.3)),
                    onPressed: () {
                      final lobby = Provider.of<LobbyProvider>(context, listen: false);
                      lobby.removeSavedRoom(room.roomId);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: const Text(
                    'JOIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
