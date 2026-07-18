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
//   deband-threshold=48, hdr-contrast-recovery=0, video-sync=audio,
//   hdr-peak-percentile=0 (mpv's high-quality profile uses 99.995).
// Also verified there so nobody re-audits them: correct-downscaling,
// linear-downscaling and sigmoid-upscaling already default to *yes* in mpv
// 0.41, and dither-depth defaults to auto — presets don't need to set them.
// gamut-mapping-mode and hdr-reference-white default to 'auto' too (the
// latter verified against a live mpv IPC connection, not just --list-options
// — see VideoState.hdrReferenceWhite for the same int-wire-type trap
// target-peak has) — presets leave both alone as well.
// The dither *algorithm* (dither/error-diffusion) is user-adjustable on the
// Grading & Deband tab; presets deliberately leave it at mpv's fruit default.
// Two rules every preset follows:
//   - targetPeak: SDR-output presets use 203 (SDR reference white, ≈ what
//     auto resolves to on the SDR path). Below 203 brightens/compresses;
//     HDR-to-SDR deliberately goes *lower* (not higher!) to brighten —
//     raising target-peak darkens. Passthrough presets (hdrOutput: true)
//     MUST use 0.0 (= auto): an explicit number there is an absolute PQ
//     output ceiling, and 203 crushed HDR to SDR brightness on a 1450-nit
//     panel (verified via video-target-params once the dead slider was
//     fixed — the 203 these presets shipped with had never reached mpv).
//   - No preset enables interpolation. It drags in video-sync=display-resample,
//     which misbehaves on any machine whose driver isn't actually vsyncing
//     (see the display-resample gotcha); users opt in via the toggle, which
//     runs the display-sync verifier.
List<VideoPreset> get builtinVideoPresets => [
  // "Best Quality" is split by *display*, not by content: the SDR preset
  // already handles HDR videos (they get tone-mapped down, and tone mapping
  // only engages when content exceeds target-peak), but on an HDR display
  // "best" means passthrough — target-trc=pq + target-colorspace-hint — which
  // directly conflicts with the SDR preset's target-trc=auto. One preset
  // cannot express both, hence the pair. Same shader/scaler stack in each;
  // only the output path differs.
  VideoPreset(
    id: 'best_quality',
    // "Best SDR", not "Best Quality SDR": the 160px preset card ellipsizes
    // longer names, which left the SDR/HDR pair reading identically as
    // "Best Quality…" — the one part that mattered was the part cut off.
    name: 'Best SDR',
    emoji: '💎',
    // Descriptions on this pair say *when to pick it*, not what's inside —
    // the card fits ~2 lines of ~22 chars, and "full shader chain…" told a
    // confused user nothing about which of the two to click.
    description: 'Use when Windows HDR is off. Any video works',
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
      // Matches mpv's high-quality profile: ignore the brightest 0.005% of
      // pixels when measuring peak, so stray speculars can't dim the tone map.
      hdrPeakPercentile: 99.995,
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
    id: 'best_quality_hdr',
    name: 'Best HDR',
    emoji: '💠',
    description: 'Use when Windows HDR is on. Any video works',
    state: VideoState(
      // Identical shader/scaler stack to Best SDR — including stock CAS, a
      // deliberate decision: CAS linearizes with sRGB math, which under-bites
      // slightly on this preset's PQ passthrough output, so Best HDR reads a
      // touch softer than Best SDR. Accepted: CAS-vivid belongs to the
      // flavor presets, and users who want more bite swap the sharpener on
      // the Shaders tab (that's what hand-tweaks + Save Preset are for).
      shadersLowRes: [
        'FSRCNNX_x2_16-0-4-1.glsl',
        'SSimSuperRes.glsl',
        'KrigBilateral.glsl',
        'CAS.glsl',
      ],
      shadersHighRes: ['CfL_Prediction.glsl', 'CAS.glsl'],
      // Passthrough block: must exactly match setHdrOutput(true) /
      // _checkWindowsHdr's auto-detect state, or applying this preset would
      // differ from toggling HDR Output on (same invariant as HDR Punch).
      toneMappingAlgorithm: 'none',
      hdrComputePeak: false,
      hdrOutput: true,
      inverseToneMapping: true,
      targetColorspaceHint: true,
      targetTrc: 'pq',
      // auto — never a number here, see the header comment.
      targetPeak: 0.0,
      contrastRecovery: 0.3,
      visualizeToneMapping: false,
      targetPrim: 'auto',
      targetGamut: 'auto',
      // Neutral grade — unlike HDR Punch this is fidelity, not punch; the
      // display's real dynamic range is the whole point.
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
      // These values are exactly Gloss level 3 on the Grading tab's macro
      // row (level 5 = the hot HDR-Output grade); keep the two in sync.
      contrast: 6,
      gamma: -3,
      saturation: 9,
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
    id: 'hdr_punch',
    name: 'HDR Punch',
    emoji: '💥',
    description: 'Full HDR passthrough with the hottest grade — for HDR displays '
        '(Windows HDR must be on)',
    state: VideoState(
      // The "3D pop" preset: real dynamic range does the heavy lifting, the
      // grade and sharpener sit on top. CAS-vivid = stock CAS with CONTRAST
      // 0.3 for micro-contrast (one sharpener only — never stacked with CAS
      // or adaptive-sharpen); CfL handles chroma at high res like Best
      // Quality does.
      shadersLowRes: ['FSRCNNX_x2_16-0-4-1.glsl', 'CAS-vivid.glsl'],
      shadersHighRes: ['CfL_Prediction.glsl', 'CAS-vivid.glsl'],
      // Passthrough block: must exactly match setHdrOutput(true) /
      // _checkWindowsHdr's auto-detect state, or applying this preset would
      // differ from toggling HDR Output on.
      toneMappingAlgorithm: 'none',
      hdrComputePeak: false,
      hdrOutput: true,
      inverseToneMapping: true,
      targetColorspaceHint: true,
      targetTrc: 'pq',
      // auto — never a number here, see the header comment.
      targetPeak: 0.0,
      contrastRecovery: 0.3,
      visualizeToneMapping: false,
      targetPrim: 'auto',
      targetGamut: 'auto',
      brightness: 0,
      // Gloss level 5 — the grade documented as "only looks right with HDR
      // Output on" (inverse tone mapping stretches the range and absorbs
      // it). Keep in sync with _glossLevels in tab_video_grading.dart.
      contrast: 10,
      gamma: -5,
      saturation: 15,
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
    id: 'overkill',
    name: 'Overkill',
    emoji: '🔥',
    description: 'Every shader and scaler maxed, colorspace hint set to '
        'forward the source\'s own dynamic HDR metadata rather than forcing '
        'a fixed PQ ceiling',
    state: VideoState(
      // Dai's personal config, promoted to a built-in on his request (was
      // "DaiFav") — deliberately stacks same-purpose shaders (CAS *and*
      // adaptive-sharpen together) that every other preset treats as
      // alternatives; toggleShader no longer enforces exclusion between
      // them, so this is just his real setup, not a bug.
      // Recalibrated again 2026-07-18 to match his latest DaiFav save. HDR
      // Output is back on (target-trc=pq, inverse-tone-mapping=yes)
      // alongside source-dynamic colorspace hint mode, so mpv still forwards
      // the source's own per-scene HDR metadata rather than a fixed target.
      // targetPeakHdr moved off its old explicit 3000 override to auto
      // (0.0), matching every other passthrough preset now that HDR Output
      // owns target-peak. Also changed: toneMappingAlgorithm bt.2446a→
      // spline, gamutMappingMode clip→perceptual, debandThreshold/Range/
      // Grain 32/16/0→35/12/5, scale spline36→ewa_lanczossharp, scale/
      // cscale-antiring 0.08→0.5. Shader chain swapped CAS-vivid for CAS
      // and added KrigBilateral, Anime4K_Restore_CNN_M, ArtCNN_C4F16.
      // Recalibrated again same day after the scale/cscale/dscale dropdowns
      // gained more mpv kernel choices: scale ewa_lanczossharp→
      // ewa_lanczos4sharpest, cscale spline36→ewa_lanczos, dscale
      // catmull_rom→mitchell, scale/cscale-antiring 0.5→0.8.
      shadersLowRes: [
        'FSRCNNX_x2_16-0-4-1.glsl',
        'SSimSuperRes.glsl',
        'CfL_Prediction.glsl',
        'adaptive-sharpen.glsl',
        'KrigBilateral.glsl',
        'CAS.glsl',
        'Anime4K_Restore_CNN_M.glsl',
        'ArtCNN_C4F16.glsl',
      ],
      shadersHighRes: ['CAS.glsl', 'CfL_Prediction.glsl', 'adaptive-sharpen.glsl'],
      toneMappingAlgorithm: 'spline',
      targetPeak: 0.0,
      targetPeakHdr: 0.0,
      contrastRecovery: 0.5,
      visualizeToneMapping: false,
      hdrComputePeak: true,
      hdrOutput: true,
      inverseToneMapping: true,
      targetColorspaceHint: true,
      targetColorspaceHintMode: 'source-dynamic',
      targetPrim: 'auto',
      targetGamut: 'auto',
      targetTrc: 'pq',
      gamutMappingMode: 'perceptual',
      brightness: 0,
      contrast: 0,
      gamma: 0,
      saturation: 0,
      deband: true,
      debandIterations: 2,
      debandThreshold: 35,
      debandRange: 12,
      debandGrain: 5,
      dither: 'error-diffusion',
      errorDiffusion: 'floyd-steinberg',
      interpolation: false,
      videoSync: 'audio',
      tscale: 'oversample',
      tscaleWindow: 'sphinx',
      tscaleRadius: 0.95,
      tscaleBlur: 0.01,
      tscaleClamp: 0.0,
      scale: 'ewa_lanczos4sharpest',
      cscale: 'ewa_lanczos',
      dscale: 'mitchell',
      sharpen: 0.02,
      scaleAntiring: 0.8,
      cscaleAntiring: 0.8,
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
      // Stock mpv is target-peak=auto, and Bypass means stock.
      targetPeak: 0.0,
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
