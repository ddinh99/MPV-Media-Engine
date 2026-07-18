// lib/widgets/tab_video_hdr.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../providers/video_provider.dart';
import 'video_controls_common.dart';

/// Shown when HDR passthrough is on but Windows HDR isn't — mpv accepts the
/// PQ output without error, so without this the picture just silently looks
/// flat/oversaturated with nothing pointing at why.
Widget _hdrOutputWarningCard(VideoProvider video) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.warning.withOpacity(0.07),
      border: Border.all(color: AppTheme.warning.withOpacity(0.35)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.hdr_off_rounded, size: 18, color: AppTheme.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Windows HDR is off',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(height: 5),
              SelectableText(
                video.hdrOutputWarning!,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
          tooltip: 'Dismiss',
          onPressed: video.dismissHdrOutputWarning,
        ),
      ],
    ),
  );
}

class TabVideoHdr extends StatelessWidget {
  const TabVideoHdr({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, video, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              videoSectionTitle('HDR / Tone Mapping', Icons.hdr_on),
              const SizedBox(height: 12),
              if (video.hdrOutputWarning != null) ...[
                _hdrOutputWarningCard(video),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildToneMapping(context, video)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildTargetHinting(context, video)),
                ],
              ),
              if (video.state.targetColorspaceHint) ...[
                const SizedBox(height: 16),
                _buildColorspaceHintMode(context, video),
              ],
            ],
          ),
        );
      },
    );
  }

  // Its own card, outside both the Tone Mapping and SDR to HDR Remap
  // (Target Hinting) cards on purpose: target-colorspace-hint-mode applies
  // whenever target-colorspace-hint is on, whether that came from the
  // manual Target Hinting switch (SDR path) or from HDR Output (HDR
  // passthrough path) — nesting it inside the "SDR to HDR Remap" card
  // made it read as SDR-only, when it isn't.
  Widget _buildColorspaceHintMode(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: videoCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dynamic Metadata Hint (experimental)',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                ),
              ),
              Switch(
                value: video.state.targetColorspaceHintMode == 'source-dynamic',
                onChanged: (v) => video.setTargetColorspaceHintMode(v),
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Applies whenever the colorspace hint is on above — during HDR '
            'passthrough (HDR Output) or the SDR-to-HDR remap panel below. '
            'Off sends your configured Target Primaries/Gamut/TRC as the '
            'hint (mpv default). On forwards the source\'s own per-scene '
            'HDR metadata instead — closer to true passthrough for content '
            'with dynamic metadata, but mpv flags it experimental and it '
            'depends on the display reacting to changing metadata '
            '(--vo=gpu-next only).',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildToneMapping(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: videoCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Algorithm:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: video.state.toneMappingAlgorithm,
                dropdownColor: AppTheme.surface,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
                underline: Container(height: 1, color: AppTheme.border),
                onChanged: (String? newValue) {
                  if (newValue != null) video.setToneMappingAlgorithm(newValue);
                },
                items: <String>['auto', 'none', 'spline', 'bt.2446a', 'mobius', 'reinhard', 'hable']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              const Spacer(),
              Text(
                'Visualizer:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: video.state.hdrOutput ? null : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: video.state.visualizeToneMapping,
                onChanged: video.state.hdrOutput ? video.setVisualizeToneMapping : null,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          if (video.isHdrContent == false && !video.state.hdrOutput) ...[
            const SizedBox(height: 8),
            Text(
              'No visible effect on SDR content unless HDR Output is on.',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 16),
          videoDropdownRow(
            label: 'Gamut Mapping',
            value: video.state.gamutMappingMode,
            items: const [
              'auto', 'clip', 'perceptual', 'relative', 'saturation',
              'absolute', 'desaturate', 'darken', 'linear', 'warn',
            ],
            onChanged: (val) {
              if (val != null) video.setGamutMappingMode(val);
            },
          ),
          const SizedBox(height: 4),
          Text(
            'Runs after tone mapping to pull out-of-gamut colors back in '
            'range — verified inert on ordinary BT.709 SDR video, since mpv '
            'only engages this for wide-gamut sources (BT.2020, DCI-P3) or '
            'HDR content.',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'HDR Compute Peak:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(width: 8),
              Switch(
                value: video.state.hdrComputePeak,
                onChanged: video.setHdrComputePeak,
                activeColor: AppTheme.primary,
              ),
              const Spacer(),
              Text('HDR Output:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              Switch(
                value: video.state.hdrOutput,
                onChanged: video.setHdrOutput,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTargetPeakRow(video),
          if (video.state.toneMappingAlgorithm == 'none') ...[
          const SizedBox(height: 8),
          Text(
            'Algorithm is None (clip): the picture passes through untouched, '
            'so Target Peak only trims highlights above it — verified inert '
            'on SDR content. Pick an algorithm for this slider to reshape '
            'brightness.',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
          ),
        ],
        if (video.state.targetColorspaceHint && !video.state.hdrOutput) ...[
            const SizedBox(height: 8),
            Text(
              'Limited effect while Target Hinting is on: output is absolute '
              'PQ, so values above the content\'s own peak change nothing.',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 20),
          _buildHdrReferenceWhiteRow(video),
          const SizedBox(height: 16),
          videoSliderRow(
            label: 'Contrast Recovery',
            value: video.state.contrastRecovery,
            min: 0.0,
            max: 2.0,
            divisions: 40,
            onChanged: video.setContrastRecovery,
          ),
        ],
      ),
    );
  }

  /// The Target Peak slider with a marker at the display's own reported peak
  /// (EDID via DXGI), so users can see when they're pushing past what the
  /// panel can physically do. Marker and caption only appear when the driver
  /// reports a usable value.
  static const double _kPeakMin = 100;
  static const double _kPeakMax = 4000;

  Widget _buildTargetPeakRow(VideoProvider video) {
    final maxNits = video.displayMaxNits;
    final hasMarker =
        maxNits != null && maxNits > _kPeakMin && maxNits < _kPeakMax;
    // 0.0 = auto (mpv derives the peak itself). The slider thumb parks where
    // auto actually resolves: the display's reported peak under HDR Output,
    // SDR reference white otherwise.
    final isAuto = video.state.targetPeak == 0.0;
    final autoResolvesTo = video.state.hdrOutput && maxNits != null
        ? maxNits.clamp(_kPeakMin, _kPeakMax).toDouble()
        : 203.0;
    final sliderValue = isAuto ? autoResolvesTo : video.state.targetPeak;
    final overSpec =
        !isAuto && maxNits != null && video.state.targetPeak > maxNits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 140,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Target Peak (Nits)',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ),
                  ChoiceChip(
                    label: Text(
                      'Auto',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    selected: isAuto,
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surface,
                    side: BorderSide(color: AppTheme.border),
                    // Selecting Auto stores the 0.0 sentinel (mpv gets
                    // 'auto'); deselecting pins the current effective value.
                    onSelected: (sel) =>
                        video.setTargetPeak(sel ? 0.0 : autoResolvesTo),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Material's default track runs from ~24px to width-24px
                  // (thumb/overlay inset); the marker uses the same geometry.
                  const trackInset = 24.0;
                  final trackWidth = constraints.maxWidth - 2 * trackInset;
                  final markerX = hasMarker
                      ? trackInset +
                          trackWidth *
                              ((maxNits - _kPeakMin) / (_kPeakMax - _kPeakMin))
                      : 0.0;
                  return SizedBox(
                    height: 48,
                    child: Stack(
                      children: [
                        Slider(
                          value: sliderValue,
                          min: _kPeakMin,
                          max: _kPeakMax,
                          // 50-nit steps under HDR passthrough: target-peak is
                          // an expansion ceiling there, so a round number is
                          // more useful than precision and 1-nit steps over a
                          // 100-4000 range made it nearly impossible to drag
                          // onto one. On the SDR path the neutral default
                          // (203, SDR reference white) is the one value that
                          // actually matters, and it doesn't sit on a 50-nit
                          // tick — so SDR stays stepless (null) for exact
                          // dragging instead of snapping past it.
                          divisions: video.state.hdrOutput
                              ? ((_kPeakMax - _kPeakMin) / 50).round()
                              : null,
                          activeColor: AppTheme.primary,
                          inactiveColor: AppTheme.primaryLight,
                          onChanged: video.setTargetPeak,
                        ),
                        if (hasMarker)
                          Positioned(
                            left: markerX - 1,
                            top: 15,
                            child: IgnorePointer(
                              child: Container(
                                width: 2,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: AppTheme.warning,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                isAuto ? 'auto' : video.state.targetPeak.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: overSpec ? AppTheme.warning : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        if (maxNits != null) ...[
          const SizedBox(height: 4),
          Text(
            overSpec
                ? 'Above your display\'s reported peak (${maxNits.toStringAsFixed(0)} nits) — the extra range gets clipped or tone-mapped by the display.'
                : isAuto
                    ? 'Auto: mpv derives the peak itself — your display\'s ~${maxNits.toStringAsFixed(0)} nits under HDR Output, SDR reference (203) otherwise.'
                    : 'Your display reports a peak of ~${maxNits.toStringAsFixed(0)} nits (marked on the slider).',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: overSpec ? AppTheme.warning : AppTheme.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  /// mpv's `hdr-reference-white`: the assumed SDR diffuse-white level (nits)
  /// inside an HDR container — a separate concern from Target Peak (which
  /// caps HDR highlights). 0.0 is the auto sentinel (mpv default, ≈203).
  Widget _buildHdrReferenceWhiteRow(VideoProvider video) {
    final isAuto = video.state.hdrReferenceWhite == 0.0;
    const autoResolvesTo = 203.0;
    final sliderValue = isAuto ? autoResolvesTo : video.state.hdrReferenceWhite;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 140,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reference White (Nits)',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ),
                  ChoiceChip(
                    label: Text(
                      'Auto',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                    selected: isAuto,
                    selectedColor: AppTheme.primary,
                    backgroundColor: AppTheme.surface,
                    side: BorderSide(color: AppTheme.border),
                    onSelected: (sel) =>
                        video.setHdrReferenceWhite(sel ? 0.0 : autoResolvesTo),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Slider(
                value: sliderValue,
                min: 50,
                max: 1000,
                divisions: 950,
                activeColor: AppTheme.primary,
                inactiveColor: AppTheme.primaryLight,
                onChanged: video.setHdrReferenceWhite,
              ),
            ),
            SizedBox(
              width: 48,
              child: Text(
                isAuto ? 'auto' : video.state.hdrReferenceWhite.toStringAsFixed(0),
                textAlign: TextAlign.right,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'How bright SDR-graded content (or on-screen text/UI) reads inside '
          'an HDR container — independent of Target Peak, which only caps '
          'HDR highlights.',
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildTargetHinting(BuildContext context, VideoProvider video) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: videoCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SDR to HDR Remap (Target Hinting)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: video.state.hdrOutput ? AppTheme.textMuted : AppTheme.primary,
                  ),
                ),
              ),
              Switch(
                value: video.state.targetColorspaceHint,
                // HDR Output already owns target-colorspace-hint/target-trc as
                // its own forced PQ passthrough shortcut; letting this switch
                // flip hint off independently while hdrOutput stays "on" would
                // leave MPV in a contradictory state (target-trc=pq with
                // hinting disabled). Disable it while HDR Output governs this.
                onChanged: video.state.hdrOutput ? null : video.setTargetColorspaceHint,
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          if (video.state.hdrOutput) ...[
            const SizedBox(height: 8),
            Text(
              'Controlled by HDR Output on the left while it\'s on.',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            ),
          ],
          if (!video.state.targetColorspaceHint) ...[
            const SizedBox(height: 16),
            videoDropdownRow(
              label: 'Target Primaries',
              value: video.state.targetPrim,
              items: const ['auto', 'bt.709', 'bt.2020', 'apple', 'dci-p3', 'display-p3'],
              onChanged: (val) => video.setTargetPrim(val!),
            ),
            const SizedBox(height: 12),
            videoDropdownRow(
              label: 'Target Gamut',
              value: video.state.targetGamut,
              items: const ['auto', 'bt.709', 'dci-p3', 'display-p3', 'bt.2020'],
              onChanged: (val) => video.setTargetGamut(val!),
            ),
            const SizedBox(height: 12),
            videoDropdownRow(
              label: 'Target TRC',
              value: video.state.targetTrc,
              items: const ['auto', 'bt.1886', 'srgb', 'linear', 'gamma2.2', 'gamma2.8', 'pq', 'hlg'],
              onChanged: (val) => video.setTargetTrc(val!),
            ),
          ],
        ],
      ),
    );
  }
}
