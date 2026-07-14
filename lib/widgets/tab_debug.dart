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

        // A ListView, not a Column: the sections below the button grid are
        // fixed-height, so on a short window a Column overflows (yellow/black
        // stripes) no matter how the grid flexes. Scrolling the whole tab is
        // the only layout that survives any window height.
        return ListView(
          padding: const EdgeInsets.all(24.0),
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
              GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 2.5,
                  // The outer ListView owns scrolling; the grid just lays out
                  // its 9 fixed buttons at natural height.
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                    // Deliberately bogus property. mpv answers "property not
                    // found", which should appear in the Rejected panel below —
                    // a live self-test that rejections are still being caught.
                    // If this button does nothing visible, error surfacing is
                    // broken and a real typo'd property would go silent again.
                    _DebugButton(
                      label: 'Test Error Surfacing',
                      icon: Icons.bug_report,
                      enabled: isConnected,
                      command: const {
                        "command": ["set_property", "not-a-real-property", true]
                      },
                      dsp: dsp,
                    ),
                  ],
              ),
              if (dsp.commandErrors.isNotEmpty) ...[
                const SizedBox(height: 8),
                _RejectedCommands(dsp: dsp),
              ],
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

/// Commands mpv answered with an error. Only rendered when there is at least
/// one — a silent panel would just be noise, and the whole point is that these
/// used to be invisible: a rejected set_property is ignored, so a wrong
/// property name (the old `hdr-output`) looked like a dead control rather than
/// a failure.
class _RejectedCommands extends StatelessWidget {
  final DspProvider dsp;

  const _RejectedCommands({required this.dsp});

  @override
  Widget build(BuildContext context) {
    final errors = dsp.commandErrors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorLight.withOpacity(0.35),
        border: Border.all(color: AppTheme.error.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: AppTheme.error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Rejected by mpv (${errors.length})',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: dsp.clearCommandErrors,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.error),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'mpv refused these commands, so they had no effect. A bad property '
            'name or an invalid value will show up here.',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 96),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in errors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: SelectableText(
                        e,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
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
