// lib/providers/video_provider.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.html) '../stubs/io_stub.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/session.dart';
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

  VideoProvider(this.dspProvider) {
    _loadAvailableShaders();
    _restoreSession();
    dspProvider.addListener(_onDspProviderChanged);
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

    final session = await PreferencesService.getLastVideoSession();
    if (session != null) {
      _state = session.state;
      _activePresetId = session.activePresetId;
    } else {
      await _checkWindowsHdr();
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
    final current = dspProvider.connectionState;
    if (current == IpcConnectionState.connected &&
        _lastKnownConnectionState != IpcConnectionState.connected) {
      _resyncAll();
    }
    _lastKnownConnectionState = current;
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
  }

  VideoState get state => _state;
  String? get activePresetId => _activePresetId;
  List<String> get availableShaders => List.unmodifiable(_availableShaders);
  List<VideoPreset> get customPresets => List.unmodifiable(_customPresets);

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
        targetColorspaceHint: true,
        targetTrc: 'pq', // matches setHdrOutput(true)'s forced-passthrough value
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
  }

  /// Builds the ordered IPC command list that takes MPV from [old] to [next],
  /// skipping any property whose value is unchanged. With [forceAll] every
  /// property is emitted regardless of the diff — used for a full resync,
  /// where local state can't be trusted as a proxy for MPV's live properties.
  List<Map<String, dynamic>> _buildStateCommands(
    VideoState old,
    VideoState next, {
    required bool forceAll,
  }) {
    final commands = <Map<String, dynamic>>[];
    void addIfChanged(String property, dynamic oldValue, dynamic newValue) {
      if (forceAll || oldValue != newValue) {
        commands.add({"command": ["set_property", property, newValue]});
      }
    }

    // Tone mapping
    addIfChanged('tone-mapping', _mpvToneMappingValue(old.toneMappingAlgorithm), _mpvToneMappingValue(next.toneMappingAlgorithm));
    addIfChanged('target-peak', old.targetPeak, next.targetPeak);
    addIfChanged('hdr-contrast-recovery', old.contrastRecovery, next.contrastRecovery);
    addIfChanged('tone-mapping-visualize', old.visualizeToneMapping, next.visualizeToneMapping);
    addIfChanged('hdr-compute-peak', old.hdrComputePeak ? 'yes' : 'no', next.hdrComputePeak ? 'yes' : 'no');
    // Note: hdrOutput has no direct mpv property of its own — it's expressed
    // via target-trc/target-colorspace-hint below, which presets set directly.

    // Colorspace
    addIfChanged('target-colorspace-hint', old.targetColorspaceHint ? 'yes' : 'no', next.targetColorspaceHint ? 'yes' : 'no');
    if (next.targetColorspaceHint) {
      addIfChanged('target-prim', old.targetPrim, next.targetPrim);
      addIfChanged('target-gamut', old.targetGamut, next.targetGamut);
      addIfChanged('target-trc', old.targetTrc, next.targetTrc);
    }

    // Grading
    addIfChanged('brightness', old.brightness, next.brightness);
    addIfChanged('contrast', old.contrast, next.contrast);
    addIfChanged('gamma', old.gamma, next.gamma);

    // Deband
    addIfChanged('deband', old.deband, next.deband);
    addIfChanged('deband-iterations', old.debandIterations, next.debandIterations);
    addIfChanged('deband-threshold', old.debandThreshold, next.debandThreshold);

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
      final oldShaders = old.activeShaders;
      final newShaders = next.activeShaders;
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
  
  void setShaders(List<String> shaderFiles) {
    _activePresetId = null; // Clear preset when manually adjusted
    _state = _state.copyWith(activeShaders: shaderFiles);
    notifyListeners();

    // Resolve absolute paths for mpv
    if (!kIsWeb) {
      if (shaderFiles.isEmpty) {
        // Send empty string to clear all shaders
        _sendCommand('glsl-shaders', '', debounce: false);
      } else {
        final shaderDir = _getShadersDirectory();
        final absolutePaths = shaderFiles
            .map((sf) => path.join(shaderDir, sf).replaceAll('\\', '/'))
            .toList();
        _sendCommand('glsl-shaders', absolutePaths, debounce: false);
      }
    }
  }

  void toggleShader(String shaderFile, bool enable) {
    final current = List<String>.from(_state.activeShaders);
    if (enable && !current.contains(shaderFile)) {
      current.add(shaderFile);
    } else if (!enable && current.contains(shaderFile)) {
      current.remove(shaderFile);
    }
    setShaders(current);
  }

  void reorderShaders(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final current = List<String>.from(_state.activeShaders);
    final item = current.removeAt(oldIndex);
    current.insert(newIndex, item);
    setShaders(current);
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
    _sendCommand('target-peak', peak, debounce: true);
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
      targetColorspaceHint: val ? true : _state.targetColorspaceHint,
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
    } else {
      _sendCommand('target-trc', 'auto');
      _sendCommand('inverse-tone-mapping', 'no');
      if (wasVisualizing) {
        _sendCommand('tone-mapping-visualize', false);
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

  // --- Module D: Scaling & Interpolation ---

  void setInterpolation(bool val) {
    _activePresetId = null;
    _state = _state.copyWith(
      interpolation: val,
      videoSync: val ? 'display-resample' : 'audio',
    );
    notifyListeners();
    _sendCommand('interpolation', val ? 'yes' : 'no');
    _sendCommand('video-sync', _state.videoSync);
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
