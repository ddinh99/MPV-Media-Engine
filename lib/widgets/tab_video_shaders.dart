// lib/widgets/tab_video_shaders.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../models/shader_metadata.dart';
import '../providers/video_provider.dart';
import 'video_controls_common.dart';

class TabVideoShaders extends StatefulWidget {
  const TabVideoShaders({super.key});

  @override
  State<TabVideoShaders> createState() => _TabVideoShadersState();
}

class _TabVideoShadersState extends State<TabVideoShaders> {
  String? _lastPlayedFile;

  @override
  void initState() {
    super.initState();
    // Listen to DspProvider to detect new video plays and cache info
    context.read<VideoProvider>().dspProvider.addListener(_onVideoProviderChanged);
  }

  @override
  void dispose() {
    context.read<VideoProvider>().dspProvider.removeListener(_onVideoProviderChanged);
    super.dispose();
  }

  void _onVideoProviderChanged() {
    // When a new video is played, fetch and cache its info once
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final video = context.read<VideoProvider>();
      final currentFile = await video.dspProvider.getProperty('filename') as String?;
      if (currentFile != null && currentFile != _lastPlayedFile) {
        _lastPlayedFile = currentFile;
        // Fetch and cache video info (resolution, codec, fps, etc.)
        await video.cacheCurrentVideoInfo();
      }
    });
  }

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
    final currentHeight = (video.cachedVideoInfo?['dheight'] as num?);
    final currentTier = getResolutionTier(currentHeight);

    // Group shaders by tier, preserving active-first ordering within each tier
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

    // Sort within each tier: active shaders first (in chain order), then inactive
    lowResTiers.sort((a, b) {
      final aActive = activeShaders.contains(a);
      final bActive = activeShaders.contains(b);
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      if (aActive && bActive) {
        return activeShaders.indexOf(a).compareTo(activeShaders.indexOf(b));
      }
      return 0;
    });

    highResTiers.sort((a, b) {
      final aActive = activeShaders.contains(a);
      final bActive = activeShaders.contains(b);
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      if (aActive && bActive) {
        return activeShaders.indexOf(a).compareTo(activeShaders.indexOf(b));
      }
      return 0;
    });

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
                  'Current video: ${currentHeight.toInt()}p',
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
          lowResTiers,
          activeShaders,
          currentTier == ResolutionTier.lowRes,
        ),
        const SizedBox(height: 16),
        _buildShaderTier(
          context,
          video,
          'For 1440p+',
          Icons.hd,
          highResTiers,
          activeShaders,
          currentTier == ResolutionTier.highRes,
        ),
      ],
    );
  }

  Widget _buildShaderTier(
    BuildContext context,
    VideoProvider video,
    String tierName,
    IconData icon,
    List<String> shaders,
    List<String> activeShaders,
    bool isCurrentTier,
  ) {
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

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isCurrentTier ? AppTheme.primary.withOpacity(0.3) : AppTheme.surfaceVariant,
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
                Icon(icon, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  tierName,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (isCurrentTier)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '← Your video',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
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
                      onChanged: (val) => video.toggleShader(shaderName, val ?? false),
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
          ),
        ],
      ),
    );
  }
}
