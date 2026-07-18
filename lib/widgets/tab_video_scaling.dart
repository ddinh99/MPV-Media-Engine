// lib/widgets/tab_video_scaling.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/video_provider.dart';
import 'video_controls_common.dart';

/// Shown when the app has had to force interpolation back off because mpv could
/// not measure the display refresh. Silently reverting would be its own
/// invisible failure — the user needs to know the control didn't stick, and why.
Widget _displaySyncWarningCard(VideoProvider video) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.warning.withOpacity(0.07),
      border: Border.all(color: AppTheme.warning.withOpacity(0.35)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.sync_problem_rounded, size: 18, color: AppTheme.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Display sync unavailable',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(height: 5),
              SelectableText(
                video.displaySyncWarning!,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
          tooltip: 'Dismiss',
          onPressed: video.dismissDisplaySyncWarning,
        ),
      ],
    ),
  );
}

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
                    if (video.displaySyncWarning != null) ...[
                      _displaySyncWarningCard(video),
                      const SizedBox(height: 12),
                    ],
                    _buildVectorMotionInterpolation(context, video),
                    const SizedBox(height: 24),
                    videoSectionTitle('Decoding', Icons.memory),
                    const SizedBox(height: 12),
                    _buildDecoding(context, video),
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

  Widget _buildDecoding(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: videoCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hardware Decoding',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'hwdec=auto-safe',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: video.state.hardwareDecoding,
                onChanged: video.setHardwareDecoding,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Decodes on the GPU\'s fixed-function decoder instead of the CPU. '
            'A performance option, not a quality one — output is identical, '
            'but CPU load drops sharply on 4K HEVC/AV1. Off matches stock mpv.',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
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
            items: const ['bilinear', 'bicubic', 'hermite', 'lanczos', 'spline36', 'spline64', 'oversample', 'mitchell', 'catmull_rom', 'sinc', 'ginseng', 'robidoux', 'robidouxsharp', 'ewa_lanczos', 'ewa_lanczossharp', 'ewa_lanczos4sharpest', 'ewa_lanczossoft', 'ewa_robidoux', 'ewa_robidouxsharp', 'haasnsoft'],
            onChanged: (val) => video.setScale(val!),
          ),
          const SizedBox(height: 12),
          videoDropdownRow(
            label: 'Chroma Upscaler (cscale)',
            value: video.state.cscale,
            items: const ['bilinear', 'bicubic', 'hermite', 'lanczos', 'spline36', 'spline64', 'oversample', 'mitchell', 'catmull_rom', 'sinc', 'ginseng', 'robidoux', 'robidouxsharp', 'ewa_lanczos', 'ewa_lanczossharp', 'ewa_lanczos4sharpest', 'ewa_lanczossoft', 'ewa_robidoux', 'ewa_robidouxsharp', 'haasnsoft'],
            onChanged: (val) => video.setCScale(val!),
          ),
          const SizedBox(height: 12),
          videoDropdownRow(
            label: 'Downscaler (dscale)',
            value: video.state.dscale,
            items: const ['bilinear', 'bicubic', 'hermite', 'mitchell', 'catmull_rom', 'spline36', 'spline64', 'oversample', 'lanczos', 'ginseng', 'sinc', 'robidoux', 'robidouxsharp'],
            onChanged: (val) => video.setDScale(val!),
          ),
          const SizedBox(height: 16),
          videoSliderRow(
            label: 'Sharpen (sharpen)',
            value: video.state.sharpen,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: video.setSharpen,
          ),
          const SizedBox(height: 12),
          videoSliderRow(
            label: 'Luma Antiring (scale-antiring)',
            value: video.state.scaleAntiring,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: video.setScaleAntiring,
          ),
          const SizedBox(height: 12),
          videoSliderRow(
            label: 'Chroma Antiring (cscale-antiring)',
            value: video.state.cscaleAntiring,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: video.setCScaleAntiring,
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
              items: const ['oversample', 'linear', 'catmull_rom', 'mitchell', 'gaussian', 'bicubic', 'box', 'spline36', 'spline64'],
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
