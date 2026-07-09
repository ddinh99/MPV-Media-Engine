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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              videoSectionTitle('Hardware Grading & Deband', Icons.tune),
              const SizedBox(height: 12),
              _buildGradingAndDeband(context, video),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGradingAndDeband(BuildContext context, VideoProvider video) {
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
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
