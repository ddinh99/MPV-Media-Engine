// lib/screens/home_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/dsp_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/connection_bar.dart';
import '../widgets/filter_preview.dart';
import '../widgets/first_run_setup.dart';
import '../widgets/preset_selector.dart';
import '../widgets/tab_ambience.dart';
import '../widgets/tab_channels.dart';
import '../widgets/tab_eq.dart';
import '../widgets/tab_loudness.dart';
import '../widgets/tab_safety.dart';
import '../widgets/tab_debug.dart';
import '../widgets/tab_video.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showLog = false;
  bool _setupDialogShown = false;

  final _tabs = const [
    Tab(text: 'Loudness & Dynamics', icon: Icon(Icons.show_chart, size: 14)),
    Tab(text: 'Channels & Stereo', icon: Icon(Icons.surround_sound, size: 14)),
    Tab(text: 'Ambience & Space', icon: Icon(Icons.spatial_audio, size: 14)),
    Tab(text: 'EQ & Tone', icon: Icon(Icons.equalizer, size: 14)),
    Tab(text: 'Safety', icon: Icon(Icons.security, size: 14)),
    Tab(text: 'Video Engine', icon: Icon(Icons.video_settings, size: 14)),
    Tab(text: 'Debug IPC', icon: Icon(Icons.bug_report, size: 14)),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // Listen for the moment prefs finish loading; show setup if needed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dsp = context.read<DspProvider>();

      void tryShowSetup() {
        if (!mounted || _setupDialogShown) return;
        // needsFirstTimeSetup is true only once _prefsLoaded=true AND no path
        if (dsp.needsFirstTimeSetup) {
          _setupDialogShown = true;
          dsp.removeListener(tryShowSetup);
          showFirstRunSetupIfNeeded(context, dsp);
        } else if (dsp.hasMpvExe) {
          // Path already saved — no setup needed
          dsp.removeListener(tryShowSetup);
        }
        // else: prefs still loading, keep listening
      }

      if (dsp.needsFirstTimeSetup) {
        // Prefs loaded synchronously (unlikely but handle it)
        _setupDialogShown = true;
        showFirstRunSetupIfNeeded(context, dsp);
      } else {
        // Wait for prefs to load (async)
        dsp.addListener(tryShowSetup);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Column(
            children: [
              // Title bar / app header
              _AppHeader(onToggleLog: () => setState(() => _showLog = !_showLog), showLog: _showLog),
              // MPV connection bar
              const ConnectionBar(),
              // Preset selector
              const PresetSelector(),
              // Tab bar
              Container(
                color: AppTheme.surface,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  tabs: _tabs,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  indicatorWeight: 2,
                ),
              ),
              const Divider(height: 1),
              // Main content
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [ // Removed const to allow children to rebuild on theme change
                          TabLoudness(),
                          TabChannels(),
                          TabAmbience(),
                          TabEq(),
                          TabSafety(),
                          TabVideo(),
                          TabDebug(),
                        ],
                      ),
                    ),
                    // Log panel
                    if (_showLog) _LogPanel(),
                  ],
                ),
              ),
              // Filter preview bar at bottom
              FilterPreview(), // Removed const
            ],
          ),
        );
      },
    );
  }
}

class _AppHeader extends StatelessWidget {
  final VoidCallback onToggleLog;
  final bool showLog;

  const _AppHeader({required this.onToggleLog, required this.showLog});

