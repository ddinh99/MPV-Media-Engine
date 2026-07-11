// lib/services/mpv_ipc_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.html) '../stubs/io_stub.dart' as io;
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
  final StreamController<String> _commandErrorController =
      StreamController<String>.broadcast();

  /// Pending get_property requests keyed by the request_id we sent, so an
  /// async reply arriving from MPV can be matched back to its caller. Works
  /// over the WebSocket bridge (which relays MPV's replies — see
  /// mpv_websocket_bridge.ps1) or a direct socket. mpv acks fire-and-forget
  /// commands with request_id 0; our counter starts at 1 so those never match.
  final Map<int, Completer<dynamic>> _pendingRequests = {};
  int _requestIdCounter = 0;

  /// Fire-and-forget commands we've sent, keyed by the request_id we stamped
  /// on them, holding a human-readable description of what was sent. mpv
  /// answers *every* command with an `error` field, but a command sent with no
  /// request_id comes back as request_id 0 — indistinguishable from every other
  /// one in flight. Stamping an id lets a rejection be traced to the exact
  /// property that caused it. See [_kMaxInFlight] for the leak bound.
  final Map<int, String> _inFlightCommands = {};

  /// mpv replies to everything, so entries normally clear as fast as they're
  /// added. Bounded anyway: a dropped connection mid-send (or a bridge that
  /// swallows a reply) would otherwise leak an entry per command, forever.
  static const int _kMaxInFlight = 128;

  Stream<IpcConnectionState> get stateStream => _stateController.stream;
  Stream<String> get responseStream => _responseController.stream;

  /// Emits a formatted message whenever mpv *rejects* a command — a bad
  /// property name, an invalid value, an unavailable property. Nothing else
  /// surfaces these: a rejected set_property is silently ignored, so a typo'd
  /// property name looks like "the slider does nothing" rather than an error.
  /// (`hdr-output` was exactly this — it isn't a real mpv property, so the
  /// toggle was a no-op for months.)
  Stream<String> get commandErrorStream => _commandErrorController.stream;

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
        
        await channel.ready.timeout(const Duration(milliseconds: _kTimeoutMs));
        
        _connection = channel;
        _subscription = channel.stream.listen(
          (data) {
            _handleIncomingData(data.toString());
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
              .timeout(const Duration(milliseconds: _kTimeoutMs));
          _connection = socket;
        } else {
          final socket = await io.Socket.connect(
            io.InternetAddress(path, type: io.InternetAddressType.unix),
            0,
          ).timeout(const Duration(milliseconds: _kTimeoutMs));
          _connection = socket;
        }

        _subscription = (_connection as io.Socket).listen(
          (data) {
            final response = utf8.decode(data);
            _handleIncomingData(response);
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

  /// Called with every raw chunk arriving from MPV (over either transport).
  /// Forwards it verbatim to [responseStream] for the Command Log, and also
  /// matches any `request_id` against a pending [getProperty] call. A single
  /// chunk can hold several newline-delimited JSON messages (events + replies),
  /// so each line is decoded independently.
  void _handleIncomingData(String raw) {
    _responseController.add(raw);
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      Map<String, dynamic> obj;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is! Map<String, dynamic>) continue;
        obj = decoded;
      } catch (_) {
        continue; // Partial line split across chunks, or a non-JSON line.
      }
      final requestId = obj['request_id'];
      if (requestId is! int) continue;

      // A rejected fire-and-forget command: nothing is awaiting it, so without
      // this it would vanish silently. Report it against the command we sent.
      final sentCommand = _inFlightCommands.remove(requestId);
      if (sentCommand != null && obj['error'] != 'success') {
        final reason = obj['error']?.toString() ?? 'unknown error';
        _commandErrorController.add('$sentCommand → $reason');
      }

      final completer = _pendingRequests.remove(requestId);
      if (completer == null || completer.isCompleted) continue;
      if (obj['error'] == 'success') {
        completer.complete(obj['data']);
      } else {
        completer.completeError(obj['error']?.toString() ?? 'mpv error');
      }
    }
  }

  /// Renders a command payload (`["set_property", "target-peak", 400]`) as a
  /// short label for the error log: `set_property target-peak = 400`.
  static String _describeCommand(dynamic command) {
    if (command is! List || command.isEmpty) return 'command';
    final verb = command[0].toString();
    if (command.length == 1) return verb;
    final target = command[1].toString();
    if (command.length == 2) return '$verb $target';
    final value = command.sublist(2).map((e) => e.toString()).join(' ');
    final label = '$verb $target = $value';
    return label.length > 120 ? '${label.substring(0, 117)}…' : label;
  }

  /// Queries a single MPV property (e.g. `dwidth`, `video-params`) and
  /// returns its decoded value, or null if MPV errored, the request timed
  /// out, or nothing is connected.
  Future<dynamic> getProperty(String property,
      {Duration timeout = const Duration(seconds: 2)}) async {
    if (_connection == null || _state != IpcConnectionState.connected) {
      return null;
    }
    final id = ++_requestIdCounter;
    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;

    final sent = await sendCommand(jsonEncode({
      'command': ['get_property', property],
      'request_id': id,
    }));
    if (!sent) {
      _pendingRequests.remove(id);
      return null;
    }

    try {
      return await completer.future.timeout(timeout);
    } catch (_) {
      return null;
    } finally {
      _pendingRequests.remove(id);
    }
  }

  Future<bool> sendCommand(String jsonCommand) async {
    if (_connection == null || _state != IpcConnectionState.connected) {
      return false;
    }

    // Stamp a request_id on anything that doesn't already carry one (i.e. every
    // fire-and-forget set_property), so mpv's reply can be traced back to it and
    // a rejection reported against the exact property. getProperty supplies its
    // own id and is left alone.
    var payload = jsonCommand;
    try {
      final decoded = jsonDecode(jsonCommand);
      if (decoded is Map<String, dynamic> && decoded['request_id'] == null) {
        final id = ++_requestIdCounter;
        decoded['request_id'] = id;
        if (_inFlightCommands.length >= _kMaxInFlight) {
          _inFlightCommands.remove(_inFlightCommands.keys.first);
        }
        _inFlightCommands[id] = _describeCommand(decoded['command']);
        payload = jsonEncode(decoded);
      }
    } catch (_) {
      // Not JSON we can parse — send it untouched rather than dropping it.
    }

    try {
      if (_connection is WebSocketChannel) {
        (_connection as WebSocketChannel).sink.add(payload);
      } else {
        (_connection as io.Socket).write('$payload\n');
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
    _commandErrorController.close();
  }
}
