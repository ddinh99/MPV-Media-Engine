enum ResolutionTier { lowRes, highRes }

class ShaderMetadata {
  final String name;
  final List<ResolutionTier> recommendedFor;
  final String? description;

  /// Small caution rendered under the shader's name inside a specific tier's
  /// section — for shaders that are *offered* in a tier without being the
  /// recommended pick there (e.g. CfL_Prediction at ≤1080p).
  final Map<ResolutionTier, String> tierNotes;

  /// Position in the recommended enable order within a tier (lower = earlier).
  /// The GUI lists shaders by this, so a new user enabling top-to-bottom gets
  /// a sensible chain: upscale → refine → chroma → sharpen, with situational
  /// or mutually-exclusive alternatives at the bottom.
  final int defaultOrder;

  const ShaderMetadata({
    required this.name,
    required this.recommendedFor,
    this.description,
    this.defaultOrder = 999,
    this.tierNotes = const {},
  });
}

/// Categorizes shaders by resolution tier.
/// Shaders appear in whichever tier they're most suited for.
/// Low-res shaders: upscaling, enhancement, restoration (benefits detail-starved content)
/// High-res shaders: tone mapping, color grading, deband (high-res has plenty of detail already)
///
/// `defaultOrder` values are global; tiers filter first, so one number yields
/// the right relative order in both tiers. mpv executes shaders at their
/// //!HOOK stage regardless of list position — list order only breaks ties
/// between shaders sharing a hook (CAS + adaptive-sharpen on OUTPUT,
/// FSRCNNX + ArtCNN on LUMA) — so the ordering here is primarily about
/// which shaders a new user should reach for first.
const Map<String, ShaderMetadata> shaderMetadataMap = {
  // ≤1080p: main upscaler first, then refinement, chroma, sharpening.
  'FSRCNNX_x2_16-0-4-1.glsl': ShaderMetadata(
    name: 'FSRCNNX_x2_16-0-4-1',
    recommendedFor: [ResolutionTier.lowRes],
    description: 'AI upscaler (2x) — best for low-res sources; enable first',
    defaultOrder: 10,
  ),
  'SSimSuperRes.glsl': ShaderMetadata(
    name: 'SSimSuperRes',
    recommendedFor: [ResolutionTier.lowRes],
    description: 'Refines the upscale result — pairs well with FSRCNNX',
    defaultOrder: 20,
  ),
  // Chroma reconstruction is the main win at 1440p+ (nothing else to
  // upscale there), but CfL works at any resolution — offered in both
  // tiers so it can replace Krig for whoever prefers it.
  'CfL_Prediction.glsl': ShaderMetadata(
    name: 'CfL_Prediction',
    recommendedFor: [ResolutionTier.lowRes, ResolutionTier.highRes],
    description: 'Chroma upsampling — sharper color detail; '
        'use instead of KrigBilateral, not with it',
    defaultOrder: 25,
    tierNotes: {
      ResolutionTier.lowRes: 'Alternative to KrigBilateral — pick one',
    },
  ),
  'KrigBilateral.glsl': ShaderMetadata(
    name: 'KrigBilateral',
    recommendedFor: [ResolutionTier.lowRes],
    description: 'Luma-guided chroma refinement — cleaner color edges; '
        'use instead of CfL_Prediction, not with it',
    defaultOrder: 30,
  ),
  // Sharpeners run last (OUTPUT hook). CAS is the lighter default;
  // adaptive-sharpen is stronger — usually pick one, not both.
  'CAS.glsl': ShaderMetadata(
    name: 'CAS',
    recommendedFor: [ResolutionTier.lowRes, ResolutionTier.highRes],
    description: 'Contrast-Adaptive Sharpening — light, safe default sharpen',
    defaultOrder: 40,
  ),
  'CAS-vivid.glsl': ShaderMetadata(
    name: 'CAS-vivid',
    recommendedFor: [ResolutionTier.lowRes, ResolutionTier.highRes],
    description: 'CAS with a micro-contrast boost (CONTRAST 0.3) — the HDR '
        'Punch sharpener; use instead of CAS/adaptive-sharpen, not with them',
    defaultOrder: 45,
  ),
  'adaptive-sharpen.glsl': ShaderMetadata(
    name: 'adaptive-sharpen',
    recommendedFor: [ResolutionTier.lowRes, ResolutionTier.highRes],
    description: 'Stronger sharpening — use instead of CAS, not with it',
    defaultOrder: 50,
  ),
  // Situational / alternatives below the everyday picks.
  'Anime4K_Restore_CNN_M.glsl': ShaderMetadata(
    name: 'Anime4K_Restore_CNN_M',
    recommendedFor: [ResolutionTier.lowRes],
    description: 'Anime restoration — for anime content only',
    defaultOrder: 60,
  ),
  'CfL_Prediction_Lite.glsl': ShaderMetadata(
    name: 'CfL_Prediction_Lite',
    recommendedFor: [ResolutionTier.highRes],
    description: 'Lighter CfL variant — use instead of CfL_Prediction on slower GPUs',
    defaultOrder: 65,
  ),
  'ArtCNN_C4F16.glsl': ShaderMetadata(
    name: 'ArtCNN_C4F16',
    recommendedFor: [ResolutionTier.lowRes],
    description: 'AI upscaler — alternative to FSRCNNX, don\'t stack both',
    defaultOrder: 70,
  ),
};

/// Recommended enable order for a shader; unknown shaders sort last.
int shaderDefaultOrder(String fileName) =>
    shaderMetadataMap[fileName]?.defaultOrder ?? 999;

/// Determines resolution tier based on display height.
/// Ranges match _resolutionLabel from video_info_dialog.dart.
ResolutionTier getResolutionTier(num? height) {
  if (height == null) return ResolutionTier.lowRes;
  if (height >= 1300) return ResolutionTier.highRes; // 1440p+
  return ResolutionTier.lowRes; // Below 1440p
}

/// Friendly display name for a resolution tier.
String resolutionTierLabel(ResolutionTier tier) {
  return tier == ResolutionTier.lowRes ? '≤1080p' : '1440p+';
}
