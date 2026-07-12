// lib/models/video_state.dart
import 'shader_metadata.dart';

class VideoState {
  /// Shader chains are kept per resolution tier and are independent: only the
  /// list matching the *current video's* tier is ever sent to mpv as
  /// `glsl-shaders` (see VideoProvider). Keeping one flat list looked simpler
  /// but meant shaders enabled for ≤1080p content silently applied to 4K too.
  List<String> shadersLowRes;
  List<String> shadersHighRes;

  String toneMappingAlgorithm;
  double targetPeak;
  double contrastRecovery;
  bool visualizeToneMapping;
  bool hdrComputePeak;
  bool hdrOutput;

  /// Mirrors mpv's `inverse-tone-mapping`. Held in state (rather than only
  /// being fired off inside setHdrOutput) so it takes part in the property
  /// diff — a reconnect/resync must re-push it, or HDR Output would come back
  /// half-applied: colorspace hint and PQ restored, but mpv still refusing to
  /// expand dynamic range.
  bool inverseToneMapping;

  bool targetColorspaceHint;
  String targetPrim;
  String targetGamut;
  String targetTrc;

  int brightness;
  int contrast;
  int gamma;

  bool deband;
  int debandIterations;
  int debandThreshold;

  bool interpolation;
  String videoSync;
  String tscale;
  String tscaleWindow;
  double tscaleRadius;
  double tscaleBlur;
  double tscaleClamp;
  String scale;
  String cscale;
  String dscale;

  bool hidpiWindowScale;

  VideoState({
    this.shadersLowRes = const [],
    this.shadersHighRes = const [],
    this.toneMappingAlgorithm = 'auto',
    // 203 nits = SDR reference white, what mpv's target-peak=auto assumes for
    // an SDR display. The old default of 100 sat *below* reference, which
    // engages tone mapping even on plain SDR content — dimming everything
    // relative to a stock mpv. (The state can't express "auto"; 203 is the
    // neutral equivalent.)
    this.targetPeak = 203.0,
    this.contrastRecovery = 0.0,
    this.visualizeToneMapping = false,
    this.hdrComputePeak = true,
    this.hdrOutput = false,
    this.inverseToneMapping = false,
    this.targetColorspaceHint = false,
    this.targetPrim = 'auto',
    this.targetGamut = 'auto',
    this.targetTrc = 'auto',
    this.brightness = 0,
    this.contrast = 0,
    this.gamma = 0,
    this.deband = false,
    this.debandIterations = 1,
    // mpv's own default strength. At the old default of 0 the deband filter
    // is a visual no-op, so flipping the Deband switch did nothing until the
    // user also discovered the threshold slider — a dead control by default.
    this.debandThreshold = 48,
    this.interpolation = false,
    this.videoSync = 'audio',
    this.tscale = 'oversample',
    this.tscaleWindow = 'sphinx',
    this.tscaleRadius = 0.95,
    this.tscaleBlur = 0.01,
    this.tscaleClamp = 0.0,
    this.scale = 'bilinear',
    this.cscale = 'bilinear',
    this.dscale = 'bilinear',
    this.hidpiWindowScale = false,
  });

  /// The shader chain that applies to a video of the given tier.
  List<String> shadersFor(ResolutionTier tier) =>
      tier == ResolutionTier.lowRes ? shadersLowRes : shadersHighRes;

  VideoState copyWith({
    List<String>? shadersLowRes,
    List<String>? shadersHighRes,
    String? toneMappingAlgorithm,
    double? targetPeak,
    double? contrastRecovery,
    bool? visualizeToneMapping,
    bool? hdrComputePeak,
    bool? hdrOutput,
    bool? inverseToneMapping,
    bool? targetColorspaceHint,
    String? targetPrim,
    String? targetGamut,
    String? targetTrc,
    int? brightness,
    int? contrast,
    int? gamma,
    bool? deband,
    int? debandIterations,
    int? debandThreshold,
    bool? interpolation,
    String? videoSync,
    String? tscale,
    String? tscaleWindow,
    double? tscaleRadius,
    double? tscaleBlur,
    double? tscaleClamp,
    String? scale,
    String? cscale,
    String? dscale,
    bool? hidpiWindowScale,
  }) {
    return VideoState(
      shadersLowRes: shadersLowRes ?? this.shadersLowRes,
      shadersHighRes: shadersHighRes ?? this.shadersHighRes,
      toneMappingAlgorithm: toneMappingAlgorithm ?? this.toneMappingAlgorithm,
      targetPeak: targetPeak ?? this.targetPeak,
      contrastRecovery: contrastRecovery ?? this.contrastRecovery,
      visualizeToneMapping: visualizeToneMapping ?? this.visualizeToneMapping,
      hdrComputePeak: hdrComputePeak ?? this.hdrComputePeak,
      hdrOutput: hdrOutput ?? this.hdrOutput,
      inverseToneMapping: inverseToneMapping ?? this.inverseToneMapping,
      targetColorspaceHint: targetColorspaceHint ?? this.targetColorspaceHint,
      targetPrim: targetPrim ?? this.targetPrim,
      targetGamut: targetGamut ?? this.targetGamut,
      targetTrc: targetTrc ?? this.targetTrc,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      gamma: gamma ?? this.gamma,
      deband: deband ?? this.deband,
      debandIterations: debandIterations ?? this.debandIterations,
      debandThreshold: debandThreshold ?? this.debandThreshold,
      interpolation: interpolation ?? this.interpolation,
      videoSync: videoSync ?? this.videoSync,
      tscale: tscale ?? this.tscale,
      tscaleWindow: tscaleWindow ?? this.tscaleWindow,
      tscaleRadius: tscaleRadius ?? this.tscaleRadius,
      tscaleBlur: tscaleBlur ?? this.tscaleBlur,
      tscaleClamp: tscaleClamp ?? this.tscaleClamp,
      scale: scale ?? this.scale,
      cscale: cscale ?? this.cscale,
      dscale: dscale ?? this.dscale,
      hidpiWindowScale: hidpiWindowScale ?? this.hidpiWindowScale,
    );
  }

