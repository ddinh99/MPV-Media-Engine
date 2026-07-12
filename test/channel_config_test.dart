// test/channel_config_test.dart
//
// Pins the channel-config (stereo / 5.1 / 7.1) switching against the bug where
// it silently died after loading a Favorite: a Favorite restores
// _customFilterOverride, and while that override is set _applyNow() resends
// the stored raw filter string verbatim (frozen at pan=stereo) instead of
// rebuilding from state. Switching configs must clear the override, exactly
// like every slider setter does via _update().
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mvp_sound_engine/models/preset.dart';
import 'package:mvp_sound_engine/providers/dsp_provider.dart';

/// Enough for the async constructor work (_loadPreferences / _restoreSession).
const _afterInit = Duration(milliseconds: 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('switching config rebuilds the pan line', () async {
    final dsp = DspProvider();
    await Future.delayed(_afterInit);

    expect(dsp.selectedChannelConfig, 'stereo');
    expect(dsp.filterPreview, contains('pan=stereo'));

    dsp.setSelectedChannelConfig('5.1');
    expect(dsp.selectedChannelConfig, '5.1');
    expect(dsp.filterPreview, contains('pan=5.1'));

    dsp.setSelectedChannelConfig('7.1');
    expect(dsp.filterPreview, contains('pan=7.1'));
  });

  test('config switching still works after loading a Favorite with a raw filter', () async {
    final dsp = DspProvider();
    await Future.delayed(_afterInit);

    // A Favorite saved while a raw filter override was active — the case that
    // froze the pan line at stereo.
    final favorite = Preset(
      id: 'custom_1',
      name: 'My Fav',
      emoji: '⭐',
      description: 'Personal preset',
      state: dsp.state.copyWith(),
      customFilter: '#af-add=lavfi=[dynaudnorm=f=500,pan=stereo|FL=FL|FR=FR]',
    );
    dsp.loadPreset(favorite);
    expect(dsp.hasCustomFilterOverride, isTrue);
    expect(dsp.filterPreview, contains('pan=stereo'));

    dsp.setSelectedChannelConfig('5.1');

    // The override must be dropped, or mpv keeps receiving the stale string.
    expect(dsp.hasCustomFilterOverride, isFalse);
    expect(dsp.selectedChannelConfig, '5.1');
    expect(dsp.filterPreview, contains('pan=5.1'));
    expect(dsp.filterPreview, isNot(contains('pan=stereo')));
  });

  test('each config keeps its own pan matrix', () async {
    final dsp = DspProvider();
    await Future.delayed(_afterInit);

    dsp.setDialogFocus(0.9); // distinctive stereo value
    expect(dsp.state.panMatrix.flfc, 0.9);

    dsp.setSelectedChannelConfig('5.1');
    expect(dsp.state.panMatrix.flfc, isNot(0.9), reason: '5.1 starts fresh');

    dsp.setDialogFocus(0.2);
    dsp.setSelectedChannelConfig('stereo');
    expect(dsp.state.panMatrix.flfc, 0.9, reason: 'stereo matrix restored');

    dsp.setSelectedChannelConfig('5.1');
    expect(dsp.state.panMatrix.flfc, 0.2, reason: '5.1 edit remembered');
  });
}
