// lib/widgets/first_run_setup.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';
import '../providers/dsp_provider.dart';
import '../services/mpv_locator.dart';

/// Shows the first-run setup dialog if the provider says it's needed.
void showFirstRunSetupIfNeeded(BuildContext context, DspProvider dsp, {bool force = false}) {
  if (!force && !dsp.needsFirstTimeSetup) return;
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
  late final TextEditingController _pathCtrl;

  /// Auto-detection state. [_scanning] is true only for the fraction of a
  /// second MpvLocator takes; [_autoDetected] is the path it found, and null
  /// once the scan is done means "couldn't find it" — never "you don't have it".
  bool _scanning = !kIsWeb;
  String? _autoDetected;

  DspProvider get dsp => widget.dsp;

  @override
  void initState() {
    super.initState();
    _pathCtrl = TextEditingController();
    _scanForMpv();
  }

  @override
  void dispose() {
    _pathCtrl.dispose();
    super.dispose();
  }

  /// Look for an mpv the user already has, so the common case is a single
  /// confirming click. Hard-capped inside MpvLocator, so this can't hang the
  /// dialog.
  Future<void> _scanForMpv() async {
    if (kIsWeb) return;
    final found = await MpvLocator.locate();
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _autoDetected = found;
    });
    if (found != null) _updatePath(found, updateTextField: true);
  }

  void _updatePath(String path, {bool updateTextField = false}) {
    if (updateTextField) {
      _pathCtrl.text = path;
    }
    setState(() {
      _pickedPath = path.isEmpty ? null : path;
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

  /// Scanning → found → not-found. The not-found copy deliberately says we
  /// couldn't *find* mpv rather than that the user doesn't *have* it: the scan
  /// never walks the disk, so a portable build in an odd folder can slip past
  /// it, and telling such a user to go download mpv would be plainly wrong.
  Widget _detectionBanner() {
    if (_scanning) {
      return _Banner(
        color: AppTheme.textMuted,
        leading: SizedBox(
          width: 15,
          height: 15,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.textMuted,
          ),
        ),
        title: 'Looking for mpv on this PC…',
      );
    }

    if (_autoDetected != null) {
      return _Banner(
        color: AppTheme.success,
        leading: Icon(Icons.check_circle, size: 16, color: AppTheme.success),
        title: 'Found mpv on this PC',
        body: Text(
          _autoDetected!,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
        footnote: 'Not the one you want? Browse for a different mpv.exe below.',
      );
    }

    return _Banner(
      color: AppTheme.warning,
      leading: Icon(Icons.search_off_rounded, size: 16, color: AppTheme.warning),
      title: "Couldn't find mpv automatically",
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'If you already have mpv, use Browse below to point at mpv.exe — '
            'a portable copy in an unusual folder can slip past the search.',
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 15),
            label: const Text("Don't have it? Get mpv"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.warning,
              side: BorderSide(color: AppTheme.warning.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: MpvLocator.openDownloadPage,
          ),
        ],
      ),
      footnote: MpvLocator.downloadUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPath = _pickedPath != null;

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
        // The content stack is ~650px tall at its tallest (path filled in →
        // banner + step 2 both visible); on a window shorter than that a bare
        // Column overflows the bottom. Scroll instead. ClipRRect keeps the
        // scrolling content inside the rounded corners.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
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
                            'MPV Media Engine',
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

                  // Auto-detection result — a found path is pre-filled below, so
                  // the common case is one confirming click.
                  if (!kIsWeb) ...[
                    _detectionBanner(),
                    const SizedBox(height: 10),
                  ],

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
                        borderSide: BorderSide(
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


                  // Step 2 ─ what happens next (shown after path chosen)
                  if (hasPath) ...[
                    const SizedBox(height: 20),
                    _StepRow(
                      number: '2',
                      done: false,
                      upcoming: true,
                      title: 'Click ▶ Play and pick a video',
                      subtitle:
                          'MPV + bridge start automatically. All DSP sliders go live.',
                    ),
                  ],

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          textStyle: GoogleFonts.inter(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
                ],
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Tinted status box used for the three auto-detection states.
class _Banner extends StatelessWidget {
  final Color color;
  final Widget leading;
  final String title;
  final Widget? body;
  final String? footnote;

  const _Banner({
    required this.color,
    required this.leading,
    required this.title,
    this.body,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 16, height: 16, child: Center(child: leading)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 6),
                  body!,
                ],
                if (footnote != null) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    footnote!,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: AppTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final bool done;
  final bool upcoming;
  final String title;
  final String subtitle;

  const _StepRow({
    required this.number,
    required this.done,
    required this.title,
    required this.subtitle,
    this.upcoming = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color circleColor = done
        ? AppTheme.success
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
