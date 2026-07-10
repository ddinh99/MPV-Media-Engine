import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/theme.dart';
import '../providers/dsp_provider.dart';

/// Maps a decoded (display) height to the label people actually use for it.
/// Ranges rather than exact matches, since sources are rarely an exact
/// 1920x1080 (letterboxing, odd encodes, anamorphic content, etc.).
String _resolutionLabel(num height) {
  if (height >= 4200) return '8K';
  if (height >= 2000) return '4K / UHD';
  if (height >= 1300) return '1440p / QHD';
  if (height >= 900) return '1080p / FHD';
  if (height >= 600) return '720p / HD';
  return 'SD';
}

/// Opens a small dialog showing what MPV reports about the currently
/// playing video (resolution, codec, fps). Fetched live via get_property —
/// see DspProvider.fetchVideoInfo — so it reflects the real MPV process,
/// not the app's own guess at what's loaded.
Future<void> showVideoInfoDialog(BuildContext context, DspProvider dsp) {
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<Map<String, dynamic>>(
            future: dsp.fetchVideoInfo(),
            builder: (context, snapshot) {
              final children = <Widget>[
                Row(
                  children: [
                    Icon(Icons.movie_outlined, size: 18, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Video Information',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ];

              if (snapshot.connectionState != ConnectionState.done) {
                children.add(Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary),
                  ),
                ));
              } else {
                final info = snapshot.data ?? const {};
                if (info.isEmpty) {
                  children.add(Text(
                    'No response from MPV. Is a video currently playing?',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ));
                } else {
                  children.addAll(_buildInfoRows(info));
                }
              }

              children.add(const SizedBox(height: 20));
              children.add(Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close',
                      style: TextStyle(color: AppTheme.primary)),
                ),
              ));

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              );
            },
          ),
        ),
      ),
    ),
  );
}

List<Widget> _buildInfoRows(Map<String, dynamic> info) {
  final rows = <Widget>[];

  final dwidth = info['dwidth'];
  final dheight = info['dheight'];
  if (dwidth is num && dheight is num) {
    rows.add(_InfoRow(
      label: 'Resolution',
      value:
          '${dwidth.toInt()}×${dheight.toInt()} (${_resolutionLabel(dheight)})',
      emphasize: true,
    ));
  }

  final filename = info['filename'];
  if (filename is String) {
    rows.add(_InfoRow(label: 'File', value: filename));
  }

  final codec = info['video-codec'];
  if (codec is String) {
    rows.add(_InfoRow(label: 'Codec', value: codec));
  }

  final fps = info['container-fps'] ?? info['estimated-vf-fps'];
  if (fps is num) {
    rows.add(
        _InfoRow(label: 'Frame rate', value: '${fps.toStringAsFixed(2)} fps'));
  }

  final params = info['video-params'];
  if (params is Map) {
    final aspect = params['aspect'];
    if (aspect is num) {
      rows.add(
          _InfoRow(label: 'Aspect ratio', value: aspect.toStringAsFixed(3)));
    }
    final pixelFormat = params['pixelformat'];
    if (pixelFormat is String) {
      rows.add(_InfoRow(label: 'Pixel format', value: pixelFormat));
    }
    final colormatrix = params['colormatrix'];
    if (colormatrix is String) {
      rows.add(_InfoRow(label: 'Color matrix', value: colormatrix));
    }
    final gamma = params['gamma'];
    if (gamma is String) {
      rows.add(_InfoRow(label: 'Gamma / transfer', value: gamma));
    }
  }

  return rows;
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _InfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: emphasize ? 14 : 12,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                color: emphasize ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
