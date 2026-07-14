// lib/providers/video_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.html) '../stubs/io_stub.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/session.dart';
import '../models/shader_metadata.dart';
import '../models/video_preset.dart';
import '../models/video_state.dart';
import '../services/mpv_ipc_service.dart';
import '../services/platform_service.dart';
import '../services/preferences_service.dart';
import 'dsp_provider.dart';

class VideoProvider extends ChangeNotifier {
  final DspProvider dspProvider;
  VideoState _state = VideoState();
  String? _activePresetId;
  List<String> _availableShaders = [];
  List<VideoPreset> _customPresets = [];
  Timer? _debounceTimer;
  num? _currentVideoHeight;
  String? _defaultPresetId;
  Map<String, dynamic>? _cachedVideoInfo;

  /// Whether the next `applyPreset()` must send every property unconditionally
  /// instead of diffing against local state. Local state is only a shadow of
  /// what we *believe* MPV has — a freshly (re)connected MPV instance may
  /// already have shaders/scalers/etc. active from its own mpv.conf or a
  /// prior session, which our diff has no way of knowing about. Forcing one
  /// full resync per connection guarantees convergence; diffing after that
  /// is safe since we're the only thing changing these properties from then on.
  bool _needsFullResync = true;
  IpcConnectionState _lastKnownConnectionState = IpcConnectionState.disconnected;

  /// See DspProvider's field of the same name — guards persistence until the
  /// saved session has been read back, so we can't overwrite it with defaults.
  bool _sessionRestored = false;
  Timer? _persistDebounce;
  String? _lastPersistedJson;

  /// The display's reported peak luminance in nits (EDID via DXGI), shown as
  /// an annotation on the Target Peak slider. Informational only — null when
  /// unknown, and deliberately not persisted (monitors change).
  double? _displayMaxNits;
  double? get displayMaxNits => _displayMaxNits;

  VideoProvider(this.dspProvider) {
    _loadAvailableShaders();
    _restoreSession();
    _loadDisplayMaxNits();
    dspProvider.addListener(_onDspProviderChanged);
  }

  Future<void> _loadDisplayMaxNits() async {
    _displayMaxNits = await PlatformService.getDisplayMaxLuminance();
    if (_displayMaxNits != null) notifyListeners();
  }

  /// Restores the last-used video settings, then makes sure MPV hears about
  /// them. Ordering matters in two directions:
  ///
  /// - `_checkWindowsHdr()` only runs when there's *no* saved session. It's a
  ///   first-launch convenience, and letting it fire afterwards would silently
  ///   override a tone-mapping choice the user deliberately saved.
  /// - DspProvider auto-connects while this is still awaiting. If it wins the
  ///   race, the connect-triggered `_resyncAll()` will have already pushed the
  ///   *default* state, so we resync again once the real state is in place.
  Future<void> _restoreSession() async {
    await _loadCustomPresets();
    _defaultPresetId = await PreferencesService.getDefaultPresetId();
    _cachedVideoInfo = await PreferencesService.getCurrentVideoInfo();

    final session = await PreferencesService.getLastVideoSession();
    if (session != null) {
      // The remembered session always wins — the default preset must never
      // override settings the user actually left the app with.
      _state = session.state;
      _activePresetId = session.activePresetId;
    } else {
      final defaultPreset = _presetById(_defaultPresetId);
      if (defaultPreset != null) {
        _state = defaultPreset.state;
        _activePresetId = defaultPreset.id;
      } else {
        await _checkWindowsHdr();
      }
    }
    _sessionRestored = true;
    notifyListeners();

    _lastKnownConnectionState = dspProvider.connectionState;
    if (_lastKnownConnectionState == IpcConnectionState.connected) {
      _resyncAll();
    }
  }

