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
}

class DspState {
  bool dynaudnormEnabled;
  DynAudNormSettings dynaudnorm;
  PanMatrix panMatrix;
  AmbienceSettings ambience;
  double extraStereo;   // 0.0 - 0.5
  List<EqBand> eqBands;
  HighShelfSettings highShelf;
  CompressorSettings compressor;
  LimiterSettings limiter;
  bool bypass; // sends af clr

  DspState({
    this.dynaudnormEnabled = true,
    DynAudNormSettings? dynaudnorm,
    PanMatrix? panMatrix,
    AmbienceSettings? ambience,
    this.extraStereo = 0.08,
    List<EqBand>? eqBands,
    HighShelfSettings? highShelf,
    CompressorSettings? compressor,
    LimiterSettings? limiter,
    this.bypass = false,
  })  : dynaudnorm = dynaudnorm ?? DynAudNormSettings(),
        panMatrix = panMatrix ?? PanMatrix(),
        ambience = ambience ?? AmbienceSettings(),
        eqBands = eqBands ?? defaultEqBands(),
        highShelf = highShelf ?? HighShelfSettings(),
        compressor = compressor ?? CompressorSettings(),
        limiter = limiter ?? LimiterSettings();

  DspState copyWith({
    bool? dynaudnormEnabled,
    DynAudNormSettings? dynaudnorm,
    PanMatrix? panMatrix,
    AmbienceSettings? ambience,
    double? extraStereo,
    List<EqBand>? eqBands,
    HighShelfSettings? highShelf,
    CompressorSettings? compressor,
    LimiterSettings? limiter,
    bool? bypass,
  }) {
    return DspState(
      dynaudnormEnabled: dynaudnormEnabled ?? this.dynaudnormEnabled,
      dynaudnorm: dynaudnorm ?? this.dynaudnorm,
      panMatrix: panMatrix ?? this.panMatrix,
      ambience: ambience ?? this.ambience,
      extraStereo: extraStereo ?? this.extraStereo,
      eqBands: eqBands ?? List.from(this.eqBands),
      highShelf: highShelf ?? this.highShelf,
      compressor: compressor ?? this.compressor,
      limiter: limiter ?? this.limiter,
      bypass: bypass ?? this.bypass,
    );
  }
}
