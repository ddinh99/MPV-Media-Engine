// lib/services/preferences_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import '../models/preset.dart';
import '../models/video_preset.dart';

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

  static const String _kCustomPresets = 'custom_presets';

  static Future<List<Preset>> getCustomPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kCustomPresets);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Preset.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Failed to load custom presets: $e');
      return [];
    }
  }

  static Future<void> saveCustomPresets(List<Preset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(presets.map((e) => e.toJson()).toList());
    await prefs.setString(_kCustomPresets, jsonStr);
  }

  static const String _kCustomVideoPresets = 'custom_video_presets';

  static Future<List<VideoPreset>> getCustomVideoPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kCustomVideoPresets);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => VideoPreset.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Failed to load custom video presets: $e');
      return [];
    }
  }

  static Future<void> saveCustomVideoPresets(List<VideoPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(presets.map((e) => e.toJson()).toList());
    await prefs.setString(_kCustomVideoPresets, jsonStr);
  }

  static Future<void> clearMpvExePath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMpvExePath);
  }

  static const String _kIsDarkTheme = 'is_dark_theme'; // legacy (pre-teal)
  static const String _kThemeMode = 'theme_mode';

  static Future<AppThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeMode);
    if (stored != null) {
      return AppThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => AppThemeMode.dark,
      );
    }
    // Migrate from the old boolean flag: an explicit `false` means the user
    // had chosen light; anything else (including no saved value) defaults to
    // dark, matching the current default.
    final legacy = prefs.getBool(_kIsDarkTheme);
    return legacy == false ? AppThemeMode.light : AppThemeMode.dark;
  }

  static Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }

  static const String _kDismissedUpdateVersion = 'dismissed_update_version';

  static Future<String?> getDismissedUpdateVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDismissedUpdateVersion);
  }

  static Future<void> setDismissedUpdateVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDismissedUpdateVersion, version);
  }
}
