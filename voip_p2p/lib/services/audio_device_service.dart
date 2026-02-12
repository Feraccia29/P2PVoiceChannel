import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'preferences_service.dart';

class AudioDeviceService {
  /// Returns list of available audio input devices.
  static Future<List<MediaDeviceInfo>> getInputDevices() async {
    final devices = await navigator.mediaDevices.enumerateDevices();
    return devices.where((d) => d.kind == 'audioinput').toList();
  }

  /// Gets the saved preferred input device ID (null = system default).
  static Future<String?> getPreferredInputDeviceId() {
    return PreferencesService.getInputDeviceId();
  }

  /// Saves preferred input device ID. Pass null to reset to system default.
  static Future<void> setPreferredInputDeviceId(String? deviceId) {
    return PreferencesService.setInputDeviceId(deviceId);
  }

  /// Returns list of available audio output devices.
  static Future<List<MediaDeviceInfo>> getOutputDevices() async {
    final devices = await navigator.mediaDevices.enumerateDevices();
    return devices.where((d) => d.kind == 'audiooutput').toList();
  }

  /// Gets the saved preferred output device ID (null = system default).
  static Future<String?> getPreferredOutputDeviceId() {
    return PreferencesService.getOutputDeviceId();
  }

  /// Saves preferred output device ID. Pass null to reset to system default.
  static Future<void> setPreferredOutputDeviceId(String? deviceId) {
    return PreferencesService.setOutputDeviceId(deviceId);
  }
}
