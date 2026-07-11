// lib/services/preferences_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import '../models/preset.dart';
import '../models/session.dart';
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

  // ── Last-used sessions ────────────────────────────────────────────────────
  // Restored at launch and pushed to every new MPV instance, so the user's
  // settings carry across app restarts and across videos. A decode failure
  // (schema drift from an older build) must never block startup — we fall
  // back to defaults rather than throwing.

  static const String _kLastDspSession = 'last_dsp_session';

  static Future<DspSession?> getLastDspSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kLastDspSession);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return DspSession.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (e) {
      print('Failed to load last DSP session, using defaults: $e');
      return null;
    }
  }

  static Future<void> saveLastDspSession(DspSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastDspSession, jsonEncode(session.toJson()));
  }

  static const String _kLastVideoSession = 'last_video_session';

  static Future<VideoSession?> getLastVideoSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kLastVideoSession);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return VideoSession.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (e) {
      print('Failed to load last video session, using defaults: $e');
      return null;
    }
  }

  static Future<void> saveLastVideoSession(VideoSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastVideoSession, jsonEncode(session.toJson()));
  }

  static const String _kLastRunVersion = 'last_run_version';

  /// Called once at startup, before anything else reads saved sessions or
  /// presets. Compares the version recorded on the previous run against
  /// [currentVersion]; if they differ, clears the saved DSP/video sessions
  /// and custom presets — the state most likely to carry a stale/incompatible
  /// shape from an older build — then records [currentVersion] for next
  /// time. Leaves the mpv.exe path, theme, dismissed-update-version, and
  /// default-preset selections untouched, since those aren't versioned data
  /// and wiping them would force first-run setup again on every update.
  /// A fresh install (no stored version yet) just records the version
  /// without clearing anything.
  static Future<void> resetSessionDataIfVersionChanged(
      String currentVersion) async {
    final prefs = await SharedPreferences.getInstance();
    final lastRunVersion = prefs.getString(_kLastRunVersion);
    if (lastRunVersion != null && lastRunVersion != currentVersion) {
      await prefs.remove(_kLastDspSession);
      await prefs.remove(_kLastVideoSession);
      await prefs.remove(_kCustomPresets);
      await prefs.remove(_kCustomVideoPresets);
    }
    await prefs.setString(_kLastRunVersion, currentVersion);
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

  // ── Default presets per resolution tier ────────────────────────────────────

  static const String _kDefaultPresetLowRes = 'default_preset_lowres';
  static const String _kDefaultPresetHighRes = 'default_preset_highres';

  static Future<String?> getDefaultPresetIdForLowRes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDefaultPresetLowRes);
  }

  static Future<void> setDefaultPresetIdForLowRes(String? presetId) async {
    final prefs = await SharedPreferences.getInstance();
    if (presetId == null) {
      await prefs.remove(_kDefaultPresetLowRes);
    } else {
      await prefs.setString(_kDefaultPresetLowRes, presetId);
    }
  }

  static Future<String?> getDefaultPresetIdForHighRes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDefaultPresetHighRes);
  }

  static Future<void> setDefaultPresetIdForHighRes(String? presetId) async {
    final prefs = await SharedPreferences.getInstance();
    if (presetId == null) {
      await prefs.remove(_kDefaultPresetHighRes);
    } else {
      await prefs.setString(_kDefaultPresetHighRes, presetId);
    }
  }

  // ── Current playing video info cache ────────────────────────────────────────

  static const String _kCurrentVideoInfo = 'current_video_info';

  static Future<Map<String, dynamic>?> getCurrentVideoInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kCurrentVideoInfo);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveCurrentVideoInfo(Map<String, dynamic> info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrentVideoInfo, jsonEncode(info));
  }

  static Future<void> clearCurrentVideoInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCurrentVideoInfo);
  }

  /// Wipes every stored preference — sessions, presets, mpv path, theme,
  /// dismissed-update-version, defaults, the lot. A diagnostic/reset escape
  /// hatch for when a stored value is stale, corrupt, or incompatible with a
  /// new build. The app should be restarted afterwards so every provider
  /// reloads from a clean slate (they only read prefs at startup).
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
