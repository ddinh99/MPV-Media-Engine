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

    // Send a test command to change volume to 20
    final volLowCmd = '{"command": ["set_property", "volume", 20]}';
    print('Sending command to set volume to 20: $volLowCmd');
    channel.sink.add(volLowCmd);

    await Future.delayed(Duration(seconds: 2));

    // Send a test command to change volume back to 100
    final volHighCmd = '{"command": ["set_property", "volume", 100]}';
    print('Sending command to set volume to 100: $volHighCmd');
    channel.sink.add(volHighCmd);

    await Future.delayed(Duration(seconds: 1));
    await channel.sink.close();
    print('Done.');
  } catch (e) {
    print('✗ Connection failed: $e');
  }
}
