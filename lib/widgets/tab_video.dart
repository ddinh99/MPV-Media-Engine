// lib/widgets/tab_video.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/video_provider.dart';
import 'video_preset_selector.dart';
import 'dsp_slider.dart'; // Reusing this if possible, or using standard sliders.

class TabVideo extends StatelessWidget {
  const TabVideo({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, video, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const VideoPresetSelector(),
              const SizedBox(height: 24),

              _buildSectionTitle('Shaders Engine', Icons.layers),
              const SizedBox(height: 12),
              _buildShadersEngine(context, video),
              const SizedBox(height: 32),
              
              _buildSectionTitle('HDR / Tone Mapping', Icons.hdr_on),
              const SizedBox(height: 12),
              _buildToneMapping(context, video),
              const SizedBox(height: 32),

              _buildSectionTitle('Scaling & Interpolation', Icons.fit_screen),
              const SizedBox(height: 12),
              _buildScalingAndInterpolation(context, video),
              const SizedBox(height: 32),

              _buildSectionTitle('Hardware Grading & Deband', Icons.tune),
              const SizedBox(height: 12),
              _buildGradingAndDeband(context, video),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildShadersEngine(BuildContext context, VideoProvider video) {
    if (video.availableShaders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 16),
            const SizedBox(width: 8),
            Text(
              'No .glsl shaders found in assets/shaders/',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: video.reorderShaders,
        children: video.availableShaders.map((shaderName) {
          final isActive = video.state.activeShaders.contains(shaderName);
          return Container(
            key: ValueKey(shaderName),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              leading: Checkbox(
                value: isActive,
                onChanged: (val) => video.toggleShader(shaderName, val ?? false),
                activeColor: AppTheme.primary,
              ),
              title: Text(
                shaderName,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              trailing: ReorderableDragStartListener(
                index: video.availableShaders.indexOf(shaderName),
                child: Icon(Icons.drag_handle, color: AppTheme.textMuted),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToneMapping(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
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
                items: <String>['auto', 'spline', 'bt.2446a', 'mobius', 'reinhard', 'hable']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              const Spacer(),
              Text('Visualizer:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Switch(
                value: video.state.visualizeToneMapping,
                onChanged: video.setVisualizeToneMapping,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSliderRow(
            label: 'Target Peak (Nits)',
            value: video.state.targetPeak,
            min: 100,
            max: 4000,
            divisions: (4000 - 100) ~/ 50,
            onChanged: video.setTargetPeak,
          ),
          const SizedBox(height: 16),
          _buildSliderRow(
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

  Widget _buildScalingAndInterpolation(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Interpolation (Motion Smoothing)',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const Spacer(),
              Switch(
                value: video.state.interpolation,
                onChanged: video.setInterpolation,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          if (video.state.interpolation) ...[
            const SizedBox(height: 16),
            _buildDropdownRow(
              label: 'Temporal Scaler (tscale)',
              value: video.state.tscale,
              items: const ['oversample', 'linear', 'catmull_rom', 'mitchell', 'box', 'spline36'],
              onChanged: (val) => video.setTScale(val!),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          _buildDropdownRow(
            label: 'Luma Upscaler (scale)',
            value: video.state.scale,
            items: const ['bilinear', 'bicubic', 'spline36', 'spline64', 'ewa_lanczos', 'ewa_lanczossharp', 'ewa_lanczos4sharpest'],
            onChanged: (val) => video.setScale(val!),
          ),
          const SizedBox(height: 12),
          _buildDropdownRow(
            label: 'Chroma Upscaler (cscale)',
            value: video.state.cscale,
            items: const ['bilinear', 'bicubic', 'spline36', 'spline64', 'ewa_lanczos', 'ewa_lanczossharp', 'ewa_lanczos4sharpest'],
            onChanged: (val) => video.setCScale(val!),
          ),
          const SizedBox(height: 12),
          _buildDropdownRow(
            label: 'Downscaler (dscale)',
            value: video.state.dscale,
            items: const ['bilinear', 'bicubic', 'mitchell', 'catmull_rom'],
            onChanged: (val) => video.setDScale(val!),
          ),
        ],
      ),
    );
  }

  Widget _buildGradingAndDeband(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSliderRow(
            label: 'Brightness',
            value: video.state.brightness.toDouble(),
            min: -100,
            max: 100,
            onChanged: (v) => video.setBrightness(v.toInt()),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: 'Contrast',
            value: video.state.contrast.toDouble(),
            min: -100,
            max: 100,
            onChanged: (v) => video.setContrast(v.toInt()),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
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
          _buildSliderRow(
            label: 'Deband Iterations',
            value: video.state.debandIterations.toDouble(),
            min: 1,
            max: 16,
            divisions: 15,
            onChanged: (v) => video.setDebandIterations(v.toInt()),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
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

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppTheme.primary,
            inactiveColor: AppTheme.primaryLight,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            value.toStringAsFixed(value == value.truncateToDouble() ? 0 : 2),
            textAlign: TextAlign.right,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownRow({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 170,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            value: value,
            dropdownColor: AppTheme.surface,
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
            underline: Container(height: 1, color: AppTheme.border),
            onChanged: onChanged,
            items: items.map<DropdownMenuItem<String>>((String val) {
              return DropdownMenuItem<String>(
                value: val,
                child: Text(val),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
