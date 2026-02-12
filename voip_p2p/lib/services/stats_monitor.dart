import 'dart:async';
import '../models/connection_stats.dart';
import 'webrtc_service.dart';

class StatsMonitor {
  final WebRTCService _webrtcService;
  Timer? _timer;

  final StreamController<ConnectionStats> _statsController =
      StreamController<ConnectionStats>.broadcast();

  Stream<ConnectionStats> get statsStream => _statsController.stream;
  ConnectionStats? _lastStats;
  ConnectionStats? get lastStats => _lastStats;

  // For bitrate calculation
  int _prevBytesReceived = 0;
  double _prevTimestamp = 0;

  static const Duration _pollInterval = Duration(seconds: 2);

  StatsMonitor(this._webrtcService);

  void start() {
    _timer?.cancel();
    _prevBytesReceived = 0;
    _prevTimestamp = 0;
    _timer = Timer.periodic(_pollInterval, (_) => _pollStats());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _pollStats() async {
    try {
      final reports = await _webrtcService.getStats();

      double rtt = 0;
      double jitter = 0;
      double packetLoss = 0;
      String codec = 'unknown';
      double bitrate = 0;
      String? codecId;

      for (final report in reports) {
        final type = report.type;
        final values = report.values;

        if (type == 'candidate-pair') {
          final state = values['state'] as String?;
          if (state == 'succeeded' || state == 'in-progress') {
            final currentRtt = values['currentRoundTripTime'];
            if (currentRtt != null) {
              rtt = (currentRtt as num).toDouble() * 1000;
            }
          }
        }

        if (type == 'inbound-rtp') {
          final kind = values['kind'] as String?;
          if (kind == 'audio') {
            final j = values['jitter'];
            if (j != null) {
              jitter = (j as num).toDouble() * 1000;
            }

            final packetsReceived =
                (values['packetsReceived'] as num?)?.toInt() ?? 0;
            final packetsLost =
                (values['packetsLost'] as num?)?.toInt() ?? 0;
            final totalPackets = packetsReceived + packetsLost;
            if (totalPackets > 0) {
              packetLoss = (packetsLost / totalPackets) * 100;
            }

            final bytesReceived =
                (values['bytesReceived'] as num?)?.toInt() ?? 0;
            final timestamp =
                (values['timestamp'] as num?)?.toDouble() ?? 0;
            if (_prevTimestamp > 0 && timestamp > _prevTimestamp) {
              final deltaBytes = bytesReceived - _prevBytesReceived;
              final deltaSec = (timestamp - _prevTimestamp) / 1000;
              if (deltaSec > 0) {
                bitrate = (deltaBytes * 8) / deltaSec / 1000;
              }
            }
            _prevBytesReceived = bytesReceived;
            _prevTimestamp = timestamp;

            codecId = values['codecId'] as String?;
          }
        }

        if (type == 'codec' && codecId != null && report.id == codecId) {
          codec =
              (values['mimeType'] as String?)?.split('/').last ?? 'unknown';
        }
      }

      final quality = ConnectionStats.computeQuality(rtt, packetLoss);
      final stats = ConnectionStats(
        rttMs: rtt,
        jitterMs: jitter,
        packetLossPercent: packetLoss,
        codec: codec,
        bitrateKbps: bitrate,
        quality: quality,
        timestamp: DateTime.now(),
      );

      _lastStats = stats;
      if (!_statsController.isClosed) {
        _statsController.add(stats);
      }
    } catch (_) {
      // Silently ignore stats errors -- non-critical
    }
  }

  void dispose() {
    stop();
    _statsController.close();
  }
}
