import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import '../models/room_info.dart';
import '../services/signaling_service.dart';
import '../services/preferences_service.dart';

class LobbyProvider with ChangeNotifier {
  final SignalingService signalingService = SignalingService();

  String? _localPeerId;
  String? _localUsername;
  List<RoomInfo> _serverRooms = [];
  Set<String> _savedRoomIds = {};
  bool _isConnected = false;
  bool _isConnecting = false;

  String? get localPeerId => _localPeerId;
  String? get localUsername => _localUsername;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  /// Merged list: server rooms + saved rooms not active on server (peerCount 0).
  /// Saved rooms come first, in saved order.
  List<RoomInfo> get rooms {
    final merged = <RoomInfo>[];

    // Saved rooms: use server data if active, otherwise show with 0 peers
    for (final roomId in _savedRoomIds) {
      final serverRoom = _serverRooms.where((r) => r.roomId == roomId).firstOrNull;
      merged.add(serverRoom ?? RoomInfo(roomId: roomId, peerCount: 0, peers: const []));
    }

    // Server rooms not saved (active but not bookmarked)
    for (final room in _serverRooms) {
      if (!_savedRoomIds.contains(room.roomId)) {
        merged.add(room);
      }
    }

    return merged;
  }

  bool isRoomSaved(String roomId) => _savedRoomIds.contains(roomId);

  LobbyProvider() {
    _localPeerId = const Uuid().v4();
    _loadUsernameAndConnect();
  }

  Future<void> _loadUsernameAndConnect() async {
    _localUsername = await PreferencesService.getUsername();
    final savedRooms = await PreferencesService.getSavedRooms();
    _savedRoomIds = savedRooms.toSet();
    notifyListeners();

    if (_localUsername != null) {
      connectToServer();
    }
  }

  void connectToServer() {
    if (_isConnected || _isConnecting) return;
    if (_localUsername == null || _localUsername!.isEmpty) return;

    _isConnecting = true;
    notifyListeners();

    signalingService.onConnected = () {
      _isConnected = true;
      _isConnecting = false;
      notifyListeners();
      signalingService.requestRoomList();
    };

    signalingService.onRoomListReceived = _handleRoomList;
    signalingService.onRoomListUpdate = _handleRoomList;

    signalingService.connect(_localPeerId!, username: _localUsername!);
  }

  void _handleRoomList(List<Map<String, dynamic>> data) {
    _serverRooms = data.map((r) => RoomInfo.fromMap(r)).toList();
    notifyListeners();
  }

  Future<void> addSavedRoom(String roomId) async {
    _savedRoomIds.add(roomId);
    notifyListeners();
    await PreferencesService.addSavedRoom(roomId);
  }

  Future<void> removeSavedRoom(String roomId) async {
    _savedRoomIds.remove(roomId);
    notifyListeners();
    await PreferencesService.removeSavedRoom(roomId);
  }

  Future<void> setUsername(String username) async {
    await PreferencesService.setUsername(username);
    _localUsername = username;
    notifyListeners();

    if (!_isConnected && !_isConnecting) {
      connectToServer();
    }
  }

  void refreshRoomList() {
    signalingService.requestRoomList();
  }

  /// Called when user returns from CallScreen to lobby.
  void returnedToLobby() {
    signalingService.onConnected = () {
      _isConnected = true;
      _isConnecting = false;
      notifyListeners();
      signalingService.requestRoomList();
    };
    signalingService.onRoomListReceived = _handleRoomList;
    signalingService.onRoomListUpdate = _handleRoomList;
    signalingService.requestRoomList();
  }

  @override
  void dispose() {
    signalingService.disconnect();
    super.dispose();
  }
}
