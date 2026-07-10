// lib/services/update_checker.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String version;
  final String releaseUrl;
  const UpdateInfo({required this.version, required this.releaseUrl});
}

/// Checks GitHub's Releases API for a version newer than [currentVersion]
/// (e.g. "1.3.1"). Returns null if already up to date, or if the check
/// fails for any reason (offline, rate-limited, malformed response) — this
/// must never throw or block normal app startup.
Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
  try {
    final response = await http
        .get(
          Uri.parse(
              'https://api.github.com/repos/ddinh99/MPV-Media-Engine/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String?)?.trim();
    final url = data['html_url'] as String?;
    if (tag == null || tag.isEmpty || url == null) return null;

    final latest = tag.startsWith('v') ? tag.substring(1) : tag;
    if (!_isNewer(latest, currentVersion)) return null;

    return UpdateInfo(version: latest, releaseUrl: url);
  } catch (_) {
    return null;
  }
}

bool _isNewer(String latest, String current) {
  List<int> parts(String v) =>
      v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final l = parts(latest);
  final c = parts(current);
  for (var i = 0; i < 3; i++) {
    final lv = i < l.length ? l[i] : 0;
    final cv = i < c.length ? c[i] : 0;
    if (lv != cv) return lv > cv;
  }
  return false;
}
