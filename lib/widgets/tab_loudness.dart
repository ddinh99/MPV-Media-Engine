// lib/widgets/tab_loudness.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/dsp_provider.dart';
import 'dsp_slider.dart';

class TabLoudness extends StatelessWidget {
  const TabLoudness({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DspProvider>(
      builder: (context, dsp, _) {
        final dn = dsp.state.dynaudnorm;
        final cp = dsp.state.compressor;
        const color = AppTheme.accentLoudness;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dsp.hasCustomFilterOverride)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    border: Border.all(color: color),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Expert Override Active. The current preset uses a raw FFmpeg filter string. The simple UI sliders below cannot parse this complex string and are temporarily disconnected.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              Opacity(
                opacity: dsp.hasCustomFilterOverride ? 0.4 : 1.0,
                child: IgnorePointer(
                  ignoring: dsp.hasCustomFilterOverride,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Dynamic Normalization
              Expanded(
                child: _Section(
                  title: 'Dynamic Normalization',
                  icon: Icons.show_chart,
                  accentColor: color,
                  badge: dsp.state.dynaudnormEnabled ? 'ON' : 'OFF',
                  badgeColor: dsp.state.dynaudnormEnabled ? AppTheme.success : AppTheme.textMuted,
                  headerTrailing: Switch(
                    value: dsp.state.dynaudnormEnabled,
                    onChanged: dsp.setDynAudNormEnabled,
                    activeColor: color,
                  ),
                  children: [
                    DspSlider(
                      label: 'Frame Length',
                      value: dn.frameLength.toDouble(),
                      min: 10,
                      max: 8000,
                      divisions: 100,
                      unit: 'ms',
                      accentColor: color,
                      onChanged: dsp.setDynAudNormFrameLength,
                    ),
                    DspSlider(
                      label: 'Target Gain (g)',
                      value: dn.gain,
                      min: 1.0,
                      max: 20.0,
                      divisions: 190,
                      accentColor: color,
                      onChanged: dsp.setDynAudNormGain,
                    ),
                    DspSlider(
                      label: 'Peak Detection (p)',
                      value: dn.peak,
                      min: 0.0,
                      max: 1.0,
                      divisions: 100,
                      accentColor: color,
                      onChanged: dsp.setDynAudNormPeak,
                    ),
                    DspSlider(
                      label: 'Max Gain Factor (m)',
                      value: dn.maxGain,
                      min: 1.0,
                      max: 20.0,
                      divisions: 190,
                      accentColor: color,
                      onChanged: dsp.setDynAudNormMaxGain,
                    ),
                    _InfoBox(
                      text: 'dynaudnorm automatically levels audio loudness frame-by-frame. '
                          'Higher g = more aggressive normalization. '
                          'p controls peak vs. RMS normalization.',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Right: Compressor
              Expanded(
                child: _Section(
                  title: 'Compressor',
                  icon: Icons.compress,
                  accentColor: color,
                  children: [
                    DspSlider(
                      label: 'Threshold',
                      value: cp.threshold,
                      min: -40,
                      max: -5,
                      divisions: 35,
                      unit: 'dB',
                      accentColor: color,
                      onChanged: dsp.setCompThreshold,
                    ),
                    DspSlider(
                      label: 'Ratio',
                      value: cp.ratio,
                      min: 1.0,
                      max: 10.0,
                      divisions: 90,
                      valueLabel: (v) => '${v.toStringAsFixed(1)}:1',
                      accentColor: color,
                      onChanged: dsp.setCompRatio,
                    ),
                    DspSlider(
                      label: 'Attack',
                      value: cp.attack,
                      min: 0.1,
                      max: 50.0,
                      divisions: 499,
                      unit: 'ms',
                      accentColor: color,
                      onChanged: dsp.setCompAttack,
                    ),
                    DspSlider(
                      label: 'Release',
                      value: cp.release,
                      min: 10,
                      max: 500,
                      divisions: 490,
                      unit: 'ms',
                      accentColor: color,
                      onChanged: dsp.setCompRelease,
                    ),
                    DspSlider(
                      label: 'Makeup Gain',
                      value: cp.makeup,
                      min: 0,
                      max: 12,
                      divisions: 120,
                      unit: 'dB',
                      accentColor: color,
                      onChanged: dsp.setCompMakeup,
                    ),
                    _InfoBox(
                      text: 'Current: threshold=${cp.threshold.toStringAsFixed(0)}dB '
                          'ratio=${cp.ratio.toStringAsFixed(1)}:1 '
                          'attack=${cp.attack.toStringAsFixed(0)}ms '
                          'release=${cp.release.toStringAsFixed(0)}ms '
                          'makeup=${cp.makeup.toStringAsFixed(0)}dB',
                    ),
                  ],
                ),
              ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;
  final String? badge;
  final Color? badgeColor;
  final Widget? headerTrailing;

  const _Section({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
    this.badge,
    this.badgeColor,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (headerTrailing != null) ...[
                const Spacer(),
                headerTrailing!,
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: AppTheme.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}
