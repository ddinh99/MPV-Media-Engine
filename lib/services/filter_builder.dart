// lib/services/filter_builder.dart
import 'dart:convert';
import 'dart:math' as math;
import '../models/dsp_state.dart';

/// Builds the complete MPV lavfi filter chain string from a DspState.
class FilterBuilder {
  static String build(DspState state) {
    if (state.bypass) return '';

    final parts = <String>[];

    // 1. Dynamic normalization
    if (state.dynaudnormEnabled) {
      final d = state.dynaudnorm;
      parts.add(
        'dynaudnorm=f=${d.frameLength}'
        ':g=${d.gaussSize}'
        ':p=${d.peak.toStringAsFixed(1)}'
        ':m=${d.maxGain.toStringAsFixed(1)}',
      );
    }

    // 2. Pan matrix
    final p = state.panMatrix;
    String fmtCoeff(double v) {
      final abs = v.abs().toStringAsFixed(2);
      return v < 0 ? '-$abs' : '+$abs';
    }

    final flParts = <String>[];
    if (p.flfl.abs() > 0.001) flParts.add('${p.flfl.toStringAsFixed(2)}*FL');
    if (p.flfc.abs() > 0.001) flParts.add('${fmtCoeff(p.flfc)}*FC');
    if (p.flbl.abs() > 0.001) flParts.add('${fmtCoeff(p.flbl)}*BL');
    if (p.flsl.abs() > 0.001) flParts.add('${fmtCoeff(p.flsl)}*SL');
    if (p.fllfe.abs() > 0.001) flParts.add('${fmtCoeff(p.fllfe)}*LFE');

    final frParts = <String>[];
    if (p.frfr.abs() > 0.001) frParts.add('${p.frfr.toStringAsFixed(2)}*FR');
    if (p.frfc.abs() > 0.001) frParts.add('${fmtCoeff(p.frfc)}*FC');
    if (p.frbr.abs() > 0.001) frParts.add('${fmtCoeff(p.frbr)}*BR');
    if (p.frsr.abs() > 0.001) frParts.add('${fmtCoeff(p.frsr)}*SR');
    if (p.frlfe.abs() > 0.001) frParts.add('${fmtCoeff(p.frlfe)}*LFE');

    // Strip only a *leading* '+' (a first term from fmtCoeff); a mid-string
    // '+' is a term separator ffmpeg requires — removing it is a syntax error.
    // An empty expression (all coefficients 0) is also rejected; emit 0*ch.
    String joinTerms(List<String> terms, String silentCh) {
      if (terms.isEmpty) return '0*$silentCh';
      final joined = terms.join('');
      return joined.startsWith('+') ? joined.substring(1) : joined;
    }

    final flStr = joinTerms(flParts, 'FL');
    final frStr = joinTerms(frParts, 'FR');
    parts.add('pan=${state.channelConfig}|FL=$flStr|FR=$frStr');

    // 3. Ambience path (split chain)
    if (state.ambience.enabled) {
      final a = state.ambience;
      final hp = a.highpassFreq.toStringAsFixed(0);
      final lp = a.lowpassFreq.toStringAsFixed(0);
      final delay = a.echoDelay.toStringAsFixed(2);
      final decay = a.echoDecay.toStringAsFixed(2);
      final vol = a.echoVolume.toStringAsFixed(0);
      final fb = a.echoFeedback.toStringAsFixed(2);
      final wt = a.mixWeight.toStringAsFixed(2);

      parts.add(
        'asplit=2[main][amb],'
        '[amb]highpass=f=$hp,lowpass=f=$lp,'
        'aecho=$delay:$decay:$vol:$fb[amb2],'
        '[main][amb2]amix=inputs=2:weights=1 $wt',
      );
    }

    // 4. ExtraStereo
    if (state.extraStereo > 0.001) {
      parts.add('extrastereo=${state.extraStereo.toStringAsFixed(2)}');
    }

    // 5. Parametric EQ (anequalizer)
    final activeBands = state.eqBands.where((b) => b.gain.abs() > 0.01).toList();
    if (activeBands.isNotEmpty) {
      final bandStr = activeBands.map((b) => b.toFilterString()).join('|');
      parts.add('anequalizer=$bandStr');
    }

    // 6. High shelf
    final hs = state.highShelf;
    if (hs.gain.abs() > 0.01) {
      parts.add(
        'highshelf=f=${hs.freq.toStringAsFixed(0)}'
        ':g=${hs.gain.toStringAsFixed(1)}'
        ':w=${hs.width.toStringAsFixed(0)}:t=h',
      );
    }

    // 7. Compressor
    final c = state.compressor;
    final thresholdAmp = math.pow(10, c.threshold / 20.0);
    final makeupAmp = math.pow(10, c.makeup / 20.0);
    parts.add(
      'acompressor='
      'threshold=${thresholdAmp.toStringAsFixed(4)}'
      ':ratio=${c.ratio.toStringAsFixed(1)}'
      ':attack=${c.attack.toStringAsFixed(2)}'
      ':release=${c.release.toStringAsFixed(0)}'
      ':makeup=${makeupAmp.toStringAsFixed(4)}',
    );

    // 8. Limiter
    if (state.limiter.enabled) {
      final limitAmp = math.pow(10, state.limiter.limit / 20.0);
      parts.add('alimiter=limit=${limitAmp.toStringAsFixed(4)}');
    }

    return 'lavfi=[${parts.join(',')}]';
  }

  /// Returns the full MPV af-add line for config file export
  static String buildConfigLine(DspState state) {
    if (state.bypass) return '# af= (bypass - no filters)';
    return 'af-add=${build(state)}';
  }

  /// Returns the IPC JSON command to send to MPV
  static String buildIpcCommand(DspState state) {
    if (state.bypass) {
      return jsonEncode({
        "command": ["set_property", "af", ""]
      });
    }
    final chain = build(state);
    return jsonEncode({
      "command": ["set_property", "af", chain]
    });
  }
}
