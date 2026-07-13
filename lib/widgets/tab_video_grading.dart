// lib/widgets/tab_video_grading.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/video_provider.dart';
import 'video_controls_common.dart';

class TabVideoGrading extends StatelessWidget {
  const TabVideoGrading({super.key});

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
