// lib/providers/dsp_provider.dart
import 'dart:async';
import 'dart:io' if (dart.library.html) '../stubs/io_stub.dart' as io;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/dsp_state.dart';
import '../models/eq_band.dart';
import '../models/preset.dart';
import '../services/filter_builder.dart';
import '../services/mpv_ipc_service.dart';
import '../services/preferences_service.dart';


class DspProvider extends ChangeNotifier {
  final MpvIpcService _ipc = MpvIpcService();

  DspState _state = DspState();
  String? _activePresetId = 'movie_dialog';
  bool _autoApply = true;
  String _filterPreview = '';
  Timer? _debounce;
  List<String> _log = [];

  /// Path to the mpv.exe binary, loaded from shared_preferences.
  String? _mpvExePath;
  bool _isPlayingTest = false;
  bool _prefsLoaded = false;

  DspState get state => _state;
  String? get activePresetId => _activePresetId;
  bool get autoApply => _autoApply;
  String get filterPreview => _filterPreview;
  IpcConnectionState get connectionState => _ipc.connectionState;
  String get socketPath => _ipc.socketPath;
  String? get lastError => _ipc.lastError;
  List<String> get log => List.unmodifiable(_log);
  String? get mpvExePath => _mpvExePath;
  bool get isPlayingTest => _isPlayingTest;
  bool get hasMpvExe => _mpvExePath != null && _mpvExePath!.isNotEmpty;
  /// True once preferences are loaded AND no mpv.exe path is saved yet.
  bool get needsFirstTimeSetup => _prefsLoaded && !hasMpvExe;

