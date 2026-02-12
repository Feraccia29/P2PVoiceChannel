import 'dart:async';
import 'package:flutter/material.dart';
import '../models/connection_stats.dart';
import '../theme/app_theme.dart';

class ConnectionQualityBadge extends StatefulWidget {
  final Stream<ConnectionStats> statsStream;
  final ConnectionStats? initialStats;

  const ConnectionQualityBadge({
    super.key,
    required this.statsStream,
    this.initialStats,
  });

  @override
  State<ConnectionQualityBadge> createState() => _ConnectionQualityBadgeState();
}

class _ConnectionQualityBadgeState extends State<ConnectionQualityBadge> {
  ConnectionStats? _stats;
  StreamSubscription<ConnectionStats>? _sub;

  @override
  void initState() {
    super.initState();
    _stats = widget.initialStats;
    _sub = widget.statsStream.listen((stats) {
      if (mounted) setState(() => _stats = stats);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Color _qualityColor(ConnectionQuality q) {
    switch (q) {
      case ConnectionQuality.good:
        return AppTheme.connectedGreen;
      case ConnectionQuality.fair:
        return AppTheme.connectingOrange;
      case ConnectionQuality.poor:
        return AppTheme.errorRed;
      case ConnectionQuality.unknown:
        return AppTheme.idleGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final quality = _stats?.quality ?? ConnectionQuality.unknown;
    final color = _qualityColor(quality);

    return Material(
      color: AppTheme.cardBackground,
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      child: InkWell(
        onTap: _stats != null ? () => _showStatsDetail(context) : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _buildSignalBars(quality, color),
        ),
      ),
    );
  }

  Widget _buildSignalBars(ConnectionQuality quality, Color color) {
    final barsActive = switch (quality) {
      ConnectionQuality.good => 3,
      ConnectionQuality.fair => 2,
      ConnectionQuality.poor => 1,
      ConnectionQuality.unknown => 0,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final height = 8.0 + (i * 5.0);
        final isActive = i < barsActive;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 4,
          height: height,
          decoration: BoxDecoration(
            color: isActive ? color : Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  void _showStatsDetail(BuildContext context) {
    final stats = _stats!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSignalBars(stats.quality, _qualityColor(stats.quality)),
                const SizedBox(width: 12),
                Text(
                  _qualityLabel(stats.quality),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _qualityColor(stats.quality),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _statRow('Latenza (RTT)', '${stats.rttMs.toStringAsFixed(0)} ms'),
            _statRow('Jitter', '${stats.jitterMs.toStringAsFixed(1)} ms'),
            _statRow(
                'Perdita pacchetti',
                '${stats.packetLossPercent.toStringAsFixed(1)}%'),
            _statRow('Codec', stats.codec),
            _statRow(
                'Bitrate', '${stats.bitrateKbps.toStringAsFixed(0)} kbps'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _qualityLabel(ConnectionQuality q) {
    switch (q) {
      case ConnectionQuality.good:
        return 'Connessione Ottima';
      case ConnectionQuality.fair:
        return 'Connessione Discreta';
      case ConnectionQuality.poor:
        return 'Connessione Scarsa';
      case ConnectionQuality.unknown:
        return 'Sconosciuta';
    }
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
