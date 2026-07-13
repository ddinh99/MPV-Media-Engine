// lib/widgets/tab_video_grading.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/video_provider.dart';
import 'video_controls_common.dart';

class TabVideoGrading extends StatelessWidget {
  const TabVideoGrading({super.key});

  /// Gloss levels are a pure macro over the contrast/gamma/saturation sliders
  /// below — they hold no state of their own, so there is nothing to persist,
  /// nothing for the coverage test to track, and nothing new that can break.
  /// A chip lights up only when the three sliders exactly match its triple.
  /// Level 3 is the Vivid preset's own grade; level 5 is the hotter grade that
  /// only looks right with HDR Output on (its inverse tone mapping absorbs it).
  static const _glossLevels = [
    [0, 0, 0], // Off
    [2, -1, 3],
    [4, -2, 6],
    [6, -3, 9], // = Vivid preset
    [8, -4, 12],
    [10, -5, 15], // pairs with HDR Output
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, video, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    videoSectionTitle('Hardware Grading', Icons.tune),
                    const SizedBox(height: 12),
                    _buildGrading(context, video),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    videoSectionTitle('Deband', Icons.blur_on),
                    const SizedBox(height: 12),
                    _buildDeband(context, video),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrading(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: videoCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGlossRow(video),
          const SizedBox(height: 16),
          videoSliderRow(
            label: 'Brightness',
            value: video.state.brightness.toDouble(),
            min: -100,
            max: 100,
            onChanged: (v) => video.setBrightness(v.toInt()),
          ),
          const SizedBox(height: 12),
          videoSliderRow(
            label: 'Contrast',
            value: video.state.contrast.toDouble(),
            min: -100,
            max: 100,
            onChanged: (v) => video.setContrast(v.toInt()),
          ),
          const SizedBox(height: 12),
          videoSliderRow(
            label: 'Gamma',
            value: video.state.gamma.toDouble(),
            min: -100,
            max: 100,
            onChanged: (v) => video.setGamma(v.toInt()),
          ),
          const SizedBox(height: 12),
          videoSliderRow(
            label: 'Saturation',
            value: video.state.saturation.toDouble(),
            min: -100,
            max: 100,
            onChanged: (v) => video.setSaturation(v.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildGlossRow(VideoProvider video) {
    final s = video.state;
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            'Gloss',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < _glossLevels.length; i++)
                ChoiceChip(
                  label: Text(i == 0 ? 'Off' : '$i'),
                  labelStyle: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  selected: s.contrast == _glossLevels[i][0] &&
                      s.gamma == _glossLevels[i][1] &&
                      s.saturation == _glossLevels[i][2],
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.surface,
                  side: BorderSide(color: AppTheme.border),
                  onSelected: (_) {
                    video.setContrast(_glossLevels[i][0]);
                    video.setGamma(_glossLevels[i][1]);
                    video.setSaturation(_glossLevels[i][2]);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeband(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: videoCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Deband',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const Spacer(),
              Switch(
                value: video.state.deband,
                onChanged: video.setDeband,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          videoSliderRow(
            label: 'Deband Iterations',
            value: video.state.debandIterations.toDouble(),
            min: 1,
            max: 16,
            divisions: 15,
            onChanged: (v) => video.setDebandIterations(v.toInt()),
          ),
          const SizedBox(height: 12),
          videoSliderRow(
            label: 'Deband Threshold',
            value: video.state.debandThreshold.toDouble(),
            min: 0,
            max: 4096,
            divisions: 256, // 4096 / 16 = 256
            onChanged: (v) => video.setDebandThreshold(v.toInt()),
          ),
        ],
      ),
    );
  }
}
