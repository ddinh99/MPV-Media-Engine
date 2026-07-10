// lib/widgets/tab_video_scaling.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/video_provider.dart';
import 'video_controls_common.dart';

class TabVideoScaling extends StatelessWidget {
  const TabVideoScaling({super.key});

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
                    videoSectionTitle('High Performance Mode', Icons.speed),
                    const SizedBox(height: 12),
                    _buildVectorMotionInterpolation(context, video),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    videoSectionTitle('Scaling', Icons.fit_screen),
                    const SizedBox(height: 12),
                    _buildScaling(context, video),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScaling(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: videoCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          videoDropdownRow(
            label: 'Luma Upscaler (scale)',
            value: video.state.scale,
            items: const ['bilinear', 'bicubic', 'spline36', 'spline64', 'ewa_lanczos', 'ewa_lanczossharp', 'ewa_lanczos4sharpest'],
            onChanged: (val) => video.setScale(val!),
          ),
          const SizedBox(height: 12),
          videoDropdownRow(
            label: 'Chroma Upscaler (cscale)',
            value: video.state.cscale,
            items: const ['bilinear', 'bicubic', 'spline36', 'spline64', 'ewa_lanczos', 'ewa_lanczossharp', 'ewa_lanczos4sharpest'],
            onChanged: (val) => video.setCScale(val!),
          ),
          const SizedBox(height: 12),
          videoDropdownRow(
            label: 'Downscaler (dscale)',
            value: video.state.dscale,
            items: const ['bilinear', 'bicubic', 'mitchell', 'catmull_rom'],
            onChanged: (val) => video.setDScale(val!),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HiDPI Window Scale',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'hidpi-window-scale',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: video.state.hidpiWindowScale,
                onChanged: video.setHidpiWindowScale,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVectorMotionInterpolation(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: videoCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Temporal Motion Interpolation',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
          ),
          const SizedBox(height: 4),
          Text(
            'Recommended for RTX 30/40 series or Radeon RX 6000/7000 and above.',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interpolation (Motion Smoothing)',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'video-sync=display-resample',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: video.state.interpolation,
                onChanged: video.setInterpolation,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          if (video.state.interpolation) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            videoDropdownRow(
              label: 'Temporal Scaler (tscale)',
              value: video.state.tscale,
              items: const ['oversample', 'linear', 'catmull_rom', 'mitchell', 'box', 'spline36', 'spline64'],
              onChanged: (val) => video.setTScale(val!),
            ),
            const SizedBox(height: 12),
            videoDropdownRow(
              label: 'Window (tscale-window)',
              value: video.state.tscaleWindow,
              items: const ['sphinx', 'hanning', 'hamming', 'quadric', 'welch', 'blackman'],
              onChanged: (val) => video.setTScaleWindow(val!),
            ),
            const SizedBox(height: 16),
            videoSliderRow(
              label: 'Radius (tscale-radius)',
              value: video.state.tscaleRadius,
              min: 0.5,
              max: 3.0,
              divisions: 250,
              onChanged: video.setTScaleRadius,
            ),
            const SizedBox(height: 12),
            videoSliderRow(
              label: 'Blur (tscale-blur)',
              value: video.state.tscaleBlur,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              onChanged: video.setTScaleBlur,
            ),
            const SizedBox(height: 12),
            videoSliderRow(
              label: 'Clamp (tscale-clamp)',
              value: video.state.tscaleClamp,
              min: 0.0,
              max: 1.0,
              divisions: 100,
              onChanged: video.setTScaleClamp,
            ),
          ],
        ],
      ),
    );
  }
}
