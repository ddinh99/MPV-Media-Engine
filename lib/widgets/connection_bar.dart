import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/dsp_provider.dart';
import '../services/mpv_ipc_service.dart';
import 'first_run_setup.dart';

class ConnectionBar extends StatelessWidget {
  const ConnectionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DspProvider>(
      builder: (context, dsp, _) {
        final isConnected = dsp.connectionState == IpcConnectionState.connected;
        final isConnecting =
            dsp.connectionState == IpcConnectionState.connecting;
        final isError = dsp.connectionState == IpcConnectionState.error;

        Color statusColor;
        String statusLabel;
        if (isConnected) {
          statusColor = AppTheme.success;
          statusLabel = 'Ready to go';
        } else if (isConnecting) {
          statusColor = AppTheme.warning;
          statusLabel = 'Connecting…';
        } else if (isError) {
          statusColor = AppTheme.error;
          statusLabel = 'Connection Error';
        } else {
          statusColor = AppTheme.textMuted;
          statusLabel = 'Disconnected';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              // ── MPV Executable Path Status ──
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      dsp.hasMpvExe
                          ? Icons.folder_copy_rounded
                          : Icons.folder_off_outlined,
                      size: 16,
                      color: dsp.hasMpvExe
                          ? AppTheme.primary
                          : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'MPV Player',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (dsp.hasMpvExe)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: AppTheme.success
                                            .withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    'LOCATED',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.success,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dsp.hasMpvExe
                                ? dsp.mpvExePath!
                                : 'Not configured — please set path',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              color: dsp.hasMpvExe
                                  ? AppTheme.textSecondary
                                  : AppTheme.error,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Action button to change/locate MPV path
                    IconButton(
                      icon: const Icon(Icons.drive_file_rename_outline,
                          size: 16),
                      tooltip: dsp.hasMpvExe ? 'Change Path' : 'Locate Path',
                      color: AppTheme.primary,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        // Triggers the onboarding setup dialog
                        showFirstRunSetupIfNeeded(context, dsp);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),
              Container(height: 28, width: 1, color: AppTheme.border),
              const SizedBox(width: 24),

              // ── Connection Status (Dot) ──
              Row(
                children: [
                  // Glowing green / yellow / red dot
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                      boxShadow: isConnected
                          ? [
                              BoxShadow(
                                color: statusColor.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: 2),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textMuted, size: 20),
                            tooltip: 'Select Connection Method',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (String path) async {
                              if (path == 'custom') {
                                final customPath = await showDialog<String>(
                                  context: context,
                                  builder: (context) {
                                    final controller = TextEditingController(text: dsp.socketPath);
                                    return AlertDialog(
                                      backgroundColor: AppTheme.surface,
                                      title: Text('Custom Connection Method', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                                      content: TextField(
                                        controller: controller,
                                        style: GoogleFonts.jetBrainsMono(color: AppTheme.textPrimary, fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'e.g., 127.0.0.1:9001 or ws://localhost:9002',
                                          hintStyle: TextStyle(color: AppTheme.textMuted),
                                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primary)),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, controller.text),
                                          child: Text('Save', style: TextStyle(color: AppTheme.primary)),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (customPath != null && customPath.trim().isNotEmpty) {
                                  dsp.setSocketPath(customPath.trim());
                                }
                              } else {
                                dsp.setSocketPath(path);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: '127.0.0.1:9001',
                                child: Text('TCP: 127.0.0.1:9001 (IPv4 TCP)', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12)),
                              ),
                              PopupMenuItem(
                                value: '127.0.0.1:9000',
                                child: Text('TCP: 127.0.0.1:9000 (Port 9000 TCP)', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12)),
                              ),
                              PopupMenuItem(
                                value: 'localhost:9001',
                                child: Text('TCP: localhost:9001 (Localhost TCP)', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12)),
                              ),
                              PopupMenuItem(
                                value: 'ws://127.0.0.1:9002',
                                child: Text('WS: ws://127.0.0.1:9002 (Bridge WebSocket)', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12)),
                              ),
                              PopupMenuItem(
                                value: 'ws://127.0.0.1:9000',
                                child: Text('WS: ws://127.0.0.1:9000 (Port 9000 WS)', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12)),
                              ),
                              PopupMenuItem(
                                value: 'ws://localhost:9002',
                                child: Text('WS: ws://localhost:9002 (Bridge WebSocket)', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 12)),
                              ),
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'custom',
                                child: Text('Custom Connection Path...', style: GoogleFonts.inter(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        kIsWeb
                            ? 'WebSocket Bridge: 9002'
                            : 'Path: ${dsp.socketPath}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  if (isError && dsp.lastError != null) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: dsp.lastError!,
                      child: Icon(Icons.info_outline,
                          size: 14, color: AppTheme.error),
                    ),
                  ],
                  const SizedBox(width: 12),
                  // Connect / Disconnect button
                  if (isConnected)
                    IconButton(
                      icon: const Icon(Icons.link_off_rounded, size: 16),
                      tooltip: 'Disconnect',
                      color: AppTheme.error,
                      visualDensity: VisualDensity.compact,
                      onPressed: dsp.disconnect,
                    )
                  else
                    IconButton(
                      icon: isConnecting
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.textMuted),
                            )
                          : const Icon(Icons.link_rounded, size: 16),
                      tooltip: 'Connect',
                      color: AppTheme.primary,
                      visualDensity: VisualDensity.compact,
                      onPressed: isConnecting ? null : dsp.connect,
                    ),
                ],
              ),

              const SizedBox(width: 24),
              Container(height: 28, width: 1, color: AppTheme.border),
              const SizedBox(width: 24),

              // ── Play / Launch Test Video Button ──
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: dsp.hasMpvExe ? 1.0 : 0.35,
                child: FilledButton.icon(
                  icon: dsp.isPlayingTest
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Play Video'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    textStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: dsp.hasMpvExe && !dsp.isPlayingTest
                      ? () => dsp.playTestVideo()
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
