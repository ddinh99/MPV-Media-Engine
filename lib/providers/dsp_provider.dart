// lib/providers/dsp_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.html) '../stubs/io_stub.dart' as io;
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/dsp_state.dart';
import '../models/eq_band.dart';
import '../models/preset.dart';
import '../models/session.dart';
import '../services/filter_builder.dart';
import '../services/filter_parser.dart';
import '../services/mpv_ipc_service.dart';
import '../services/preferences_service.dart';


/// A single raw IPC command waiting to be sent, paired with a completer so
/// callers can still await the real send result.
class _QueuedCommand {
  final String jsonStr;
  final Completer<bool> completer;
  /// Minimum gap to wait *after* this command before sending the next one.
  /// Lets callers flag commands known to trigger an expensive MPV/libplacebo
  /// pipeline rebuild (scale/shader/interpolation changes) so they get extra
  /// breathing room, while cheap property tweaks stay snappy.
  final Duration? gapAfter;
  _QueuedCommand(this.jsonStr, this.completer, this.gapAfter);
}

class DspProvider extends ChangeNotifier {
  final MpvIpcService _ipc = MpvIpcService();

  /// Every raw IPC command (from DSP, VideoProvider, presets, or the debug
  /// tab) funnels through this single FIFO queue, so no two commands from
  /// different call sites can ever be written to MPV back-to-back. MPV/its
  /// GPU pipeline (libplacebo) can freeze if it's slammed with a burst of
  /// property changes (e.g. scale/shader reinit) with no breathing room.
  final List<_QueuedCommand> _outbox = [];
  bool _isDrainingOutbox = false;
  static const Duration _kMinCommandGap = Duration(milliseconds: 150);

  DspState _state = DspState();
  String? _activePresetId = 'movie_dialog';
  String? _customFilterOverride;
  List<Preset> _customPresets = [];
  bool _autoApply = true;
  String _filterPreview = '';
  Timer? _debounce;
  List<String> _log = [];

  /// Commands mpv rejected (bad property name, invalid value, unavailable),
  /// newest first. Kept apart from [_log] so the Debug tab can show them
  /// prominently instead of letting them scroll past in the raw traffic.
  List<String> _commandErrors = [];

  /// Path to the mpv.exe binary, loaded from shared_preferences.
  String? _mpvExePath;
  bool _isPlayingTest = false;
  bool _prefsLoaded = false;

  /// Guards session persistence until the saved session has been read back.
  /// Without it, the notifyListeners() fired while preferences are still
  /// loading would write default state over the user's saved session.
  bool _sessionRestored = false;
  Timer? _persistDebounce;
  String? _lastPersistedJson;

  DspState get state => _state;
  String? get activePresetId => _activePresetId;
  List<Preset> get customPresets => List.unmodifiable(_customPresets);
  bool get autoApply => _autoApply;
  String get filterPreview => _filterPreview;
  bool get hasCustomFilterOverride => _customFilterOverride != null;
  IpcConnectionState get connectionState => _ipc.connectionState;
  String get socketPath => _ipc.socketPath;
  String? get lastError => _ipc.lastError;
  List<String> get log => List.unmodifiable(_log);
  List<String> get commandErrors => List.unmodifiable(_commandErrors);
  String? get mpvExePath => _mpvExePath;
  bool get isPlayingTest => _isPlayingTest;
  bool get hasMpvExe => _mpvExePath != null && _mpvExePath!.isNotEmpty;
  /// True once preferences are loaded AND no mpv.exe path is saved yet.
  bool get needsFirstTimeSetup => _prefsLoaded && !hasMpvExe;
  String get selectedChannelConfig => _state.channelConfig;

  DspProvider() {
    _ipc.stateStream.listen((_) => notifyListeners());
    _ipc.responseStream.listen((msg) {
      _addLog('MPV: ${msg.trim()}');
    });
    _ipc.commandErrorStream.listen((msg) {
      // mpv rejected a command. These used to disappear into the raw response
      // log, which is why a bogus property name (hdr-output) presented as "the
      // toggle does nothing" instead of an error. Keep them in a separate list
      // the Debug tab can surface on its own.
      _addLog('❌ mpv REJECTED: $msg');
      _commandErrors = [
        '[${DateTime.now().toIso8601String().substring(11, 19)}] $msg',
        ..._commandErrors.take(19),
      ];
      notifyListeners();
    });
    _rebuildPreview();
    _loadPreferences();
  }

