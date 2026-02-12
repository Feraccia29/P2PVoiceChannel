import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/call_state.dart';
import '../providers/call_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_status_indicator.dart';
import '../widgets/call_timer.dart';
import '../widgets/participant_list.dart';
import '../widgets/connection_quality_badge.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final provider = Provider.of<CallProvider>(context, listen: false);
        provider.disconnect();
        Navigator.of(context).pop();
      },
      child: Scaffold(
        body: Container(
          color: AppTheme.backgroundDark,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: Consumer<CallProvider>(
                    builder: (context, provider, _) =>
                        _buildBody(context, provider),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, provider, _) {
        final roomName = provider.currentRoomId
                ?.replaceAll('-', ' ')
                .split(' ')
                .map((w) =>
                    w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
                .join(' ') ??
            'Voice Channel';

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Material(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: InkWell(
                  onTap: () {
                    provider.disconnect();
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back, color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roomName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentPurple,
                        letterSpacing: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      provider.localUsername ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.isConnected)
                ConnectionQualityBadge(
                  statsStream: provider.connectionStatsStream,
                  initialStats: provider.lastConnectionStats,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, CallProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Status indicator when not connected
          if (provider.callState.state != CallState.connected)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child:
                  AnimatedStatusIndicator(state: provider.callState.state),
            ),

          // Participant list
          if (provider.peers.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: ParticipantList(
                  peers: provider.peers,
                  localAudioLevel: provider.localAudioLevel,
                  remoteAudioLevel: provider.remoteAudioLevel,
                ),
              ),
            )
          else
            const Spacer(),

          // Call timer
          if (provider.callState.connectedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _buildTimerCard(provider.callState.connectedAt!),
            ),

          // Error message
          if (provider.callState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildErrorCard(provider.callState.errorMessage!),
            ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildActionButtons(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerCard(DateTime connectedAt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 18, color: Colors.white54),
          const SizedBox(width: 8),
          CallTimer(
            connectedAt: connectedAt,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, CallProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (provider.callState.state != CallState.idle) ...[
          _buildMuteButton(provider),
          const SizedBox(width: 20),
        ],
        _buildDisconnectButton(context, provider),
      ],
    );
  }

  Widget _buildDisconnectButton(BuildContext context, CallProvider provider) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        color: AppTheme.errorRed,
        boxShadow: [
          BoxShadow(
            color: AppTheme.errorRed.withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            provider.disconnect();
            Navigator.of(context).pop();
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.call_end, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'ESCI',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMuteButton(CallProvider provider) {
    final isMuted = provider.callState.isMuted;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMuted ? AppTheme.errorRed : AppTheme.cardBackground,
        border: Border.all(
          color: isMuted ? AppTheme.errorRed : AppTheme.accentPurple,
          width: 2,
        ),
        boxShadow: isMuted
            ? [AppTheme.glowShadow(AppTheme.errorRed)]
            : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: provider.toggleMute,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(
              isMuted ? Icons.mic_off : Icons.mic,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String errorMessage) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.errorRed),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: AppTheme.errorRed,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
