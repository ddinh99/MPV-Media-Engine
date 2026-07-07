import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  final url = 'ws://127.0.0.1:9002';
  print('Connecting to $url...');
  try {
    final uri = Uri.parse(url);
    final channel = IOWebSocketChannel.connect(uri);
    await channel.ready;
    print('✓ Connected successfully!');
    
    // Listen for responses
    channel.stream.listen((message) {
      print('Received from server: $message');
    }, onError: (e) {
      print('Stream error: $e');
    }, onDone: () {
      print('Connection closed.');
    });

    // Send a test command to mute MPV
    final muteCmd = '{"command": ["set_property", "mute", true]}';
    print('Sending command to mute MPV: $muteCmd');
    channel.sink.add(muteCmd);

    await Future.delayed(Duration(seconds: 2));

    // Send a test command to unmute MPV
    final unmuteCmd = '{"command": ["set_property", "mute", false]}';
    print('Sending command to unmute MPV: $unmuteCmd');
    channel.sink.add(unmuteCmd);

    await Future.delayed(Duration(seconds: 1));
    await channel.sink.close();
    print('Done.');
  } catch (e) {
    print('✗ Connection failed: $e');
  }
}
