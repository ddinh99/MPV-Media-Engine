// lib/widgets/dsp_slider.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';

class DspSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? valueLabel;
  final ValueChanged<double> onChanged;
  /// Defaults to the theme's primary colour when null. Can't default to
  /// `AppTheme.primary` directly — it's a theme-dependent getter now, not a
  /// compile-time constant, so it can't be a const default parameter value.
  final Color? accentColor;
  final String? unit;

  const DspSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.valueLabel,
    this.accentColor,
    this.unit,
  });

  String get _displayValue {
    if (valueLabel != null) return valueLabel!(value);
    if (unit != null) return '${value.toStringAsFixed(1)} $unit';
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _displayValue,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              thumbColor: accent,
              inactiveTrackColor: accent.withOpacity(0.15),
              overlayColor: accent.withOpacity(0.10),
              trackHeight: 3,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                valueLabel != null ? valueLabel!(min) : '$min${unit != null ? ' $unit' : ''}',
                style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
              ),
              Text(
                valueLabel != null ? valueLabel!(max) : '$max${unit != null ? ' $unit' : ''}',
                style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DspToggleRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  /// See [DspSlider.accentColor] — null falls back to the theme primary.
  final Color? accentColor;

  const DspToggleRow({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: accentColor ?? AppTheme.primary,
        ),
      ],
    );
  }
}
