// lib/models/dsp_state.dart
import 'eq_band.dart';

class PanMatrix {
  // FL output: FL*flfl + FC*flfc + BL*flbl + SL*flsl + LFE*fllfe
  double flfl, flfc, flbl, flsl, fllfe;
  // FR output: FR*frfr + FC*frfc + BR*frbr + SR*frsr + LFE*frlfe
  double frfr, frfc, frbr, frsr, frlfe;

  PanMatrix({
    this.flfl = 0.40,
    this.flfc = 0.55,
    this.flbl = -0.20,
    this.flsl = -0.18,
    this.fllfe = 0.06,
    this.frfr = 0.40,
    this.frfc = 0.55,
    this.frbr = 0.20,
    this.frsr = 0.18,
    this.frlfe = 0.06,
  });

  PanMatrix copyWith({
    double? flfl, double? flfc, double? flbl, double? flsl, double? fllfe,
    double? frfr, double? frfc, double? frbr, double? frsr, double? frlfe,
  }) {
    return PanMatrix(
      flfl: flfl ?? this.flfl,
      flfc: flfc ?? this.flfc,
      flbl: flbl ?? this.flbl,
      flsl: flsl ?? this.flsl,
      fllfe: fllfe ?? this.fllfe,
      frfr: frfr ?? this.frfr,
      frfc: frfc ?? this.frfc,
      frbr: frbr ?? this.frbr,
      frsr: frsr ?? this.frsr,
      frlfe: frlfe ?? this.frlfe,
    );
  }

  Map<String, dynamic> toJson() => {
    'flfl': flfl, 'flfc': flfc, 'flbl': flbl, 'flsl': flsl, 'fllfe': fllfe,
    'frfr': frfr, 'frfc': frfc, 'frbr': frbr, 'frsr': frsr, 'frlfe': frlfe,
  };

  factory PanMatrix.fromJson(Map<String, dynamic> json) => PanMatrix(
    flfl: (json['flfl'] as num?)?.toDouble() ?? 0.40,
    flfc: (json['flfc'] as num?)?.toDouble() ?? 0.55,
    flbl: (json['flbl'] as num?)?.toDouble() ?? -0.20,
    flsl: (json['flsl'] as num?)?.toDouble() ?? -0.18,
    fllfe: (json['fllfe'] as num?)?.toDouble() ?? 0.06,
    frfr: (json['frfr'] as num?)?.toDouble() ?? 0.40,
    frfc: (json['frfc'] as num?)?.toDouble() ?? 0.55,
    frbr: (json['frbr'] as num?)?.toDouble() ?? 0.20,
    frsr: (json['frsr'] as num?)?.toDouble() ?? 0.18,
    frlfe: (json['frlfe'] as num?)?.toDouble() ?? 0.06,
  );
}

class DynAudNormSettings {
  int frameLength;   // f: frame length in ms (10-8000)
  double gain;       // g: target gain (1.0-100.0)
  double peak;       // p: peak normalization (0.0-1.0)
  double maxGain;    // m: max gain factor (1.0-100.0)

  DynAudNormSettings({
    this.frameLength = 420,
    this.gain = 3.3,
    this.peak = 0.5,
    this.maxGain = 3.0,
  });

  DynAudNormSettings copyWith({
    int? frameLength, double? gain, double? peak, double? maxGain,
  }) {
    return DynAudNormSettings(
      frameLength: frameLength ?? this.frameLength,
      gain: gain ?? this.gain,
      peak: peak ?? this.peak,
      maxGain: maxGain ?? this.maxGain,
    );
  }

  Map<String, dynamic> toJson() => {
    'frameLength': frameLength,
    'gain': gain,
    'peak': peak,
    'maxGain': maxGain,
  };

  factory DynAudNormSettings.fromJson(Map<String, dynamic> json) => DynAudNormSettings(
    frameLength: json['frameLength'] as int? ?? 420,
    gain: (json['gain'] as num?)?.toDouble() ?? 3.3,
    peak: (json['peak'] as num?)?.toDouble() ?? 0.5,
    maxGain: (json['maxGain'] as num?)?.toDouble() ?? 3.0,
  );
}

class AmbienceSettings {
  bool enabled;
  double highpassFreq;   // HPF cutoff (Hz)
  double lowpassFreq;    // LPF cutoff (Hz)
  double echoDelay;      // aecho delay
  double echoDecay;      // aecho decay
  double echoVolume;     // aecho volume
  double echoFeedback;   // aecho feedback
  double mixWeight;      // amix weights (1 X) - X is this value

  AmbienceSettings({
    this.enabled = true,
    this.highpassFreq = 700,
    this.lowpassFreq = 7500,
    this.echoDelay = 0.22,
    this.echoDecay = 0.32,
    this.echoVolume = 18,
    this.echoFeedback = 0.20,
    this.mixWeight = 0.36,
  });

