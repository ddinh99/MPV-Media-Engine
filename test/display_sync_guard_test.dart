// test/display_sync_guard_test.dart
//
// Guards the bug that raced video ~5x ahead of audio.
//
// Interpolation requires a display-* video-sync mode, and `display-resample`
// retimes video against `estimated-display-fps` — the refresh rate mpv
// *measures*, not the one the panel reports. When that measurement runs away
// (observed at 347 and 2817 against a real 60Hz display), mpv faithfully
// sprints the video to chase it: audio keeps normal speed, video runs several
// times too fast, and A/V desync hit -14s within 4s of playback.
//
// Crucially mpv ACCEPTS `display-resample` without error and only then
// misbehaves, so no rejection is ever emitted and the Debug IPC panel stays
// silent. The only defence is to read the measurement back and refuse display
// sync when it isn't credible — which is what these tests pin.
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_sound_engine/providers/dsp_provider.dart';
import 'package:mvp_sound_engine/providers/video_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for mpv: answers the two refresh properties with whatever the test
/// wants, and records what would have been sent.
class _FakeDsp extends DspProvider {
  final double? nominal;
  final double? estimated;
  final sent = <List<dynamic>>[];

  _FakeDsp({this.nominal, this.estimated});

  @override
  Future<dynamic> getProperty(String property) async {
    if (property == 'display-fps') return nominal;
    if (property == 'estimated-display-fps') return estimated;
    return null;
  }

  @override
  Future<bool> sendRawCommand(Map<String, dynamic> command,
      {Duration? minGapAfter}) async {
    sent.add(command['command'] as List<dynamic>);
    return true;
  }

  /// Last value sent for [property], or null if it was never sent.
  dynamic lastSent(String property) {
    for (final c in sent.reversed) {
      if (c.length >= 3 && c[0] == 'set_property' && c[1] == property) {
        return c[2];
      }
    }
    return null;
  }
}

/// Longer than VideoProvider's 3s settle, so the check has certainly run.
Future<void> _awaitVerification() =>
    Future<void>.delayed(const Duration(milliseconds: 3600));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a runaway estimated-display-fps forces interpolation back off',
      () async {
    // 60Hz panel, but mpv measures 347Hz — the exact shape of the real failure.
    final dsp = _FakeDsp(nominal: 60, estimated: 347);
    final video = VideoProvider(dsp);

    video.setInterpolation(true);
    // It goes on optimistically — we can't know it's bad until mpv measures.
    expect(video.state.interpolation, isTrue);
    expect(video.state.videoSync, 'display-resample');

    await _awaitVerification();

    expect(video.state.interpolation, isFalse,
        reason: 'interpolation must not be left on when mpv cannot measure '
            'the display — that is what races the video ahead of the audio');
    expect(video.state.videoSync, 'audio',
        reason: 'video-sync=audio played correctly in every configuration '
            'tested, including with vsync off');
    expect(dsp.lastSent('video-sync'), 'audio',
        reason: 'the fallback has to actually reach mpv, not just the GUI');
    expect(dsp.lastSent('interpolation'), 'no');
    expect(video.displaySyncWarning, isNotNull,
        reason: 'silently reverting the control is its own invisible failure');
    expect(video.displaySyncWarning, contains('347'),
        reason: 'the warning should name the bogus rate it measured');
  });

  test('a credible display measurement leaves interpolation alone', () async {
    final dsp = _FakeDsp(nominal: 60, estimated: 59.98);
    final video = VideoProvider(dsp);

    video.setInterpolation(true);
    await _awaitVerification();

    expect(video.state.interpolation, isTrue);
    expect(video.state.videoSync, 'display-resample');
    expect(video.displaySyncWarning, isNull);
  });

  test('a high-refresh panel is not mistaken for a runaway', () async {
    // 144Hz display, measured accurately. Must not trip the guard.
    final dsp = _FakeDsp(nominal: 144, estimated: 143.7);
    final video = VideoProvider(dsp);

    video.setInterpolation(true);
    await _awaitVerification();

    expect(video.state.interpolation, isTrue);
    expect(video.displaySyncWarning, isNull);
  });

  test('no measurement at all is left alone rather than nagged about',
      () async {
    // mpv reports nothing when display sync isn't running yet (nothing playing).
    final dsp = _FakeDsp(nominal: null, estimated: null);
    final video = VideoProvider(dsp);

    video.setInterpolation(true);
    await _awaitVerification();

    expect(video.state.interpolation, isTrue);
    expect(video.displaySyncWarning, isNull);
  });

  test('turning interpolation off clears the warning', () async {
    final dsp = _FakeDsp(nominal: 60, estimated: 2817);
    final video = VideoProvider(dsp);

    video.setInterpolation(true);
    await _awaitVerification();
    expect(video.displaySyncWarning, isNotNull);

    video.setInterpolation(false);
    expect(video.displaySyncWarning, isNull);
  });
}