  /// Persist on every state change — see DspProvider.notifyListeners().
  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_sessionRestored) return;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 400), _persistSession);
  }

  void _persistSession() {
    final session = VideoSession(state: _state, activePresetId: _activePresetId);
    final encoded = jsonEncode(session.toJson());
    if (encoded == _lastPersistedJson) return;
    _lastPersistedJson = encoded;
    PreferencesService.saveLastVideoSession(session);
  }

  void _onDspProviderChanged() {
    _checkMpvBinaryChanged();

    final current = dspProvider.connectionState;
    if (current == IpcConnectionState.connected &&
        _lastKnownConnectionState != IpcConnectionState.connected) {
      _resyncAll();
    }
    _lastKnownConnectionState = current;

    _maybeRefreshVideoInfo();
  }

  String? _lastSeenFilename;
  bool _checkingCurrentFile = false;

  /// Watches for a new file starting to play and refreshes the cached video
  /// info (resolution → tier) when it does. This used to live inside the
  /// Shaders tab widget, but TabBarView disposes off-screen tabs — so tier
  /// detection silently stopped whenever the user was on another tab. Which
  /// shader list actually applies is decided by the tier, so detection has to
  /// be alive for the whole app session, not just while that tab is visible.
  void _maybeRefreshVideoInfo() {
    if (_checkingCurrentFile) return;
    if (dspProvider.connectionState != IpcConnectionState.connected) return;
    _checkingCurrentFile = true;
    () async {
      try {
        final file = await dspProvider.getProperty('filename') as String?;
        if (file != null && file != _lastSeenFilename) {
          // Only mark the file as seen once its resolution was readable —
          // right after load mpv hasn't populated dheight yet, and giving up
          // there would leave the tier stuck on the previous video's until
          // the *next* file change. Unresolved, the next notify retries.
          if (await cacheCurrentVideoInfo()) {
            _lastSeenFilename = file;
          }
        }
      } finally {
        _checkingCurrentFile = false;
      }
    }();
  }

  /// The mpv binary we last saw. Null until the saved path has been read back —
  /// the first sighting is prefs loading, not the user choosing a new binary.
  String? _lastKnownMpvPath;
  bool _sawMpvPath = false;

  /// Switching to a different mpv.exe drops interpolation.
  ///
  /// GPU driver settings are keyed to the *executable path* — an NVIDIA
  /// per-application V-Sync override for one mpv.exe does not follow you to
  /// another one, even on the same machine. Display sync working on the old
  /// binary therefore says nothing about the new one, and carrying
  /// `interpolation: true` across silently pushes display-resample to an
  /// unverified display. Start from the safe mode and let the user re-enable,
  /// which re-runs the check against the binary they actually chose.
  void _checkMpvBinaryChanged() {
    final path = dspProvider.mpvExePath;
    if (path == null || path.isEmpty) return;

    if (!_sawMpvPath) {
      // First sighting is prefs loading at startup, not a user change.
      _sawMpvPath = true;
      _lastKnownMpvPath = path;
      return;
    }
    if (path == _lastKnownMpvPath) return;
    _lastKnownMpvPath = path;

    if (!_state.interpolation) return;

    _displaySyncCheckToken++; // cancel any check against the previous binary
    _activePresetId = null;
    _state = _state.copyWith(interpolation: false, videoSync: 'audio');
    _displaySyncWarning =
        'Interpolation was turned off because you switched to a different '
        'mpv.exe. GPU settings like V-Sync are tied to the executable path, so '
        'display sync has to be re-checked against the new binary. Turn '
        'interpolation back on to re-check it.';
    notifyListeners();
    _sendCommand('interpolation', 'no');
    _sendCommand('video-sync', 'audio');
  }

  /// Pushes the entire current [VideoState] to a freshly connected MPV.
  ///
  /// Commands enqueued while disconnected are dropped outright (see
  /// `DspProvider.sendRawCommand`), so anything the user changed before MPV
  /// came up — a preset click, a slider drag — never reached the player even
  /// though the GUI shows it as active. Without this, that divergence would
  /// persist until the user happened to touch the same control again.
  /// DspProvider.connect() does the equivalent for the audio chain.
  void _resyncAll() {
    _sendCommandQueue(_buildStateCommands(_state, _state, forceAll: true));
    // We just sent everything, so a subsequent applyPreset() can safely diff.
    _needsFullResync = false;

    // A resync pushes persisted state to an mpv we have never measured. If that
    // state has interpolation on, we have just enabled display sync on an
    // unknown display — exactly the situation _verifyDisplaySync() exists for.
    // Without this, a saved `interpolation: true` reaches a new mpv and is never
    // checked, so the video races indefinitely rather than for one settle window.
    if (_state.interpolation) _verifyDisplaySync();
  }

  VideoState get state => _state;
  String? get activePresetId => _activePresetId;
  List<String> get availableShaders => List.unmodifiable(_availableShaders);
  List<VideoPreset> get customPresets => List.unmodifiable(_customPresets);
  num? get currentVideoHeight => _currentVideoHeight;
  String? get defaultPresetId => _defaultPresetId;
  Map<String, dynamic>? get cachedVideoInfo => _cachedVideoInfo;

  /// The resolution tier of the video mpv is (believed to be) playing, which
  /// decides which of the two shader lists is live. No cached info means no
  /// evidence either way; getResolutionTier treats that as lowRes.
  ResolutionTier get currentTier =>
      getResolutionTier(_cachedVideoInfo?['dheight'] as num?);

  /// Whether the currently loaded video's own transfer function is HDR (PQ
  /// or HLG), per mpv's `video-params/gamma`. Null means unknown (no video
  /// cached yet) — callers should treat that as "don't know", not as SDR,
  /// since `--tone-mapping` only ever affects HDR source content (downward)
  /// or SDR content with HDR Output on (upward); on SDR source with HDR
  /// Output off the Algorithm dropdown is a real no-op.
  bool? get isHdrContent {
    final params = _cachedVideoInfo?['video-params'];
    if (params is! Map) return null;
    final gamma = params['gamma'];
    if (gamma is! String) return null;
    return gamma == 'pq' || gamma == 'hlg';
  }

  Future<void> setDefaultPreset(String? presetId) async {
    _defaultPresetId = presetId;
    await PreferencesService.setDefaultPresetId(presetId);
    notifyListeners();
  }

  /// Fetches current video info (resolution, codec, fps) and caches it.
  /// Called when a new video is loaded. Updates GUI and swaps the live shader
  /// list if the resolution tier changed.
  /// Returns true once the video's resolution was actually readable — a
  /// missing dheight means the file hasn't finished loading, not that the
  /// video is low-res, and acting on it would flip the tier (and the live
  /// shader list) based on nothing.
  Future<bool> cacheCurrentVideoInfo() async {
    try {
      final info = await dspProvider.fetchVideoInfo();
      final height = info['dheight'] as num?;
      if (height == null) return false;

      final oldTier = currentTier;
      _cachedVideoInfo = info;
      await PreferencesService.saveCurrentVideoInfo(info);

      if (height != _currentVideoHeight) {
        _currentVideoHeight = height;

        final newTier = getResolutionTier(height);
        // Crossing the tier boundary swaps which shader list is live, so
        // the chain mpv is holding (built for the old tier) is now wrong —
        // push the new tier's list before any tier-default preset diffs
        // against it. Skipped when both tiers resolve to the same chain,
        // since a redundant glsl-shaders set forces a pipeline rebuild.
        if (newTier != oldTier &&
            !listEquals(_state.shadersFor(oldTier), _state.shadersFor(newTier))) {
          _sendGlslShaders(_state.shadersFor(newTier));
        }
        // Deliberately NO preset auto-apply here. The default preset used to
        // be re-applied on tier changes, but that stomped the remembered
        // session on the first video of every app launch — the user's last
        // settings always win; the default only seeds a session that has
        // nothing to restore (see _restoreSession).
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error caching video info: $e');
      return false;
    }
  }

  /// Looks up a preset (built-in or custom) by id; null when absent.
  VideoPreset? _presetById(String? presetId) {
    if (presetId == null) return null;
    for (final p in builtinVideoPresets) {
      if (p.id == presetId) return p;
    }
    for (final p in _customPresets) {
      if (p.id == presetId) return p;
    }
    return null;
  }

  Future<void> _loadCustomPresets() async {
    _customPresets = await PreferencesService.getCustomVideoPresets();
    notifyListeners();
  }

  /// If Windows HDR is on, default to full HDR passthrough settings.
  Future<void> _checkWindowsHdr() async {
    final hdrOn = await PlatformService.isWindowsHdrEnabled();
    if (hdrOn && _state.toneMappingAlgorithm == 'auto') {
      _state = _state.copyWith(
        toneMappingAlgorithm: 'none',
        hdrComputePeak: false,
        hdrOutput: true,
        // Every field below must match what setHdrOutput(true) does, or the
        // auto-detected passthrough would differ from the toggled one.
        inverseToneMapping: true,
        targetColorspaceHint: true,
        targetTrc: 'pq',
      );
      notifyListeners();
    }
  }

  void saveCustomPreset(String name) {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final newPreset = VideoPreset(
      id: id,
      name: name,
      emoji: '⭐',
      description: 'Personal configuration',
      state: _state.copyWith(), // Snapshot current state
    );
    _customPresets.add(newPreset);
    _activePresetId = id;
    PreferencesService.saveCustomVideoPresets(_customPresets);
    notifyListeners();
  }

  void deleteCustomPreset(String id) {
    _customPresets.removeWhere((p) => p.id == id);
    if (_activePresetId == id) {
      _activePresetId = null;
    }
    PreferencesService.saveCustomVideoPresets(_customPresets);
    notifyListeners();
  }

  String _getShadersDirectory() {
    final baseDir = io.Directory.current.path;
    final releasePath = path.join(baseDir, 'data', 'flutter_assets', 'assets', 'shaders');
    if (io.Directory(releasePath).existsSync()) {
      return releasePath;
    }
    return path.join(baseDir, 'assets', 'shaders');
  }

  void _loadAvailableShaders() async {
    // Attempt to load from flutter assets via Directory on desktop
    if (!kIsWeb) {
      try {
        final dir = io.Directory(_getShadersDirectory());
        if (await dir.exists()) {
          final entities = await dir.list().toList();
          _availableShaders = entities
              .whereType<io.File>()
              .where((f) => f.path.endsWith('.glsl'))
              .map((f) => path.basename(f.path))
              .toList()
              ..sort();
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error loading shaders: $e');
      }
    }
  }

  /// Properties that force MPV/libplacebo to tear down and rebuild the
  /// whole GPU render pipeline (shader recompilation). These get extra
  /// breathing room after they're sent instead of the standard gap.
  static const Set<String> _kExpensiveProperties = {
    'scale', 'cscale', 'dscale',
    'tscale', 'tscale-window',
    'glsl-shaders', 'interpolation', 'video-sync',
  };
  static const Duration _kExpensiveGap = Duration(milliseconds: 400);

  /// Sends a command to MPV, utilizing a debounce timer for properties that change rapidly.
  void _sendCommand(String property, dynamic value, {bool debounce = false}) {
    final command = {
      "command": ["set_property", property, value]
    };
    final gap = _kExpensiveProperties.contains(property) ? _kExpensiveGap : null;

    if (debounce) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 32), () {
        dspProvider.sendRawCommand(command, minGapAfter: gap);
      });
    } else {
      dspProvider.sendRawCommand(command, minGapAfter: gap);
    }
  }

  // ── Display-sync verification ──────────────────────────────────────────────
  //
  // Interpolation requires a display-* video-sync mode, and `display-resample`
  // retimes video against `estimated-display-fps` — mpv's *measured* refresh,
  // not the nominal one. When that measurement runs away (measured at 347 and
  // 2817 against a real 60Hz panel), mpv faithfully sprints the video to chase
  // it: audio keeps normal speed, video runs several times too fast, and A/V
  // desync grows without bound (-14s within 4s of playback).
  //
  // mpv accepts `display-resample` unconditionally and only *then* misbehaves,
  // so no rejection is ever emitted and the Debug IPC panel stays silent. The
  // only way to catch it is to stop trusting the write and read the measurement
  // back — and to refuse display sync when it isn't credible, rather than let
  // playback be silently, badly wrong.
  static const Duration _kDisplaySyncSettle = Duration(seconds: 3);

  /// Set when we've had to force interpolation off; surfaced by the UI.
  String? _displaySyncWarning;
  String? get displaySyncWarning => _displaySyncWarning;

  /// Invalidates an in-flight check if the user changes their mind mid-settle.
  int _displaySyncCheckToken = 0;

  void dismissDisplaySyncWarning() {
    if (_displaySyncWarning == null) return;
    _displaySyncWarning = null;
    notifyListeners();
  }

  /// Set when HDR passthrough gets enabled while Windows HDR is off; surfaced
  /// by the HDR tab. mpv accepts PQ output to an SDR display without error —
  /// the image just silently looks flat and oversaturated, the same
  /// invisible-failure class as the display-sync runaway.
  String? _hdrOutputWarning;
  String? get hdrOutputWarning => _hdrOutputWarning;

  void dismissHdrOutputWarning() {
    if (_hdrOutputWarning == null) return;
    _hdrOutputWarning = null;
    notifyListeners();
  }

  Future<void> _checkHdrOutputSupported() async {
    final hdrOn = await PlatformService.isWindowsHdrEnabled();
    if (!_state.hdrOutput) return; // Turned back off while we were checking.
    if (hdrOn) {
      if (_hdrOutputWarning != null) {
        _hdrOutputWarning = null;
        notifyListeners();
      }
      return;
    }
    _hdrOutputWarning =
        'Windows HDR looks like it\'s off, so HDR passthrough is sending an HDR '
        'signal to an SDR display — colors will look flat or oversaturated. '
        'Turn on HDR in Windows Display settings (Settings > System > Display), '
        'or switch HDR Output off.';
    notifyListeners();
  }

  /// Attempts before giving up. A resync fires on *connect*, which can land
  /// before playback starts — mpv has measured nothing yet and reports no
  /// estimate. One shot would silently skip the check in exactly the case that
  /// matters most (persisted `interpolation: true` reaching a brand-new mpv).
  static const int _kDisplaySyncAttempts = 3;

  Future<void> _verifyDisplaySync({int attempt = 1}) async {
    final token = ++_displaySyncCheckToken;
    // mpv needs a few frames of playback before it has measured anything.
    await Future.delayed(_kDisplaySyncSettle);
    if (token != _displaySyncCheckToken || !_state.interpolation) return;

    final nominal = (await dspProvider.getProperty('display-fps') as num?)?.toDouble();
    final estimated =
        (await dspProvider.getProperty('estimated-display-fps') as num?)?.toDouble();
    if (token != _displaySyncCheckToken || !_state.interpolation) return;

    // No measurement yet — display sync isn't running, usually because nothing
    // is playing. Come back rather than assume it's fine.
    if (estimated == null || estimated <= 0) {
      if (attempt < _kDisplaySyncAttempts) {
        return _verifyDisplaySync(attempt: attempt + 1);
      }
      return;
    }

    // Generous headroom: high-refresh panels are real and the measurement is
    // noisy. We are catching a runaway, not a few Hz of drift.
    final ceiling = (nominal != null && nominal > 0) ? nominal * 1.5 : 200.0;
    if (estimated <= ceiling) {
      if (_displaySyncWarning != null) {
        _displaySyncWarning = null;
        notifyListeners();
      }
      return;
    }

    // Not credible. Fall back to video-sync=audio, which measured correct in
    // every configuration tested, including vsync off.
    _activePresetId = null;
    _state = _state.copyWith(interpolation: false, videoSync: 'audio');
    final panel = nominal != null && nominal > 0
        ? ' (your display reports ${nominal.toStringAsFixed(0)} Hz)'
        : '';
    _displaySyncWarning =
        'Interpolation was turned back off. mpv measures the display refresh at '
        '${estimated.toStringAsFixed(0)} Hz$panel, and interpolation needs display '
        'sync — which would race the video ahead of the audio. Enable V-Sync for '
        'this mpv.exe in your GPU control panel, then try again.';
    notifyListeners();
    _sendCommand('interpolation', 'no');
    _sendCommand('video-sync', 'audio');
  }

  void applyPreset(VideoPreset preset) {
    // Snapshot the outgoing state so we only send properties that actually
    // changed — resending unchanged scale/shader/interpolation properties
    // forces needless libplacebo pipeline rebuilds and is a big contributor
    // to overwhelming MPV with IPC commands on preset switches.
    final old = _state;
    final next = preset.state;
    // Force an unconditional full send on the first apply after a (re)connect
    // — see _needsFullResync's doc comment for why local state can't be
    // trusted as a proxy for MPV's actual live properties at that point.
    final forceAll = _needsFullResync;
    _needsFullResync = false;

    // 1. Update ALL local state at once so the UI refreshes instantly
    _activePresetId = preset.id;
    _state = next.copyWith();
    notifyListeners();

    // 2. Enqueue only what changed; the outbox queue paces delivery to MPV.
    _sendCommandQueue(_buildStateCommands(old, next, forceAll: forceAll));

    // 3. A preset that enables interpolation drags display sync in with it, so
    //    it needs the same verification as the manual toggle.
    if (next.interpolation) {
      _verifyDisplaySync();
    } else if (_displaySyncWarning != null) {
      _displaySyncWarning = null;
    }

    // 4. A preset that enables HDR passthrough (e.g. HDR Punch) needs the same
    //    Windows-HDR check as the manual HDR Output toggle.
    if (next.hdrOutput) {
      _checkHdrOutputSupported();
    } else if (_hdrOutputWarning != null) {
      _hdrOutputWarning = null;
    }
  }

  /// Test-only door onto [_buildStateCommands]. Exists so a test can assert
  /// that every persisted VideoState field actually reaches mpv — a field with
  /// no corresponding `addIfChanged` emits nothing, which is invisible at
  /// runtime (the GUI shows the setting as active while mpv never hears about
  /// it). `inverseToneMapping` shipped exactly that way. Delegates only; no
  /// behaviour of its own.
  @visibleForTesting
  List<Map<String, dynamic>> buildStateCommandsForTest(
    VideoState old,
    VideoState next, {
    required bool forceAll,
    ResolutionTier? tier,
  }) =>
      _buildStateCommands(old, next, forceAll: forceAll, tier: tier);

  /// Builds the ordered IPC command list that takes MPV from [old] to [next],
  /// skipping any property whose value is unchanged. With [forceAll] every
  /// property is emitted regardless of the diff — used for a full resync,
  /// where local state can't be trusted as a proxy for MPV's live properties.
  /// [tier] selects which per-tier shader list is the live one (defaults to
  /// the current video's tier); only that list is compared and sent.
  List<Map<String, dynamic>> _buildStateCommands(
    VideoState old,
    VideoState next, {
    required bool forceAll,
    ResolutionTier? tier,
  }) {
    final shaderTier = tier ?? currentTier;
    final commands = <Map<String, dynamic>>[];
    void addIfChanged(String property, dynamic oldValue, dynamic newValue) {
      if (forceAll || oldValue != newValue) {
        commands.add({"command": ["set_property", property, newValue]});
      }
    }

    // Tone mapping
    addIfChanged('tone-mapping', _mpvToneMappingValue(old.toneMappingAlgorithm), _mpvToneMappingValue(next.toneMappingAlgorithm));
    // Rounded: target-peak is an integer option; mpv rejects doubles over
    // JSON IPC (see setTargetPeak).
    addIfChanged('target-peak', old.targetPeak.round(), next.targetPeak.round());
    addIfChanged('hdr-contrast-recovery', old.contrastRecovery, next.contrastRecovery);
    addIfChanged('tone-mapping-visualize', old.visualizeToneMapping, next.visualizeToneMapping);
    addIfChanged('hdr-compute-peak', old.hdrComputePeak ? 'yes' : 'no', next.hdrComputePeak ? 'yes' : 'no');
    addIfChanged('hdr-peak-percentile', old.hdrPeakPercentile, next.hdrPeakPercentile);
    // Note: hdrOutput has no direct mpv property of its own — it's expressed
    // via target-trc/target-colorspace-hint below, which presets set directly.

    // Colorspace
    addIfChanged('inverse-tone-mapping', old.inverseToneMapping ? 'yes' : 'no', next.inverseToneMapping ? 'yes' : 'no');
    addIfChanged('target-colorspace-hint', old.targetColorspaceHint ? 'yes' : 'no', next.targetColorspaceHint ? 'yes' : 'no');
    // Unconditional regardless of the hint flag: these describe the target
    // color for tone/gamut-mapping and matter to mpv's rendering even when
    // target-colorspace-hint is off (the manual setTargetPrim/Gamut/Trc
    // setters already send unconditionally for the same reason). Gating
    // this on next.targetColorspaceHint left a stale target-trc (e.g. 'pq'
    // from an HDR preset) applied to mpv after switching to a preset that
    // turns the hint off, producing visibly wrong SDR color until something
    // else (like toggling HDR Output) happened to resend target-trc.
    addIfChanged('target-prim', old.targetPrim, next.targetPrim);
    addIfChanged('target-gamut', old.targetGamut, next.targetGamut);
    addIfChanged('target-trc', old.targetTrc, next.targetTrc);

    // Grading
    addIfChanged('brightness', old.brightness, next.brightness);
    addIfChanged('contrast', old.contrast, next.contrast);
    addIfChanged('gamma', old.gamma, next.gamma);
    addIfChanged('saturation', old.saturation, next.saturation);

    // Deband
    addIfChanged('deband', old.deband, next.deband);
    addIfChanged('deband-iterations', old.debandIterations, next.debandIterations);
    addIfChanged('deband-threshold', old.debandThreshold, next.debandThreshold);

    // Dithering. error-diffusion is sent even while dither != error-diffusion:
    // mpv accepts it any time (it's just dormant), and keeping it unconditional
    // means a later switch to error-diffusion finds the kernel already set.
    addIfChanged('dither', old.dither, next.dither);
    addIfChanged('error-diffusion', old.errorDiffusion, next.errorDiffusion);

    // Decoding. 'auto-safe' over 'auto': it only picks hw decoders known to
    // be reliable, which is mpv's own recommendation for config use.
    addIfChanged('hwdec', old.hardwareDecoding ? 'auto-safe' : 'no',
        next.hardwareDecoding ? 'auto-safe' : 'no');

    // Interpolation
    addIfChanged('interpolation', old.interpolation ? 'yes' : 'no', next.interpolation ? 'yes' : 'no');
    addIfChanged('video-sync', old.videoSync, next.videoSync);
    if (next.interpolation) {
      addIfChanged('tscale', old.tscale, next.tscale);
      addIfChanged('tscale-window', old.tscaleWindow, next.tscaleWindow);
      addIfChanged('tscale-radius', old.tscaleRadius, next.tscaleRadius);
      addIfChanged('tscale-blur', old.tscaleBlur, next.tscaleBlur);
      addIfChanged('tscale-clamp', old.tscaleClamp, next.tscaleClamp);
    }

    // Scaling (each of these forces a full libplacebo pipeline rebuild)
    addIfChanged('scale', old.scale, next.scale);
    addIfChanged('cscale', old.cscale, next.cscale);
    addIfChanged('dscale', old.dscale, next.dscale);
    addIfChanged('hidpi-window-scale', old.hidpiWindowScale ? 'yes' : 'no', next.hidpiWindowScale ? 'yes' : 'no');

    if (!kIsWeb) {
      // Only the current tier's list is live; the other tier's list changing
      // doesn't alter what mpv should be running.
      final oldShaders = old.shadersFor(shaderTier);
      final newShaders = next.shadersFor(shaderTier);
      final shadersChanged = forceAll ||
          oldShaders.length != newShaders.length ||
          !oldShaders.asMap().entries.every((e) => newShaders[e.key] == e.value);
      if (shadersChanged) {
        if (newShaders.isEmpty) {
          commands.add({"command": ["set_property", "glsl-shaders", ""]});
        } else {
          final shaderDir = _getShadersDirectory();
          final absolutePaths = newShaders
              .map((sf) => path.join(shaderDir, sf).replaceAll('\\', '/'))
              .toList();
          commands.add({"command": ["set_property", "glsl-shaders", absolutePaths]});
        }
      }
    }

    return commands;
  }

  /// Enqueues a list of commands to be sent sequentially. Pacing and strict
  /// ordering are guaranteed centrally by `DspProvider.sendRawCommand`'s
  /// outbox queue, so it's safe to enqueue all of them immediately here even
  /// if a previous batch (or an unrelated slider/toggle) is still draining.
  void _sendCommandQueue(List<Map<String, dynamic>> commands) {
    for (final cmd in commands) {
      final property = (cmd["command"] as List)[1] as String;
      final gap = _kExpensiveProperties.contains(property) ? _kExpensiveGap : null;
      dspProvider.sendRawCommand(cmd, minGapAfter: gap);
    }
  }

  // --- Module A: Shaders Engine ---

  /// Sends a shader chain to mpv, resolving files to absolute paths (or the
  /// empty string to clear). Callers are responsible for only passing the
  /// chain that's live for the current video's tier.
  void _sendGlslShaders(List<String> shaderFiles) {
    if (kIsWeb) return;
    if (shaderFiles.isEmpty) {
      _sendCommand('glsl-shaders', '', debounce: false);
    } else {
      final shaderDir = _getShadersDirectory();
      final absolutePaths = shaderFiles
          .map((sf) => path.join(shaderDir, sf).replaceAll('\\', '/'))
          .toList();
      _sendCommand('glsl-shaders', absolutePaths, debounce: false);
    }
  }

  void setShaders(ResolutionTier tier, List<String> shaderFiles) {
    _activePresetId = null; // Clear preset when manually adjusted
    _state = tier == ResolutionTier.lowRes
        ? _state.copyWith(shadersLowRes: shaderFiles)
        : _state.copyWith(shadersHighRes: shaderFiles);
    notifyListeners();

    // Editing the tier that isn't live only changes stored state — mpv keeps
    // running the current video's chain untouched.
    if (tier != currentTier) return;
    _sendGlslShaders(shaderFiles);
  }

  void toggleShader(ResolutionTier tier, String shaderFile, bool enable) {
    final current = List<String>.from(_state.shadersFor(tier));
    if (enable && !current.contains(shaderFile)) {
      // Mutually exclusive groups of shaders
      const exclusionGroups = [
        ['CfL_Prediction.glsl', 'CfL_Prediction_Lite.glsl', 'KrigBilateral.glsl'],
        ['CAS.glsl', 'adaptive-sharpen.glsl'],
        ['FSRCNNX_x2_16-0-4-1.glsl', 'ArtCNN_C4F16.glsl'],
      ];

      for (final group in exclusionGroups) {
        if (group.contains(shaderFile)) {
          for (final otherShader in group) {
            if (otherShader != shaderFile) {
              current.remove(otherShader);
            }
          }
        }
      }
      current.add(shaderFile);
    } else if (!enable && current.contains(shaderFile)) {
      current.remove(shaderFile);
    }
    setShaders(tier, current);
  }

  void reorderShaders(ResolutionTier tier, int oldIndex, int newIndex) {
    final current = List<String>.from(_state.shadersFor(tier));
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    setShaders(tier, current);
  }

  // --- Module B: HDR Tone Mapping ---

  /// mpv's --tone-mapping has no "none" choice (verified against mpv 0.41's
  /// own --list-options); "clip" is the real value that disables tone curve
  /// shaping. "none" is kept only as the friendly label shown in the GUI.
  static String _mpvToneMappingValue(String algo) => algo == 'none' ? 'clip' : algo;

  void setToneMappingAlgorithm(String algo) {
    _activePresetId = null;
    _state = _state.copyWith(toneMappingAlgorithm: algo);
    notifyListeners();
    _sendCommand('tone-mapping', _mpvToneMappingValue(algo));
  }

  void setTargetPeak(double peak) {
    _activePresetId = null;
    _state = _state.copyWith(targetPeak: peak);
    notifyListeners();
    // target-peak is an *integer* option and mpv's JSON IPC refuses to coerce
    // a double — 203.0 comes back "error accessing property" while 203
    // succeeds (verified against mpv 0.41). Sending the raw double made this
    // slider a dead control.
    _sendCommand('target-peak', peak.round(), debounce: true);
  }

  void setContrastRecovery(double val) {
    _activePresetId = null;
    _state = _state.copyWith(contrastRecovery: val);
    notifyListeners();
    // Real mpv property is `hdr-contrast-recovery` (0-2); the app previously
    // sent two nonexistent property names ("tone-mapping-contrast-recovery"
    // and "contrast-recovery") that mpv silently rejected.
    _sendCommand('hdr-contrast-recovery', val, debounce: true);
  }

  void setVisualizeToneMapping(bool vis) {
    _activePresetId = null;
    _state = _state.copyWith(visualizeToneMapping: vis);
    notifyListeners();
    _sendCommand('tone-mapping-visualize', vis);
  }

  void setHdrComputePeak(bool val) {
    _activePresetId = null;
    _state = _state.copyWith(hdrComputePeak: val);
    notifyListeners();
    _sendCommand('hdr-compute-peak', val ? 'yes' : 'no');
  }

  void setHdrOutput(bool val) {
    // mpv has no `hdr-output` property (verified against mpv 0.41's own
    // --list-options — it doesn't exist, so this used to be a silent no-op).
    // Repurposed as a "force HDR passthrough" shortcut: tell mpv the display
    // can accept PQ directly via the same target-colorspace-hint mechanism
    // the manual SDR-to-HDR remap panel uses, forcing target-trc to pq.
    // The Visualizer switch is only usable while HDR Output is on (it has
    // nothing to draw otherwise), so force it off too when HDR Output is
    // turned off — otherwise it'd show a stuck-on, greyed-out toggle.
    final wasVisualizing = _state.visualizeToneMapping;
    _activePresetId = null;
    _state = _state.copyWith(
      hdrOutput: val,
      inverseToneMapping: val,
      // Symmetric with target-trc: on forces the hint, off releases it. This
      // used to leave the hint at "whatever it currently is" — which was the
      // true that enabling just wrote — so one on/off cycle stranded mpv in
      // PQ output with inverse-tone-mapping off, where target-peak is dead
      // for every value above the content's own peak (verified via
      // video-target-params: gamma stayed pq under the stale hint). On any
      // machine with Windows HDR on, startup auto-enables HDR Output, so
      // merely toggling it off landed every such user in that state.
      targetColorspaceHint: val,
      targetTrc: val ? 'pq' : 'auto',
      visualizeToneMapping: val ? _state.visualizeToneMapping : false,
    );
    notifyListeners();
    if (val) {
      _sendCommand('target-colorspace-hint', 'yes');
      _sendCommand('target-trc', 'pq');
      // Without this, mpv never expands dynamic range at all (per its own
      // manual: "allows inverse tone mapping ... for upscaling SDR content
      // to HDR"), so the Algorithm dropdown would silently do nothing
      // whenever the loaded content is SDR and HDR Output is on.
      _sendCommand('inverse-tone-mapping', 'yes');
      _checkHdrOutputSupported();
    } else {
      _sendCommand('target-colorspace-hint', 'no');
      _sendCommand('target-trc', 'auto');
      _sendCommand('inverse-tone-mapping', 'no');
      if (wasVisualizing) {
        _sendCommand('tone-mapping-visualize', false);
      }
      if (_hdrOutputWarning != null) {
        _hdrOutputWarning = null;
      }
    }
  }

  void setTargetColorspaceHint(bool val) {
    _activePresetId = null;
    _state = _state.copyWith(targetColorspaceHint: val);
    notifyListeners();
    _sendCommand('target-colorspace-hint', val ? 'yes' : 'no');
  }

  void setTargetPrim(String prim) {
    _activePresetId = null;
    _state = _state.copyWith(targetPrim: prim);
    notifyListeners();
    _sendCommand('target-prim', prim);
    if (_state.targetColorspaceHint) {
      _sendCommand('target-colorspace-hint', 'yes');
    }
  }

  void setTargetGamut(String gamut) {
    _activePresetId = null;
    _state = _state.copyWith(targetGamut: gamut);
    notifyListeners();
    _sendCommand('target-gamut', gamut);
    if (_state.targetColorspaceHint) {
      _sendCommand('target-colorspace-hint', 'yes');
    }
  }

  void setTargetTrc(String trc) {
    _activePresetId = null;
    _state = _state.copyWith(targetTrc: trc);
    notifyListeners();
    _sendCommand('target-trc', trc);
    if (_state.targetColorspaceHint) {
      _sendCommand('target-colorspace-hint', 'yes');
    }
  }

  // --- Module C: Hardware Grading & Deband ---
  
  void setBrightness(int val) {
    _activePresetId = null;
    _state = _state.copyWith(brightness: val);
    notifyListeners();
    _sendCommand('brightness', val, debounce: true);
  }

  void setContrast(int val) {
    _activePresetId = null;
    _state = _state.copyWith(contrast: val);
    notifyListeners();
    _sendCommand('contrast', val, debounce: true);
  }

  void setGamma(int val) {
    _activePresetId = null;
    _state = _state.copyWith(gamma: val);
    notifyListeners();
    _sendCommand('gamma', val, debounce: true);
  }

  void setSaturation(int val) {
    _activePresetId = null;
    _state = _state.copyWith(saturation: val);
    notifyListeners();
    _sendCommand('saturation', val, debounce: true);
  }

  void setDeband(bool val) {
    _activePresetId = null;
    _state = _state.copyWith(deband: val);
    notifyListeners();
    _sendCommand('deband', val);
  }

  void setDebandIterations(int val) {
    _activePresetId = null;
    _state = _state.copyWith(debandIterations: val);
    notifyListeners();
    _sendCommand('deband-iterations', val, debounce: true);
  }

  void setDebandThreshold(int val) {
    _activePresetId = null;
    _state = _state.copyWith(debandThreshold: val);
    notifyListeners();
    _sendCommand('deband-threshold', val, debounce: true);
  }

  void setDither(String val) {
    _activePresetId = null;
    _state = _state.copyWith(dither: val);
    notifyListeners();
    _sendCommand('dither', val);
  }

  void setErrorDiffusion(String val) {
    _activePresetId = null;
    _state = _state.copyWith(errorDiffusion: val);
    notifyListeners();
    _sendCommand('error-diffusion', val);
  }

  void setHardwareDecoding(bool val) {
    _activePresetId = null;
    _state = _state.copyWith(hardwareDecoding: val);
    notifyListeners();
    _sendCommand('hwdec', val ? 'auto-safe' : 'no');
  }

  // --- Module D: Scaling & Interpolation ---

  void setInterpolation(bool val) {
    _activePresetId = null;
    _state = _state.copyWith(
      interpolation: val,
      videoSync: val ? 'display-resample' : 'audio',
    );
    _displaySyncWarning = null;
    notifyListeners();
    _sendCommand('interpolation', val ? 'yes' : 'no');
    _sendCommand('video-sync', _state.videoSync);

    // Turning this on silently switches mpv to display sync. Confirm mpv can
    // actually measure the display before leaving it that way.
    if (val) _verifyDisplaySync();
  }

  void setTScale(String algo) {
    _activePresetId = null;
    _state = _state.copyWith(tscale: algo);
    notifyListeners();
    _sendCommand('tscale', algo);
  }

  void setTScaleWindow(String window) {
    _activePresetId = null;
    _state = _state.copyWith(tscaleWindow: window);
    notifyListeners();
    _sendCommand('tscale-window', window);
  }

  void setTScaleRadius(double radius) {
    _activePresetId = null;
    _state = _state.copyWith(tscaleRadius: radius);
    notifyListeners();
    _sendCommand('tscale-radius', radius, debounce: true);
  }

  void setTScaleBlur(double blur) {
    _activePresetId = null;
    _state = _state.copyWith(tscaleBlur: blur);
    notifyListeners();
    _sendCommand('tscale-blur', blur, debounce: true);
  }

  void setTScaleClamp(double clamp) {
    _activePresetId = null;
    _state = _state.copyWith(tscaleClamp: clamp);
    notifyListeners();
    _sendCommand('tscale-clamp', clamp, debounce: true);
  }

  void setScale(String algo) {
    _activePresetId = null;
    _state = _state.copyWith(scale: algo);
    notifyListeners();
    _sendCommand('scale', algo);
  }

  void setCScale(String algo) {
    _activePresetId = null;
    _state = _state.copyWith(cscale: algo);
    notifyListeners();
    _sendCommand('cscale', algo);
  }

  void setDScale(String algo) {
    _activePresetId = null;
    _state = _state.copyWith(dscale: algo);
    notifyListeners();
    _sendCommand('dscale', algo);
  }

  void setHidpiWindowScale(bool val) {
    _activePresetId = null;
    _state = _state.copyWith(hidpiWindowScale: val);
    notifyListeners();
    _sendCommand('hidpi-window-scale', val ? 'yes' : 'no');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    // Flush a pending write so settings changed in the last 400ms survive quit.
    if (_persistDebounce?.isActive ?? false) _persistSession();
    _persistDebounce?.cancel();
    dspProvider.removeListener(_onDspProviderChanged);
    super.dispose();
  }
}