  AmbienceSettings copyWith({
    bool? enabled,
    double? highpassFreq, double? lowpassFreq,
    double? echoDelay, double? echoDecay,
    double? echoVolume, double? echoFeedback,
    double? mixWeight,
  }) {
    return AmbienceSettings(
      enabled: enabled ?? this.enabled,
      highpassFreq: highpassFreq ?? this.highpassFreq,
      lowpassFreq: lowpassFreq ?? this.lowpassFreq,
      echoDelay: echoDelay ?? this.echoDelay,
      echoDecay: echoDecay ?? this.echoDecay,
      echoVolume: echoVolume ?? this.echoVolume,
      echoFeedback: echoFeedback ?? this.echoFeedback,
      mixWeight: mixWeight ?? this.mixWeight,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'highpassFreq': highpassFreq,
    'lowpassFreq': lowpassFreq,
    'echoDelay': echoDelay,
    'echoDecay': echoDecay,
    'echoVolume': echoVolume,
    'echoFeedback': echoFeedback,
    'mixWeight': mixWeight,
  };

  factory AmbienceSettings.fromJson(Map<String, dynamic> json) => AmbienceSettings(
    enabled: json['enabled'] as bool? ?? true,
    highpassFreq: (json['highpassFreq'] as num?)?.toDouble() ?? 700.0,
    lowpassFreq: (json['lowpassFreq'] as num?)?.toDouble() ?? 7500.0,
    echoDelay: (json['echoDelay'] as num?)?.toDouble() ?? 0.22,
    echoDecay: (json['echoDecay'] as num?)?.toDouble() ?? 0.32,
    echoVolume: (json['echoVolume'] as num?)?.toDouble() ?? 18.0,
    echoFeedback: (json['echoFeedback'] as num?)?.toDouble() ?? 0.20,
    mixWeight: (json['mixWeight'] as num?)?.toDouble() ?? 0.36,
  );
}

class HighShelfSettings {
  double freq;   // f: frequency (Hz)
  double gain;   // g: gain (dB)
  double width;  // w: width

  HighShelfSettings({
    this.freq = 4200,
    this.gain = 1.4,
    this.width = 2200,
  });

  HighShelfSettings copyWith({double? freq, double? gain, double? width}) {
    return HighShelfSettings(
      freq: freq ?? this.freq,
      gain: gain ?? this.gain,
      width: width ?? this.width,
    );
  }

  Map<String, dynamic> toJson() => {
    'freq': freq,
    'gain': gain,
    'width': width,
  };

  factory HighShelfSettings.fromJson(Map<String, dynamic> json) => HighShelfSettings(
    freq: (json['freq'] as num?)?.toDouble() ?? 4200.0,
    gain: (json['gain'] as num?)?.toDouble() ?? 1.4,
    width: (json['width'] as num?)?.toDouble() ?? 2200.0,
  );
}

class CompressorSettings {
  double threshold; // dB
  double ratio;
  double attack;   // ms
  double release;  // ms
  double makeup;   // dB

  CompressorSettings({
    this.threshold = -22,
    this.ratio = 4.5,
    this.attack = 3,
    this.release = 110,
    this.makeup = 4,
  });

  CompressorSettings copyWith({
    double? threshold, double? ratio,
    double? attack, double? release, double? makeup,
  }) {
    return CompressorSettings(
      threshold: threshold ?? this.threshold,
      ratio: ratio ?? this.ratio,
      attack: attack ?? this.attack,
      release: release ?? this.release,
      makeup: makeup ?? this.makeup,
    );
  }

  Map<String, dynamic> toJson() => {
    'threshold': threshold,
    'ratio': ratio,
    'attack': attack,
    'release': release,
    'makeup': makeup,
  };

  factory CompressorSettings.fromJson(Map<String, dynamic> json) => CompressorSettings(
    threshold: (json['threshold'] as num?)?.toDouble() ?? -22.0,
    ratio: (json['ratio'] as num?)?.toDouble() ?? 4.5,
    attack: (json['attack'] as num?)?.toDouble() ?? 3.0,
    release: (json['release'] as num?)?.toDouble() ?? 110.0,
    makeup: (json['makeup'] as num?)?.toDouble() ?? 4.0,
  );
}

class LimiterSettings {
  bool enabled;
  double limit; // dB ceiling

  LimiterSettings({this.enabled = true, this.limit = -1.0});

  LimiterSettings copyWith({bool? enabled, double? limit}) {
    return LimiterSettings(
      enabled: enabled ?? this.enabled,
      limit: limit ?? this.limit,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'limit': limit,
  };

  factory LimiterSettings.fromJson(Map<String, dynamic> json) => LimiterSettings(
    enabled: json['enabled'] as bool? ?? true,
    limit: (json['limit'] as num?)?.toDouble() ?? -1.0,
  );
}

class DspState {
  bool dynaudnormEnabled;
  DynAudNormSettings dynaudnorm;
  PanMatrix panMatrix;
  Map<String, PanMatrix> panMatrices; // Per-config pan matrices
  AmbienceSettings ambience;
  double extraStereo;   // 0.0 - 0.5
  List<EqBand> eqBands;
  HighShelfSettings highShelf;
  CompressorSettings compressor;
  LimiterSettings limiter;
  bool bypass; // sends af clr
  String channelConfig; // 'stereo', '5.1', '7.1'

