// lib/constants/theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The available UI themes. `dark` (default) and `light` are the classic
/// pair; `teal` is a dark, forest/teal-tinted variant that sits as a
/// distinct middle-ground option — dark enough to be easy on the eyes but
/// with a green identity and teal accents instead of blue.
enum AppThemeMode { dark, teal, light }

class AppTheme {
  static AppThemeMode mode = AppThemeMode.dark;

  /// True only for the genuinely light theme. `teal` counts as dark for
  /// Material brightness purposes.
  static bool get isLight => mode == AppThemeMode.light;

  // Color palette
  static Color get background => switch (mode) {
        AppThemeMode.dark => const Color(0xFF0F172A),
        AppThemeMode.teal => const Color(0xFF0A1A17),
        AppThemeMode.light => const Color(0xFFF8F9FA),
      };
  static Color get surface => switch (mode) {
        AppThemeMode.dark => const Color(0xFF1E293B),
        AppThemeMode.teal => const Color(0xFF102923),
        AppThemeMode.light => const Color(0xFFFFFFFF),
      };
  static Color get surfaceVariant => switch (mode) {
        AppThemeMode.dark => const Color(0xFF334155),
        AppThemeMode.teal => const Color(0xFF17362E),
        AppThemeMode.light => const Color(0xFFF1F3F5),
      };
  static Color get border => switch (mode) {
        AppThemeMode.dark => const Color(0xFF475569),
        AppThemeMode.teal => const Color(0xFF254A40),
        AppThemeMode.light => const Color(0xFFE9ECEF),
      };
  static Color get borderStrong => switch (mode) {
        AppThemeMode.dark => const Color(0xFF64748B),
        AppThemeMode.teal => const Color(0xFF315F52),
        AppThemeMode.light => const Color(0xFFCED4DA),
      };

  static Color get primary => switch (mode) {
        AppThemeMode.teal => const Color(0xFF14B8A6),
        _ => const Color(0xFF2563EB),
      };
  static Color get primaryLight => switch (mode) {
        AppThemeMode.dark => const Color(0xFF1E3A8A),
        AppThemeMode.teal => const Color(0xFF0F3D37),
        AppThemeMode.light => const Color(0xFFDBEAFE),
      };
  static Color get primaryDark => switch (mode) {
        AppThemeMode.dark => const Color(0xFF60A5FA),
        AppThemeMode.teal => const Color(0xFF2DD4BF),
        AppThemeMode.light => const Color(0xFF1D4ED8),
      };

  static const Color success = Color(0xFF16A34A);
  static Color get successLight => isLight ? const Color(0xFFDCFCE7) : const Color(0xFF064E3B);
  static const Color error = Color(0xFFDC2626);
  static Color get errorLight => isLight ? const Color(0xFFFEE2E2) : const Color(0xFF7F1D1D);
  static const Color warning = Color(0xFFD97706);
  static Color get warningLight => isLight ? const Color(0xFFFEF3C7) : const Color(0xFF78350F);

  static Color get textPrimary => switch (mode) {
        AppThemeMode.dark => const Color(0xFFF8FAFC),
        AppThemeMode.teal => const Color(0xFFE8F5F0),
        AppThemeMode.light => const Color(0xFF111827),
      };
  static Color get textSecondary => switch (mode) {
        AppThemeMode.dark => const Color(0xFFCBD5E1),
        AppThemeMode.teal => const Color(0xFFA9C7BE),
        AppThemeMode.light => const Color(0xFF6B7280),
      };
  static Color get textMuted => switch (mode) {
        AppThemeMode.dark => const Color(0xFF94A3B8),
        AppThemeMode.teal => const Color(0xFF6D8E84),
        AppThemeMode.light => const Color(0xFF9CA3AF),
      };

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
        brightness: isLight ? Brightness.light : Brightness.dark,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: isLight ? Brightness.light : Brightness.dark).textTheme,
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
