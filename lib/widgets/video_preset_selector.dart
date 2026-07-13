// lib/widgets/video_preset_selector.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../models/video_preset.dart';
import '../providers/video_provider.dart';

class VideoPresetSelector extends StatefulWidget {
  const VideoPresetSelector({super.key});

  @override
  State<VideoPresetSelector> createState() => _VideoPresetSelectorState();
}

class _VideoPresetSelectorState extends State<VideoPresetSelector> {
  /// The preset strip has always been horizontally scrollable, but on desktop
  /// that was invisible: no scrollbar, and the mouse wheel doesn't drive
  /// horizontal lists — so on a narrow window it just looked like the cards
  /// were cut off. The controller feeds an always-visible scrollbar and a
  /// wheel-to-horizontal listener.
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, provider, child) {
        final allPresets = [...builtinVideoPresets, ...provider.customPresets];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              // Fixed height (matches Material's minimum interactive tap
              // height) so this title row lines up exactly with
              // SoundSettingsEntry's title row next to it, regardless of the
              // "Save Current Settings" button's own intrinsic height.
              height: 48,
              child: Row(
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
                  label: Text('Save Preset', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
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
            ),
            const SizedBox(height: 12),
            SizedBox(
              // 90 for the cards + a lane below them for the scrollbar.
              height: 102,
              child: Listener(
                // A plain vertical wheel only pans vertical scrollables;
                // translate it so hovering the strip and scrolling just works
                // (shift+wheel / drag already worked natively).
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent && _scrollCtrl.hasClients) {
                    final delta = event.scrollDelta.dy != 0
                        ? event.scrollDelta.dy
                        : event.scrollDelta.dx;
                    _scrollCtrl.position.moveTo(_scrollCtrl.offset + delta);
                  }
                },
                child: Scrollbar(
                  controller: _scrollCtrl,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: allPresets.length,
                    itemBuilder: (context, index) {
                  final preset = allPresets[index];
                  final isActive = provider.activePresetId == preset.id;
                  final isCustom = preset.id.startsWith('custom_');
                  final isDefaultLowRes = provider.defaultPresetIdLowRes == preset.id;
                  final isDefaultHighRes = provider.defaultPresetIdHighRes == preset.id;

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Material(
                      color: Colors.transparent,
                      child: GestureDetector(
                        onTap: () => provider.applyPreset(preset),
                        onLongPress: () => _showPresetMenu(context, provider, preset),
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
                              Wrap(
                                spacing: 4,
                                children: [
                                  if (isDefaultLowRes)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        '≤1080p',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                  if (isDefaultHighRes)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        '1440p+',
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primary,
                                        ),
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
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPresetMenu(BuildContext context, VideoProvider provider, VideoPreset preset) {
    final isDefaultLowRes = provider.defaultPresetIdLowRes == preset.id;
    final isDefaultHighRes = provider.defaultPresetIdHighRes == preset.id;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: AppTheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${preset.emoji} ${preset.name}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  isDefaultLowRes ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: AppTheme.primary,
                ),
                title: Text(
                  'Default for ≤1080p',
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
                ),
                onTap: () async {
                  await provider.setDefaultPresetForLowRes(isDefaultLowRes ? null : preset.id);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(
                  isDefaultHighRes ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: AppTheme.primary,
                ),
                title: Text(
                  'Default for 1440p+',
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
                ),
                onTap: () async {
                  await provider.setDefaultPresetForHighRes(isDefaultHighRes ? null : preset.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
