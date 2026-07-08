// lib/providers/video_provider.dart
import 'dart:async';
import 'dart:io' if (dart.library.html) '../stubs/io_stub.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/video_preset.dart';
import '../models/video_state.dart';
import 'dsp_provider.dart';

class VideoProvider extends ChangeNotifier {
  final DspProvider dspProvider;
  VideoState _state = VideoState();
  String? _activePresetId;
  List<String> _availableShaders = [];
  Timer? _debounceTimer;
  
  VideoProvider(this.dspProvider) {
    _loadAvailableShaders();
  }

  VideoState get state => _state;
  String? get activePresetId => _activePresetId;
  List<String> get availableShaders => List.unmodifiable(_availableShaders);

  void _loadAvailableShaders() async {
    // Attempt to load from flutter assets via Directory on desktop
    if (!kIsWeb) {
      try {
        final dir = io.Directory(path.join('assets', 'shaders'));
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
    // Call individual setters to ensure IPC commands are dispatched
    setToneMappingAlgorithm(preset.state.toneMappingAlgorithm);
    setTargetPeak(preset.state.targetPeak);
    setContrastRecovery(preset.state.contrastRecovery);
    setVisualizeToneMapping(preset.state.visualizeToneMapping);
    
    setBrightness(preset.state.brightness);
    setContrast(preset.state.contrast);
    setGamma(preset.state.gamma);
    
    setDeband(preset.state.deband);
    setDebandIterations(preset.state.debandIterations);
    setDebandThreshold(preset.state.debandThreshold);
    
    setInterpolation(preset.state.interpolation);
    setTScale(preset.state.tscale);
    setScale(preset.state.scale);
    setCScale(preset.state.cscale);
    setDScale(preset.state.dscale);

    // Set shaders last
    setShaders(preset.state.activeShaders);

    // Set active preset ID at the very end to override the nulls set by individual setters
    _activePresetId = preset.id;
    notifyListeners();
  }

  // --- Module A: Shaders Engine ---
  
  void setShaders(List<String> shaderFiles) {
    _activePresetId = null; // Clear preset when manually adjusted
    _state = _state.copyWith(activeShaders: shaderFiles);
    notifyListeners();

    // Resolve absolute paths for mpv
    List<String> absolutePaths = [];
    if (!kIsWeb) {
      // Basic resolution: Assuming execution from project root or next to assets
      // A more robust method involves resolving relative to Platform.resolvedExecutable
      final baseDir = io.Directory.current.path;
      for (final sf in shaderFiles) {
        absolutePaths.add(path.join(baseDir, 'assets', 'shaders', sf).replaceAll('\\', '/'));
      }
    }
    
    _sendCommand('glsl-shaders', absolutePaths, debounce: false);
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
    // Some mpv versions use hdr-contrast-recovery or tone-mapping-contrast-recovery
    // vo=gpu-next uses tone-mapping-contrast-recovery or contrast-recovery.
    _sendCommand('tone-mapping-contrast-recovery', val, debounce: true); 
    // also set standard one just in case
    _sendCommand('contrast-recovery', val, debounce: true); 
  }

  void setVisualizeToneMapping(bool vis) {
    _activePresetId = null;
    _state = _state.copyWith(visualizeToneMapping: vis);
    notifyListeners();
    _sendCommand('tone-mapping-visualize', vis);
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
