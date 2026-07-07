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
}

class Platform {
  static String get pathSeparator => '/';
  static const bool isWindows = false;
}

class Process {
  static Future<ProcessResult> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    dynamic mode,
  }) async {
    return ProcessResult(0);
  }
}

class ProcessResult {
  final int pid;
  ProcessResult(this.pid);
}

class ProcessStartMode {
  static const ProcessStartMode detached = ProcessStartMode._();
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
