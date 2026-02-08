import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestMicrophonePermission() async {
    // Su web, i permessi sono gestiti dal browser quando si chiama getUserMedia
    if (kIsWeb) {
      return true;
    }

    final status = await Permission.microphone.request();

    if (status.isGranted) {
      return true;
    } else if (status.isDenied || status.isPermanentlyDenied) {
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
      return false;
    }

    return false;
  }

  static Future<bool> checkMicrophonePermission() async {
    if (kIsWeb) {
      return true;
    }
    return await Permission.microphone.isGranted;
  }
}
