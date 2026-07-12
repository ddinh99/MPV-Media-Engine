// lib/widgets/tab_video_shaders.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../models/shader_metadata.dart';
import '../providers/video_provider.dart';
import 'video_controls_common.dart';

/// Shaders Engine tab. Each resolution tier owns an independent shader list,
/// and only the list matching the current video's tier is live — the other
/// section is disabled so what's checked always equals what mpv is running.
/// New-video detection lives in VideoProvider (not here): this tab is inside
/// a TabBarView, so it's disposed whenever another tab is showing.
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
                'Each list only applies to videos in its resolution range — playing a '
                'video activates the matching list and disables the other. Listed in '
                'recommended order; use the arrows to reorder active shaders.',
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

    final currentHeight = (video.cachedVideoInfo?['dheight'] as num?);
    final currentTier = video.currentTier;

    // Group the available shader files by the tier(s) they're recommended for.
    final lowResTiers = <String>[];
    final highResTiers = <String>[];

    for (final shader in video.availableShaders) {
      final metadata = shaderMetadataMap[shader];
      final tiers = metadata?.recommendedFor ?? [ResolutionTier.lowRes, ResolutionTier.highRes];

      if (tiers.contains(ResolutionTier.lowRes)) {
        lowResTiers.add(shader);
      }
      if (tiers.contains(ResolutionTier.highRes)) {
        highResTiers.add(shader);
      }
    }

    // Sort within each tier: active shaders first (in chain order), then
    // inactive shaders in the recommended enable order — so a new user can
    // just check boxes top-to-bottom and get a sensible chain.
    void sortForTier(List<String> shaders, List<String> activeShaders) {
      shaders.sort((a, b) {
        final aActive = activeShaders.contains(a);
        final bActive = activeShaders.contains(b);
        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;
        if (aActive && bActive) {
          return activeShaders.indexOf(a).compareTo(activeShaders.indexOf(b));
        }
        final byOrder = shaderDefaultOrder(a).compareTo(shaderDefaultOrder(b));
        if (byOrder != 0) return byOrder;
        return a.compareTo(b);
      });
    }

    sortForTier(lowResTiers, video.state.shadersLowRes);
    sortForTier(highResTiers, video.state.shadersHighRes);

    return Column(
      children: [
        if (currentHeight != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary, size: 14),
                const SizedBox(width: 8),
                Text(
                  'Current video: ${currentHeight.toInt()}p — using the '
                  '${resolutionTierLabel(currentTier)} list',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        if (currentHeight != null) const SizedBox(height: 16),
        _buildShaderTier(
          context,
          video,
          'For ≤1080p',
          Icons.trending_up,
          ResolutionTier.lowRes,
          lowResTiers,
          video.state.shadersLowRes,
          // With no video detected there's nothing to gate on, so both lists
          // stay editable; the lowRes list is what a fresh mpv would get.
          videoDetected: currentHeight != null,
          isCurrentTier: currentTier == ResolutionTier.lowRes,
        ),
        const SizedBox(height: 16),
        _buildShaderTier(
          context,
          video,
          'For 1440p+',
          Icons.hd,
          ResolutionTier.highRes,
          highResTiers,
          video.state.shadersHighRes,
          videoDetected: currentHeight != null,
          isCurrentTier: currentTier == ResolutionTier.highRes,
        ),
      ],
    );
  }

  Widget _buildShaderTier(
    BuildContext context,
    VideoProvider video,
    String tierName,
    IconData icon,
    ResolutionTier tier,
    List<String> shaders,
    List<String> activeShaders, {
    required bool videoDetected,
    required bool isCurrentTier,
  }) {
    if (shaders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No shaders for this category',
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
        ),
      );
    }

    final enabled = !videoDetected || isCurrentTier;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: (videoDetected && isCurrentTier)
              ? AppTheme.primary.withOpacity(0.3)
              : AppTheme.surfaceVariant,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 16,
                    color: enabled ? AppTheme.primary : AppTheme.textMuted),
                const SizedBox(width: 8),
                Text(
                  tierName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
                  ),
                ),
                if (videoDetected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCurrentTier
                            ? AppTheme.primary.withOpacity(0.2)
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isCurrentTier
                            ? '● Active — your video'
                            : 'Disabled — doesn\'t match this video',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isCurrentTier ? AppTheme.primary : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: 44,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 2,
                ),
                itemCount: shaders.length,
                itemBuilder: (context, index) {
                  final shaderName = shaders[index];
                  final isActive = activeShaders.contains(shaderName);
                  final activeIndex = activeShaders.indexOf(shaderName);

                  return Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        onChanged: enabled
                            ? (val) => video.toggleShader(tier, shaderName, val ?? false)
                            : null,
                        activeColor: AppTheme.primary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      Expanded(
                        child: Tooltip(
                          message: shaderMetadataMap[shaderName]?.description ?? shaderName,
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
                      ),
                      if (isActive && enabled) ...[
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                          tooltip: 'Move earlier in chain',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          color: AppTheme.textMuted,
                          onPressed: activeIndex > 0
                              ? () => video.reorderShaders(tier, activeIndex, activeIndex - 1)
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
                              ? () => video.reorderShaders(tier, activeIndex, activeIndex + 1)
                              : null,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
