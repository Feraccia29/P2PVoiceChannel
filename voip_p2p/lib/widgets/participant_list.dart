import 'package:flutter/material.dart';
import '../models/peer_info.dart';
import 'participant_tile.dart';

class ParticipantList extends StatelessWidget {
  final List<PeerInfo> peers;
  final Stream<double> localAudioLevel;
  final Stream<double> remoteAudioLevel;

  const ParticipantList({
    super.key,
    required this.peers,
    required this.localAudioLevel,
    required this.remoteAudioLevel,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<PeerInfo>.from(peers)
      ..sort((a, b) {
        if (a.isLocal) return -1;
        if (b.isLocal) return 1;
        return a.username.compareTo(b.username);
      });

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final peer = sorted[index];
        return ParticipantTile(
          peer: peer,
          audioLevelStream: peer.isLocal ? localAudioLevel : remoteAudioLevel,
        );
      },
    );
  }
}
