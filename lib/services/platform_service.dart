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

  /// The display's reported peak luminance in nits (from EDID via DXGI),
  /// preferring an output currently in HDR mode. Returns null when unknown
  /// (non-Windows, check failed, or the driver reported 0).
  static Future<double?> getDisplayMaxLuminance() async {
    if (kIsWeb) return null;
    try {
      final result =
          await _channel.invokeMethod<double>('getDisplayMaxLuminance');
      return (result == null || result <= 0) ? null : result;
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('Display luminance query failed: $e');
      return null;
    }
  }
}
