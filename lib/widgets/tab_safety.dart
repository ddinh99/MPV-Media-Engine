// lib/widgets/tab_safety.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/dsp_provider.dart';
import 'dsp_slider.dart';

class TabSafety extends StatelessWidget {
  const TabSafety({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DspProvider>(
      builder: (context, dsp, _) {
        final lim = dsp.state.limiter;
        const color = AppTheme.accentSafety;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Limiter
              Expanded(
                child: _Box(
                  title: 'Limiter (alimiter)',
                  icon: Icons.security,
                  accentColor: color,
                  headerTrailing: Switch(
                    value: lim.enabled,
                    onChanged: dsp.setLimiterEnabled,
                    activeColor: color,
                  ),
                  children: [
                    DspSlider(
                      label: 'Ceiling (limit)',
                      value: lim.limit,
                      min: -6.0,
                      max: -0.1,
                      divisions: 59,
                      unit: 'dB',
                      accentColor: color,
                      onChanged: dsp.setLimiterCeiling,
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.20)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'alimiter=limit=${lim.limit.toStringAsFixed(1)}dB',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'The limiter is the last safety stage. It hard-clips any peak above '
                            '${lim.limit.toStringAsFixed(1)} dB. At −1dB it prevents digital clipping '
                            'while preserving all dynamics from the compressor stage.',
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Bypass
              Expanded(
                child: _Box(
                  title: 'Bypass',
                  icon: Icons.do_not_disturb,
                  accentColor: AppTheme.textSecondary,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bypass All Processing',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sends: af clr — removes all filters from MPV immediately.',
                                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: dsp.state.bypass,
                          onChanged: dsp.setBypass,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dsp.state.bypass ? AppTheme.warningLight : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: dsp.state.bypass ? AppTheme.warning.withOpacity(0.4) : AppTheme.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            dsp.state.bypass ? Icons.warning_amber : Icons.check_circle_outline,
                            size: 16,
                            color: dsp.state.bypass ? AppTheme.warning : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dsp.state.bypass
                                  ? 'BYPASS ACTIVE — MPV is playing raw unprocessed audio. '
                                      'All your DSP settings are preserved and will reapply when you disable bypass.'
                                  : 'DSP chain is active. Toggle bypass to compare with raw audio.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: dsp.state.bypass ? AppTheme.warning : AppTheme.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'About: for music vs. movies',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InfoTile(
                      emoji: '🎬',
                      title: 'Movies',
                      desc: 'Use Movie preset. Your filter was built for dialog-first cinematic content.',
                    ),
                    _InfoTile(
                      emoji: '🎵',
                      title: 'Music',
                      desc: 'Use Music (Transparent) or Bypass. Music is already mastered — less is more.',
                    ),
                    _InfoTile(
                      emoji: '🌙',
                      title: 'Night',
                      desc: 'Use Night Mode. Heavy compression reduces dynamic peaks for quiet listening.',
                    ),
                    _InfoTile(
                      emoji: '🎤',
                      title: '96kHz tip',
                      desc: 'Set Windows audio output to 96000Hz for stable MPV playback. Your DSP runs smoother.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String emoji, title, desc;
  const _InfoTile({required this.emoji, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Text(desc, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
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