  DspState({
    this.dynaudnormEnabled = true,
    DynAudNormSettings? dynaudnorm,
    PanMatrix? panMatrix,
    Map<String, PanMatrix>? panMatrices,
    AmbienceSettings? ambience,
    this.extraStereo = 0.08,
    List<EqBand>? eqBands,
    HighShelfSettings? highShelf,
    CompressorSettings? compressor,
    LimiterSettings? limiter,
    this.bypass = false,
    this.channelConfig = 'stereo',
  })  : dynaudnorm = dynaudnorm ?? DynAudNormSettings(),
        panMatrix = panMatrix ?? PanMatrix(),
        panMatrices = panMatrices ?? {
          'stereo': PanMatrix(),
          '5.1': PanMatrix(),
          '7.1': PanMatrix(),
        },
        ambience = ambience ?? AmbienceSettings(),
        eqBands = eqBands ?? defaultEqBands(),
        highShelf = highShelf ?? HighShelfSettings(),
        compressor = compressor ?? CompressorSettings(),
        limiter = limiter ?? LimiterSettings();

  DspState copyWith({
    bool? dynaudnormEnabled,
    DynAudNormSettings? dynaudnorm,
    PanMatrix? panMatrix,
    Map<String, PanMatrix>? panMatrices,
    AmbienceSettings? ambience,
    double? extraStereo,
    List<EqBand>? eqBands,
    HighShelfSettings? highShelf,
    CompressorSettings? compressor,
    LimiterSettings? limiter,
    bool? bypass,
    String? channelConfig,
  }) {
    return DspState(
      dynaudnormEnabled: dynaudnormEnabled ?? this.dynaudnormEnabled,
      dynaudnorm: dynaudnorm ?? this.dynaudnorm,
      panMatrix: panMatrix ?? this.panMatrix,
      panMatrices: panMatrices ?? this.panMatrices,
      ambience: ambience ?? this.ambience,
      extraStereo: extraStereo ?? this.extraStereo,
      eqBands: eqBands ?? List.from(this.eqBands),
      highShelf: highShelf ?? this.highShelf,
      compressor: compressor ?? this.compressor,
      limiter: limiter ?? this.limiter,
      bypass: bypass ?? this.bypass,
      channelConfig: channelConfig ?? this.channelConfig,
    );
  }

  Map<String, dynamic> toJson() => {
    'dynaudnormEnabled': dynaudnormEnabled,
    'dynaudnorm': dynaudnorm.toJson(),
    'panMatrix': panMatrix.toJson(),
    'panMatrices': panMatrices.map((k, v) => MapEntry(k, v.toJson())),
    'ambience': ambience.toJson(),
    'extraStereo': extraStereo,
    'eqBands': eqBands.map((e) => e.toJson()).toList(),
    'highShelf': highShelf.toJson(),
    'compressor': compressor.toJson(),
    'limiter': limiter.toJson(),
    'bypass': bypass,
    'channelConfig': channelConfig,
  };

  factory DspState.fromJson(Map<String, dynamic> json) {
    Map<String, PanMatrix>? panMatrices;
    if (json['panMatrices'] != null) {
      final pm = json['panMatrices'] as Map<String, dynamic>;
      panMatrices = pm.map((k, v) => MapEntry(k, PanMatrix.fromJson(v as Map<String, dynamic>)));
    }
    return DspState(
      dynaudnormEnabled: json['dynaudnormEnabled'] as bool? ?? true,
      dynaudnorm: json['dynaudnorm'] != null ? DynAudNormSettings.fromJson(json['dynaudnorm']) : null,
      panMatrix: json['panMatrix'] != null ? PanMatrix.fromJson(json['panMatrix']) : null,
      panMatrices: panMatrices,
      ambience: json['ambience'] != null ? AmbienceSettings.fromJson(json['ambience']) : null,
      extraStereo: (json['extraStereo'] as num?)?.toDouble() ?? 0.08,
      eqBands: json['eqBands'] != null
          ? (json['eqBands'] as List).map((e) => EqBand.fromJson(e as Map<String, dynamic>)).toList()
          : null,
      highShelf: json['highShelf'] != null ? HighShelfSettings.fromJson(json['highShelf']) : null,
      compressor: json['compressor'] != null ? CompressorSettings.fromJson(json['compressor']) : null,
      limiter: json['limiter'] != null ? LimiterSettings.fromJson(json['limiter']) : null,
      bypass: json['bypass'] as bool? ?? false,
      channelConfig: json['channelConfig'] as String? ?? 'stereo',
    );
  }
}
