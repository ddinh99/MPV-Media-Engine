// lib/services/mpv_locator.dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import 'dart:io' if (dart.library.html) '../stubs/io_stub.dart' as io;

/// Finds an mpv.exe that is already on this machine, so first-run setup can
/// pre-fill the path instead of making the user hunt for it.
///
/// Deliberately never walks the filesystem. mpv on Windows has no installer —
/// most people extract a portable build to an arbitrary folder — so the only
/// way to find those without a multi-minute drive crawl is to ask Windows where
/// it has *seen mpv run from* (PATH shims and the registry). Everything here is
/// either a stat call or a short-lived helper process, and the whole search is
/// capped by [_budget].
///
/// Returning null does not prove mpv is absent — it only means we couldn't
/// cheaply prove it's present. The UI must treat null as "couldn't find it,
/// here's Browse" rather than "you don't have mpv".
class MpvLocator {
  const MpvLocator._();

  /// Where to send users who genuinely don't have mpv yet.
  static const String downloadUrl = 'https://mpv.io/installation/';

  /// Ceiling on the entire search. A wrong "not found" costs the user one
  /// Browse click; a ten-second stall costs them their patience.
  static const Duration _budget = Duration(milliseconds: 1500);

  /// Per-helper-process ceiling, so one wedged `reg.exe` can't eat the budget.
  static const Duration _processBudget = Duration(milliseconds: 600);

  /// Registry locations that record the full path of an mpv the user has
  /// actually run or associated with a file type. These are what catch a
  /// portable `D:\Tools\mpv\mpv.exe` that appears nowhere else.
  static const List<String> _registryKeys = [
    // Set as soon as someone does "Open with → mpv" on a video.
    r'HKCU\Software\Classes\Applications\mpv.exe\shell\open\command',
    // Registered by the installers that bother to.
    r'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\mpv.exe',
    // Windows records the full path of every executable that has been launched.
    r'HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache',
  ];

  /// Any Windows path ending in mpv.exe, as it appears inside registry values
  /// like `"C:\mpv\mpv.exe" "%1"`.
  static final RegExp _mpvPath = RegExp(
    r'[a-zA-Z]:\\[^"\r\n|]*?mpv\.exe',
    caseSensitive: false,
  );

  static Future<String?> locate() async {
    if (kIsWeb || !io.Platform.isWindows) return null;
    try {
      return await _locate().timeout(_budget);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _locate() async {
    // Cheapest first: ~14 stat calls, sub-millisecond, and covers every
    // conventional install location.
    for (final candidate in _knownLocations()) {
      if (io.File(candidate).existsSync()) return candidate;
    }

    // PATH. Covers scoop, chocolatey and winget, all of which install a shim
    // rather than putting the binary anywhere guessable.
    final onPath = await _firstMpvFrom('where.exe', ['mpv.exe']);
    if (onPath != null) return onPath;

    // Portable extractions the user has already run at least once, via what
    // Windows remembers about them.
    for (final key in _registryKeys) {
      final hit = await _firstMpvFrom('reg.exe', ['query', key, '/s']);
      if (hit != null) return hit;
    }

    // Last resort: a portable build sitting on another drive that has never
    // been launched, so nothing above can know about it. Common for someone who
    // downloaded mpv *because* of this app and went straight here.
    return _sweepLikelyFolders();
  }

  /// Depth-1 sweep of a few plausible parents on every drive. Never recurses —
  /// the cost is a fixed handful of directory listings regardless of how much
  /// is on the disk.
  ///
  /// The folder name can't be guessed (shinchiro's archive extracts to e.g.
  /// `mpv-x86_64-v3-20240101-git-abc1234\`), so this matches any child folder
  /// whose name starts with "mpv" and checks for mpv.exe directly inside it.
  ///
  /// Exposed for tests because [locate] short-circuits long before reaching it
  /// on any machine that has mpv installed conventionally — which is exactly
  /// the machine you'd be testing on.
  @visibleForTesting
  static Future<String?> sweepLikelyFolders() => _sweepLikelyFolders();

  static Future<String?> _sweepLikelyFolders() async {
    final roots = await _driveRoots();
    if (roots.isEmpty) return null;
    // Concurrently, so one slow drive can't starve the others of the budget.
    return _firstNonNull(roots.map(_sweepDrive));
  }

  static Future<String?> _sweepDrive(String root) async {
    final env = io.Platform.environment;
    final userProfile = env['USERPROFILE'];
    final onProfileDrive = userProfile != null &&
        userProfile.toLowerCase().startsWith(root.toLowerCase());

    final parents = <String>[
      root,
      '${root}Tools',
      '${root}Apps',
      '${root}Programs',
      '${root}Program Files',
      '${root}Media',
      if (onProfileDrive) ...[
        '$userProfile\\Downloads',
        '$userProfile\\Desktop',
        '$userProfile\\Documents',
      ],
    ];

    return _firstNonNull(parents.map(_sweepParent));
  }

  /// List one directory, one level deep. Anything named mpv* gets an mpv.exe
  /// check; the parent itself does too.
  static Future<String?> _sweepParent(String parent) async {
    final direct = _join(parent, 'mpv.exe');
    if (io.File(direct).existsSync()) return direct;

    try {
      final dir = io.Directory(parent);
      // Async, never listSync: a dead mapped network drive blocks for the SMB
      // timeout, and a synchronous call there would wedge the isolate where no
      // timeout could reach it.
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! io.Directory) continue;
        final name = entity.path.split('\\').last.toLowerCase();
        if (!name.startsWith('mpv')) continue;
        final exe = _join(entity.path, 'mpv.exe');
        if (io.File(exe).existsSync()) return exe;
      }
    } catch (_) {
      // Unreadable, missing, or access-denied parent. Nothing to do.
    }
    return null;
  }

