import 'dart:math' as math;
import '../models/dsp_state.dart';
import '../models/eq_band.dart';

class FilterParser {
  /// Repairs a raw dynaudnorm 'g' value in-place within a raw filter string.
  ///
  /// Raw customFilter strings (hardcoded Favorites, saved personal presets,
  /// the last-used session) bypass DynAudNormSettings entirely and are sent
  /// to mpv verbatim, so DynAudNormSettings' own clamping can't protect
  /// them. ffmpeg's dynaudnorm 'g' must be an odd integer in [3, 301]; any
  /// other value (e.g. a fractional "gain" from before that bug was fixed)
  /// kills the whole filter graph.
  static String sanitizeDynaudnormG(String filter) {
    return filter.replaceAllMapped(
      RegExp(r'(dynaudnorm=[^,\]]*?:g=)(-?[\d.]+)'),
      (m) {
        var g = (double.tryParse(m.group(2)!) ?? 31).round().clamp(3, 301);
        if (g.isEven) g += 1;
        return '${m.group(1)}$g';
      },
    );
  }

  static DspState parse(String rawFilter) {
    final state = DspState();
    
    // Default disable things that might not be in the string
    state.dynaudnormEnabled = false;
    state.ambience.enabled = false;
    state.limiter.enabled = false;
    state.extraStereo = 0.0;
    state.highShelf.gain = 0.0;
    for (var b in state.eqBands) { b.gain = 0.0; }

    // Remove wrappers
    var s = rawFilter.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.startsWith('af-add=')) s = s.substring(7);
    if (s.startsWith('af=')) s = s.substring(3);
    if (s.startsWith('lavfi=')) s = s.substring(6);
    if (s.startsWith('[')) s = s.substring(1);
    if (s.endsWith(']')) s = s.substring(0, s.length - 1);

    // DynAudNorm
    final dynReg = RegExp(r'dynaudnorm=([^,]+)');
    final dynMatch = dynReg.firstMatch(s);
    if (dynMatch != null) {
      state.dynaudnormEnabled = true;
      final params = dynMatch.group(1)!.split(':');
      for (var p in params) {
        final kv = p.split('=');
        if (kv.length == 2) {
          final val = double.tryParse(kv[1]) ?? 0;
          if (kv[0] == 'f') state.dynaudnorm.frameLength = val.toInt();
          if (kv[0] == 'g') state.dynaudnorm.gaussSize = val.round();
          if (kv[0] == 'p') state.dynaudnorm.peak = val;
          if (kv[0] == 'm') state.dynaudnorm.maxGain = val;
        }
      }
    }

    // Pan Matrix
    final panReg = RegExp(r'pan=(stereo|5\.1|7\.1)\|([^,]+)');
    final panMatch = panReg.firstMatch(s);
    if (panMatch != null) {
      final layout = panMatch.group(1);
      final rules = panMatch.group(2)!.split('|');
      state.channelConfig = layout!;
      
      // Reset matrix
      state.panMatrix = PanMatrix(
        flfl: 0, flfc: 0, flbl: 0, flsl: 0, fllfe: 0,
        frfr: 0, frfc: 0, frbr: 0, frsr: 0, frlfe: 0,
      );

      double extractCoeff(String rule, String channel) {
        final reg = RegExp(r'([+-]?\d*\.?\d+)\*' + channel);
        final m = reg.firstMatch(rule);
        if (m != null) return double.tryParse(m.group(1)!) ?? 0.0;
        // Check if channel exists without coeff
        if (RegExp(r'(^|[+-])' + channel + r'($|[+-])').hasMatch(rule)) return 1.0;
        return 0.0;
      }

      for (var rule in rules) {
        if (rule.startsWith('FL=')) {
          state.panMatrix.flfl = extractCoeff(rule, 'FL');
          state.panMatrix.flfc = extractCoeff(rule, 'FC');
          state.panMatrix.flbl = extractCoeff(rule, 'BL');
          state.panMatrix.flsl = extractCoeff(rule, 'SL');
          state.panMatrix.fllfe = extractCoeff(rule, 'LFE');
        } else if (rule.startsWith('FR=')) {
          state.panMatrix.frfr = extractCoeff(rule, 'FR');
          state.panMatrix.frfc = extractCoeff(rule, 'FC');
          state.panMatrix.frbr = extractCoeff(rule, 'BR');
          state.panMatrix.frsr = extractCoeff(rule, 'SR');
          state.panMatrix.frlfe = extractCoeff(rule, 'LFE');
        }
      }
    }

    // ExtraStereo
    final extraReg = RegExp(r'extrastereo=([\d\.]+)');
    final extraMatch = extraReg.firstMatch(s);
    if (extraMatch != null) {
      state.extraStereo = double.tryParse(extraMatch.group(1)!) ?? 0.0;
    }

