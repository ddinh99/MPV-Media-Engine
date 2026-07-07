// lib/widgets/filter_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/dsp_provider.dart';
import '../services/mpv_ipc_service.dart';

class FilterPreview extends StatefulWidget {
  const FilterPreview({super.key});

  @override
  State<FilterPreview> createState() => _FilterPreviewState();
}

class _FilterPreviewState extends State<FilterPreview> {
  late TextEditingController _controller;
  String _lastKnownFilter = '';
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DspProvider>(
      builder: (context, dsp, _) {
        final isConnected = dsp.connectionState == IpcConnectionState.connected;
        final currentFilter = dsp.filterPreview;

        // If the DSP state changed externally (e.g., slider moved, preset loaded)
        // and we are NOT actively typing, update the text field.
        if (currentFilter != _lastKnownFilter && !_isEditing) {
          _lastKnownFilter = currentFilter;
          _controller.text = currentFilter;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              // Editable Preview text
              Expanded(
                child: Focus(
                  onFocusChange: (hasFocus) {
                    setState(() => _isEditing = hasFocus);
                  },
                  child: TextField(
                    controller: _controller,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: dsp.state.bypass ? AppTheme.textMuted : AppTheme.primary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (value) {
                      setState(() => _isEditing = false);
                      if (value.trim().isNotEmpty) {
                        dsp.applyCustomFilter('Manual Edit', value);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Apply Button (only visible if editing or text differs)
              if (_isEditing || _controller.text != currentFilter)
                Tooltip(
                  message: 'Apply Manual Edit (Expert Mode)',
                  child: IconButton.filled(
                    icon: const Icon(Icons.check, size: 14),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: AppTheme.surface,
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(32, 32),
                    ),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => _isEditing = false);
                      if (_controller.text.trim().isNotEmpty) {
                        dsp.applyCustomFilter('Manual Edit', _controller.text);
                      }
                    },
                  ),
                ),
              if (!_isEditing && _controller.text == currentFilter) ...[
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
              ],
              const SizedBox(width: 12),
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
