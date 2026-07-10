// test/session_persistence_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mvp_sound_engine/models/video_preset.dart';
import 'package:mvp_sound_engine/providers/dsp_provider.dart';
import 'package:mvp_sound_engine/providers/video_provider.dart';

/// Longer than the providers' 400ms persist debounce.
const _afterDebounce = Duration(milliseconds: 600);

/// Enough for the async constructor work (_loadPreferences / _restoreSession).
const _afterInit = Duration(milliseconds: 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('DSP session', () {
    test('a slider change survives a restart', () async {
      final first = DspProvider();
      await Future.delayed(_afterInit);
      // 6.0 is not any band's default, so a pass can't be a false positive.
      expect(first.state.eqBands[0].gain, isNot(6.0));

      first.setEqBandGain(0, 6.0);
      first.setExtraStereo(0.4);
      await Future.delayed(_afterDebounce);

      final second = DspProvider();
      await Future.delayed(_afterInit);
      expect(second.state.eqBands[0].gain, 6.0);
      expect(second.state.extraStereo, 0.4);
    });

    test('a Favorites raw filter survives a restart', () async {
      // The custom filter overrides the parsed state, so persisting the state
      // alone would silently drop the filter the user actually hears.
      final first = DspProvider();
      await Future.delayed(_afterInit);
      first.applyCustomFilter('My Fav', '#af-add=lavfi=[dynaudnorm=f=500]');
      await Future.delayed(_afterDebounce);

      final second = DspProvider();
      await Future.delayed(_afterInit);
      expect(second.hasCustomFilterOverride, isTrue);
      expect(second.activePresetId, 'My Fav');
      expect(second.filterPreview, contains('dynaudnorm=f=500'));
    });

    test('the auto-apply toggle survives a restart', () async {
      final first = DspProvider();
      await Future.delayed(_afterInit);
      expect(first.autoApply, isTrue, reason: 'default');
      first.setAutoApply(false);
      await Future.delayed(_afterDebounce);

      final second = DspProvider();
      await Future.delayed(_afterInit);
      expect(second.autoApply, isFalse);
    });
  });

  group('Video session', () {
    test('a preset choice survives a restart', () async {
      final dsp = DspProvider();
      final first = VideoProvider(dsp);
      await Future.delayed(_afterInit);

      final anime = builtinVideoPresets.firstWhere((p) => p.id == 'anime_cartoon');
      first.applyPreset(anime);
      await Future.delayed(_afterDebounce);

      final second = VideoProvider(DspProvider());
      await Future.delayed(_afterInit);
      expect(second.activePresetId, 'anime_cartoon');
      expect(second.state.activeShaders, anime.state.activeShaders);
      expect(second.state.deband, anime.state.deband);
    });

    test('a hand-tweaked property survives a restart and clears the preset',
        () async {
      final first = VideoProvider(DspProvider());
      await Future.delayed(_afterInit);
      first.setBrightness(15);
      await Future.delayed(_afterDebounce);

      final second = VideoProvider(DspProvider());
      await Future.delayed(_afterInit);
      expect(second.state.brightness, 15);
      expect(second.activePresetId, isNull);
    });
  });

  group('restore is non-destructive', () {
    test('constructing a provider and not touching it preserves the session',
        () async {
      // Launching the app must not rewrite the saved session with defaults.
      // Providers notifyListeners() while preferences are still loading, and
      // _persistSession() runs on a debounce, so a mistake in either could let
      // default state land on disk before the restore is read back.
      final first = DspProvider();
      await Future.delayed(_afterInit);
      first.setEqBandGain(2, -7.5);
      await Future.delayed(_afterDebounce);

      // Construct and let every timer settle, without touching anything.
      final second = DspProvider();
      await Future.delayed(_afterDebounce);
      expect(second.state.eqBands[2].gain, -7.5);

      final third = DspProvider();
      await Future.delayed(_afterInit);
      expect(third.state.eqBands[2].gain, -7.5,
          reason: 'the untouched second provider must not have clobbered it');
    });
  });
}
