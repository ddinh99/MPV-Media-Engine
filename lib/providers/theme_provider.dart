import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../constants/theme.dart';

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _mode = AppThemeMode.dark;

  AppThemeMode get mode => _mode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _mode = await PreferencesService.getThemeMode();
    AppTheme.mode = _mode;
    notifyListeners();
  }

  void setMode(AppThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    AppTheme.mode = _mode;
    PreferencesService.setThemeMode(_mode);
    notifyListeners();
  }
}
