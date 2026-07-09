// lib/widgets/tab_video_shaders.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/video_provider.dart';
import 'video_controls_common.dart';

class TabVideoShaders extends StatelessWidget {
  const TabVideoShaders({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, video, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              videoSectionTitle('Shaders Engine', Icons.layers),
              const SizedBox(height: 12),
              _buildShadersEngine(context, video),
            ],
          ),
        );
      },
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
      decoration: videoCardDecoration(),
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
}
