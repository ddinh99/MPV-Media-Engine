// lib/stubs/io_stub.dart
// Stub for dart:io on web — all classes throw or return safe defaults.
// This file is only loaded when dart.library.html is available (i.e., web).
import 'dart:async';

class File {
  File(String path);
  String get path => '';
  Directory get parent => Directory('');
  bool existsSync() => false;
  Future<void> writeAsString(String contents) async {}
}

class Directory {
  final String path;
  Directory(this.path);
  static Directory get systemTemp => Directory('');
  bool existsSync() => false;
  Stream<dynamic> list({bool recursive = false, bool followLinks = true}) =>
      const Stream.empty();
}

class Platform {
  static String get pathSeparator => '/';
  static const bool isWindows = false;
  static Map<String, String> get environment => const {};
}

class Process {
  final int pid;
  final Stream<List<int>> stdout;
  final Stream<List<int>> stderr;

  Process(this.pid)
      : stdout = const Stream.empty(),
        stderr = const Stream.empty();

  static Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    dynamic mode,
  }) async {
    return Process(0);
  }

  static Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) async {
    return ProcessResult(0, exitCode: 1);
  }
}

class ProcessResult {
  final int pid;
  final int exitCode;
  final dynamic stdout;
  final dynamic stderr;
  ProcessResult(
    this.pid, {
    this.exitCode = 0,
    this.stdout = '',
    this.stderr = '',
  });
}

class ProcessStartMode {
  static const ProcessStartMode detached = ProcessStartMode._();
  static const ProcessStartMode normal = ProcessStartMode._();
  const ProcessStartMode._();
}

class Socket {
  static Future<Socket> connect(dynamic host, int port, {dynamic sourceAddress, int sourcePort = 0, Duration? timeout}) async {
    throw UnsupportedError('Socket not supported on web');
  }
  StreamSubscription<List<int>> listen(void onData(List<int> event)?, {Function? onError, void onDone()?, bool? cancelOnError}) {
    throw UnsupportedError('Socket not supported on web');
  }
  void write(Object? obj) {}
  Future<void> flush() async {}
  Future<void> close() async {}
}

class InternetAddress {
  InternetAddress(String address, {InternetAddressType? type});
}

class InternetAddressType {
  static const InternetAddressType unix = InternetAddressType._();
  const InternetAddressType._();
}
