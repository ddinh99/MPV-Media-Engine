import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../constants/theme.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _isDark = await PreferencesService.getIsDarkTheme();
    AppTheme.isDark = _isDark;
    notifyListeners();
  }

  void toggleTheme() {
    _isDark = !_isDark;
    AppTheme.isDark = _isDark;
    PreferencesService.setIsDarkTheme(_isDark);
    notifyListeners();
  }
}
