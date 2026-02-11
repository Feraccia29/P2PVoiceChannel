import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundServiceManager {
  bool _isRunning = false;

  /// Configura i parametri del foreground task. Chiamare una volta all'avvio.
  void initialize() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'voip_p2p_call',
        channelName: 'VoiP2P Active Call',
        channelDescription: 'Notifica durante chiamata vocale attiva',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Avvia il foreground service quando la chiamata inizia.
  Future<void> startService() async {
    if (_isRunning || !Platform.isAndroid) return;

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'VoiP2P',
      notificationText: 'Chiamata in corso',
    );
    _isRunning = true;
  }

  /// Ferma il foreground service quando la chiamata termina.
  Future<void> stopService() async {
    if (!_isRunning || !Platform.isAndroid) return;

    await FlutterForegroundTask.stopService();
    _isRunning = false;
  }

  bool get isRunning => _isRunning;
}
