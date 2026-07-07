// lib/widgets/first_run_setup.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';
import '../providers/dsp_provider.dart';

// dart:io is only used on non-web targets. Guard every call with kIsWeb.
import 'dart:io' if (dart.library.html) '../stubs/io_stub.dart' as io;

/// Shows the first-run setup dialog if the provider says it's needed.
void showFirstRunSetupIfNeeded(BuildContext context, DspProvider dsp) {
  if (!dsp.needsFirstTimeSetup) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => FirstRunSetupDialog(dsp: dsp),
  );
}

class FirstRunSetupDialog extends StatefulWidget {
  final DspProvider dsp;
  const FirstRunSetupDialog({super.key, required this.dsp});

  @override
  State<FirstRunSetupDialog> createState() => _FirstRunSetupDialogState();
}

class _FirstRunSetupDialogState extends State<FirstRunSetupDialog> {
  bool _picking = false;
  String? _pickedPath;
  String? _bridgeStatus; // null=unchecked, 'found', 'missing'
  late final TextEditingController _pathCtrl;

  DspProvider get dsp => widget.dsp;

  @override
  void initState() {
    super.initState();
    _pathCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  void _updatePath(String path, {bool updateTextField = false}) {
    if (updateTextField) {
      _pathCtrl.text = path;
    }
    // Check for bridge script in the same directory (desktop only)
    String bridgeState = 'missing';
    if (path.isNotEmpty && !kIsWeb) {
      try {
        final dir = io.File(path).parent.path;
        final sep = io.Platform.pathSeparator;
        final bridge = io.File('$dir${sep}mpv_websocket_bridge.py');
        bridgeState = bridge.existsSync() ? 'found' : 'missing';
      } catch (_) {}
    }
    setState(() {
      _pickedPath = path.isEmpty ? null : path;
      _bridgeStatus = path.isEmpty ? null : bridgeState;
    });
  }

  void _onPathChanged(String path) {
    _updatePath(path, updateTextField: false);
  }

  Future<void> _browseMpvExe() async {
    if (kIsWeb) return;
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
        if (path != null && path.isNotEmpty) {
          _updatePath(path, updateTextField: true);
        }
      }
    } catch (_) {
      // File picker not supported — user can type path manually
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _confirm() async {
    final path = _pickedPath ?? _pathCtrl.text.trim();
    if (path.isEmpty) return;
    await dsp.setMpvExePath(path);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasPath = _pickedPath != null;
    final bridgeFound = _bridgeStatus == 'found';
    final bridgeMissing = _bridgeStatus == 'missing';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(40),
      child: Container(
        width: 560,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E40AF), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.graphic_eq,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MVP Sound Engine',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'First-time setup  ·  takes 30 seconds',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.72),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Locate your mpv.exe once, then hit ▶ Play to open any video.\n'
                    'DSP controls (EQ, compression, spatial audio…) apply live.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.88),
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step 1 ─ locate mpv.exe
                  _StepRow(
                    number: '1',
                    done: hasPath,
                    title: 'Locate mpv.exe',
                    subtitle: 'The MPV media player executable.',
                  ),
                  const SizedBox(height: 10),

                  // Path text field (type/paste or use Browse button below)

                  TextField(
                    controller: _pathCtrl,
                    onChanged: (val) => _onPathChanged(val.trim()),
                    style: GoogleFonts.jetBrainsMono(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: kIsWeb
                          ? 'e.g. C:\\Program Files\\MPV\\mpv.exe'
                          : 'Type or paste path, or use Browse →',
                      hintStyle: GoogleFonts.jetBrainsMono(
                          fontSize: 11, color: AppTheme.textMuted),
                      prefixIcon: Icon(
                        _pickedPath != null
                            ? Icons.check_circle
                            : Icons.folder_outlined,
                        size: 16,
                        color: _pickedPath != null
                            ? AppTheme.success
                            : AppTheme.textMuted,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _pickedPath != null
                              ? AppTheme.success
                              : AppTheme.border,
                          width: _pickedPath != null ? 1.5 : 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppTheme.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      filled: true,
                      fillColor: _pickedPath != null
                          ? AppTheme.success.withOpacity(0.05)
                          : AppTheme.surfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (kIsWeb)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.06),
                        border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Running in Web browser: browser security prevents reading local paths via file picker. Please type or paste your local path to mpv.exe manually.\n\n',
                                  ),
                                  TextSpan(
                                    text: 'Don\'t have MPV installed? Download it from: ',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                  ),
                                  const TextSpan(
                                    text: 'https://mpv.io/installation/',
                                  ),
                                ],
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: AppTheme.warning,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Browse button (opens file picker — works on desktop)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: _picking
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.folder_open_rounded, size: 16),
                        label: Text(
                          _picking
                              ? 'Browsing…'
                              : hasPath
                                  ? 'Change mpv.exe'
                                  : 'Browse for mpv.exe',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: hasPath
                              ? AppTheme.textSecondary
                              : AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: GoogleFonts.inter(
                              fontSize: 13, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _picking ? null : _browseMpvExe,
                      ),
                    ),


                  // Step 2 ─ bridge status (shown after path chosen)
                  if (_bridgeStatus != null) ...[
                    const SizedBox(height: 20),
                    _StepRow(
                      number: '2',
                      done: bridgeFound,
                      warning: bridgeMissing,
                      title: 'WebSocket bridge script',
                      subtitle: 'mpv_websocket_bridge.py — must be next to mpv.exe',
                    ),
                    const SizedBox(height: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bridgeFound
                            ? AppTheme.success.withOpacity(0.06)
                            : AppTheme.warning.withOpacity(0.06),
                        border: Border.all(
                          color: bridgeFound
                              ? AppTheme.success
                              : AppTheme.warning,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            bridgeFound
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                            size: 16,
                            color: bridgeFound
                                ? AppTheme.success
                                : AppTheme.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              bridgeFound
                                  ? 'Bridge found ✓  WebSocket mode enabled.'
                                  : 'Bridge script not found.\n'
                                    'Copy mpv_websocket_bridge.py next to mpv.exe to enable WebSocket.\n'
                                    'You can still proceed — the app will connect via TCP directly.',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: bridgeFound
                                    ? AppTheme.success
                                    : AppTheme.warning,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Step 3 ─ what happens next (shown after path chosen)
                  if (hasPath) ...[
                    const SizedBox(height: 20),
                    _StepRow(
                      number: '3',
                      done: false,
                      upcoming: true,
                      title: 'Click ▶ Play and pick a video',
                      subtitle:
                          'MPV + bridge start automatically. All DSP sliders go live.',
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_circle_filled_rounded,
                          size: 20),
                      label: const Text("I'm ready — let's go!"),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            hasPath ? AppTheme.primary : AppTheme.border,
                        foregroundColor:
                            hasPath ? Colors.white : AppTheme.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: hasPath ? _confirm : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  final String number;
  final bool done;
  final bool warning;
  final bool upcoming;
  final String title;
  final String subtitle;

  const _StepRow({
    required this.number,
    required this.done,
    required this.title,
    required this.subtitle,
    this.warning = false,
    this.upcoming = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color circleColor = done
        ? AppTheme.success
        : warning
            ? AppTheme.warning
            : upcoming
                ? AppTheme.textMuted
                : AppTheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: circleColor.withOpacity(0.1),
            border: Border.all(color: circleColor, width: 1.5),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? Icon(Icons.check_rounded, size: 14, color: circleColor)
                : warning
                    ? Icon(Icons.warning_rounded, size: 14, color: circleColor)
                    : Text(
                        number,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: circleColor,
                        ),
                      ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: upcoming
                        ? AppTheme.textMuted
                        : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
