import 'dart:async';
import 'webrtc_service.dart';

class AudioLevelMonitor {
  final WebRTCService _webrtcService;
  Timer? _timer;

  final StreamController<double> _localLevelController =
      StreamController<double>.broadcast();
  final StreamController<double> _remoteLevelController =
      StreamController<double>.broadcast();

  Stream<double> get localAudioLevel => _localLevelController.stream;
  Stream<double> get remoteAudioLevel => _remoteLevelController.stream;

  static const Duration _pollInterval = Duration(milliseconds: 100);

  AudioLevelMonitor(this._webrtcService);

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _pollStats());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (!_localLevelController.isClosed) _localLevelController.add(0.0);
    if (!_remoteLevelController.isClosed) _remoteLevelController.add(0.0);
  }

  Future<void> _pollStats() async {
    try {
      final reports = await _webrtcService.getStats();

      double localLevel = 0.0;
      double remoteLevel = 0.0;

      for (final report in reports) {
        final type = report.type;
        final values = report.values;

        // Remote audio level from inbound-rtp
        if (type == 'inbound-rtp') {
          final kind = values['kind'] as String?;
          if (kind == 'audio') {
            final level = values['audioLevel'];
            if (level != null) {
              remoteLevel = (level as num).toDouble();
            } else {
              // Fallback: compute from totalAudioEnergy
              final energy =
                  (values['totalAudioEnergy'] as num?)?.toDouble();
              final duration =
                  (values['totalSamplesDuration'] as num?)?.toDouble();
              if (energy != null && duration != null && duration > 0) {
                remoteLevel = (energy / duration).clamp(0.0, 1.0);
              }
            }
          }
        }

        // Local audio level from media-source
        if (type == 'media-source') {
          final kind = values['kind'] as String?;
          if (kind == 'audio') {
            final level = values['audioLevel'];
            if (level != null) {
              localLevel = (level as num).toDouble();
            }
          }
        }
      }

      if (!_localLevelController.isClosed) _localLevelController.add(localLevel);
      if (!_remoteLevelController.isClosed) _remoteLevelController.add(remoteLevel);
    } catch (_) {
      // Silently ignore stats errors -- non-critical
    }
  }

  void dispose() {
    stop();
    _localLevelController.close();
    _remoteLevelController.close();
  }
}
