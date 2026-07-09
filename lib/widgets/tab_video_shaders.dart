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
              const SizedBox(height: 8),
              Text(
                'Check to enable. Active shaders apply in order — use the arrows to reorder them.',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted),
              ),
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

    final activeShaders = video.state.activeShaders;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: videoCardDecoration(),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: 44,
          crossAxisSpacing: 8,
          mainAxisSpacing: 2,
        ),
        itemCount: video.availableShaders.length,
        itemBuilder: (context, index) {
          final shaderName = video.availableShaders[index];
          final isActive = activeShaders.contains(shaderName);
          // Reordering only makes sense among *active* shaders (only those
          // are actually applied, in this order) — position within the full
          // available-shaders list is unrelated and must not be used here.
          final activeIndex = activeShaders.indexOf(shaderName);

          return Row(
            children: [
              Checkbox(
                value: isActive,
                onChanged: (val) => video.toggleShader(shaderName, val ?? false),
                activeColor: AppTheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  shaderName,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isActive) ...[
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                  tooltip: 'Move earlier in chain',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  color: AppTheme.textMuted,
                  onPressed: activeIndex > 0
                      ? () => video.reorderShaders(activeIndex, activeIndex - 1)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  tooltip: 'Move later in chain',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  color: AppTheme.textMuted,
                  onPressed: activeIndex < activeShaders.length - 1
                      ? () => video.reorderShaders(activeIndex, activeIndex + 2)
                      : null,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