  Map<String, dynamic> toJson() => {
    'shadersLowRes': shadersLowRes,
    'shadersHighRes': shadersHighRes,
    'toneMappingAlgorithm': toneMappingAlgorithm,
    'targetPeak': targetPeak,
    'contrastRecovery': contrastRecovery,
    'visualizeToneMapping': visualizeToneMapping,
    'hdrComputePeak': hdrComputePeak,
    'hdrOutput': hdrOutput,
    'inverseToneMapping': inverseToneMapping,
    'targetColorspaceHint': targetColorspaceHint,
    'targetPrim': targetPrim,
    'targetGamut': targetGamut,
    'targetTrc': targetTrc,
    'brightness': brightness,
    'contrast': contrast,
    'gamma': gamma,
    'deband': deband,
    'debandIterations': debandIterations,
    'debandThreshold': debandThreshold,
    'interpolation': interpolation,
    'videoSync': videoSync,
    'tscale': tscale,
    'tscaleWindow': tscaleWindow,
    'tscaleRadius': tscaleRadius,
    'tscaleBlur': tscaleBlur,
    'tscaleClamp': tscaleClamp,
    'scale': scale,
    'cscale': cscale,
    'dscale': dscale,
    'hidpiWindowScale': hidpiWindowScale,
  };

  static List<String>? _stringList(dynamic v) =>
      (v as List<dynamic>?)?.map((e) => e.toString()).toList();

  factory VideoState.fromJson(Map<String, dynamic> json) {
    var low = _stringList(json['shadersLowRes']);
    var high = _stringList(json['shadersHighRes']);

    // Migration: sessions/presets saved before the per-tier split carry one
    // flat 'activeShaders' list. Split it by each shader's recommended tier
    // (unknown shaders go in both) so an existing setup keeps working instead
    // of silently losing its shaders on first launch after the update.
    if (low == null && high == null) {
      final legacy = _stringList(json['activeShaders']);
      if (legacy != null) {
        low = <String>[];
        high = <String>[];
        for (final shader in legacy) {
          final tiers = shaderMetadataMap[shader]?.recommendedFor ??
              const [ResolutionTier.lowRes, ResolutionTier.highRes];
          if (tiers.contains(ResolutionTier.lowRes)) low.add(shader);
          if (tiers.contains(ResolutionTier.highRes)) high.add(shader);
        }
      }
    }

    return VideoState(
      shadersLowRes: low ?? [],
      shadersHighRes: high ?? [],
      toneMappingAlgorithm: json['toneMappingAlgorithm'] as String? ?? 'auto',
      targetPeak: (json['targetPeak'] as num?)?.toDouble() ?? 203.0,
      contrastRecovery: (json['contrastRecovery'] as num?)?.toDouble() ?? 0.0,
      visualizeToneMapping: json['visualizeToneMapping'] as bool? ?? false,
      hdrComputePeak: json['hdrComputePeak'] as bool? ?? true,
      hdrOutput: json['hdrOutput'] as bool? ?? false,
      inverseToneMapping: json['inverseToneMapping'] as bool? ?? false,
      targetColorspaceHint: json['targetColorspaceHint'] as bool? ?? false,
      targetPrim: json['targetPrim'] as String? ?? 'auto',
      targetGamut: json['targetGamut'] as String? ?? 'auto',
      targetTrc: json['targetTrc'] as String? ?? 'auto',
      brightness: json['brightness'] as int? ?? 0,
      contrast: json['contrast'] as int? ?? 0,
      gamma: json['gamma'] as int? ?? 0,
      deband: json['deband'] as bool? ?? false,
      debandIterations: json['debandIterations'] as int? ?? 1,
      debandThreshold: json['debandThreshold'] as int? ?? 48,
      interpolation: json['interpolation'] as bool? ?? false,
      videoSync: json['videoSync'] as String? ?? 'audio',
      tscale: json['tscale'] as String? ?? 'oversample',
      tscaleWindow: json['tscaleWindow'] as String? ?? 'sphinx',
      tscaleRadius: (json['tscaleRadius'] as num?)?.toDouble() ?? 0.95,
      tscaleBlur: (json['tscaleBlur'] as num?)?.toDouble() ?? 0.01,
      tscaleClamp: (json['tscaleClamp'] as num?)?.toDouble() ?? 0.0,
      scale: json['scale'] as String? ?? 'bilinear',
      cscale: json['cscale'] as String? ?? 'bilinear',
      dscale: json['dscale'] as String? ?? 'bilinear',
      hidpiWindowScale: json['hidpiWindowScale'] as bool? ?? false,
    );
  }
}
