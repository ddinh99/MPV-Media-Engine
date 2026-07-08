// lib/models/video_state.dart

class VideoState {
  List<String> activeShaders;
  String toneMappingAlgorithm;
  double targetPeak;
  double contrastRecovery;
  bool visualizeToneMapping;
  
  int brightness;
  int contrast;
  int gamma;
  
  bool deband;
  int debandIterations;
  int debandThreshold;

  bool interpolation;
  String videoSync;
  String tscale;
  String scale;
  String cscale;
  String dscale;

  VideoState({
    this.activeShaders = const [],
    this.toneMappingAlgorithm = 'auto',
    this.targetPeak = 100.0,
    this.contrastRecovery = 0.0,
    this.visualizeToneMapping = false,
    this.brightness = 0,
    this.contrast = 0,
    this.gamma = 0,
    this.deband = false,
    this.debandIterations = 1,
    this.debandThreshold = 0,
    this.interpolation = false,
    this.videoSync = 'audio',
    this.tscale = 'oversample',
    this.scale = 'bilinear',
    this.cscale = 'bilinear',
    this.dscale = 'bilinear',
  });

  VideoState copyWith({
    List<String>? activeShaders,
    String? toneMappingAlgorithm,
    double? targetPeak,
    double? contrastRecovery,
    bool? visualizeToneMapping,
    int? brightness,
    int? contrast,
    int? gamma,
    bool? deband,
    int? debandIterations,
    int? debandThreshold,
    bool? interpolation,
    String? videoSync,
    String? tscale,
    String? scale,
    String? cscale,
    String? dscale,
  }) {
    return VideoState(
      activeShaders: activeShaders ?? this.activeShaders,
      toneMappingAlgorithm: toneMappingAlgorithm ?? this.toneMappingAlgorithm,
      targetPeak: targetPeak ?? this.targetPeak,
      contrastRecovery: contrastRecovery ?? this.contrastRecovery,
      visualizeToneMapping: visualizeToneMapping ?? this.visualizeToneMapping,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      gamma: gamma ?? this.gamma,
      deband: deband ?? this.deband,
      debandIterations: debandIterations ?? this.debandIterations,
      debandThreshold: debandThreshold ?? this.debandThreshold,
      interpolation: interpolation ?? this.interpolation,
      videoSync: videoSync ?? this.videoSync,
      tscale: tscale ?? this.tscale,
      scale: scale ?? this.scale,
      cscale: cscale ?? this.cscale,
      dscale: dscale ?? this.dscale,
    );
  }
}
