// test/filter_builder_pan_test.dart
//
// Pins the pan-expression syntax against the bug where the built filter chain
// was rejected wholesale by ffmpeg ("Parsed_pan_1: Syntax error near
// '0.55*FC-'"): the builder stripped the first '+' found ANYWHERE in the
// expression (intended to drop a leading sign), which deleted the required
// separator between the first two terms whenever the first coefficient was
// non-zero — i.e. for every default matrix. A broken pan kills the entire
// lavfi graph, so ALL audio DSP silently stopped applying.
//
// Verified empirically against a real ffmpeg binary:
//   FL=0.40*FL0.55*FC   -> rejected (missing separator; the shipped bug)
//   FL=0.40*FL-0.35*FC  -> accepted (bare '-' separator is legal)
//   FL=                 -> rejected (empty expression; must emit 0*FL)
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_sound_engine/models/dsp_state.dart';
import 'package:mvp_sound_engine/services/filter_builder.dart';
import 'package:mvp_sound_engine/services/filter_parser.dart';

/// Mirrors ffmpeg af_pan's grammar for one output channel expression:
/// term ('+'|'-' term)*  where term = coeff '*' channel.
final _panExpr = RegExp(r'^\d+\.?\d*\*[A-Z]+([+-]\d+\.?\d*\*[A-Z]+)*$');

/// Extracts the FL=… and FR=… expressions from the built chain.
(String, String) _panExprs(DspState state) {
  final chain = FilterBuilder.build(state);
  final m = RegExp(r'pan=[^|]+\|FL=([^|]*)\|FR=([^,\]]*)').firstMatch(chain);
  expect(m, isNotNull, reason: 'no pan filter in chain: $chain');
  return (m!.group(1)!, m.group(2)!);
}

void main() {
  test('default matrix builds valid pan syntax (the shipped repro)', () {
    // Defaults: flfl=0.40, flfc=0.55 — first term unsigned, so the old
    // replaceFirst("+","") ate the FL/FC separator.
    final (fl, fr) = _panExprs(DspState());
    expect(fl, matches(_panExpr), reason: 'FL=$fl');
    expect(fr, matches(_panExpr), reason: 'FR=$fr');
    expect(fl, contains('*FL+'), reason: 'separator after first term survives');
  });

  test('valid for every channel config layout', () {
    for (final config in ['stereo', '5.1', '7.1']) {
      final (fl, fr) = _panExprs(DspState()..channelConfig = config);
      expect(fl, matches(_panExpr), reason: '$config FL=$fl');
      expect(fr, matches(_panExpr), reason: '$config FR=$fr');
    }
  });

  test('zero first coefficient leaves no leading +', () {
    final state = DspState()..panMatrix.flfl = 0.0;
    final (fl, _) = _panExprs(state);
    expect(fl, matches(_panExpr), reason: 'FL=$fl');
  });

  test('negative coefficients stay legal and round-trip', () {
    final state = DspState()
      ..panMatrix.flbl = -0.35
      ..panMatrix.frbr = -0.35;
    final (fl, fr) = _panExprs(state);
    expect(fl, matches(_panExpr), reason: 'FL=$fl');
    expect(fr, matches(_panExpr), reason: 'FR=$fr');

    final parsed = FilterParser.parse(FilterBuilder.build(state));
    expect(parsed.panMatrix.flbl, closeTo(-0.35, 0.001));
    expect(parsed.panMatrix.frbr, closeTo(-0.35, 0.001));
  });

  test('all-zero matrix emits 0*ch, never an empty expression', () {
    final state = DspState()
      ..panMatrix = PanMatrix(
        flfl: 0, flfc: 0, flbl: 0, flsl: 0, fllfe: 0,
        frfr: 0, frfc: 0, frbr: 0, frsr: 0, frlfe: 0,
      );
    final (fl, fr) = _panExprs(state);
    expect(fl, '0*FL');
    expect(fr, '0*FR');
  });
}
