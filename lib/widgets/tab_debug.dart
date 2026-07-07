import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/dsp_provider.dart';
import '../services/mpv_ipc_service.dart';

class TabDebug extends StatelessWidget {
  const TabDebug({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DspProvider>(
      builder: (context, dsp, _) {
        final isConnected = dsp.connectionState == IpcConnectionState.connected;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IPC Command Debugger',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Test raw IPC commands directly. Ensure MPV is connected first.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 2.5,
                  children: [
                    _DebugButton(
                      label: 'Volume 100%',
                      icon: Icons.volume_up,
                      enabled: isConnected,
                      command: const {"command": ["set_property", "volume", 100]},
                      dsp: dsp,
                    ),
                    _DebugButton(
                      label: 'Volume 50%',
                      icon: Icons.volume_down,
                      enabled: isConnected,
                      command: const {"command": ["set_property", "volume", 50]},
                      dsp: dsp,
                    ),
                    _DebugButton(
                      label: 'Volume 20%',
                      icon: Icons.volume_mute,
                      enabled: isConnected,
                      command: const {"command": ["set_property", "volume", 20]},
                      dsp: dsp,
                    ),
                    _DebugButton(
                      label: 'Mute (True)',
                      icon: Icons.volume_off,
                      enabled: isConnected,
                      command: const {"command": ["set_property", "mute", true]},
                      dsp: dsp,
                    ),
                    _DebugButton(
                      label: 'Mute (False)',
                      icon: Icons.volume_up,
                      enabled: isConnected,
                      command: const {"command": ["set_property", "mute", false]},
                      dsp: dsp,
                    ),
                    _DebugButton(
                      label: 'Pause Video',
                      icon: Icons.pause,
                      enabled: isConnected,
                      command: const {"command": ["set_property", "pause", true]},
                      dsp: dsp,
                    ),
                    _DebugButton(
                      label: 'Play Video',
                      icon: Icons.play_arrow,
                      enabled: isConnected,
                      command: const {"command": ["set_property", "pause", false]},
                      dsp: dsp,
                    ),
                    _DebugButton(
                      label: 'Clear Audio Filters',
                      icon: Icons.clear_all,
                      enabled: isConnected,
                      command: const {"command": ["set_property", "af", ""]},
                      dsp: dsp,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DebugButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final Map<String, dynamic> command;
  final DspProvider dsp;

  const _DebugButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.command,
    required this.dsp,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: enabled ? () => dsp.sendRawCommand(command) : null,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.surfaceVariant,
        foregroundColor: AppTheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: AppTheme.primary.withOpacity(0.1),
          ),
        ),
      ),
    );
  }
}
