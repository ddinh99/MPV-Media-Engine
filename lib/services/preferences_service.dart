// lib/services/preferences_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _kMpvExePath = 'mpv_exe_path';

  static Future<String?> getMpvExePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kMpvExePath);
  }

  static Future<void> setMpvExePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMpvExePath, path);
  }

  static Future<void> clearMpvExePath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMpvExePath);
  }
}