  /// Drive roots arrive as `F:\`, everything else without a trailing separator.
  static String _join(String parent, String child) {
    final base =
        parent.endsWith('\\') ? parent.substring(0, parent.length - 1) : parent;
    return '$base\\$child';
  }

  /// Drive roots, from fsutil rather than probing C:..Z: by hand — a probe of a
  /// disconnected network mount would be a synchronous stall we can't abort.
  static Future<List<String>> _driveRoots() async {
    try {
      final result = await io.Process
          .run('fsutil', ['fsinfo', 'drives']).timeout(_processBudget);
      return RegExp(r'([A-Za-z]):\\')
          .allMatches('${result.stdout}')
          .map((m) => '${m.group(1)!.toUpperCase()}:\\')
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Resolve to the first future that yields a non-null path, without waiting
  /// on the stragglers.
  static Future<String?> _firstNonNull(Iterable<Future<String?>> futures) {
    final pending = futures.toList();
    if (pending.isEmpty) return Future.value(null);

    final completer = Completer<String?>();
    var outstanding = pending.length;

    void settle(String? value) {
      if (value != null && !completer.isCompleted) {
        completer.complete(value);
      } else if (--outstanding == 0 && !completer.isCompleted) {
        completer.complete(null);
      }
    }

    for (final future in pending) {
      future.then(settle, onError: (_) => settle(null));
    }
    return completer.future;
  }

  /// Run [exe], scrape every mpv.exe-shaped path out of its output, and return
  /// the first one that actually exists on disk. A missing registry key just
  /// makes reg.exe exit non-zero with no output, which falls out as null.
  static Future<String?> _firstMpvFrom(String exe, List<String> args) async {
    try {
      final result = await io.Process.run(exe, args).timeout(_processBudget);
      for (final match in _mpvPath.allMatches('${result.stdout}')) {
        final path = match.group(0)!;
        if (io.File(path).existsSync()) return path;
      }
    } catch (_) {
      // Helper missing, blocked by policy, or too slow. Never fatal — the
      // caller just moves on to the next source.
    }
    return null;
  }

  static List<String> _knownLocations() {
    final env = io.Platform.environment;
    final programFiles = env['ProgramFiles'];
    final programFilesX86 = env['ProgramFiles(x86)'];
    final programData = env['ProgramData'];
    final localAppData = env['LOCALAPPDATA'];
    final appData = env['APPDATA'];
    final userProfile = env['USERPROFILE'];
    final systemDrive = env['SystemDrive'] ?? 'C:';

    return <String>[
      if (programFiles != null) ...[
        '$programFiles\\mpv\\mpv.exe',
        '$programFiles\\mpv-player\\mpv.exe',
      ],
      if (programFilesX86 != null) '$programFilesX86\\mpv\\mpv.exe',
      if (localAppData != null) ...[
        '$localAppData\\Programs\\mpv\\mpv.exe',
        '$localAppData\\Microsoft\\WinGet\\Links\\mpv.exe',
      ],
      if (appData != null) '$appData\\mpv\\mpv.exe',
      if (userProfile != null) ...[
        '$userProfile\\scoop\\apps\\mpv\\current\\mpv.exe',
        '$userProfile\\scoop\\shims\\mpv.exe',
        '$userProfile\\Downloads\\mpv\\mpv.exe',
        '$userProfile\\Desktop\\mpv\\mpv.exe',
      ],
      if (programData != null) ...[
        '$programData\\chocolatey\\bin\\mpv.exe',
        '$programData\\chocolatey\\lib\\mpv\\tools\\mpv.exe',
      ],
      '$systemDrive\\mpv\\mpv.exe',
      '$systemDrive\\tools\\mpv\\mpv.exe',
    ];
  }

  /// Open the mpv download page in the user's browser. Best-effort: if it
  /// fails, the dialog still shows the URL as selectable text.
  static Future<void> openDownloadPage() async {
    if (kIsWeb || !io.Platform.isWindows) return;
    try {
      await io.Process.run('explorer.exe', [downloadUrl]);
    } catch (_) {
      // Nothing to do.
    }
  }
}
