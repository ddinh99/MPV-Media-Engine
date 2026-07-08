// lib/widgets/video_preset_selector.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../models/video_preset.dart';
import '../providers/video_provider.dart';

class VideoPresetSelector extends StatelessWidget {
  const VideoPresetSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.video_library, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Video Presets',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: builtinVideoPresets.length,
                itemBuilder: (context, index) {
                  final preset = builtinVideoPresets[index];
                  final isActive = provider.activePresetId == preset.id;

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => provider.applyPreset(preset),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 160,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.primary.withOpacity(0.1) : AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isActive ? AppTheme.primary : AppTheme.border,
                              width: isActive ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(preset.emoji, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      preset.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isActive ? AppTheme.primary : AppTheme.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                preset.description,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  height: 1.3,
                                  color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
