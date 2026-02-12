import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _usernameKey = 'user_username';
  static const String _inputDeviceIdKey = 'audio_input_device_id';
  static const String _outputDeviceIdKey = 'audio_output_device_id';
  static const String _savedRoomsKey = 'saved_rooms';

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<bool> setUsername(String username) async {
    if (username.length < 2 || username.length > 20) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_usernameKey, username);
  }

  static Future<bool> hasUsername() async {
    final username = await getUsername();
    return username != null && username.isNotEmpty;
  }

  static Future<String?> getInputDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_inputDeviceIdKey);
  }

  static Future<void> setInputDeviceId(String? deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    if (deviceId == null) {
      await prefs.remove(_inputDeviceIdKey);
    } else {
      await prefs.setString(_inputDeviceIdKey, deviceId);
    }
  }

  static Future<String?> getOutputDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_outputDeviceIdKey);
  }

  static Future<void> setOutputDeviceId(String? deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    if (deviceId == null) {
      await prefs.remove(_outputDeviceIdKey);
    } else {
      await prefs.setString(_outputDeviceIdKey, deviceId);
    }
  }

  static Future<List<String>> getSavedRooms() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_savedRoomsKey) ?? [];
  }

  static Future<void> addSavedRoom(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final rooms = prefs.getStringList(_savedRoomsKey) ?? [];
    if (!rooms.contains(roomId)) {
      rooms.add(roomId);
      await prefs.setStringList(_savedRoomsKey, rooms);
    }
  }

  static Future<void> removeSavedRoom(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final rooms = prefs.getStringList(_savedRoomsKey) ?? [];
    rooms.remove(roomId);
    await prefs.setStringList(_savedRoomsKey, rooms);
  }
}
