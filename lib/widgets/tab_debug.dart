import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/dsp_provider.dart';
import '../services/mpv_ipc_service.dart';
import '../services/preferences_service.dart';

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
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'App Data',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Clears every saved preference — sessions, presets, mpv.exe path, '
                'theme, and the dismissed-update flag. Use this to test whether a '
                'stale or corrupt preferences file is the cause of a problem. '
                'Restart the app afterwards.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmClearAll(context),
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text('Clear All App Data'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    textStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Clear all app data?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'This permanently deletes all saved preferences: sessions, custom '
          'presets, the saved mpv.exe path, theme choice, and the '
          'dismissed-update flag. You will need to redo first-time setup. '
          'This cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await PreferencesService.clearAll();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All app data cleared. Please restart the app.'),
        duration: Duration(seconds: 6),
      ),
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
