enum ResolutionTier { lowRes, highRes }

class ShaderMetadata {
  final String name;
  final List<ResolutionTier> recommendedFor;
  final String? description;

  const ShaderMetadata({
    required this.name,
    required this.recommendedFor,
    this.description,
  });
}

/// Categorizes shaders by resolution tier.
/// Shaders appear in whichever tier they're most suited for.
/// Low-res shaders: upscaling, enhancement, restoration (benefits detail-starved content)
/// High-res shaders: tone mapping, color grading, deband (high-res has plenty of detail already)
const Map<String, ShaderMetadata> shaderMetadataMap = {
  'FSRCNNX_x2_16-0-4-1.glsl': ShaderMetadata(
    name: 'FSRCNNX_x2_16-0-4-1',
    recommendedFor: [ResolutionTier.lowRes],
    description: 'AI upscaler (2x) — best for low-res sources',
  ),
  'SSimSuperRes.glsl': ShaderMetadata(
    name: 'SSimSuperRes',
    recommendedFor: [ResolutionTier.lowRes],
    description: 'Smart upscaling — optimized for sub-1080p',
  ),
  'Anime4K_Restore_CNN_M.glsl': ShaderMetadata(
    name: 'Anime4K_Restore_CNN_M',
    recommendedFor: [ResolutionTier.lowRes],
    description: 'Anime restoration — enhances low-res anime',
  ),
  'CAS.glsl': ShaderMetadata(
    name: 'CAS',
    recommendedFor: [ResolutionTier.lowRes, ResolutionTier.highRes],
    description: 'Contrast-Adaptive Sharpening — works at any resolution',
  ),
  'adaptive-sharpen.glsl': ShaderMetadata(
    name: 'adaptive-sharpen',
    recommendedFor: [ResolutionTier.lowRes, ResolutionTier.highRes],
    description: 'Adaptive sharpening — preserves details at any res',
  ),
  'KrigBilateral.glsl': ShaderMetadata(
    name: 'KrigBilateral',
    recommendedFor: [ResolutionTier.lowRes],
    description: 'Denoising — best for low-res to reduce artifacts',
  ),
  'CfL_Prediction.glsl': ShaderMetadata(
    name: 'CfL_Prediction',
    recommendedFor: [ResolutionTier.highRes],
    description: 'Chroma upsampling — helps high-res content detail',
  ),
  'CfL_Prediction_Lite.glsl': ShaderMetadata(
    name: 'CfL_Prediction_Lite',
    recommendedFor: [ResolutionTier.highRes],
    description: 'Chroma upsampling (lite) — lighter version',
  ),
  'ArtCNN_C4F16.glsl': ShaderMetadata(
    name: 'ArtCNN_C4F16',
    recommendedFor: [ResolutionTier.lowRes],
    description: 'Artistic upscaler — stylized enhancement',
  ),
};

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
