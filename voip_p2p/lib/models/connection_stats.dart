enum ConnectionQuality { good, fair, poor, unknown }

class ConnectionStats {
  final double rttMs;
  final double jitterMs;
  final double packetLossPercent;
  final String codec;
  final double bitrateKbps;
  final ConnectionQuality quality;
  final DateTime timestamp;

  const ConnectionStats({
    this.rttMs = 0,
    this.jitterMs = 0,
    this.packetLossPercent = 0,
    this.codec = 'unknown',
    this.bitrateKbps = 0,
    this.quality = ConnectionQuality.unknown,
    required this.timestamp,
  });

  static ConnectionQuality computeQuality(
      double rttMs, double packetLossPercent) {
    if (rttMs < 100 && packetLossPercent < 1) return ConnectionQuality.good;
    if (rttMs < 250 && packetLossPercent < 5) return ConnectionQuality.fair;
    return ConnectionQuality.poor;
  }
}
