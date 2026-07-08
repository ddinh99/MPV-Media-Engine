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
        final allPresets = [...builtinVideoPresets, ...provider.customPresets];

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
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.bookmark_add, size: 16),
                  label: Text('Save Current Settings', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () async {
                    final nameCtrl = TextEditingController();
                    final name = await showDialog<String>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Text('Save Personal Preset', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        content: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(hintText: 'Enter a name for this preset'),
                          autofocus: true,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, nameCtrl.text),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    );
                    if (name != null && name.trim().isNotEmpty) {
                      provider.saveCustomPreset(name.trim());
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: allPresets.length,
                itemBuilder: (context, index) {
                  final preset = allPresets[index];
                  final isActive = provider.activePresetId == preset.id;
                  final isCustom = preset.id.startsWith('custom_');

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
                                  if (isCustom)
                                    GestureDetector(
                                      onTap: () => provider.deleteCustomPreset(preset.id),
                                      child: Icon(Icons.close, size: 14, color: AppTheme.textMuted),
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
