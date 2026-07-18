// test/shader_tier_test.dart
//
// Pins the per-tier shader split: the ≤1080p and 1440p+ lists are independent,
// and only the list matching the current video's tier is ever sent to mpv as
// glsl-shaders. Before this split, one flat list applied to everything — so a
// chain of upscalers enabled for 1080p content silently ran on 4K video too,
// and nothing in the GUI told the user which shaders were actually on.

import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_sound_engine/models/shader_metadata.dart';
import 'package:mvp_sound_engine/models/video_state.dart';
import 'package:mvp_sound_engine/providers/dsp_provider.dart';
import 'package:mvp_sound_engine/providers/video_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The glsl-shaders payloads (one per command) found in a command list.
List<dynamic> _glslPayloads(List<Map<String, dynamic>> commands) => commands
    .where((c) => (c['command'] as List)[1] == 'glsl-shaders')
    .map((c) => (c['command'] as List)[2])
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('tier gating in _buildStateCommands', () {
    test('only the current tier\'s list is sent as glsl-shaders', () {
      final provider = VideoProvider(DspProvider());
      final state = VideoState(
        shadersLowRes: ['FSRCNNX_x2_16-0-4-1.glsl'],
        shadersHighRes: ['CfL_Prediction.glsl'],
      );

      final lowCommands = provider.buildStateCommandsForTest(
        state, state, forceAll: true, tier: ResolutionTier.lowRes);
      final highCommands = provider.buildStateCommandsForTest(
        state, state, forceAll: true, tier: ResolutionTier.highRes);

      final lowPayload = _glslPayloads(lowCommands).single.toString();
      final highPayload = _glslPayloads(highCommands).single.toString();

      expect(lowPayload, contains('FSRCNNX'));
      expect(lowPayload, isNot(contains('CfL')),
          reason: 'the 1440p+ list leaked into ≤1080p playback');
      expect(highPayload, contains('CfL'));
      expect(highPayload, isNot(contains('FSRCNNX')),
          reason: 'the ≤1080p list leaked into 1440p+ playback — the exact '
              'bug the per-tier split exists to prevent');
    });

    test('changing only the inactive tier\'s list sends nothing', () {
      // Resending an identical chain still forces a full libplacebo pipeline
      // rebuild, so the diff must ignore the list that isn't live.
      final provider = VideoProvider(DspProvider());
      final old = VideoState(shadersLowRes: ['CAS.glsl']);
      final next = VideoState(
        shadersLowRes: ['CAS.glsl'],
        shadersHighRes: ['CfL_Prediction.glsl'],
      );

      final commands = provider.buildStateCommandsForTest(
        old, next, forceAll: false, tier: ResolutionTier.lowRes);

      expect(_glslPayloads(commands), isEmpty);
    });
  });

  group('legacy activeShaders migration', () {
    test('a flat pre-split list is divided by each shader\'s recommended tier',
        () {
      final restored = VideoState.fromJson({
        'activeShaders': [
          'FSRCNNX_x2_16-0-4-1.glsl', // lowRes only
          'CfL_Prediction_Lite.glsl', // highRes only
          'CAS.glsl', // both tiers
          'SomeUnknownShader.glsl', // no metadata → both, to be safe
        ],
      });

      expect(restored.shadersLowRes,
          ['FSRCNNX_x2_16-0-4-1.glsl', 'CAS.glsl', 'SomeUnknownShader.glsl']);
      expect(restored.shadersHighRes,
          ['CfL_Prediction_Lite.glsl', 'CAS.glsl', 'SomeUnknownShader.glsl']);
    });

    test('new-format keys win and are not re-migrated', () {
      final restored = VideoState.fromJson({
        'shadersLowRes': ['CAS.glsl'],
        'shadersHighRes': <String>[],
        'activeShaders': ['CfL_Prediction.glsl'], // stale leftover
      });

      expect(restored.shadersLowRes, ['CAS.glsl']);
      expect(restored.shadersHighRes, isEmpty);
    });
  });

  // toggleShader used to silently disable "alternative" shaders (e.g.
  // enabling CAS would drop adaptive-sharpen) via hardcoded exclusion
  // groups. Removed on request: users can stack as many shaders as they
  // want, and the GUI no longer enforces on/off relationships between them.
  group('toggleShader no longer enforces exclusion groups', () {
    test('enabling CfL_Prediction_Lite does not disable CfL_Prediction', () {
      final provider = VideoProvider(DspProvider());
      provider.toggleShader(ResolutionTier.highRes, 'CfL_Prediction.glsl', true);
      provider.toggleShader(ResolutionTier.highRes, 'CfL_Prediction_Lite.glsl', true);
      expect(provider.state.shadersHighRes, contains('CfL_Prediction.glsl'));
      expect(provider.state.shadersHighRes, contains('CfL_Prediction_Lite.glsl'));
    });

    test('enabling CAS-vivid does not disable CAS or adaptive-sharpen', () {
      final provider = VideoProvider(DspProvider());
      provider.toggleShader(ResolutionTier.lowRes, 'CAS.glsl', true);
      provider.toggleShader(ResolutionTier.lowRes, 'adaptive-sharpen.glsl', true);
      provider.toggleShader(ResolutionTier.lowRes, 'CAS-vivid.glsl', true);
      expect(provider.state.shadersLowRes, contains('CAS.glsl'));
      expect(provider.state.shadersLowRes, contains('adaptive-sharpen.glsl'));
      expect(provider.state.shadersLowRes, contains('CAS-vivid.glsl'));
    });

    test('disabling a shader only removes that shader', () {
      final provider = VideoProvider(DspProvider());
      provider.toggleShader(ResolutionTier.lowRes, 'CAS.glsl', true);
      provider.toggleShader(ResolutionTier.lowRes, 'adaptive-sharpen.glsl', true);
      provider.toggleShader(ResolutionTier.lowRes, 'CAS.glsl', false);
      expect(provider.state.shadersLowRes, isNot(contains('CAS.glsl')));
      expect(provider.state.shadersLowRes, contains('adaptive-sharpen.glsl'));
    });
  });
}
