// lib/services/mpv_ipc_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web_socket_channel/web_socket_channel.dart';

enum IpcConnectionState { disconnected, connecting, connected, error }

class MpvIpcService {
  static const int _kTimeoutMs = 3000;

  String _socketPath = _defaultSocketPath();
  IpcConnectionState _state = IpcConnectionState.disconnected;
  String? _lastError;

  // Connection object: dynamic to handle either io.Socket (desktop) or WebSocketChannel (web)
  dynamic _connection; 
  StreamSubscription? _subscription;

  final StreamController<IpcConnectionState> _stateController =
      StreamController<IpcConnectionState>.broadcast();
  final StreamController<String> _responseController =
      StreamController<String>.broadcast();

  Stream<IpcConnectionState> get stateStream => _stateController.stream;
  Stream<String> get responseStream => _responseController.stream;
  IpcConnectionState get connectionState => _state;
  String get socketPath => _socketPath;
  String? get lastError => _lastError;

  void setSocketPath(String path) {
    _socketPath = path;
  }

  static String _defaultSocketPath() {
    if (kIsWeb) return 'ws://127.0.0.1:9002';
    try {
      if (io.Platform.isWindows) {
        return '127.0.0.1:9001'; // Default to TCP port for easy testing
      }
    } catch (_) {}
    return '/tmp/mpvsocket';
  }

  static String defaultPath() => _defaultSocketPath();

  Future<bool> connect() async {
    if (_state == IpcConnectionState.connected) await disconnect();
    _setState(IpcConnectionState.connecting);

    // Gather all candidate connection paths to try sequentially
    final candidatePaths = <String>[
      _socketPath,
      '127.0.0.1:9001',
      'ws://127.0.0.1:9002',
      'localhost:9001',
      'ws://localhost:9002',
    ];

    // Filter out duplicates while preserving insertion order
    final uniquePaths = candidatePaths.toSet().toList();

    for (final path in uniquePaths) {
      final ok = await _tryConnect(path);
      if (ok) {
        _socketPath = path;
        return true;
      }
    }

    _setState(IpcConnectionState.error);
    return false;
  }

  Future<bool> _tryConnect(String path) async {
    if (kIsWeb || path.startsWith('ws')) {
      // ── WebSocket Connection ──
      try {
        final uri = Uri.parse(path.startsWith('ws') ? path : 'ws://$path');
        final channel = WebSocketChannel.connect(uri);
        
        await channel.ready.timeout(const Duration(milliseconds: 1000));
        
        _connection = channel;
        _subscription = channel.stream.listen(
          (data) {
            _responseController.add(data.toString());
          },
          onError: (e) {
            _connection = null;
            _subscription = null;
            _setState(IpcConnectionState.error);
          },
          onDone: () {
            _connection = null;
            _subscription = null;
            _setState(IpcConnectionState.disconnected);
          },
        );

        _setState(IpcConnectionState.connected);
        _lastError = null;
        return true;
      } catch (e) {
        _connection = null;
        _subscription = null;
        _lastError = 'WebSocket connection failed: $e';
        return false;
      }
    } else {
      // ── Direct TCP Connection ──
      try {
        bool isWindows = false;
        try {
          isWindows = io.Platform.isWindows;
        } catch (_) {}

        if (isWindows) {
          if (path.startsWith(r'\\') || path.startsWith('pipe')) {
            return false;
          }
          final parts = path.split(':');
          final host = parts[0];
          final port = int.tryParse(parts.last) ?? 9001;
          
          final socket = await io.Socket.connect(host, port)
              .timeout(const Duration(milliseconds: 1000));
          _connection = socket;
        } else {
          final socket = await io.Socket.connect(
            io.InternetAddress(path, type: io.InternetAddressType.unix),
            0,
          ).timeout(const Duration(milliseconds: 1000));
          _connection = socket;
        }

        _subscription = (_connection as io.Socket).listen(
          (data) {
            final response = utf8.decode(data);
            _responseController.add(response);
          },
          onError: (e) {
            _connection = null;
            _subscription = null;
            _setState(IpcConnectionState.error);
          },
          onDone: () {
            _connection = null;
            _subscription = null;
            _setState(IpcConnectionState.disconnected);
          },
        );

        _setState(IpcConnectionState.connected);
        _lastError = null;
        return true;
      } catch (e) {
        _connection = null;
        _subscription = null;
        _lastError = 'TCP connection failed: $e';
        return false;
      }
    }
  }

  Future<bool> sendCommand(String jsonCommand) async {
    if (_connection == null || _state != IpcConnectionState.connected) {
      return false;
    }
    try {
      if (_connection is WebSocketChannel) {
        (_connection as WebSocketChannel).sink.add(jsonCommand);
      } else {
        (_connection as io.Socket).write('$jsonCommand\n');
        await (_connection as io.Socket).flush();
      }
      return true;
    } catch (e) {
      _lastError = e.toString();
      _setState(IpcConnectionState.error);
      _connection = null;
      return false;
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    if (_connection is WebSocketChannel) {
      try {
        await (_connection as WebSocketChannel?)?.sink.close();
      } catch (_) {}
    } else {
      try {
        await (_connection as io.Socket?)?.close();
      } catch (_) {}
    }
    _connection = null;
    _setState(IpcConnectionState.disconnected);
  }

  Future<bool> setAf(String afChain) async {
    if (afChain.isEmpty) {
      return sendCommand('{"command": ["set_property", "af", ""]}');
    }
    final cmd = jsonEncode({
      'command': ['set_property', 'af', afChain],
    });
    return sendCommand(cmd);
  }

  Future<bool> clearAf() async {
    return sendCommand('{"command": ["set_property", "af", ""]}');
  }

  void _setState(IpcConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    _subscription?.cancel();
    if (_connection is WebSocketChannel) {
      try {
        (_connection as WebSocketChannel?)?.sink.close();
      } catch (_) {}
    } else {
      try {
        (_connection as io.Socket?)?.close();
      } catch (_) {}
    }
    _stateController.close();
    _responseController.close();
  }
}
