// test/filter_chain_validity_test.dart
//
// Validates every DSP filter chain the app can ever send to mpv against a
// REAL ffmpeg binary (the one mpv itself embeds as libavfilter), not a
// hand-maintained range table. This project has repeatedly shipped filter
// params that "looked right" from memory but were rejected outright by
// ffmpeg, silently killing the *entire* af chain (dynaudnorm 'g' being fed a
// fractional "gain" instead of the real odd-integer Gaussian window size;
// the pan filter emitting a syntax error). A single bad parameter in one
// filter breaks every other filter in the same chain, so this must be
// checked proactively, not discovered from a rejection log after the fact.
//
// If ffmpeg.exe can't be found, every test here is skipped rather than
// failed - this is a correctness net for whoever is changing DSP code, not
// a CI requirement, and not every machine running `flutter test` will have
// a standalone ffmpeg binary sitting next to mpv.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_sound_engine/models/dsp_state.dart';
import 'package:mvp_sound_engine/models/eq_band.dart';
import 'package:mvp_sound_engine/models/favorites.dart';
import 'package:mvp_sound_engine/models/preset.dart';
import 'package:mvp_sound_engine/services/filter_builder.dart';

String? _findFfmpeg() {
  const candidates = [
    r'C:\Program Files\MPV1\ffmpeg.exe',
    r'C:\Program Files\mpv\ffmpeg.exe',
    r'C:\mpv\ffmpeg.exe',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  try {
    final result = Process.runSync('where', ['ffmpeg'], runInShell: true);
    if (result.exitCode == 0) {
      final first = (result.stdout as String).split('\n').first.trim();
      if (first.isNotEmpty && File(first).existsSync()) return first;
    }
  } catch (_) {
    // 'where' not available or errored - fall through to "not found".
  }
  return null;
}

/// Strips mpv's IPC-specific wrapper (`#af-add=lavfi=[...]` / `lavfi=[...]`)
/// down to the raw ffmpeg filtergraph ffmpeg's own `-af` flag expects.
/// Mirrors the wrapper-stripping in FilterParser.parse.
String _rawChain(String wrapped) {
  var s = wrapped.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.startsWith('af-add=')) s = s.substring(7);
  if (s.startsWith('af=')) s = s.substring(3);
  if (s.startsWith('lavfi=')) s = s.substring(6);
  if (s.startsWith('[')) s = s.substring(1);
  if (s.endsWith(']')) s = s.substring(0, s.length - 1);
  return s;
}

/// Runs [chain] through real ffmpeg against a silent test source; returns
/// null if it configures cleanly, or the tail of stderr explaining why not.
String? _rejectionReason(String ffmpegPath, String chain) {
  final result = Process.runSync(ffmpegPath, [
    '-y', '-f', 'lavfi', '-i', 'anullsrc',
    '-t', '0.05',
    '-af', chain,
    '-f', 'null', '-',
  ]);
  if (result.exitCode == 0) return null;
  final lines = (result.stderr as String)
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  return lines.length > 6 ? lines.sublist(lines.length - 6).join('\n') : lines.join('\n');
}

/// Builds a DspState with every user-adjustable field pinned to the min (or
/// max) of its real GUI slider bounds, so a future slider range change that
/// ffmpeg would reject fails here instead of shipping silently. Bounds taken
/// directly from tab_loudness/tab_ambience/tab_channels/tab_eq/tab_safety.dart.
DspState _extremeState({required bool useMin}) {
  double v(double lo, double hi) => useMin ? lo : hi;
  int vi(int lo, int hi) => useMin ? lo : hi;
  return DspState(
    dynaudnormEnabled: true,
    dynaudnorm: DynAudNormSettings(
      frameLength: vi(10, 8000),
      gaussSize: vi(3, 301),
      peak: v(0.0, 1.0),
      maxGain: v(1.0, 20.0),
    ),
    ambience: AmbienceSettings(
      enabled: true,
      highpassFreq: v(100, 2000),
      lowpassFreq: v(2000, 16000),
      echoDelay: v(0.0, 1.0),
      echoDecay: v(0.0, 1.0),
      echoVolume: v(5, 200),
      echoFeedback: v(0.01, 0.9),
      mixWeight: v(0.0, 1.0),
    ),
    extraStereo: v(0.0, 0.5),
    eqBands: defaultEqBands().map((b) => b.copyWith(gain: v(-12.0, 12.0))).toList(),
    highShelf: HighShelfSettings(freq: v(1000, 16000), gain: v(-12.0, 12.0), width: 2200),
    compressor: CompressorSettings(
      threshold: v(-40, -5),
      ratio: v(1.0, 10.0),
      attack: v(0.1, 50.0),
      release: v(10, 500),
      makeup: v(0.0, 12.0),
    ),
    limiter: LimiterSettings(enabled: true, limit: v(-6.0, -0.1)),
  );
}

void main() {
  final ffmpegPath = _findFfmpeg();
  final skip = ffmpegPath == null
      ? 'ffmpeg.exe not found (checked common paths + PATH) - this test '
        'validates filter chains against a real ffmpeg binary and can only '
        'run on a machine that has one'
      : null;

  group('every built-in preset survives real ffmpeg', () {
    for (final preset in builtinPresets) {
      // Bypass mode builds an intentionally empty chain (mpv's own "clear
      // all filters" signal via set_property af "") - it never reaches
      // ffmpeg's filtergraph parser in real use, so there's nothing to
      // validate here.
      if (preset.state.bypass) continue;
      test(preset.name, () {
        final chain = _rawChain(FilterBuilder.build(preset.state));
        final error = _rejectionReason(ffmpegPath!, chain);
        expect(error, isNull,
            reason: 'preset "${preset.name}" rejected by ffmpeg:\n$error\n\nchain: $chain');
      }, skip: skip);
    }
  });

  group('every hardcoded Favorite survives real ffmpeg', () {
    for (final fav in builtinFavorites) {
      test(fav.id, () {
        final chain = _rawChain(fav.filter);
        final error = _rejectionReason(ffmpegPath!, chain);
        expect(error, isNull,
            reason: 'favorite "${fav.id}" rejected by ffmpeg:\n$error\n\nchain: $chain');
      }, skip: skip);
    }
  });

  group('slider boundary extremes survive real ffmpeg', () {
    for (final useMin in [true, false]) {
      test(useMin ? 'all sliders at minimum' : 'all sliders at maximum', () {
        final chain = _rawChain(FilterBuilder.build(_extremeState(useMin: useMin)));
        final error = _rejectionReason(ffmpegPath!, chain);
        expect(error, isNull,
            reason: '${useMin ? "min" : "max"} boundary state rejected by ffmpeg:\n$error\n\nchain: $chain');
      }, skip: skip);
    }
  });
}
