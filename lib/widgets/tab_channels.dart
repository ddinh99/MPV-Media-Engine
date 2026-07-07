// lib/widgets/tab_channels.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../models/dsp_state.dart';
import '../providers/dsp_provider.dart';
import 'dsp_slider.dart';

class TabChannels extends StatelessWidget {
  const TabChannels({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DspProvider>(
      builder: (context, dsp, _) {
        final p = dsp.state.panMatrix;
        const color = AppTheme.accentChannels;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      // Quick controls
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SectionBox(
                      title: 'Quick Controls',
                      icon: Icons.tune,
                      accentColor: color,
                      children: [
                        DspSlider(
                          label: 'Dialog Focus (FC → FL/FR)',
                          value: p.flfc,
                          min: 0.0,
                          max: 1.0,
                          divisions: 100,
                          accentColor: color,
                          onChanged: dsp.setDialogFocus,
                        ),
                        DspSlider(
                          label: 'LFE Blend (into mains)',
                          value: p.fllfe,
                          min: 0.0,
                          max: 0.30,
                          divisions: 30,
                          accentColor: color,
                          onChanged: dsp.setLfeBlend,
                        ),
                        _InfoBox(
                          'Pan matrix reroutes multichannel audio into stereo. '
                          'Dialog Focus controls how much the center channel (FC) '
                          'is mixed into Left/Right. LFE adds subwoofer content to mains.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _SectionBox(
                      title: 'Stereo Widening (extrastereo)',
                      icon: Icons.spatial_audio,
                      accentColor: color,
                      children: [
                        DspSlider(
                          label: 'Stereo Width',
                          value: dsp.state.extraStereo,
                          min: 0.0,
                          max: 0.5,
                          divisions: 50,
                          accentColor: color,
                          onChanged: dsp.setExtraStereo,
                        ),
                        _InfoBox(
                          'extrastereo enhances stereo separation. '
                          '0.0 = no effect, 0.08 = subtle (your movie setting), '
                          '0.5 = strong widening. Too high may cause phase issues.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Advanced matrix
              _SectionBox(
                title: 'Advanced Pan Matrix Coefficients',
                icon: Icons.grid_on,
                accentColor: color,
                children: [
                  Text(
                    'Fine-tune each channel routing coefficient. '
                    'FL = Left output, FR = Right output.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _MatrixTable(matrix: p, dsp: dsp, accentColor: color),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MatrixTable extends StatelessWidget {
  final PanMatrix matrix;
  final DspProvider dsp;
  final Color accentColor;

  const _MatrixTable({required this.matrix, required this.dsp, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final headers = ['Source →', 'FL', 'FC', 'BL', 'SL', 'LFE'];
    final flValues = [matrix.flfl, matrix.flfc, matrix.flbl, matrix.flsl, matrix.fllfe];
    final frValues = [matrix.frfr, matrix.frfc, matrix.frbr, matrix.frsr, matrix.frlfe];

    return Table(
      border: TableBorder.all(color: AppTheme.border, borderRadius: BorderRadius.circular(8)),
      columnWidths: const {
        0: FixedColumnWidth(90),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
        4: FlexColumnWidth(),
        5: FlexColumnWidth(),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppTheme.surfaceVariant),
          children: headers.map((h) => _TableHeader(h)).toList(),
        ),
        _matrixRow('FL out', flValues, accentColor, (i, v) {
          final vals = [matrix.flfl, matrix.flfc, matrix.flbl, matrix.flsl, matrix.fllfe];
          vals[i] = v;
          dsp.setPanMatrix(matrix.copyWith(
            flfl: vals[0], flfc: vals[1], flbl: vals[2], flsl: vals[3], fllfe: vals[4],
          ));
        }),
        _matrixRow('FR out', frValues, accentColor, (i, v) {
          final vals = [matrix.frfr, matrix.frfc, matrix.frbr, matrix.frsr, matrix.frlfe];
          vals[i] = v;
          dsp.setPanMatrix(matrix.copyWith(
            frfr: vals[0], frfc: vals[1], frbr: vals[2], frsr: vals[3], frlfe: vals[4],
          ));
        }),
      ],
    );
  }

  TableRow _matrixRow(String label, List<double> values, Color color, Function(int, double) onChanged) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(label,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ),
        ...List.generate(values.length, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: _CoeffCell(value: values[i], color: color, onChanged: (v) => onChanged(i, v)),
          );
        }),
      ],
    );
  }
}

class _CoeffCell extends StatelessWidget {
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  const _CoeffCell({required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isNeg = value < 0;
    final displayColor = isNeg ? AppTheme.error : (value > 0 ? color : AppTheme.textMuted);

    return Column(
      children: [
        Text(
          value.toStringAsFixed(2),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: displayColor,
          ),
        ),
        SizedBox(
          height: 30,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: displayColor,
              thumbColor: displayColor,
              inactiveTrackColor: displayColor.withOpacity(0.15),
              trackHeight: 2,
            ),
            child: Slider(
              value: value.clamp(-0.5, 1.0),
              min: -0.5,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _SectionBox extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  const _SectionBox({
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
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
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

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox(this.text);

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
        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, height: 1.5),
      ),
    );
  }
}
