// test/video_state_coverage_test.dart
//
// Guards the bug class that hid `hdr-output` and `inverse-tone-mapping`:
// a VideoState field the GUI happily reads and writes, that never actually
// reaches mpv. Nothing throws when that happens — the control just silently
// does nothing, and you find out months later while watching a film.
//
// Two holes have to be plugged, and they're different:
//   1. The field isn't sent  — no `addIfChanged` in _buildStateCommands.
//      (`inverseToneMapping` was this: state had it, mpv never heard it.)
//   2. The field isn't saved — missing from toJson/fromJson, so it resets on
//      every launch. (`hdrOutput` was this.)
//
// Field inventory comes from toJson()'s keys, because Flutter has no runtime
// reflection. That's also this test's blind spot: a field missing from toJson
// entirely is invisible here. The round-trip test below narrows that, but the
// honest residue is that toJson itself is hand-maintained.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_sound_engine/models/shader_metadata.dart';
import 'package:mvp_sound_engine/models/video_state.dart';
import 'package:mvp_sound_engine/providers/dsp_provider.dart';
import 'package:mvp_sound_engine/providers/video_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fields that legitimately have no mpv property behind them. Anything listed
/// here is a deliberate exemption — adding a name to this set should require
/// justifying it, which is the entire point of keeping the list explicit.
const _guiOnlyFields = <String, String>{
  // `hdr-output` is not a real mpv property. HDR Output is a GUI shortcut that
  // drives target-colorspace-hint + target-trc + inverse-tone-mapping instead,
  // each of which is its own VideoState field and is covered by this test.
  'hdrOutput': 'no mpv property; drives the passthrough trio instead',
};

