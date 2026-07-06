// lib/widgets/tab_eq.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../models/eq_band.dart';
import '../providers/dsp_provider.dart';
import 'dsp_slider.dart';

class TabEq extends StatelessWidget {
  const TabEq({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DspProvider>(
      builder: (context, dsp, _) {
        const color = AppTheme.accentEQ;
        final hs = dsp.state.highShelf;
        final bands = dsp.state.eqBands;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // EQ bands section
                  Expanded(
                    flex: 3,
                    child: _Box(
                      title: 'Parametric Equalizer (anequalizer)',
                      icon: Icons.equalizer,
                      accentColor: color,
                      children: [
                        // Visual EQ bar display
                        _EqVisualizer(bands: bands, color: color),
                        const SizedBox(height: 20),
                        // Frequency band labels
                        Row(
                          children: bands
                              .map((b) => Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          _freqLabel(b.freq),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: _gainColor(b.gain, color),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        // Individual band sliders
                        ...bands.asMap().entries.map((entry) {
                          final i = entry.key;
                          final band = entry.value;
                          return DspSlider(
                            label: '${_freqLabel(band.freq)} (${band.freq}Hz)',
                            value: band.gain,
                            min: -12.0,
                            max: 12.0,
                            divisions: 240,
                            unit: 'dB',
                            accentColor: _gainColor(band.gain, color),
                            onChanged: (v) => dsp.setEqBandGain(i, v),
                          );
                        }),
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Your movie filter cuts 60Hz (${bands[0].gain.toStringAsFixed(1)}dB), '
                            'boosts dialog clarity at 125Hz–3.5kHz, '
                            'cuts harshness at 5.5kHz (${bands[5].gain.toStringAsFixed(1)}dB), '
                            'adds air at 8kHz.',
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // High shelf section
                  Expanded(
                    flex: 1,
                    child: _Box(
                      title: 'High Shelf (highshelf)',
                      icon: Icons.trending_up,
                      accentColor: color,
                      children: [
                        DspSlider(
                          label: 'Shelf Frequency',
                          value: hs.freq,
                          min: 1000,
                          max: 16000,
                          divisions: 150,
                          unit: 'Hz',
                          accentColor: color,
                          onChanged: dsp.setHighShelfFreq,
                        ),
                        DspSlider(
                          label: 'Gain',
                          value: hs.gain,
                          min: -12.0,
                          max: 12.0,
                          divisions: 240,
                          unit: 'dB',
                          accentColor: _gainColor(hs.gain, color),
                          onChanged: dsp.setHighShelfGain,
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'highshelf=f=${hs.freq.toStringAsFixed(0)}'
                            ':g=${hs.gain.toStringAsFixed(1)}'
                            ':w=${hs.width.toStringAsFixed(0)}:t=1\n\n'
                            'Adds "air" — subtle brightness above ${hs.freq.toStringAsFixed(0)}Hz. '
                            'Your movie setting: +${hs.gain.toStringAsFixed(1)}dB.',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _freqLabel(int freq) {
    if (freq >= 1000) return '${(freq / 1000).toStringAsFixed(freq % 1000 == 0 ? 0 : 1)}k';
    return '$freq';
  }

  Color _gainColor(double gain, Color neutral) {
    if (gain > 0.5) return AppTheme.accentAmbience;
    if (gain < -0.5) return AppTheme.error;
    return neutral;
  }
}

class _EqVisualizer extends StatelessWidget {
  final List<EqBand> bands;
  final Color color;

  const _EqVisualizer({required this.bands, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: CustomPaint(
        painter: _EqPainter(bands: bands, color: color),
        size: Size.infinite,
      ),
    );
  }
}

class _EqPainter extends CustomPainter {
  final List<EqBand> bands;
  final Color color;

  _EqPainter({required this.bands, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final maxGain = 12.0;

    // Draw center line
    final linePaint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), linePaint);

    if (bands.isEmpty) return;

    final barPaint = Paint()..color = color.withOpacity(0.7);
    final negPaint = Paint()..color = AppTheme.error.withOpacity(0.7);

    final bandWidth = size.width / bands.length;
    final innerPad = 6.0;

    for (int i = 0; i < bands.length; i++) {
      final gain = bands[i].gain;
      final barHeight = (gain / maxGain) * midY;
      final left = i * bandWidth + innerPad;
      final right = (i + 1) * bandWidth - innerPad;

      if (gain.abs() < 0.01) {
        // Draw a small dot at center
        canvas.drawCircle(
          Offset((left + right) / 2, midY),
          2,
          Paint()..color = AppTheme.textMuted,
        );
        continue;
      }

      final rect = gain > 0
          ? Rect.fromLTRB(left, midY - barHeight, right, midY)
          : Rect.fromLTRB(left, midY, right, midY - barHeight);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        gain > 0 ? barPaint : negPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqPainter old) => old.bands != bands;
}

class _Box extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  const _Box({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
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
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
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
