import 'dart:io';
import 'dart:convert';

void main() async {
  final transcriptPath = r'C:\Users\Dai\.gemini\antigravity-ide\brain\e91c957e-ec23-4d4e-ad19-ce6d23412906\.system_generated\logs\transcript.jsonl';
  final file = File(transcriptPath);
  if (!file.existsSync()) {
    print('Transcript file not found at $transcriptPath');
    return;
  }

  final lines = await file.readAsLines();

  for (int i = 0; i < lines.length; i++) {
    try {
      final obj = jsonDecode(lines[i]);
      final content = obj['content']?.toString() ?? '';
      final toolCalls = obj['tool_calls'] as List?;
      if (toolCalls != null) {
        for (final tc in toolCalls) {
          final args = tc['args'] as Map?;
          if (args != null && args['TargetFile'] != null && args['TargetFile'].toString().contains('dsp_provider.dart')) {
            final instr = args['Instruction']?.toString() ?? '';
            final repl = args['ReplacementContent']?.toString() ?? '';
            if (repl.contains('playTestVideo') || instr.contains('playTestVideo') || instr.contains('bridge')) {
              print('Step $i: $instr');
              print('Repl: \n$repl\n');
            }
          }
        }
      }
    } catch (e) {
      // ignore
    }
  }
}
