// lib/screens/sound_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';
import '../widgets/tab_sound.dart';

/// Full-screen destination for the Sound (audio DSP) experience — reached via
/// the "Sound Settings" entry card next to Video Presets, now that Video
/// Engine owns the main tab bar. Wraps the exact same TabSound content
/// (preset bar, 5 sub-tabs, filter preview) that used to live inline as a tab.
class SoundSettingsScreen extends StatelessWidget {
  const SoundSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Sound Settings',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.border),
        ),
      ),
      body: const TabSound(),
    );
  }
}
