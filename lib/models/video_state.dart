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

  Map<String, dynamic> toJson() => {
    'activeShaders': activeShaders,
    'toneMappingAlgorithm': toneMappingAlgorithm,
    'targetPeak': targetPeak,
    'contrastRecovery': contrastRecovery,
    'visualizeToneMapping': visualizeToneMapping,
    'brightness': brightness,
    'contrast': contrast,
    'gamma': gamma,
    'deband': deband,
    'debandIterations': debandIterations,
    'debandThreshold': debandThreshold,
    'interpolation': interpolation,
    'videoSync': videoSync,
    'tscale': tscale,
    'scale': scale,
    'cscale': cscale,
    'dscale': dscale,
  };

  factory VideoState.fromJson(Map<String, dynamic> json) => VideoState(
    activeShaders: (json['activeShaders'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    toneMappingAlgorithm: json['toneMappingAlgorithm'] as String? ?? 'auto',
    targetPeak: (json['targetPeak'] as num?)?.toDouble() ?? 100.0,
    contrastRecovery: (json['contrastRecovery'] as num?)?.toDouble() ?? 0.0,
    visualizeToneMapping: json['visualizeToneMapping'] as bool? ?? false,
    brightness: json['brightness'] as int? ?? 0,
    contrast: json['contrast'] as int? ?? 0,
    gamma: json['gamma'] as int? ?? 0,
    deband: json['deband'] as bool? ?? false,
    debandIterations: json['debandIterations'] as int? ?? 1,
    debandThreshold: json['debandThreshold'] as int? ?? 0,
    interpolation: json['interpolation'] as bool? ?? false,
    videoSync: json['videoSync'] as String? ?? 'audio',
    tscale: json['tscale'] as String? ?? 'oversample',
    scale: json['scale'] as String? ?? 'bilinear',
    cscale: json['cscale'] as String? ?? 'bilinear',
    dscale: json['dscale'] as String? ?? 'bilinear',
  );
}