  @override
  Widget build(BuildContext context) {
    return Consumer2<DspProvider, ThemeProvider>(
      builder: (context, dsp, themeProvider, _) {
        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              // App icon / logo
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, const Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.graphic_eq, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                'MVP Sound Engine',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DSP Control Surface for MPV',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              // Theme toggle
              IconButton(
                icon: Icon(
                  themeProvider.isDark ? Icons.light_mode : Icons.dark_mode,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () => themeProvider.toggleTheme(),
              ),
              // Settings button
              IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  size: 16,
                  color: dsp.hasMpvExe ? AppTheme.primary : AppTheme.textMuted,
                ),
                tooltip: 'Settings',
                onPressed: () => _showSettings(context, dsp),
              ),
              // Log toggle
              IconButton(
                icon: Icon(
                  Icons.terminal,
                  size: 16,
                  color: showLog ? AppTheme.primary : AppTheme.textMuted,
                ),
                tooltip: 'Command Log',
                onPressed: onToggleLog,
              ),
              // Info
              IconButton(
                icon: Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
                tooltip: 'About',
                onPressed: () => _showAbout(context),
              ),
              // Help
              IconButton(
                icon: Icon(Icons.help_outline, size: 16, color: AppTheme.textMuted),
                tooltip: 'How to use',
                onPressed: () => _showHelp(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'MVP Sound Engine',
      applicationVersion: 'v1.0.0',
      applicationLegalese: '© 2026 Dai Dinh',
      children: [
        const SizedBox(height: 16),
        Text(
          'A professional Digital Signal Processing (DSP) control surface '
          'for MPV, providing real-time manipulation of audio filters, '
          'hardware speaker tuning, and cinematic loudness management.',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        const SizedBox(height: 16),
        Text(
          'Credits & Acknowledgements:\n'
          '• Developed by Dai Dinh\n'
          '• Built with Flutter\n'
          '• Audio Engine: MPV & FFmpeg\n\n'
          'For bug reports and feedback, contact:\n'
          'ddinh99@gmail.com',
          style: GoogleFonts.inter(fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  void _showSettings(BuildContext context, DspProvider dsp) {
    showDialog(
      context: context,
      builder: (ctx) => _SettingsDialog(dsp: dsp),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.graphic_eq, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('How to use MVP Sound Engine', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HelpStep('1', 'Configure MPV Executable:',
                  'Click the Settings (gear) icon in the top right to locate your mpv.exe.'),
              const SizedBox(height: 12),
              _HelpStep('2', 'Play a Video:',
                  'Click the green ▶ Play button in the connection bar and select a video.'),
              const SizedBox(height: 12),
              _HelpStep('3', 'Automatic Connection:', 'The app automatically launches MPV and connects the DSP bridge.'),
              const SizedBox(height: 12),
              _HelpStep('4', 'Tweak Audio Real-Time:', 'Select presets or adjust sliders. Changes apply instantly to MPV.'),
              const SizedBox(height: 12),
              _HelpStep('5', 'Manual Mode (Advanced):', 'If running MPV manually, make sure to run mpv_websocket_bridge.py alongside it and click Connect.'),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                '💡 Tip: Set Windows audio output to 96000 Hz for the highest quality DSP processing.',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  final String number;
  final String title;
  final String code;

  const _HelpStep(this.number, this.title, this.code);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              if (code.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    code,
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LogPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<DspProvider>(
      builder: (context, dsp, _) {
        return Container(
          width: 260,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(left: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Command Log',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: dsp.log.length,
                  itemBuilder: (ctx, i) {
                    final entry = dsp.log[i];
                    final isError = entry.contains('✗');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        entry,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: isError ? AppTheme.error : AppTheme.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsDialog extends StatefulWidget {
  final DspProvider dsp;
  const _SettingsDialog({required this.dsp});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  bool _picking = false;

  Future<void> _browseMpvExe() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Locate mpv.exe',
        type: FileType.custom,
        allowedExtensions: ['exe'],
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null && mounted) {
          await widget.dsp.setMpvExePath(path);
        }
      }
    } catch (e, st) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file picker: $e')),
        );
      }
      debugPrint('File picker error: $e\n$st');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.dsp,
      builder: (context, _) {
        final dsp = widget.dsp;
        final hasPath = dsp.hasMpvExe;

        return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.settings_outlined, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text('Settings', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── MPV Executable ──────────────────────────────────────────────
            Text(
              'MPV Executable',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Required to launch MPV directly and test your DSP settings with a video.',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            // Path display + browse button
            Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      border: Border.all(
                        color: hasPath ? AppTheme.success : AppTheme.border,
                        width: hasPath ? 1.5 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasPath ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                          size: 14,
                          color: hasPath ? AppTheme.success : AppTheme.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasPath ? dsp.mpvExePath! : 'Not configured — click Browse to locate mpv.exe',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: hasPath ? AppTheme.textPrimary : AppTheme.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: _picking
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.folder_open, size: 14),
                  label: Text(_picking ? 'Browsing…' : 'Browse'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _picking ? null : _browseMpvExe,
                ),
                if (hasPath) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Clear mpv.exe path',
                    child: IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      color: AppTheme.error,
                      onPressed: () => dsp.setMpvExePath(null),
                    ),
                  ),
                ],
              ],
            ),
            if (hasPath) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.play_circle_outline, size: 16, color: AppTheme.success),
                        const SizedBox(width: 8),
                        Text(
                          'Play button is now enabled.',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Clicking Play will:\n'
                      '  1. Launch mpv.exe with the video + TCP IPC on your socket path\n'
                      '  2. Start mpv_websocket_bridge.py (must be in the same folder as mpv.exe)\n'
                      '  3. Bridge exposes ws://localhost:9002 for the web app to connect',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],

          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
        );
      },
    );
  }
}