/// Produces a value that differs from [v], preserving its type so the mutated
/// map still round-trips through VideoState.fromJson.
dynamic _mutate(dynamic v) {
  if (v is bool) return !v;
  if (v is int) return v + 1;
  if (v is double) return v + 1.0;
  if (v is String) return v == '__changed__' ? '__other__' : '__changed__';
  if (v is List) return [...v.map((e) => e.toString()), 'CAS.glsl'];
  throw StateError('No mutation rule for ${v.runtimeType} ($v) — add one.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('every persisted VideoState field emits an mpv command when it changes',
      () {
    final provider = VideoProvider(DspProvider());

    // Both gated blocks are switched ON in the baseline, and identically in
    // `old` and `next`, so the gate itself never shows up as a change:
    //   - tscale* are only sent when interpolation is on
    //   - target-prim/gamut/trc are only sent when targetColorspaceHint is on
    // Without this, those fields would look uncovered for the wrong reason.
    final baseline = VideoState(
      interpolation: true,
      targetColorspaceHint: true,
    );
    final baseJson = baseline.toJson();

    final uncovered = <String>[];

    for (final key in baseJson.keys) {
      if (_guiOnlyFields.containsKey(key)) continue;

      final mutatedJson = Map<String, dynamic>.from(baseJson);
      mutatedJson[key] = _mutate(baseJson[key]);

      // Sanity: the mutation must actually change something, or a field could
      // "pass" simply because we compared a value against itself.
      expect(
        mutatedJson[key],
        isNot(equals(baseJson[key])),
        reason: 'Mutation of "$key" produced an identical value',
      );

      final next = VideoState.fromJson(mutatedJson);
      // The per-tier shader lists are tier-gated by design: only the list
      // matching the current video's tier is ever sent. A field is covered
      // if it reaches mpv under *some* tier — a field reaching mpv under
      // neither is the bug this test exists to catch.
      final covered = ResolutionTier.values.any((tier) => provider
          .buildStateCommandsForTest(baseline, next, forceAll: false, tier: tier)
          .isNotEmpty);

      if (!covered) uncovered.add(key);
    }

    expect(
      uncovered,
      isEmpty,
      reason: 'These VideoState fields change without sending anything to mpv, '
          'so the GUI will show them as active while mpv never hears about '
          'them: $uncovered. Either add an addIfChanged(...) for each in '
          'VideoProvider._buildStateCommands, or — if the field genuinely has '
          'no mpv property — add it to _guiOnlyFields with a reason.',
    );
  });

  test('VideoState survives a toJson/fromJson round-trip without losing fields',
      () {
    // Catches the other half: a field present in toJson but absent from
    // fromJson (or vice versa) silently resets to its default on every launch,
    // which is exactly how HDR Output failed to persist.
    final original = VideoState(
      shadersLowRes: ['CAS.glsl', 'adaptive-sharpen.glsl'],
      shadersHighRes: ['CfL_Prediction.glsl'],
      toneMappingAlgorithm: 'bt.2390',
      targetPeak: 400.0,
      contrastRecovery: 0.5,
      visualizeToneMapping: true,
      hdrComputePeak: false,
      hdrOutput: true,
      inverseToneMapping: true,
      targetColorspaceHint: true,
      targetPrim: 'bt.2020',
      targetGamut: 'bt.2020',
      targetTrc: 'pq',
      brightness: 5,
      contrast: -3,
      gamma: 2,
      saturation: 15,
      deband: true,
      debandIterations: 3,
      debandThreshold: 48,
      interpolation: true,
      videoSync: 'display-resample',
      tscale: 'mitchell',
      tscaleWindow: 'hanning',
      tscaleRadius: 1.5,
      tscaleBlur: 0.8,
      tscaleClamp: 0.2,
      scale: 'ewa_lanczossharp',
      cscale: 'spline36',
      dscale: 'mitchell',
      hidpiWindowScale: true,
    );

    final restored = VideoState.fromJson(original.toJson());

    // Compare as maps: any key dropped by fromJson comes back as its default
    // and shows up here as a mismatch, naming the exact field.
    expect(restored.toJson(), equals(original.toJson()));
  });

  test('HDR Output persists — the specific regression this guards', () {
    // A focused restatement of the bug the user actually hit: turn HDR Output
    // on, restart, find it off again.
    final on = VideoState(
      hdrOutput: true,
      inverseToneMapping: true,
      targetColorspaceHint: true,
      targetTrc: 'pq',
    );

    final restored = VideoState.fromJson(on.toJson());

    expect(restored.hdrOutput, isTrue, reason: 'HDR Output did not survive a save/load');
    expect(restored.inverseToneMapping, isTrue,
        reason: 'inverse-tone-mapping did not survive; HDR Output would restore half-applied');
    expect(restored.targetColorspaceHint, isTrue);
    expect(restored.targetTrc, 'pq');
  });

  test('a resync forces every property, even with no diff', () {
    // _resyncAll() leans on forceAll to re-push state to a fresh mpv instance
    // that may have its own mpv.conf settings. If forceAll ever stopped
    // meaning "send everything", reconnects would silently under-apply.
    final provider = VideoProvider(DspProvider());
    final state = VideoState(interpolation: true, targetColorspaceHint: true);

    final commands = provider.buildStateCommandsForTest(
      state,
      state,
      forceAll: true,
    );

    final sentProperties = commands
        .map((c) => (c['command'] as List)[1] as String)
        .toSet();

    // Every non-GUI-only persisted field must have pushed something. The two
    // per-tier shader lists share the single glsl-shaders property (only the
    // live tier's list is sent), so they count as one property, not two.
    final expectedCount = state.toJson().keys
            .where((k) => !_guiOnlyFields.containsKey(k))
            .length -
        1;

    expect(
      sentProperties.length,
      greaterThanOrEqualTo(expectedCount),
      reason: 'forceAll sent only ${sentProperties.length} properties for '
          '$expectedCount persisted fields: $sentProperties',
    );

    debugPrint('resync pushes ${sentProperties.length} properties');
  });
}
