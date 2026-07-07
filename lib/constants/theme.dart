// lib/constants/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static bool isDark = false;

  // Color palette
  static Color get background => isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F9FA);
  static Color get surface => isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get surfaceVariant => isDark ? const Color(0xFF334155) : const Color(0xFFF1F3F5);
  static Color get border => isDark ? const Color(0xFF475569) : const Color(0xFFE9ECEF);
  static Color get borderStrong => isDark ? const Color(0xFF64748B) : const Color(0xFFCED4DA);

  static const Color primary = Color(0xFF2563EB);
  static Color get primaryLight => isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
  static Color get primaryDark => isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);

  static const Color success = Color(0xFF16A34A);
  static Color get successLight => isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
  static const Color error = Color(0xFFDC2626);
  static Color get errorLight => isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFD97706);
  static Color get warningLight => isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);

  static Color get textPrimary => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
  static Color get textSecondary => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF6B7280);
  static Color get textMuted => isDark ? const Color(0xFF94A3B8) : const Color(0xFF9CA3AF);

  // Slider accent colors per tab
  static const Color accentLoudness = Color(0xFF7C3AED); // purple
  static const Color accentChannels = Color(0xFF0891B2); // cyan
  static const Color accentAmbience = Color(0xFF059669); // green
  static const Color accentEQ = Color(0xFFD97706);       // amber
  static const Color accentSafety = Color(0xFFDC2626);   // red

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: isDark ? Brightness.dark : Brightness.light).textTheme,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: border,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 4,
      ),
      dividerColor: border,
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
    );
  }
}
