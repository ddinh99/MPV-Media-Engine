// lib/widgets/filter_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/dsp_provider.dart';
import '../services/mpv_ipc_service.dart';

class FilterPreview extends StatelessWidget {
  const FilterPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DspProvider>(
      builder: (context, dsp, _) {
        final isConnected = dsp.connectionState == IpcConnectionState.connected;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              // Label
              Text(
                'af=',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              // Preview text
              Expanded(
                child: Text(
                  dsp.filterPreview,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: dsp.state.bypass ? AppTheme.textMuted : AppTheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              // Copy button
              Tooltip(
                message: 'Copy af= config line to clipboard',
                child: IconButton.outlined(
                  icon: const Icon(Icons.copy, size: 14),
                  style: IconButton.styleFrom(
                    side: BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(32, 32),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: dsp.exportConfigLine()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied af= line to clipboard'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              // Status dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? AppTheme.success : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
