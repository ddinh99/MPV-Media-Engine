// lib/widgets/sound_settings_entry.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';
import '../screens/sound_settings_screen.dart';

/// Compact entry point into the full Sound (audio DSP) experience, styled to
/// match VideoPresetSelector (same title-row-on-top + preset-chip look) so
/// the two sit consistently side by side. Sound used to be a tab in the main
/// tab bar; now it's reached via this card instead.
class SoundSettingsEntry extends StatelessWidget {
  const SoundSettingsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          // Matches VideoPresetSelector's title row height exactly (its
          // "Save Current Settings" button forces Material's minimum
          // interactive tap height there), so both title rows — and thus
          // both button/chip rows below them — line up.
          height: 48,
          child: Row(
            children: [
              Icon(Icons.graphic_eq, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sound Settings',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SoundSettingsScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🎚️', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Open Sound Settings',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_forward, size: 14, color: AppTheme.textMuted),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'EQ, compressor, loudness, spatial audio…',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        height: 1.3,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
