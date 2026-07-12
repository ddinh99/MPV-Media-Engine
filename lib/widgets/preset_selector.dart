// lib/widgets/preset_selector.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../models/favorites.dart';
import '../models/preset.dart';
import '../providers/dsp_provider.dart';

class PresetSelector extends StatelessWidget {
  const PresetSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DspProvider>(
      builder: (context, dsp, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Text(
                'PRESET',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: builtinPresets.map((preset) {
                      final isActive = dsp.activePresetId == preset.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _PresetChip(
                          preset: preset,
                          isActive: isActive,
                          onTap: () => dsp.loadPreset(preset),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Favorites Menu
              PopupMenuButton<Map<String, String>>(
                tooltip: 'Favorites',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Favorites',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
                itemBuilder: (context) {
                  final activeId = dsp.activePresetId;

                  PopupMenuItem<Map<String, String>> buildFav(String name, String label, String filter) {
                    final isActive = activeId == name;
                    return PopupMenuItem(
                      value: {'name': name, 'filter': filter},
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(color: isActive ? AppTheme.primary : AppTheme.textPrimary, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isActive) Padding(padding: const EdgeInsets.only(left: 8.0), child: Icon(Icons.check, color: AppTheme.primary, size: 18)),
                        ],
                      ),
                    );
                  }

                  final items = <PopupMenuEntry<Map<String, String>>>[];
                  for (var i = 0; i < builtinFavoriteGroups.length; i++) {
                    if (i > 0) items.add(const PopupMenuDivider());
                    for (final f in builtinFavoriteGroups[i]) {
                      items.add(buildFav(f.id, f.label, f.filter));
                    }
                  }
                  return items;
                },
                onSelected: (val) {
                  dsp.applyCustomFilter(val['name']!, val['filter']!);
                },
              ),
              const SizedBox(width: 8),
              // Personal Settings Menu
              PopupMenuButton<String>(
                tooltip: 'Personal Settings',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person, color: Colors.blueAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Personal',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[
                    const PopupMenuItem(
                      value: '__import__',
                      child: Text('📥 Import Raw Filter String...'),
                    ),
                    const PopupMenuItem(
                      value: '__save__',
                      child: Text('➕ Save Current Settings...'),
                    ),
                  ];
                  if (dsp.customPresets.isNotEmpty) {
                    items.add(const PopupMenuDivider());
                    for (final p in dsp.customPresets) {
                      final isActive = dsp.activePresetId == p.id;
                      items.add(
                        PopupMenuItem(
                          value: p.id,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('👤 ${p.name}', style: TextStyle(color: isActive ? AppTheme.primary : AppTheme.textPrimary, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                              ),
                              if (isActive) Padding(padding: const EdgeInsets.only(right: 8.0), child: Icon(Icons.check, color: AppTheme.primary, size: 18)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: 'Delete this preset',
                                onPressed: () {
                                  Navigator.pop(context); // Close the popup menu
                                  dsp.deleteCustomPreset(p.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  }
                  return items;
                },
                onSelected: (val) async {
                  if (val == '__import__') {
                    final ctrl = TextEditingController();
                    final result = await showDialog<String>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: Row(
                          children: [
                            Icon(Icons.code, color: AppTheme.primary),
                            const SizedBox(width: 8),
                            const Text('Import Custom Filter'),
                          ],
                        ),
                        content: SizedBox(
                          width: 500,
                          child: TextField(
                            controller: ctrl,
                            maxLines: 5,
                            style: GoogleFonts.jetBrainsMono(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'Paste your raw filter string here...\ne.g. af-add=lavfi=[dynaudnorm...]',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, ctrl.text),
                            child: const Text('Activate'),
                          ),
                        ],
                      ),
                    );
                    if (result != null && result.trim().isNotEmpty) {
                      String cleanFilter = result.trim();
                      // Normalize the string so it works correctly with our backend format
                      if (cleanFilter.startsWith('af-add=')) {
                        cleanFilter = '#' + cleanFilter;
                      } else if (cleanFilter.startsWith('af=')) {
                        cleanFilter = '#af-add=' + cleanFilter.substring(3);
                      } else if (cleanFilter.startsWith('lavfi=')) {
                        cleanFilter = '#af-add=' + cleanFilter;
                      } else if (!cleanFilter.startsWith('#af-add=')) {
                        cleanFilter = '#af-add=' + cleanFilter;
                      }
                      dsp.applyCustomFilter('Imported Filter', cleanFilter);
                    }
                  } else if (val == '__save__') {
                    final nameCtrl = TextEditingController();
                    final name = await showDialog<String>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Save Personal Preset'),
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
                      dsp.saveCurrentAsPreset(name.trim());
                    }
                  } else {
                    try {
                      final p = dsp.customPresets.firstWhere((preset) => preset.id == val);
                      dsp.loadPreset(p);
                    } catch (_) {}
                  }
                },
              ),
              const SizedBox(width: 8),
              // Auto-apply toggle
              Row(
                children: [
                  Text(
                    'Auto-apply',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: dsp.autoApply,
                    onChanged: dsp.setAutoApply,
                    activeColor: AppTheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Manual apply button
              FilledButton.icon(
                icon: const Icon(Icons.send, size: 14),
                label: const Text('Apply Now'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: dsp.applyNow,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  final Preset preset;
  final bool isActive;
  final VoidCallback onTap;

  const _PresetChip({
    required this.preset,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: preset.description,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppTheme.primary : AppTheme.border,
              width: 1.5,
            ),
            boxShadow: isActive
                ? [BoxShadow(color: AppTheme.primary.withOpacity(0.20), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(preset.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                preset.name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
