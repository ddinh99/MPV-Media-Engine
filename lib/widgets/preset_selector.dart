// lib/widgets/preset_selector.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
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
              ...builtinPresets.map((preset) {
                final isActive = dsp.activePresetId == preset.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _PresetChip(
                    preset: preset,
                    isActive: isActive,
                    onTap: () => dsp.loadPreset(preset),
                  ),
                );
              }),
              const Spacer(),
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
