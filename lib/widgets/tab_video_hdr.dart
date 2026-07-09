// lib/widgets/tab_video_hdr.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/video_provider.dart';
import 'video_controls_common.dart';

class TabVideoHdr extends StatelessWidget {
  const TabVideoHdr({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, video, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              videoSectionTitle('HDR / Tone Mapping', Icons.hdr_on),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildToneMapping(context, video)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildTargetHinting(context, video)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToneMapping(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: videoCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Algorithm:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: video.state.toneMappingAlgorithm,
                dropdownColor: AppTheme.surface,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
                underline: Container(height: 1, color: AppTheme.border),
                onChanged: (String? newValue) {
                  if (newValue != null) video.setToneMappingAlgorithm(newValue);
                },
                items: <String>['auto', 'none', 'spline', 'bt.2446a', 'mobius', 'reinhard', 'hable']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              const Spacer(),
              Text(
                'Visualizer:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: video.state.hdrOutput ? null : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: video.state.visualizeToneMapping,
                onChanged: video.state.hdrOutput ? video.setVisualizeToneMapping : null,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'HDR Compute Peak:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 8),
              Switch(
                value: video.state.hdrComputePeak,
                onChanged: video.setHdrComputePeak,
                activeColor: AppTheme.primary,
              ),
              const Spacer(),
              Text('HDR Output:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              Switch(
                value: video.state.hdrOutput,
                onChanged: video.setHdrOutput,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          videoSliderRow(
            label: 'Target Peak (Nits)',
            value: video.state.targetPeak,
            min: 100,
            max: 4000,
            divisions: (4000 - 100) ~/ 50,
            onChanged: video.setTargetPeak,
          ),
          const SizedBox(height: 16),
          videoSliderRow(
            label: 'Contrast Recovery',
            value: video.state.contrastRecovery,
            min: 0.0,
            max: 2.0,
            divisions: 40,
            onChanged: video.setContrastRecovery,
          ),
        ],
      ),
    );
  }

  Widget _buildTargetHinting(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: videoCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SDR to HDR Remap (Target Hinting)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: video.state.hdrOutput ? AppTheme.textMuted : AppTheme.primary,
                  ),
                ),
              ),
              Switch(
                value: video.state.targetColorspaceHint,
                // HDR Output already owns target-colorspace-hint/target-trc as
                // its own forced PQ passthrough shortcut; letting this switch
                // flip hint off independently while hdrOutput stays "on" would
                // leave MPV in a contradictory state (target-trc=pq with
                // hinting disabled). Disable it while HDR Output governs this.
                onChanged: video.state.hdrOutput ? null : video.setTargetColorspaceHint,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          if (video.state.hdrOutput) ...[
            const SizedBox(height: 8),
            Text(
              'Controlled by HDR Output on the left while it\'s on.',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            ),
          ],
          if (!video.state.targetColorspaceHint) ...[
            const SizedBox(height: 16),
            videoDropdownRow(
              label: 'Target Primaries',
              value: video.state.targetPrim,
              items: const ['auto', 'bt.709', 'bt.2020', 'apple', 'dci-p3', 'display-p3'],
              onChanged: (val) => video.setTargetPrim(val!),
            ),
            const SizedBox(height: 12),
            videoDropdownRow(
              label: 'Target Gamut',
              value: video.state.targetGamut,
              items: const ['auto', 'bt.709', 'dci-p3', 'display-p3', 'bt.2020'],
              onChanged: (val) => video.setTargetGamut(val!),
            ),
            const SizedBox(height: 12),
            videoDropdownRow(
              label: 'Target TRC',
              value: video.state.targetTrc,
              items: const ['auto', 'bt.1886', 'srgb', 'linear', 'gamma2.2', 'gamma2.8', 'pq', 'hlg'],
              onChanged: (val) => video.setTargetTrc(val!),
            ),
          ],
        ],
      ),
    );
  }
}