  /// Clears the rejected-command list (the Debug tab's "Clear" button).
  void clearCommandErrors() {
    _commandErrors = [];
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    _mpvExePath = await PreferencesService.getMpvExePath();
    _customPresets = await PreferencesService.getCustomPresets();

    // Restore whatever the user was last listening with. This must happen
    // before the auto-connect below, since connect() pushes the current state
    // to MPV — restoring afterwards would leave MPV on the defaults.
    final session = await PreferencesService.getLastDspSession();
    if (session != null) {
      _state = session.state;
      _activePresetId = session.activePresetId;
      _customFilterOverride = session.customFilter == null
          ? null
          : FilterParser.sanitizeDynaudnormG(session.customFilter!);
      _autoApply = session.autoApply;
      _rebuildPreview();
    }
    _sessionRestored = true;

    _prefsLoaded = true;
    notifyListeners();
    if (hasMpvExe) {
      // Auto-connect if possible, but keep state clean if it fails
      final ok = await _ipc.connect();
      if (!ok) {
        await _ipc.disconnect();
      }
    }
  }

  /// Persist on every state change. Hooking notifyListeners() rather than each
  /// of the setters means no mutation path can forget to save. Writes are
  /// debounced (slider drags fire continuously) and skipped when the encoded
  /// session is unchanged, so the log/connection notifications that don't
  /// touch DSP state cost nothing.
  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_sessionRestored) return;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 400), _persistSession);
  }

  void _persistSession() {
    final session = DspSession(
      state: _state,
      activePresetId: _activePresetId,
      customFilter: _customFilterOverride,
      autoApply: _autoApply,
    );
    final encoded = jsonEncode(session.toJson());
    if (encoded == _lastPersistedJson) return;
    _lastPersistedJson = encoded;
    unawaited(PreferencesService.saveLastDspSession(session));
  }

  /// Sends a raw JSON IPC command to MPV. Commands are queued and dispatched
  /// one at a time with a minimum gap between them (see [_kMinCommandGap]),
  /// regardless of which part of the app enqueued them, so bursts from
  /// overlapping presets/sliders/toggles can never reach MPV at once.
  /// [minGapAfter] can widen the gap after *this* command specifically —
  /// use it for properties known to trigger a full MPV/libplacebo render
  /// pipeline rebuild (scale/cscale/dscale/tscale/glsl-shaders/interpolation).
  Future<bool> sendRawCommand(Map<String, dynamic> command, {Duration? minGapAfter}) {
    // Refuse to queue while disconnected. MpvIpcService.sendCommand would drop
    // these anyway, but queuing them still costs a pacing gap each (draining a
    // whole preset takes seconds) and — worse — lets a connection that lands
    // mid-drain deliver an arbitrary *tail* of the batch to MPV, applying half
    // a preset. VideoProvider._resyncAll() pushes the real state on connect.
    if (_ipc.connectionState != IpcConnectionState.connected) {
      _addLog('⏭ Not connected — skipped: ${_describe(command)}');
      return Future.value(false);
    }
    final jsonStr = jsonEncode(command);
    final completer = Completer<bool>();
    _outbox.add(_QueuedCommand(jsonStr, completer, minGapAfter));
    unawaited(_drainOutbox());
    return completer.future;
  }

  /// Short human-readable form of an IPC command, for the log.
  /// `{"command": ["set_property", "scale", "ewa_lanczos"]}` → `set_property scale`.
  static String _describe(Map<String, dynamic> command) {
    final parts = command['command'];
    if (parts is List && parts.length >= 2) return '${parts[0]} ${parts[1]}';
    return jsonEncode(command);
  }

  Future<void> _drainOutbox() async {
    if (_isDrainingOutbox) return;
    _isDrainingOutbox = true;
    try {
      while (_outbox.isNotEmpty) {
        final item = _outbox.removeAt(0);
        final ok = await _ipc.sendCommand(item.jsonStr);
        // Report what actually happened. The old log line announced the send
        // before attempting it and ignored the result, so a dropped command
        // was indistinguishable from a delivered one.
        _addLog(ok
            ? 'Sent: ${item.jsonStr}'
            : '✗ Send failed (connection lost): ${item.jsonStr}');
        item.completer.complete(ok);
        if (_outbox.isNotEmpty) {
          final gap = item.gapAfter ?? _kMinCommandGap;
          await Future.delayed(gap < _kMinCommandGap ? _kMinCommandGap : gap);
        }
      }
    } finally {
      _isDrainingOutbox = false;
    }
  }

  void setSelectedChannelConfig(String config) {
    if (_state.channelConfig == config) return;
    // Stash the current config's matrix, then swap in the target config's.
    _state.panMatrices[_state.channelConfig] = _state.panMatrix;
    // Route through _update like every other setter — it clears
    // _customFilterOverride, without which _applyNow keeps resending the
    // favorite's stored raw filter string (frozen at pan=stereo) instead of
    // rebuilding from state.
    _update(
      _state.copyWith(
        channelConfig: config,
        panMatrix: _state.panMatrices[config],
      ),
      clearPreset: true,
    );
  }

  /// Save the mpv.exe path to preferences.
  Future<void> setMpvExePath(String? path) async {
    _mpvExePath = path;
    if (path != null && path.isNotEmpty) {
      await PreferencesService.setMpvExePath(path);
      _addLog('MPV path set: $path');
    } else {
      await PreferencesService.clearMpvExePath();
      _addLog('MPV path cleared');
    }
    notifyListeners();
  }

  /// Pick a video file, launch mpv.exe with Named Pipe IPC, start the
  /// PowerShell WebSocket bridge, then auto-connect.
  Future<void> playTestVideo() async {
    if (!hasMpvExe) return;

    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select a video to play',
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final videoPath = result.files.first.path;
    if (videoPath == null) return;

    _isPlayingTest = true;
    notifyListeners();

    try {
      // ── Step 1: disconnect any existing session ──────────────────────────
      if (_ipc.connectionState == IpcConnectionState.connected) {
        await _ipc.disconnect();
      }

      // Generate a unique session ID and port to guarantee zero collisions
      final rng = math.Random();
      final sessionPort = 9000 + rng.nextInt(10000);
      final sessionPipe = 'mpvsocket_${rng.nextInt(999999)}';

      // ── Step 2: launch mpv.exe with Named Pipe IPC (standard for Windows) ──
      final mpvPipePath = r'\\.\pipe\' + sessionPipe;
      _addLog('▶ Launching MPV…');
      final mpvProcess = await io.Process.start(
        _mpvExePath!,
        // Force gpu-next: nearly every HDR-tab property this app drives
        // (inverse-tone-mapping, hdr-reference-white, gamut-mapping-mode,
        // target-colorspace-hint-mode, the bt.2446a/st2094-40 tone curves...)
        // is gpu-next-only per mpv's manual. mpv would otherwise silently
        // pick whatever --vo its own mpv.conf/build defaults to, and every
        // one of those properties would be a no-op with no rejection to
        // surface it — the same invisible-failure class as the dead
        // hdr-output toggle.
        // Trailing comma keeps mpv's own fallback behavior (falls back to
        // other compiled-in VOs if gpu-next isn't available on this build),
        // matching what --vo already does unset — this only makes the
        // otherwise-implicit default explicit, it doesn't remove fallback.
        ['--input-ipc-server=$mpvPipePath', '--vo=gpu-next,', videoPath],
        mode: io.ProcessStartMode.detached,
      );
      _addLog('  MPV pid ${mpvProcess.pid}');

      // ── Step 3: wait for MPV to create the Named Pipe ─────────────────────
      await Future.delayed(const Duration(milliseconds: 3000));

      // ── Step 4: unpack & launch the PowerShell bridge ─────────────────────
      // powershell.exe ships on every Windows install, and the .ps1 speaks
      // mpv's named pipe — which is the only thing --input-ipc-server ever
      // creates on Windows (see CLAUDE.md). There is deliberately no
      // fallback interpreter here.
      String bridgePs1Path = '';
      final tempDir = io.Directory.systemTemp.path;
      final sep = io.Platform.pathSeparator;

      try {
        var ps1Content = await rootBundle.loadString('mpv_websocket_bridge.ps1');
        ps1Content = ps1Content.replaceAll('\$wsPort = 9002', '\$wsPort = $sessionPort');
        ps1Content = ps1Content.replaceAll("\$pipeName = 'mpvsocket'", "\$pipeName = '$sessionPipe'");
        final ps1File = io.File('$tempDir${sep}mpv_websocket_bridge.ps1');
        await ps1File.writeAsString(ps1Content);
        bridgePs1Path = ps1File.path;
      } catch (_) {}

      bool bridgeStarted = false;
      if (bridgePs1Path.isNotEmpty && io.File(bridgePs1Path).existsSync()) {
        _addLog('▶ Starting WebSocket bridge (PowerShell)…');
        try {
          final bp = await io.Process.start(
            'powershell.exe',
            ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', bridgePs1Path],
            mode: io.ProcessStartMode.normal,
          );
          // Drain stdout/stderr so PowerShell doesn't freeze when the 4KB pipe buffer fills
          bp.stdout.listen((_) {});
          bp.stderr.listen((_) {});
          _addLog('  PowerShell bridge pid ${bp.pid} → ws://127.0.0.1:$sessionPort');
          _ipc.setSocketPath('ws://127.0.0.1:$sessionPort');
          bridgeStarted = true;
          await Future.delayed(const Duration(milliseconds: 1200));
        } catch (e) {
          _addLog('  PowerShell bridge start failed: $e');
        }
      }

      if (!bridgeStarted) {
        _addLog('⚠ The PowerShell bridge failed to launch. Please run mpv_websocket_bridge.ps1 manually.');
      }

      // ── Step 5: auto-connect with retry ─────────────────────────────────
      _addLog('  Connecting to MPV…');
      bool connected = false;
      for (int attempt = 1; attempt <= 10 && !connected; attempt++) {
        connected = await _ipc.connect();
        if (!connected) {
          _addLog('  Retry $attempt/10 (Error: ${_ipc.lastError})…');
          await Future.delayed(const Duration(milliseconds: 700));
        }
      }

      if (connected) {
        _addLog('✓ Connected! DSP settings are now live.');
        notifyListeners();
        await _applyNow(); // push current settings immediately
      } else {
        _addLog('✗ Could not connect after 10 attempts.');
      }
    } catch (e) {
      _addLog('✗ Launch failed: $e');
    } finally {
      _isPlayingTest = false;
      notifyListeners();
    }
  }


  // ── Connection ──────────────────────────────────────────────────────────────

  void setSocketPath(String path) {
    _ipc.setSocketPath(path);
    notifyListeners();
  }

  Future<void> connect() async {
    await _ipc.connect();
    notifyListeners();
    if (_ipc.connectionState == IpcConnectionState.connected && _autoApply) {
      await _applyNow();
    }
  }

  Future<void> disconnect() async {
    await _ipc.disconnect();
    notifyListeners();
  }

  /// Queries a single MPV property and returns its decoded value, or null on
  /// error/timeout/disconnected. See [MpvIpcService.getProperty].
  Future<dynamic> getProperty(String property) => _ipc.getProperty(property);

  /// Gathers a snapshot of properties describing what MPV is currently
  /// playing (resolution, codec, fps, filename). Missing/errored properties
  /// are simply absent from the returned map rather than failing the whole
  /// call, since e.g. `video-params` is null until a video is loaded.
  Future<Map<String, dynamic>> fetchVideoInfo() async {
    const properties = [
      'filename',
      'video-codec',
      'dwidth',
      'dheight',
      'video-params',
      'container-fps',
      'estimated-vf-fps',
    ];
    final info = <String, dynamic>{};
    for (final prop in properties) {
      final value = await getProperty(prop);
      if (value != null) info[prop] = value;
    }
    return info;
  }

  // ── State mutation helpers ──────────────────────────────────────────────────

  void _update(DspState newState, {bool clearPreset = false}) {
    _state = newState;
    _customFilterOverride = null;
    if (clearPreset) _activePresetId = null;
    _rebuildPreview();
    notifyListeners();
    if (_autoApply) _scheduleApply();
  }

  void _rebuildPreview() {
    if (_customFilterOverride != null) {
      _filterPreview = _customFilterOverride!;
    } else if (_state.bypass) {
      _filterPreview = '# BYPASS — no filters applied';
    } else {
      _filterPreview = FilterBuilder.buildConfigLine(_state);
    }
  }

  void _scheduleApply() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () => _applyNow());
  }

  Future<void> _applyNow() async {
    if (_ipc.connectionState != IpcConnectionState.connected) return;
    
    String cmd;
    if (_customFilterOverride != null) {
      cmd = jsonEncode({
        "command": ["set_property", "af", _customFilterOverride!.replaceFirst('#af-add=', '')]
      });
    } else {
      cmd = FilterBuilder.buildIpcCommand(_state);
    }
    
    final ok = await _ipc.sendCommand(cmd);
    _addLog(ok ? '✓ Applied' : '✗ Send failed');
  }

  Future<void> applyNow() async {
    await _applyNow();
  }

  void _addLog(String msg) {
    print('LOG: $msg');
    _log = ['[${DateTime.now().toIso8601String().substring(11, 19)}] $msg', ..._log.take(49)];
    notifyListeners();
  }

  // ── Auto apply toggle ───────────────────────────────────────────────────────

  void setAutoApply(bool value) {
    _autoApply = value;
    notifyListeners();
  }

  // ── Preset loading ──────────────────────────────────────────────────────────

  void loadPreset(Preset preset) {
    _activePresetId = preset.id;
    _customFilterOverride = preset.customFilter == null
        ? null
        : FilterParser.sanitizeDynaudnormG(preset.customFilter!);
    _state = preset.state.copyWith();
    _rebuildPreview();
    notifyListeners();
    if (_autoApply) _scheduleApply();
    _addLog('Preset: ${preset.emoji} ${preset.name}');
  }

  void applyCustomFilter(String name, String filterString) {
    _activePresetId = name;
    _customFilterOverride = FilterParser.sanitizeDynaudnormG(filterString);

    // Attempt to parse the raw string back into the GUI state so sliders update!
    try {
      _state = FilterParser.parse(filterString);
    } catch (e) {
      _addLog('Parser warning: Could not fully parse string to GUI ($e)');
    }

    _rebuildPreview();
    notifyListeners();
    if (_autoApply) _scheduleApply();
    _addLog('Preset: ⭐ $name');
  }

  Future<void> saveCurrentAsPreset(String name) async {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final newPreset = Preset(
      id: id,
      name: name,
      emoji: '👤',
      description: 'Personal preset',
      state: _state.copyWith(),
      customFilter: _customFilterOverride,
      channelConfig: _state.channelConfig,
    );
    _customPresets.add(newPreset);
    _activePresetId = id;
    // We intentionally DO NOT clear _customFilterOverride here, so the GUI keeps displaying it!
    notifyListeners();
    await PreferencesService.saveCustomPresets(_customPresets);
    _addLog('Saved personal preset: $name');
  }

  Future<void> deleteCustomPreset(String id) async {
    _customPresets.removeWhere((p) => p.id == id);
    if (_activePresetId == id) {
      _activePresetId = null;
    }
    notifyListeners();
    await PreferencesService.saveCustomPresets(_customPresets);
    _addLog('Deleted personal preset');
  }

  // ── DynAudNorm ─────────────────────────────────────────────────────────────

  void setDynAudNormEnabled(bool v) =>
      _update(_state.copyWith(dynaudnormEnabled: v), clearPreset: true);

  void setDynAudNormFrameLength(double v) => _update(
        _state.copyWith(dynaudnorm: _state.dynaudnorm.copyWith(frameLength: v.round())),
        clearPreset: true);

  void setDynAudNormGaussSize(double v) => _update(
        _state.copyWith(dynaudnorm: _state.dynaudnorm.copyWith(gaussSize: v.round())),
        clearPreset: true);

  void setDynAudNormPeak(double v) => _update(
        _state.copyWith(dynaudnorm: _state.dynaudnorm.copyWith(peak: v)),
        clearPreset: true);

  void setDynAudNormMaxGain(double v) => _update(
        _state.copyWith(dynaudnorm: _state.dynaudnorm.copyWith(maxGain: v)),
        clearPreset: true);

  // ── Pan Matrix ─────────────────────────────────────────────────────────────

  void setPanMatrix(PanMatrix m) =>
      _update(_state.copyWith(panMatrix: m), clearPreset: true);

  void setDialogFocus(double v) {
    final m = _state.panMatrix.copyWith(flfc: v, frfc: v);
    _update(_state.copyWith(panMatrix: m), clearPreset: true);
  }

  void setSurroundLevel(double v) {
    final m = _state.panMatrix.copyWith(
      flbl: -v * 0.20 / 0.20,
      flsl: -v * 0.18 / 0.20,
      frbr: v * 0.20 / 0.20,
      frsr: v * 0.18 / 0.20,
    );
    _update(_state.copyWith(panMatrix: m), clearPreset: true);
  }

  void setLfeBlend(double v) {
    final m = _state.panMatrix.copyWith(fllfe: v, frlfe: v);
    _update(_state.copyWith(panMatrix: m), clearPreset: true);
  }

  // ── Ambience ───────────────────────────────────────────────────────────────

  void setAmbienceEnabled(bool v) =>
      _update(_state.copyWith(ambience: _state.ambience.copyWith(enabled: v)), clearPreset: true);

  void setAmbienceMixWeight(double v) =>
      _update(_state.copyWith(ambience: _state.ambience.copyWith(mixWeight: v)), clearPreset: true);

  void setAmbienceHighpass(double v) =>
      _update(_state.copyWith(ambience: _state.ambience.copyWith(highpassFreq: v)), clearPreset: true);

  void setAmbienceLowpass(double v) =>
      _update(_state.copyWith(ambience: _state.ambience.copyWith(lowpassFreq: v)), clearPreset: true);

  void setEchoDelay(double v) =>
      _update(_state.copyWith(ambience: _state.ambience.copyWith(echoDelay: v)), clearPreset: true);

  void setEchoDecay(double v) =>
      _update(_state.copyWith(ambience: _state.ambience.copyWith(echoDecay: v)), clearPreset: true);

  void setEchoVolume(double v) =>
      _update(_state.copyWith(ambience: _state.ambience.copyWith(echoVolume: v)), clearPreset: true);

  void setEchoFeedback(double v) =>
      _update(_state.copyWith(ambience: _state.ambience.copyWith(echoFeedback: v)), clearPreset: true);

  // ── ExtraStereo ────────────────────────────────────────────────────────────

  void setExtraStereo(double v) =>
      _update(_state.copyWith(extraStereo: v), clearPreset: true);

  // ── EQ ─────────────────────────────────────────────────────────────────────

  void setEqBandGain(int index, double gain) {
    final bands = List<EqBand>.from(_state.eqBands);
    bands[index] = bands[index].copyWith(gain: gain);
    _update(_state.copyWith(eqBands: bands), clearPreset: true);
  }

  // ── High shelf ─────────────────────────────────────────────────────────────

  void setHighShelfGain(double v) =>
      _update(_state.copyWith(highShelf: _state.highShelf.copyWith(gain: v)), clearPreset: true);

  void setHighShelfFreq(double v) =>
      _update(_state.copyWith(highShelf: _state.highShelf.copyWith(freq: v)), clearPreset: true);

  // ── Compressor ─────────────────────────────────────────────────────────────

  void setCompThreshold(double v) =>
      _update(_state.copyWith(compressor: _state.compressor.copyWith(threshold: v)), clearPreset: true);

  void setCompRatio(double v) =>
      _update(_state.copyWith(compressor: _state.compressor.copyWith(ratio: v)), clearPreset: true);

  void setCompAttack(double v) =>
      _update(_state.copyWith(compressor: _state.compressor.copyWith(attack: v)), clearPreset: true);

  void setCompRelease(double v) =>
      _update(_state.copyWith(compressor: _state.compressor.copyWith(release: v)), clearPreset: true);

  void setCompMakeup(double v) =>
      _update(_state.copyWith(compressor: _state.compressor.copyWith(makeup: v)), clearPreset: true);

  // ── Limiter ────────────────────────────────────────────────────────────────

  void setLimiterEnabled(bool v) =>
      _update(_state.copyWith(limiter: _state.limiter.copyWith(enabled: v)), clearPreset: true);

  void setLimiterCeiling(double v) =>
      _update(_state.copyWith(limiter: _state.limiter.copyWith(limit: v)), clearPreset: true);

  // ── Bypass ─────────────────────────────────────────────────────────────────

  void setBypass(bool v) {
    _activePresetId = v ? 'bypass' : null;
    _update(_state.copyWith(bypass: v));
  }

  // ── Clipboard / Export ─────────────────────────────────────────────────────

  String exportConfigLine() => _filterPreview;

  @override
  void dispose() {
    _debounce?.cancel();
    // Flush any pending session write before the timer is discarded, so
    // settings changed in the last 400ms aren't lost on quit.
    if (_persistDebounce?.isActive ?? false) _persistSession();
    _persistDebounce?.cancel();
    for (final item in _outbox) {
      item.completer.complete(false);
    }
    _outbox.clear();
    _ipc.dispose();
    super.dispose();
  }
}
