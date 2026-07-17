// lib/widgets/video_controls_common.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';

/// Shared row/section builders used across the split Video Engine tabs
/// (Shaders, HDR & Tone Mapping, Scaling & Interpolation, Grading & Deband).

Widget videoSectionTitle(String title, IconData icon) {
  return Row(
    children: [
      Icon(icon, size: 18, color: AppTheme.primary),
      const SizedBox(width: 8),
      Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    ],
  );
}

Widget videoSliderRow({
  required String label,
  required double value,
  required double min,
  required double max,
  int? divisions,
  required ValueChanged<double> onChanged,
}) {
  return Row(
    children: [
      SizedBox(
        width: 140,
        child: Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ),
      Expanded(
        child: Slider(
          // Slider asserts min <= value <= max; a value persisted from before
          // a range was tightened (or from mpv's own wider limit) would
          // otherwise crash the tab in debug builds. See dsp_slider.dart for
          // the same pattern.
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppTheme.primary,
          inactiveColor: AppTheme.primaryLight,
          onChanged: onChanged,
        ),
      ),
      SizedBox(
        width: 48,
        child: Text(
          value.toStringAsFixed(value == value.truncateToDouble() ? 0 : 2),
          textAlign: TextAlign.right,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    ],
  );
}

Widget videoDropdownRow({
  required String label,
  required String value,
  required List<String> items,
  required ValueChanged<String?> onChanged,
  bool enabled = true,
}) {
  return Row(
    children: [
      SizedBox(
        width: 170,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: enabled ? AppTheme.textSecondary : AppTheme.textSecondary.withOpacity(0.4),
          ),
        ),
      ),
      Expanded(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          dropdownColor: AppTheme.surface,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: enabled ? AppTheme.textPrimary : AppTheme.textPrimary.withOpacity(0.4),
          ),
          underline: Container(height: 1, color: AppTheme.border),
          onChanged: enabled ? onChanged : null,
          items: items.map<DropdownMenuItem<String>>((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val),
            );
          }).toList(),
        ),
      ),
    ],
  );
}

/// Shared card container styling used by every section on these tabs.
BoxDecoration videoCardDecoration() => BoxDecoration(
      color: AppTheme.surfaceVariant,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.border),
    );
