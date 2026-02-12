import 'package:flutter/material.dart';
import '../models/peer_info.dart';
import '../theme/app_theme.dart';
import 'voice_activity_ring.dart';

class ParticipantTile extends StatelessWidget {
  final PeerInfo peer;
  final Stream<double>? audioLevelStream;

  const ParticipantTile({
    super.key,
    required this.peer,
    this.audioLevelStream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: peer.isSpeaking && !peer.isMuted
              ? AppTheme.connectedGreen.withValues(alpha: 0.5)
              : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              peer.isLocal ? '${peer.username} (Tu)' : peer.username,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildStatusIcon(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatar = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: peer.isLocal ? null : AppTheme.accentGradient,
        color: peer.isLocal ? AppTheme.accentPurple : null,
      ),
      child: Center(
        child: Text(
          peer.username.isNotEmpty ? peer.username[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );

    if (audioLevelStream != null && !peer.isMuted) {
      return VoiceActivityRing(
        audioLevelStream: audioLevelStream!,
        maxScale: 1.1,
        child: avatar,
      );
    }
    return avatar;
  }

  Widget _buildStatusIcon() {
    if (peer.isMuted) {
      return const Icon(Icons.mic_off, color: AppTheme.errorRed, size: 20);
    }
    if (peer.isSpeaking) {
      return const Icon(Icons.volume_up, color: AppTheme.connectedGreen, size: 20);
    }
    return const Icon(Icons.mic, color: Colors.white38, size: 20);
  }
}
