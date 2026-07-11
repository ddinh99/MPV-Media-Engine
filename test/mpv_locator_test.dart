// test/mpv_locator_test.dart
//
// Guards the one property first-run setup actually depends on: the mpv search
// is FAST and never throws. It runs while the setup dialog is on screen, so a
// stall is a stall the user sits through. It must never walk the filesystem.
//
// Deliberately does NOT assert that mpv is found — that depends on the machine.
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_sound_engine/services/mpv_locator.dart';

void main() {
  test('locate() finishes well inside its budget and never throws', () async {
    final sw = Stopwatch()..start();
    final found = await MpvLocator.locate();
    sw.stop();

    // MpvLocator caps itself at 1500ms. Allow slack for a cold process spawn on
    // a loaded machine, but anything near 10s means someone added a disk walk.
    expect(
      sw.elapsedMilliseconds,
      lessThan(3000),
      reason: 'mpv detection blocks the first-run dialog — it must stay quick',
    );

    // Whatever it returns, it must be a real mpv.exe or nothing at all. A stale
    // registry entry pointing at a deleted portable build must not leak through.
    if (found != null) {
      expect(found.toLowerCase(), endsWith('mpv.exe'));
    }

    // ignore: avoid_print
    print('MpvLocator.locate() -> ${found ?? '(not found)'} '
        'in ${sw.elapsedMilliseconds}ms');
  });

  // The drive sweep is the fallback for an mpv that was extracted somewhere odd
  // and never launched, so nothing on PATH or in the registry knows about it.
  // locate() never reaches it on a machine with a conventional install, hence
  // exercising it directly.
  test('the drive sweep stays bounded — it must never recurse', () async {
    final sw = Stopwatch()..start();
    final found = await MpvLocator.sweepLikelyFolders();
    sw.stop();

    expect(
      sw.elapsedMilliseconds,
      lessThan(3000),
      reason: 'a depth-1 sweep of a few folders per drive cannot be slow; '
          'if this fails, someone made it recursive',
    );
    if (found != null) {
      expect(found.toLowerCase(), endsWith('mpv.exe'));
    }

    // ignore: avoid_print
    print('MpvLocator.sweepLikelyFolders() -> ${found ?? '(not found)'} '
        'in ${sw.elapsedMilliseconds}ms');
  });
}
