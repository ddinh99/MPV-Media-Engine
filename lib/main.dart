// lib/main.dart
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app.dart';
import 'services/preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final packageInfo = await PackageInfo.fromPlatform();
  await PreferencesService.resetSessionDataIfVersionChanged(packageInfo.version);
  runApp(const MvpSoundEngineApp());
}
