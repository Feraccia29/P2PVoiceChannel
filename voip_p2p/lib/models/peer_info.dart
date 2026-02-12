class PeerInfo {
  final String peerId;
  final String username;
  final bool isMuted;
  final bool isSpeaking;
  final bool isLocal;

  const PeerInfo({
    required this.peerId,
    required this.username,
    this.isMuted = false,
    this.isSpeaking = false,
    this.isLocal = false,
  });

  PeerInfo copyWith({
    String? username,
    bool? isMuted,
    bool? isSpeaking,
    bool? isLocal,
  }) {
    return PeerInfo(
      peerId: peerId,
      username: username ?? this.username,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isLocal: isLocal ?? this.isLocal,
    );
  }
}
