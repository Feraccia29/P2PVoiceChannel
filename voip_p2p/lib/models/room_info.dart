class RoomInfo {
  final String roomId;
  final int peerCount;
  final List<RoomPeer> peers;

  const RoomInfo({
    required this.roomId,
    required this.peerCount,
    required this.peers,
  });

  factory RoomInfo.fromMap(Map<String, dynamic> map) {
    final peerList = (map['peers'] as List?)
            ?.map((p) => RoomPeer.fromMap(Map<String, dynamic>.from(p as Map)))
            .toList() ??
        [];
    return RoomInfo(
      roomId: map['roomId'] as String,
      peerCount: map['peerCount'] as int,
      peers: peerList,
    );
  }

  String get displayName {
    return roomId
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }
}

class RoomPeer {
  final String peerId;
  final String username;

  const RoomPeer({required this.peerId, required this.username});

  factory RoomPeer.fromMap(Map<String, dynamic> map) {
    return RoomPeer(
      peerId: map['peerId'] as String,
      username: map['username'] as String? ?? 'Anonymous',
    );
  }
}
