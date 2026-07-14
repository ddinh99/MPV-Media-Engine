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
                  final isDefault = provider.defaultPresetId == preset.id;

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Tooltip(
                      // The card ellipsizes both the name and the two-line
                      // description, so hover is the only place the full text
                      // is readable.
                      message:
                          '${preset.emoji} ${preset.name}\n${preset.description}'
                          '\nLong-press: ${isDefault ? 'unset' : 'set'} as default',
                      // Hover-only: the default longPress trigger would fight
                      // the long-press that toggles the default.
                      triggerMode: TooltipTriggerMode.manual,
                      waitDuration: const Duration(milliseconds: 400),
                      textStyle: GoogleFonts.inter(
                        fontSize: 12,
                        height: 1.4,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Material(
                      color: Colors.transparent,
                      child: GestureDetector(
                        onTap: () => provider.applyPreset(preset),
                        // No menu here anymore: the default is one preset for
                        // all resolutions, so long-press just toggles it.
                        onLongPress: () =>
                            provider.setDefaultPreset(isDefault ? null : preset.id),
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
                              if (isDefault)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    'Default',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              // Expanded (not Spacer + fixed Text): the active
                              // border is 0.5px thicker and Container insets
                              // the child by the border, so on badge-bearing
                              // cards a fixed-height description overflowed
                              // the 90px slot by ~2px when clicked.
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Text(
                                    preset.description,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      height: 1.3,
                                      color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

}