    // Highpass / Lowpass (Ambience)
    final hpReg = RegExp(r'highpass=f=([\d\.]+)');
    final lpReg = RegExp(r'lowpass=f=([\d\.]+)');
    final hpMatch = hpReg.firstMatch(s);
    final lpMatch = lpReg.firstMatch(s);
    if (hpMatch != null || lpMatch != null) {
      state.ambience.enabled = true;
      if (hpMatch != null) state.ambience.highpassFreq = double.tryParse(hpMatch.group(1)!) ?? 700.0;
      if (lpMatch != null) state.ambience.lowpassFreq = double.tryParse(lpMatch.group(1)!) ?? 7500.0;
    }

    // Echo (aecho)
    final echoReg = RegExp(r'aecho=([\d\.]+):([\d\.]+):([\d\.]+):([\d\.]+)');
    final echoMatch = echoReg.firstMatch(s);
    if (echoMatch != null) {
      state.ambience.enabled = true;
      state.ambience.echoDelay = double.tryParse(echoMatch.group(1)!) ?? 0.22;
      state.ambience.echoDecay = double.tryParse(echoMatch.group(2)!) ?? 0.32;
      state.ambience.echoVolume = double.tryParse(echoMatch.group(3)!) ?? 18.0;
      state.ambience.echoFeedback = double.tryParse(echoMatch.group(4)!) ?? 0.20;
    }

    // Amix weights
    final amixReg = RegExp(r'amix=inputs=2:weights=1\s+([\d\.]+)');
    final amixMatch = amixReg.firstMatch(s);
    if (amixMatch != null) {
      state.ambience.enabled = true;
      state.ambience.mixWeight = double.tryParse(amixMatch.group(1)!) ?? 0.36;
    }

    // HighShelf
    final hsReg = RegExp(r'highshelf=([^,]+)');
    final hsMatch = hsReg.firstMatch(s);
    if (hsMatch != null) {
      final params = hsMatch.group(1)!.split(':');
      for (var p in params) {
        final kv = p.split('=');
        if (kv.length == 2) {
          final val = double.tryParse(kv[1]) ?? 0;
          if (kv[0] == 'f') state.highShelf.freq = val;
          if (kv[0] == 'g') state.highShelf.gain = val;
          if (kv[0] == 'w') state.highShelf.width = val;
        }
      }
    }

    // Compressor
    final compReg = RegExp(r'acompressor=([^,]+)');
    final compMatch = compReg.firstMatch(s);
    if (compMatch != null) {
      final params = compMatch.group(1)!.split(':');
      for (var p in params) {
        final kv = p.split('=');
        if (kv.length == 2) {
          if (kv[0] == 'threshold') state.compressor.threshold = _parseDbOrAmp(kv[1]);
          if (kv[0] == 'makeup') state.compressor.makeup = _parseDbOrAmp(kv[1]);
          if (kv[0] == 'ratio') state.compressor.ratio = double.tryParse(kv[1]) ?? 4.5;
          if (kv[0] == 'attack') state.compressor.attack = double.tryParse(kv[1]) ?? 3.0;
          if (kv[0] == 'release') state.compressor.release = double.tryParse(kv[1]) ?? 110.0;
        }
      }
    }

    // Limiter
    final limReg = RegExp(r'alimiter=limit=([^,]+)');
    final limMatch = limReg.firstMatch(s);
    if (limMatch != null) {
      state.limiter.enabled = true;
      state.limiter.limit = _parseDbOrAmp(limMatch.group(1)!);
    }

    // Equalizer
    final eqReg = RegExp(r'anequalizer=([^,]+)');
    final eqMatch = eqReg.firstMatch(s);
    if (eqMatch != null) {
      final eqStr = eqMatch.group(1)!;
      final bands = eqStr.split('|');
      for (var bandStr in bands) {
        // e.g. "c0 f=40 w=30 g=+2.0 t=1"
        final freqReg = RegExp(r'f=([\d\.]+)');
        final gainReg = RegExp(r'g=([+-]?[\d\.]+)');
        final fMatch = freqReg.firstMatch(bandStr);
        final gMatch = gainReg.firstMatch(bandStr);
        
        if (fMatch != null && gMatch != null) {
          final f = double.tryParse(fMatch.group(1)!) ?? 0.0;
          final g = double.tryParse(gMatch.group(1)!) ?? 0.0;
          
          // Find matching band in our default list
          for (var i = 0; i < state.eqBands.length; i++) {
            if ((state.eqBands[i].freq - f).abs() < 10) {
              state.eqBands[i].gain = g;
              break;
            }
          }
        }
      }
    }

    return state;
  }

  static double _parseDbOrAmp(String value) {
    if (value.endsWith('dB')) {
      return double.tryParse(value.replaceAll('dB', '')) ?? 0.0;
    }
    final amp = double.tryParse(value) ?? 1.0;
    if (amp <= 0.0001) return -60.0;
    return 20.0 * math.log(amp) / math.ln10;
  }
}