  DspProvider() {
    _ipc.stateStream.listen((_) => notifyListeners());
    _ipc.responseStream.listen((msg) {
      _addLog('MPV: ${msg.trim()}');
    });
    _rebuildPreview();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    _mpvExePath = await PreferencesService.getMpvExePath();
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

  /// Save the mpv.exe path to preferences and copy the WebSocket bridge script to its directory.
  Future<void> setMpvExePath(String? path) async {
    _mpvExePath = path;
    if (path != null && path.isNotEmpty) {
      await PreferencesService.setMpvExePath(path);
      _addLog('MPV path set: $path');
      
      // Auto-copy the WebSocket bridge script next to mpv.exe (desktop only)
      if (!kIsWeb) {
        try {
          final content = await rootBundle.loadString('mpv_websocket_bridge.py');
          final dir = io.File(path).parent.path;
          final sep = io.Platform.pathSeparator;
          final target = io.File('$dir${sep}mpv_websocket_bridge.py');
          await target.writeAsString(content);
          _addLog('✓ Auto-copied bridge script next to mpv.exe.');
        } catch (e) {
          _addLog('⚠ Note: Could not copy bridge script next to mpv.exe ($e).');
        }
      }
    } else {
      await PreferencesService.clearMpvExePath();
      _addLog('MPV path cleared');
    }
    notifyListeners();
  }

  /// Pick a video file, launch mpv.exe with Named Pipe IPC, start the Python
  /// (or PowerShell fallback) WebSocket bridge, then auto-connect.
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

      // ── Step 2: launch mpv.exe with Named Pipe IPC (standard for Windows) ──
      const mpvPipePath = r'\\.\pipe\mpvsocket';
      _addLog('▶ Launching MPV…');
      final mpvProcess = await io.Process.start(
        _mpvExePath!,
        ['--input-ipc-server=$mpvPipePath', videoPath],
        mode: io.ProcessStartMode.detached,
      );
      _addLog('  MPV pid ${mpvProcess.pid}');

      // ── Step 3: wait for MPV to create the Named Pipe ─────────────────────
      await Future.delayed(const Duration(milliseconds: 1500));

      // ── Step 4: unpack & launch the bridge (Python or PowerShell) ─────────
      String bridgePyPath = '';
      String bridgePs1Path = '';
      final tempDir = io.Directory.systemTemp.path;
      final sep = io.Platform.pathSeparator;

      // 4a. Copy next to mpv.exe if permissions allow
      try {
        final content = await rootBundle.loadString('mpv_websocket_bridge.py');
        final mpvDir = io.File(_mpvExePath!).parent.path;
        final target = io.File('$mpvDir${sep}mpv_websocket_bridge.py');
        await target.writeAsString(content);
        _addLog('✓ Refreshed python bridge next to mpv.exe.');
      } catch (e) {
        // Silently ignore or note
      }

      // 4b. Unpack scripts to temp directory
      try {
        final pyContent = await rootBundle.loadString('mpv_websocket_bridge.py');
        final pyFile = io.File('$tempDir${sep}mpv_websocket_bridge.py');
        await pyFile.writeAsString(pyContent);
        bridgePyPath = pyFile.path;
      } catch (_) {}

      try {
        final ps1Content = await rootBundle.loadString('mpv_websocket_bridge.ps1');
        final ps1File = io.File('$tempDir${sep}mpv_websocket_bridge.ps1');
        await ps1File.writeAsString(ps1Content);
        bridgePs1Path = ps1File.path;
      } catch (_) {}

      // 4c. Try starting Python bridge first
      bool bridgeStarted = false;
      if (bridgePyPath.isNotEmpty && io.File(bridgePyPath).existsSync()) {
        _addLog('▶ Starting WebSocket bridge (Python)…');
        try {
          final bp = await io.Process.start(
            'python',
            [bridgePyPath],
            mode: io.ProcessStartMode.detached,
            environment: {'PYTHONUNBUFFERED': '1'},
          );
          _addLog('  Python bridge pid ${bp.pid} → ws://127.0.0.1:9002');
          _ipc.setSocketPath('ws://127.0.0.1:9002');
          bridgeStarted = true;
          await Future.delayed(const Duration(milliseconds: 1000));
        } catch (e) {
          _addLog('  Python bridge start failed: $e');
        }
      }

      // 4d. Fallback to PowerShell bridge if Python failed
      if (!bridgeStarted && bridgePs1Path.isNotEmpty && io.File(bridgePs1Path).existsSync()) {
        _addLog('▶ Starting WebSocket bridge (PowerShell Fallback)…');
        try {
          final bp = await io.Process.start(
            'powershell.exe',
            ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', bridgePs1Path],
            mode: io.ProcessStartMode.detached,
          );
          _addLog('  PowerShell bridge pid ${bp.pid} → ws://127.0.0.1:9002');
          _ipc.setSocketPath('ws://127.0.0.1:9002');
          bridgeStarted = true;
          await Future.delayed(const Duration(milliseconds: 1200));
        } catch (e) {
          _addLog('  PowerShell bridge start failed: $e');
        }
      }

      if (!bridgeStarted) {
        _addLog('⚠ Both Python and PowerShell bridges failed to launch. Please run the bridge manually.');
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

  // ── State mutation helpers ──────────────────────────────────────────────────

  void _update(DspState newState, {bool clearPreset = false}) {
    _state = newState;
    if (clearPreset) _activePresetId = null;
    _rebuildPreview();
    notifyListeners();
    if (_autoApply) _scheduleApply();
  }

  void _rebuildPreview() {
    if (_state.bypass) {
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
    final cmd = FilterBuilder.buildIpcCommand(_state);
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
    _state = preset.state.copyWith();
    _rebuildPreview();
    notifyListeners();
    if (_autoApply) _scheduleApply();
    _addLog('Preset: ${preset.emoji} ${preset.name}');
  }

  // ── DynAudNorm ─────────────────────────────────────────────────────────────

  void setDynAudNormEnabled(bool v) =>
      _update(_state.copyWith(dynaudnormEnabled: v), clearPreset: true);

  void setDynAudNormFrameLength(double v) => _update(
        _state.copyWith(dynaudnorm: _state.dynaudnorm.copyWith(frameLength: v.round())),
        clearPreset: true);

  void setDynAudNormGain(double v) => _update(
        _state.copyWith(dynaudnorm: _state.dynaudnorm.copyWith(gain: v)),
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

  String exportConfigLine() => FilterBuilder.buildConfigLine(_state);

  @override
  void dispose() {
    _debounce?.cancel();
    _ipc.dispose();
    super.dispose();
  }
}
