// lib/widgets/tab_ambience.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/dsp_provider.dart';
import 'dsp_slider.dart';

class TabAmbience extends StatelessWidget {
  const TabAmbience({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DspProvider>(
      builder: (context, dsp, _) {
        final a = dsp.state.ambience;
        const color = AppTheme.accentAmbience;

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
                      // Left: Enable + Mix + Tone
              Expanded(
                child: _Box(
                  title: 'Ambience Path',
                  icon: Icons.surround_sound,
                  accentColor: color,
                  headerTrailing: Switch(
                    value: a.enabled,
                    onChanged: dsp.setAmbienceEnabled,
                    activeColor: color,
                  ),
                  children: [
                    if (!a.enabled)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Ambience path is disabled. Enable it to add synthetic room ambience to the audio.',
                                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      DspSlider(
                        label: 'Ambience Level (amix weight)',
                        value: a.mixWeight,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        accentColor: color,
                        onChanged: dsp.setAmbienceMixWeight,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ambient Tone Filter',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DspSlider(
                        label: 'High-pass cutoff (removes rumble)',
                        value: a.highpassFreq,
                        min: 100,
                        max: 2000,
                        divisions: 190,
                        unit: 'Hz',
                        accentColor: color,
                        onChanged: dsp.setAmbienceHighpass,
                      ),
                      DspSlider(
                        label: 'Low-pass cutoff (removes harshness)',
                        value: a.lowpassFreq,
                        min: 2000,
                        max: 16000,
                        divisions: 140,
                        unit: 'Hz',
                        accentColor: color,
                        onChanged: dsp.setAmbienceLowpass,
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Ambient path: signal is split → filtered (${a.highpassFreq.toStringAsFixed(0)}Hz–${a.lowpassFreq.toStringAsFixed(0)}Hz) '
                          '→ echo added → mixed back at ${(a.mixWeight * 100).toStringAsFixed(0)}% level.',
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, height: 1.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Right: Echo / Reverb controls
              Expanded(
                child: _Box(
                  title: 'Echo / Room Simulation (aecho)',
                  icon: Icons.graphic_eq,
                  accentColor: color,
                  children: [
                    if (!a.enabled)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Enable the Ambience Path to use echo controls.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      )
                    else ...[
                      DspSlider(
                        label: 'Echo Delay (in)',
                        value: a.echoDelay,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        accentColor: color,
                        onChanged: dsp.setEchoDelay,
                      ),
                      DspSlider(
                        label: 'Echo Decay (out)',
                        value: a.echoDecay,
                        min: 0.0,
                        max: 1.0,
                        divisions: 100,
                        accentColor: color,
                        onChanged: dsp.setEchoDecay,
                      ),
                      DspSlider(
                        label: 'Room Size (delay ms)',
                        value: a.echoVolume,
                        min: 5,
                        max: 200,
                        divisions: 195,
                        unit: 'ms',
                        accentColor: color,
                        onChanged: dsp.setEchoVolume,
                      ),
                      DspSlider(
                        label: 'Feedback (echo tail)',
                        value: a.echoFeedback,
                        min: 0.0,
                        max: 0.9,
                        divisions: 90,
                        accentColor: color,
                        onChanged: dsp.setEchoFeedback,
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          'aecho=${a.echoDelay.toStringAsFixed(2)}'
                          ':${a.echoDecay.toStringAsFixed(2)}'
                          ':${a.echoVolume.toStringAsFixed(0)}'
                          ':${a.echoFeedback.toStringAsFixed(2)}\n\n'
                          'Creates a subtle room reflection. Keep Room Size low (10–30ms) for '
                          'cinema-style ambience without muddiness.',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textSecondary, height: 1.5),
                        ),
                      ),
                    ],
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

class _Box extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;
  final Widget? headerTrailing;

  const _Box({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
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
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
              ),
              if (headerTrailing != null) headerTrailing!,
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
