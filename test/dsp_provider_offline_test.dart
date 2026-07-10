// test/dsp_provider_offline_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mvp_sound_engine/providers/dsp_provider.dart';
import 'package:mvp_sound_engine/services/mpv_ipc_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // No stored mpv.exe path, so DspProvider won't try to auto-connect.
    SharedPreferences.setMockInitialValues({});
  });

  group('sendRawCommand while disconnected', () {
    test('reports failure instead of claiming a send', () async {
      final dsp = DspProvider();
      expect(dsp.connectionState, isNot(IpcConnectionState.connected));

      final ok = await dsp.sendRawCommand({
        "command": ["set_property", "scale", "ewa_lanczos"]
      });

      expect(ok, isFalse);
    });

    test('logs the command as skipped, never as sent', () async {
      final dsp = DspProvider();

      await dsp.sendRawCommand({
        "command": ["set_property", "glsl-shaders", ""]
      });

      final log = dsp.log.join('\n');
      expect(log, contains('Not connected'));
      expect(log, contains('set_property glsl-shaders'));
      // The old code logged "Sending raw command: ..." before attempting the
      // send and discarded the result, so a dropped command looked delivered.
      expect(log, isNot(contains('Sending raw command')));
      expect(log, isNot(contains('Sent:')));
    });

    test('a whole preset-sized batch resolves immediately, not over seconds',
        () async {
      // Each queued command costs a >=150ms pacing gap (400ms for the
      // expensive ones). Dropping at enqueue time means an offline batch must
      // not pay any of that -- and nothing can linger in the outbox to be
      // delivered later if a connection lands mid-drain.
      final dsp = DspProvider();
      final stopwatch = Stopwatch()..start();

      await Future.wait([
        for (var i = 0; i < 20; i++)
          dsp.sendRawCommand({
            "command": ["set_property", "brightness", i]
          }),
      ]);

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(150));
    });
  });
}
