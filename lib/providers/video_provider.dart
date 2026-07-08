// lib/providers/video_provider.dart
import 'dart:async';
import 'dart:io' if (dart.library.html) '../stubs/io_stub.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/video_state.dart';
import 'dsp_provider.dart';

class VideoProvider extends ChangeNotifier {
  final DspProvider dspProvider;
  VideoState _state = VideoState();
  List<String> _availableShaders = [];
  Timer? _debounceTimer;
  
  VideoProvider(this.dspProvider) {
    _loadAvailableShaders();
  }

  VideoState get state => _state;
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

  // --- Module A: Shaders Engine ---
  
  void setShaders(List<String> shaderFiles) {
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
    _state = _state.copyWith(toneMappingAlgorithm: algo);
    notifyListeners();
    _sendCommand('tone-mapping', algo);
  }

  void setTargetPeak(double peak) {
    _state = _state.copyWith(targetPeak: peak);
    notifyListeners();
    _sendCommand('target-peak', peak, debounce: true);
  }

  void setContrastRecovery(double val) {
    _state = _state.copyWith(contrastRecovery: val);
    notifyListeners();
    // Some mpv versions use hdr-contrast-recovery or tone-mapping-contrast-recovery
    // vo=gpu-next uses tone-mapping-contrast-recovery or contrast-recovery.
    _sendCommand('tone-mapping-contrast-recovery', val, debounce: true); 
    // also set standard one just in case
    _sendCommand('contrast-recovery', val, debounce: true); 
  }

  void setVisualizeToneMapping(bool vis) {
    _state = _state.copyWith(visualizeToneMapping: vis);
    notifyListeners();
    _sendCommand('tone-mapping-visualize', vis);
  }

  // --- Module C: Hardware Grading & Deband ---
  
  void setBrightness(int val) {
    _state = _state.copyWith(brightness: val);
    notifyListeners();
    _sendCommand('brightness', val, debounce: true);
  }

  void setContrast(int val) {
    _state = _state.copyWith(contrast: val);
    notifyListeners();
    _sendCommand('contrast', val, debounce: true);
  }

  void setGamma(int val) {
    _state = _state.copyWith(gamma: val);
    notifyListeners();
    _sendCommand('gamma', val, debounce: true);
  }

  void setDeband(bool val) {
    _state = _state.copyWith(deband: val);
    notifyListeners();
    _sendCommand('deband', val);
  }

  void setDebandIterations(int val) {
    _state = _state.copyWith(debandIterations: val);
    notifyListeners();
    _sendCommand('deband-iterations', val, debounce: true);
  }

  void setDebandThreshold(int val) {
    _state = _state.copyWith(debandThreshold: val);
    notifyListeners();
    _sendCommand('deband-threshold', val, debounce: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
