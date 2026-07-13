// lib/models/video_preset.dart
import 'video_state.dart';

class VideoPreset {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final VideoState state;

  const VideoPreset({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.state,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'description': description,
    'state': state.toJson(),
  };

  factory VideoPreset.fromJson(Map<String, dynamic> json) => VideoPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: json['emoji'] as String? ?? '🎬',
    description: json['description'] as String? ?? '',
    state: VideoState.fromJson(json['state'] as Map<String, dynamic>),
  );
}

// Preset value choices are cross-checked against a real mpv 0.41 binary's
// --list-options defaults (see CLAUDE.md's "Verified mpv property gotchas"):
//   scale=lanczos, dscale=hermite, target-peak=auto (≈203 for SDR),
//   deband-threshold=48, hdr-contrast-recovery=0, video-sync=audio.
// Two rules every preset follows:
//   - target-peak 203 = SDR reference white, the neutral value. Anything
//     below dims/compresses even SDR content; HDR-to-SDR deliberately goes
//     *lower* (not higher!) to brighten — raising target-peak darkens.
//   - No preset enables interpolation. It drags in video-sync=display-resample,
//     which misbehaves on any machine whose driver isn't actually vsyncing
//     (see the display-resample gotcha); users opt in via the toggle, which
//     runs the display-sync verifier.
List<VideoPreset> get builtinVideoPresets => [
  VideoPreset(
    id: 'best_quality',
    name: 'Best Quality',
    emoji: '💎',
    description: 'Full shader chain and high-quality scalers — needs a capable GPU',
    state: VideoState(
      // The recommended chain per tier, in metadata order: upscale → refine →
      // chroma → sharpen for low-res sources; chroma reconstruction + sharpen
      // for high-res (which needs no upscaling).
      shadersLowRes: [
        'FSRCNNX_x2_16-0-4-1.glsl',
        'SSimSuperRes.glsl',
        'KrigBilateral.glsl',
        'CAS.glsl',
      ],
      shadersHighRes: ['CfL_Prediction.glsl', 'CAS.glsl'],
      toneMappingAlgorithm: 'auto',
      targetPeak: 203.0,
      // Matches mpv's own high-quality profile (0.30).
      contrastRecovery: 0.3,
      visualizeToneMapping: false,
      hdrComputePeak: true,
      hdrOutput: false,
      targetColorspaceHint: false,
      targetPrim: 'auto',
      targetGamut: 'auto',
      targetTrc: 'auto',
      brightness: 0,
      contrast: 0,
      gamma: 0,
      deband: true,
      debandIterations: 1,
      debandThreshold: 48,
      interpolation: false,
      videoSync: 'audio',
      tscale: 'oversample',
      tscaleWindow: 'sphinx',
      tscaleRadius: 0.95,
      tscaleBlur: 0.01,
      tscaleClamp: 0.0,
      scale: 'ewa_lanczossharp',
      // Krig/CfL take over chroma upscaling anyway; spline36 covers the rest
      // without ewa_lanczossharp's cost for no visible gain on chroma.
      cscale: 'spline36',
      dscale: 'mitchell',
    ),
  ),
  VideoPreset(
    id: 'anime_cartoon',
    name: 'Anime/Cartoon',
    emoji: '🌸',
    // "Restoration", not "upscale": Anime4K_Restore_CNN_M deblurs/denoises
    // but does not scale — the Anime4K upscaler shaders aren't shipped.
    // Actual upscaling is spline36.
    description: 'Anime4K restoration with medium debanding',
    state: VideoState(
      shadersLowRes: ['Anime4K_Restore_CNN_M.glsl'],
      shadersHighRes: ['CfL_Prediction.glsl'],
      toneMappingAlgorithm: 'auto',
      targetPeak: 203.0,
      contrastRecovery: 0.0,
      visualizeToneMapping: false,
      hdrComputePeak: true,
      hdrOutput: false,
      targetColorspaceHint: false,
      targetPrim: 'auto',
      targetGamut: 'auto',
      targetTrc: 'auto',
      brightness: 0,
      contrast: 0,
      gamma: 0,
      // "Medium": mpv's default strength (48) but two passes.
      deband: true,
      debandIterations: 2,
      debandThreshold: 48,
      interpolation: false,
      videoSync: 'audio',
      tscale: 'oversample',
      tscaleWindow: 'sphinx',
      tscaleRadius: 0.95,
      tscaleBlur: 0.01,
      tscaleClamp: 0.0,
      scale: 'spline36',
      cscale: 'spline36',
      dscale: 'mitchell',
    ),
  ),
  VideoPreset(
    id: 'cinematic_upscale',
    name: 'Live Action',
    emoji: '🎬',
    description: 'FSRCNNX and CAS for sharp upscaling',
    state: VideoState(
      // Upscaling only helps detail-starved sources, so FSRCNNX is ≤1080p
      // only; CAS sharpening is worthwhile at any resolution.
      shadersLowRes: ['FSRCNNX_x2_16-0-4-1.glsl', 'CAS.glsl'],
      shadersHighRes: ['CAS.glsl'],
      toneMappingAlgorithm: 'auto',
      targetPeak: 203.0,
      contrastRecovery: 0.0,
      visualizeToneMapping: false,
      hdrComputePeak: true,
      hdrOutput: false,
      targetColorspaceHint: false,
      targetPrim: 'auto',
      targetGamut: 'auto',
      targetTrc: 'auto',
      brightness: 0,
      contrast: 0,
      gamma: 0,
      deband: false,
      debandIterations: 1,
      debandThreshold: 48,
      interpolation: false,
      videoSync: 'audio',
      tscale: 'oversample',
      tscaleWindow: 'sphinx',
      tscaleRadius: 0.95,
      tscaleBlur: 0.01,
      tscaleClamp: 0.0,
      scale: 'ewa_lanczossharp',
      cscale: 'spline36',
      dscale: 'mitchell',
    ),
  ),
  VideoPreset(
    id: 'hdr_bright',
    name: 'HDR to SDR',
    emoji: '☀️',
    description: 'Brightened HDR-to-SDR tone mapping for well-lit rooms',
    state: VideoState(
      shadersLowRes: [],
      shadersHighRes: [],
      // Purpose-built HDR→SDR curve.
      toneMappingAlgorithm: 'bt.2446a',
      // *Below* the 203 reference on purpose: a lower target-peak compresses
      // the tone map harder and pushes midtones up — that's what "brighter"
      // means here. The old value of 400 did the opposite (darkened the
      // image on a typical SDR panel), which the old brightness/contrast +5
      // offsets then tried to claw back; both hacks are gone.
      targetPeak: 150.0,
      contrastRecovery: 0.35,
      visualizeToneMapping: false,
      hdrComputePeak: true,
      hdrOutput: false,
      targetColorspaceHint: false,
      targetPrim: 'auto',
      targetGamut: 'auto',
      targetTrc: 'auto',
      brightness: 0,
      contrast: 0,
      gamma: 0,
      // Tone-mapped skies/gradients band easily; default-strength deband.
      deband: true,
      debandIterations: 1,
      debandThreshold: 48,
      interpolation: false,
      videoSync: 'audio',
      tscale: 'oversample',
      tscaleWindow: 'sphinx',
      tscaleRadius: 0.95,
      tscaleBlur: 0.01,
      tscaleClamp: 0.0,
      scale: 'spline36',
      cscale: 'spline36',
      dscale: 'hermite',
    ),
  ),
  VideoPreset(
    id: 'vivid',
    name: 'Vivid',
    emoji: '✨',
    description: 'Glossy, punchy look — strong sharpening, deeper contrast, richer color',
    state: VideoState(
      // adaptive-sharpen (instead of CAS — stronger, don't stack them) does
      // the "glass" crispness at any resolution; low-res sources get FSRCNNX
      // first so the sharpener has real detail to bite into.
      shadersLowRes: ['FSRCNNX_x2_16-0-4-1.glsl', 'adaptive-sharpen.glsl'],
      shadersHighRes: ['adaptive-sharpen.glsl'],
      toneMappingAlgorithm: 'auto',
      targetPeak: 203.0,
      contrastRecovery: 0.3,
      visualizeToneMapping: false,
      hdrComputePeak: true,
      hdrOutput: false,
      targetColorspaceHint: false,
      targetPrim: 'auto',
      targetGamut: 'auto',
      targetTrc: 'auto',
      brightness: 0,
      // The grade: deliberately restrained — sharpen + saturation is exactly
      // the combo that tips into "TV showroom mode" if pushed. Contrast up a
      // notch, gamma a hair down for deeper mids, a mild color boost.
      // Tuned for plain SDR output (the default): live testing showed +15
      // saturation only looked right with HDR Output on, whose inverse tone
      // mapping stretches the range and absorbs the boost — on a plain SDR
      // path the same value reads oversaturated.
      contrast: 6,
      gamma: -3,
      saturation: 8,
      // Clean gradients are half of "glossy"; banding reads as cheap.
      deband: true,
      debandIterations: 1,
      debandThreshold: 48,
      interpolation: false,
      videoSync: 'audio',
      tscale: 'oversample',
      tscaleWindow: 'sphinx',
      tscaleRadius: 0.95,
      tscaleBlur: 0.01,
      tscaleClamp: 0.0,
      scale: 'ewa_lanczossharp',
      cscale: 'spline36',
      dscale: 'mitchell',
    ),
  ),
  VideoPreset(
    id: 'bypass',
    name: 'Bypass (Default)',
    emoji: '🔇',
    description: 'Stock mpv defaults — no shaders, no tweaks',
    state: VideoState(
      shadersLowRes: [],
      shadersHighRes: [],
      toneMappingAlgorithm: 'auto',
      targetPeak: 203.0,
      contrastRecovery: 0.0,
      visualizeToneMapping: false,
      hdrComputePeak: true,
      hdrOutput: false,
      targetColorspaceHint: false,
      targetPrim: 'auto',
      targetGamut: 'auto',
      targetTrc: 'auto',
      brightness: 0,
      contrast: 0,
      gamma: 0,
      deband: false,
      debandIterations: 1,
      debandThreshold: 48,
      interpolation: false,
      videoSync: 'audio',
      tscale: 'oversample',
      tscaleWindow: 'sphinx',
      tscaleRadius: 0.95,
      tscaleBlur: 0.01,
      tscaleClamp: 0.0,
      // Stock mpv, verified against 0.41: scale=lanczos, dscale=hermite,
      // cscale unset (follows scale). The old bilinear/bilinear/bilinear was
      // *below* stock — "Bypass" rendered worse than a clean mpv install.
      scale: 'lanczos',
      cscale: 'lanczos',
      dscale: 'hermite',
    ),
  ),
];
