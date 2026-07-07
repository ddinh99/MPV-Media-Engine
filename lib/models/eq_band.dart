// lib/models/eq_band.dart

class EqBand {
  final int freq;
  final int width;
  double gain;
  final int type;

  EqBand({
    required this.freq,
    required this.width,
    required this.gain,
    this.type = 1,
  });

  EqBand copyWith({double? gain, int? width}) {
    return EqBand(
      freq: freq,
      width: width ?? this.width,
      gain: gain ?? this.gain,
      type: type,
    );
  }

  Map<String, dynamic> toJson() => {
    'freq': freq,
    'width': width,
    'gain': gain,
    'type': type,
  };

  factory EqBand.fromJson(Map<String, dynamic> json) => EqBand(
    freq: json['freq'] as int,
    width: json['width'] as int,
    gain: (json['gain'] as num).toDouble(),
    type: json['type'] as int? ?? 1,
  );

  /// Builds anequalizer band string for both channels (c0 and c1)
  String toFilterString() {
    final sign = gain >= 0 ? '+' : '';
    return 'c0 f=$freq w=$width g=$sign${gain.toStringAsFixed(1)} t=$type'
        '|c1 f=$freq w=$width g=$sign${gain.toStringAsFixed(1)} t=$type';
  }
}

/// Default EQ bands from the user's filter chain
List<EqBand> defaultEqBands() {
  return [
    EqBand(freq: 60,   width: 110, gain: -4.5),
    EqBand(freq: 125,  width: 110, gain: 3.0),
    EqBand(freq: 1800, width: 300, gain: 2.2),
    EqBand(freq: 2600, width: 500, gain: 1.8),
    EqBand(freq: 3500, width: 600, gain: 1.0),
    EqBand(freq: 5500, width: 200, gain: -3.0),
    EqBand(freq: 8000, width: 1600, gain: 1.2),
  ];
}

/// Music transparent EQ (near-flat)
List<EqBand> musicEqBands() {
  return [
    EqBand(freq: 60,   width: 110, gain: 0.0),
    EqBand(freq: 125,  width: 110, gain: 0.0),
    EqBand(freq: 1800, width: 300, gain: 0.0),
    EqBand(freq: 2600, width: 500, gain: 0.0),
    EqBand(freq: 3500, width: 600, gain: 0.0),
    EqBand(freq: 5500, width: 200, gain: 0.0),
    EqBand(freq: 8000, width: 1600, gain: 0.0),
  ];
}

/// Night mode EQ (less treble, less bass)
List<EqBand> nightEqBands() {
  return [
    EqBand(freq: 60,   width: 110, gain: -6.0),
    EqBand(freq: 125,  width: 110, gain: 2.0),
    EqBand(freq: 1800, width: 300, gain: 1.5),
    EqBand(freq: 2600, width: 500, gain: 1.2),
    EqBand(freq: 3500, width: 600, gain: 0.8),
    EqBand(freq: 5500, width: 200, gain: -4.0),
    EqBand(freq: 8000, width: 1600, gain: -1.0),
  ];
}
