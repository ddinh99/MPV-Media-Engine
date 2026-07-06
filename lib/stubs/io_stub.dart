// lib/stubs/io_stub.dart
// Stub for dart:io on web — all classes throw or return safe defaults.
// This file is only loaded when dart.library.html is available (i.e., web).

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
