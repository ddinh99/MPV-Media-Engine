// lib/providers/video_provider.dart
import 'dart:async';
import 'dart:io' if (dart.library.html) '../stubs/io_stub.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/video_preset.dart';
import '../models/video_state.dart';
import '../services/preferences_service.dart';
import 'dsp_provider.dart';

class VideoProvider extends ChangeNotifier {
  final DspProvider dspProvider;
  VideoState _state = VideoState();
  String? _activePresetId;
  List<String> _availableShaders = [];
  List<VideoPreset> _customPresets = [];
  Timer? _debounceTimer;
  
  VideoProvider(this.dspProvider) {
    _loadAvailableShaders();
    _loadCustomPresets();
  }

  VideoState get state => _state;
  String? get activePresetId => _activePresetId;
  List<String> get availableShaders => List.unmodifiable(_availableShaders);
  List<VideoPreset> get customPresets => List.unmodifiable(_customPresets);

  Future<void> _loadCustomPresets() async {
    _customPresets = await PreferencesService.getCustomVideoPresets();
    notifyListeners();
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

  /// Sends a command to MPV, utilizing a debounce timer for properties that change rapidly.
  void _sendCommand(String property, dynamic value, {bool debounce = false}) {
    final command = {
      "command": ["set_property", property, value]
    };

    if (debounce) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 32), () {
        dspProvider.sendRawCommand(command);
      });
    } else {
      dspProvider.sendRawCommand(command);
    }
  }

  void applyPreset(VideoPreset preset) {
    // 1. Update ALL local state at once so the UI refreshes instantly
    _activePresetId = preset.id;
    _state = preset.state.copyWith();
    notifyListeners();

    // 2. Build a list of IPC commands to send (order matters)
    final commands = <Map<String, dynamic>>[];

    // Tone mapping
    commands.add({"command": ["set_property", "tone-mapping", preset.state.toneMappingAlgorithm]});
    commands.add({"command": ["set_property", "target-peak", preset.state.targetPeak]});
    commands.add({"command": ["set_property", "tone-mapping-contrast-recovery", preset.state.contrastRecovery]});
    commands.add({"command": ["set_property", "tone-mapping-visualize", preset.state.visualizeToneMapping]});

    // Colorspace
    commands.add({"command": ["set_property", "target-colorspace-hint", preset.state.targetColorspaceHint ? 'yes' : 'no']});
    if (preset.state.targetColorspaceHint) {
      commands.add({"command": ["set_property", "target-prim", preset.state.targetPrim]});
      commands.add({"command": ["set_property", "target-gamut", preset.state.targetGamut]});
      commands.add({"command": ["set_property", "target-trc", preset.state.targetTrc]});
    }

    // Grading
    commands.add({"command": ["set_property", "brightness", preset.state.brightness]});
    commands.add({"command": ["set_property", "contrast", preset.state.contrast]});
    commands.add({"command": ["set_property", "gamma", preset.state.gamma]});

    // Deband
    commands.add({"command": ["set_property", "deband", preset.state.deband]});
    commands.add({"command": ["set_property", "deband-iterations", preset.state.debandIterations]});
    commands.add({"command": ["set_property", "deband-threshold", preset.state.debandThreshold]});

    // Interpolation
    commands.add({"command": ["set_property", "interpolation", preset.state.interpolation ? 'yes' : 'no']});
    commands.add({"command": ["set_property", "video-sync", preset.state.interpolation ? 'display-resample' : 'audio']});
    if (preset.state.interpolation) {
      commands.add({"command": ["set_property", "tscale", preset.state.tscale]});
      commands.add({"command": ["set_property", "tscale-window", preset.state.tscaleWindow]});
      commands.add({"command": ["set_property", "tscale-radius", preset.state.tscaleRadius]});
      commands.add({"command": ["set_property", "tscale-blur", preset.state.tscaleBlur]});
      commands.add({"command": ["set_property", "tscale-clamp", preset.state.tscaleClamp]});
    }

    // Scaling
    commands.add({"command": ["set_property", "scale", preset.state.scale]});
    commands.add({"command": ["set_property", "cscale", preset.state.cscale]});
    commands.add({"command": ["set_property", "dscale", preset.state.dscale]});

    if (!kIsWeb) {
      if (preset.state.activeShaders.isEmpty) {
        commands.add({"command": ["set_property", "glsl-shaders", ""]});
      } else {
        final shaderDir = _getShadersDirectory();
        final absolutePaths = preset.state.activeShaders
            .map((sf) => path.join(shaderDir, sf).replaceAll('\\', '/'))
            .toList();
        commands.add({"command": ["set_property", "glsl-shaders", absolutePaths]});
      }
    }

    // 3. Drip-feed commands to MPV with 150ms gaps
    _sendCommandQueue(commands);
  }

  /// Sends a list of commands sequentially with a delay between each.
  void _sendCommandQueue(List<Map<String, dynamic>> commands) {
    for (int i = 0; i < commands.length; i++) {
      final cmd = commands[i];
      Timer(Duration(milliseconds: 150 * i), () {
        dspProvider.sendRawCommand(cmd);
      });
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
  
  void setToneMappingAlgorithm(String algo) {
    _activePresetId = null;
    _state = _state.copyWith(toneMappingAlgorithm: algo);
    notifyListeners();
    _sendCommand('tone-mapping', algo);
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
    _sendCommand('tone-mapping-contrast-recovery', val, debounce: true);
    // Stagger the second command so MPV doesn't choke
    Timer(const Duration(milliseconds: 200), () {
      _sendCommand('contrast-recovery', val);
    });
  }

  void setVisualizeToneMapping(bool vis) {
    _activePresetId = null;
    _state = _state.copyWith(visualizeToneMapping: vis);
    notifyListeners();
    _sendCommand('tone-mapping-visualize', vis);
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
      Timer(const Duration(milliseconds: 200), () {
        _sendCommand('target-colorspace-hint', 'yes');
      });
    }
  }

  void setTargetGamut(String gamut) {
    _activePresetId = null;
    _state = _state.copyWith(targetGamut: gamut);
    notifyListeners();
    _sendCommand('target-gamut', gamut);
    if (_state.targetColorspaceHint) {
      Timer(const Duration(milliseconds: 200), () {
        _sendCommand('target-colorspace-hint', 'yes');
      });
    }
  }

  void setTargetTrc(String trc) {
    _activePresetId = null;
    _state = _state.copyWith(targetTrc: trc);
    notifyListeners();
    _sendCommand('target-trc', trc);
    if (_state.targetColorspaceHint) {
      Timer(const Duration(milliseconds: 200), () {
        _sendCommand('target-colorspace-hint', 'yes');
      });
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
    // Stagger the second command so MPV doesn't choke
    Timer(const Duration(milliseconds: 200), () {
      _sendCommand('video-sync', _state.videoSync);
    });
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

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
