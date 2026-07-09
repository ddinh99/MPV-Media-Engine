// lib/services/platform_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PlatformService {
  static const _channel = MethodChannel('com.mpv_media_engine/platform');

  /// Returns true if Windows 11 HDR is currently enabled on any display.
  /// Returns false on non-Windows platforms or if the check fails.
  static Future<bool> isWindowsHdrEnabled() async {
    if (kIsWeb) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isWindowsHdrEnabled');
      return result ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('HDR detection failed: $e');
      return false;
    }
  }
}
