// lib/models/preset.dart
import 'dsp_state.dart';
import 'eq_band.dart';

class Preset {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final DspState state;

  const Preset({
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

  factory Preset.fromJson(Map<String, dynamic> json) => Preset(
    id: json['id'] as String,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
    description: json['description'] as String,
    state: DspState.fromJson(json['state'] as Map<String, dynamic>),
  );
}

List<Preset> get builtinPresets => [
  Preset(
    id: 'movie_dialog',
    name: 'Movie',
    emoji: '🎬',
    description: 'Dialog-first cinematic mix',
    state: DspState(
      dynaudnormEnabled: true,
      dynaudnorm: DynAudNormSettings(frameLength: 420, gain: 3.3, peak: 0.5, maxGain: 3.0),
      panMatrix: PanMatrix(),
      ambience: AmbienceSettings(enabled: true),
      extraStereo: 0.08,
      eqBands: defaultEqBands(),
      highShelf: HighShelfSettings(freq: 4200, gain: 1.4, width: 2200),
      compressor: CompressorSettings(threshold: -22, ratio: 4.5, attack: 3, release: 110, makeup: 4),
      limiter: LimiterSettings(enabled: true, limit: -1.0),
    ),
  ),
  Preset(
    id: 'movie_balanced',
    name: 'Balanced',
    emoji: '⚖️',
    description: 'Lighter compression, wider dynamics',
    state: DspState(
      dynaudnormEnabled: true,
      dynaudnorm: DynAudNormSettings(frameLength: 420, gain: 2.5, peak: 0.6, maxGain: 3.0),
      panMatrix: PanMatrix(flfc: 0.45, frfc: 0.45),
      ambience: AmbienceSettings(enabled: true, mixWeight: 0.25),
      extraStereo: 0.05,
      eqBands: [
        EqBand(freq: 60,   width: 110, gain: -3.0),
        EqBand(freq: 125,  width: 110, gain: 2.0),
        EqBand(freq: 1800, width: 300, gain: 1.5),
        EqBand(freq: 2600, width: 500, gain: 1.2),
        EqBand(freq: 3500, width: 600, gain: 0.7),
        EqBand(freq: 5500, width: 200, gain: -2.0),
        EqBand(freq: 8000, width: 1600, gain: 0.8),
      ],
      highShelf: HighShelfSettings(freq: 4200, gain: 1.0, width: 2200),
      compressor: CompressorSettings(threshold: -20, ratio: 3.0, attack: 5, release: 130, makeup: 3),
      limiter: LimiterSettings(enabled: true, limit: -1.0),
    ),
  ),
  Preset(
    id: 'night_mode',
    name: 'Night',
    emoji: '🌙',
    description: 'Compressed dynamics, reduced peaks',
    state: DspState(
      dynaudnormEnabled: true,
      dynaudnorm: DynAudNormSettings(frameLength: 420, gain: 4.0, peak: 0.4, maxGain: 3.0),
      panMatrix: PanMatrix(flfc: 0.60, frfc: 0.60),
      ambience: AmbienceSettings(enabled: false),
      extraStereo: 0.04,
      eqBands: nightEqBands(),
      highShelf: HighShelfSettings(freq: 4200, gain: 0.5, width: 2200),
      compressor: CompressorSettings(threshold: -26, ratio: 6.0, attack: 2, release: 80, makeup: 5),
      limiter: LimiterSettings(enabled: true, limit: -2.0),
    ),
  ),
  Preset(
    id: 'music_transparent',
    name: 'Music',
    emoji: '🎵',
    description: 'Transparent — only limiter active',
    state: DspState(
      dynaudnormEnabled: false,
      dynaudnorm: DynAudNormSettings(),
      panMatrix: PanMatrix(flfl: 1.0, flfc: 0.0, flbl: 0.0, flsl: 0.0, fllfe: 0.0,
                          frfr: 1.0, frfc: 0.0, frbr: 0.0, frsr: 0.0, frlfe: 0.0),
      ambience: AmbienceSettings(enabled: false),
      extraStereo: 0.0,
      eqBands: musicEqBands(),
      highShelf: HighShelfSettings(freq: 4200, gain: 0.0, width: 2200),
      compressor: CompressorSettings(threshold: -16, ratio: 1.6, attack: 12, release: 120, makeup: 2),
      limiter: LimiterSettings(enabled: true, limit: -1.0),
    ),
  ),
  Preset(
    id: 'bypass',
    name: 'Bypass',
    emoji: '🔇',
    description: 'No processing — raw MPV output',
    state: DspState(bypass: true),
  ),
];
