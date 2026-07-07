// lib/widgets/preset_selector.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/theme.dart';
import '../models/preset.dart';
import '../providers/dsp_provider.dart';

class PresetSelector extends StatelessWidget {
  const PresetSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DspProvider>(
      builder: (context, dsp, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Text(
                'PRESET',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 16),
              ...builtinPresets.map((preset) {
                final isActive = dsp.activePresetId == preset.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _PresetChip(
                    preset: preset,
                    isActive: isActive,
                    onTap: () => dsp.loadPreset(preset),
                  ),
                );
              }),
              const Spacer(),
              // Favorites Menu
              PopupMenuButton<Map<String, String>>(
                tooltip: 'Favorites',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Favorites',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, size: 16),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: {
                      'name': 'GOOGLE AI tweak rev 4',
                      'filter': '#af-add=lavfi=[dynaudnorm=f=500:g=3.5:p=0.7:m=5,pan=stereo|FL=0.68*FL+0.55*FC+0.30*BL+0.25*SL+0.30*LFE|FR=0.68*FR+0.55*FC+0.30*BR+0.25*SR+0.30*LFE,asplit=2[main][amb],[amb]highpass=f=220,lowpass=f=8500,aecho=0.25:0.40:24:0.35,aphaser=type=t:speed=0.1:decay=0.2,extrastereo=0.32[amb2],[main][amb2]amix=inputs=2:weights=1 0.75:normalize=0,anequalizer=c0 f=40 w=30 g=+2.0 t=1|c1 f=40 w=30 g=+2.0 t=1|c0 f=130 w=50 g=-3.5 t=1|c1 f=130 w=50 g=-3.5 t=1|c0 f=250 w=70 g=+1.5 t=1|c1 f=250 w=70 g=+1.5 t=1|c0 f=1000 w=200 g=+1.8 t=1|c1 f=1000 w=200 g=+1.8 t=1|c0 f=1800 w=300 g=+2.0 t=1|c1 f=1800 w=300 g=+2.0 t=1|c0 f=2800 w=500 g=+3.5 t=1|c1 f=2800 w=500 g=+3.5 t=1|c0 f=3500 w=600 g=+2.0 t=1|c1 f=3500 w=600 g=+2.0 t=1|c0 f=5500 w=300 g=-2.0 t=1|c1 f=5500 w=300 g=-2.0 t=1|c0 f=10000 w=2000 g=+1.5 t=1|c1 f=10000 w=2000 g=+1.5 t=1,highshelf=f=5000:g=1.2:w=2000:t=1,acompressor=threshold=-20dB:ratio=2.5:attack=10:release=180:makeup=2dB,alimiter=limit=-0.5dB]'
                    },
                    child: const Text('⭐ GOOGLE AI tweak rev 4 (Incredible)'),
                  ),
                  PopupMenuItem(
                    value: {
                      'name': 'GOOGLE same as rev 4. fix parse filter size 4 invalid',
                      'filter': '#af-add=lavfi=[dynaudnorm=f=250:g=3.5:p=0.95:m=8:c=1,pan=stereo|FL=0.68*FL+0.55*FC+0.30*BL+0.25*SL+0.30*LFE|FR=0.68*FR+0.55*FC+0.30*BR+0.25*SR+0.30*LFE,asplit=2[main][amb],[amb]highpass=f=220,lowpass=f=8500,aecho=0.25:0.40:24:0.35,aphaser=type=t:speed=0.1:decay=0.2,extrastereo=0.32[amb2],[main][amb2]amix=inputs=2:weights=1 0.75:normalize=0,anequalizer=c0 f=40 w=30 g=+2.0 t=1|c1 f=40 w=30 g=+2.0 t=1|c0 f=130 w=50 g=-3.5 t=1|c1 f=130 w=50 g=-3.5 t=1|c0 f=250 w=70 g=+1.5 t=1|c1 f=250 w=70 g=+1.5 t=1|c0 f=1000 w=200 g=+1.8 t=1|c1 f=1000 w=200 g=+1.8 t=1|c0 f=1800 w=300 g=+2.0 t=1|c1 f=1800 w=300 g=+2.0 t=1|c0 f=2800 w=500 g=+3.5 t=1|c1 f=2800 w=500 g=+3.5 t=1|c0 f=3500 w=600 g=+2.0 t=1|c1 f=3500 w=600 g=+2.0 t=1|c0 f=5500 w=300 g=-2.0 t=1|c1 f=5500 w=300 g=-2.0 t=1|c0 f=10000 w=2000 g=+1.5 t=1|c1 f=10000 w=2000 g=+1.5 t=1,highshelf=f=5000:g=1.2:w=2000:t=1,acompressor=threshold=-20dB:ratio=2.5:attack=10:release=180:makeup=2dB,alimiter=limit=-0.5dB]'
                    },
                    child: const Text('⭐ GOOGLE same as rev 4 (Best)'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: {
                      'name': 'Klipsch ProMedia 2.1 THX',
                      'filter': '#af-add=lavfi=[dynaudnorm=f=400:g=4.0:p=0.8,pan=stereo|FL=0.7*FL+0.5*FC+0.5*BL+0.4*LFE|FR=0.7*FR+0.5*FC+0.5*BR+0.4*LFE,anequalizer=c0 f=60 w=50 g=+4.5 t=1|c1 f=60 w=50 g=+4.5 t=1|c0 f=8000 w=2000 g=+2.5 t=1|c1 f=8000 w=2000 g=+2.5 t=1,acompressor=threshold=-18dB:ratio=3:makeup=2dB]'
                    },
                    child: const Text('🔊 Klipsch ProMedia 2.1 THX'),
                  ),
                  PopupMenuItem(
                    value: {
                      'name': 'Logitech Z906 5.1 Surround',
                      'filter': '#af-add=lavfi=[dynaudnorm=f=300:g=3.5:p=0.9,pan=5.1|FL=FL|FR=FR|FC=FC+0.2*FL+0.2*FR|LFE=LFE+0.2*FC|BL=BL+0.2*SL|BR=BR+0.2*SR,anequalizer=c0 f=80 w=50 g=+3.0 t=1|c1 f=80 w=50 g=+3.0 t=1,acompressor=threshold=-20dB:ratio=2.5:makeup=1.5dB]'
                    },
                    child: const Text('🔊 Logitech Z906 5.1 Surround'),
                  ),
                  PopupMenuItem(
                    value: {
                      'name': 'Standard 7.1 Home Theater',
                      'filter': '#af-add=lavfi=[dynaudnorm=f=500:g=2.5,pan=7.1|FL=FL|FR=FR|FC=FC|LFE=LFE|BL=BL|BR=BR|SL=SL|SR=SR,anequalizer=c0 f=40 w=30 g=+2.0 t=1|c1 f=40 w=30 g=+2.0 t=1,acompressor=threshold=-16dB:ratio=2:makeup=1dB]'
                    },
                    child: const Text('🔊 Standard 7.1 Home Theater'),
                  ),
                  PopupMenuItem(
                    value: {
                      'name': 'Bose Companion 20 (Stereo)',
                      'filter': '#af-add=lavfi=[dynaudnorm=f=450:g=3.0,pan=stereo|FL=0.8*FL+0.5*FC+0.3*LFE|FR=0.8*FR+0.5*FC+0.3*LFE,extrastereo=0.15,anequalizer=c0 f=80 w=60 g=+2.0 t=1|c1 f=80 w=60 g=+2.0 t=1|c0 f=250 w=100 g=-1.5 t=1|c1 f=250 w=100 g=-1.5 t=1,acompressor=threshold=-20dB:ratio=2.2:makeup=1.5dB]'
                    },
                    child: const Text('🔊 Bose Companion 20 (Stereo)'),
                  ),
                  PopupMenuItem(
                    value: {
                      'name': 'Razer Leviathan Soundbar',
                      'filter': '#af-add=lavfi=[dynaudnorm=f=250:g=3.5:p=0.85,pan=stereo|FL=0.6*FL+0.4*FC+0.5*BL+0.3*LFE|FR=0.6*FR+0.4*FC+0.5*BR+0.3*LFE,extrastereo=0.4,anequalizer=c0 f=100 w=80 g=+2.5 t=1|c1 f=100 w=80 g=+2.5 t=1|c0 f=4000 w=1000 g=+1.5 t=1|c1 f=4000 w=1000 g=+1.5 t=1,acompressor=threshold=-22dB:ratio=4:makeup=3dB]'
                    },
                    child: const Text('🔊 Razer Leviathan Soundbar'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: {
                      'name': 'Apple AirPods Pro',
                      'filter': '#af-add=lavfi=[dynaudnorm=f=400:g=3.0,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=60 w=50 g=+2.0 t=1|c1 f=60 w=50 g=+2.0 t=1|c0 f=3000 w=500 g=+1.5 t=1|c1 f=3000 w=500 g=+1.5 t=1,acompressor=threshold=-22dB:ratio=2.5:makeup=1.5dB]'
                    },
                    child: const Text('🎧 Apple AirPods Pro'),
                  ),
                  PopupMenuItem(
                    value: {
                      'name': 'Sony WH-1000XM Series',
                      'filter': '#af-add=lavfi=[dynaudnorm=f=300:g=2.5,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=40 w=30 g=+4.0 t=1|c1 f=40 w=30 g=+4.0 t=1|c0 f=150 w=80 g=-2.0 t=1|c1 f=150 w=80 g=-2.0 t=1,acompressor=threshold=-18dB:ratio=3:makeup=1dB]'
                    },
                    child: const Text('🎧 Sony WH-1000XM Series'),
                  ),
                  PopupMenuItem(
                    value: {
                      'name': 'Sennheiser HD600 Series',
                      'filter': '#af-add=lavfi=[dynaudnorm=f=500:g=2.0,pan=stereo|FL=FL+0.5*FC|FR=FR+0.5*FC,anequalizer=c0 f=30 w=20 g=+4.5 t=1|c1 f=30 w=20 g=+4.5 t=1|c0 f=4000 w=500 g=-1.5 t=1|c1 f=4000 w=500 g=-1.5 t=1,alimiter=limit=-0.5dB]'
                    },
                    child: const Text('🎧 Sennheiser HD600 Series'),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: {
                      'name': 'Late Night Viewing',
                      'filter': '#af-add=lavfi=[dynaudnorm=f=150:g=6.0:p=0.9,pan=stereo|FL=0.5*FL+0.8*FC|FR=0.5*FR+0.8*FC,anequalizer=c0 f=80 w=60 g=-6.0 t=1|c1 f=80 w=60 g=-6.0 t=1|c0 f=2000 w=500 g=+3.0 t=1|c1 f=2000 w=500 g=+3.0 t=1,acompressor=threshold=-28dB:ratio=6.0:attack=2:release=50:makeup=8dB,alimiter=limit=-2dB]'
                    },
                    child: const Text('🌛 Late Night Viewing'),
                  ),
                  PopupMenuItem(
                    value: {
                      'name': 'Anime & Clear Vocals',
                      'filter': '#af-add=lavfi=[dynaudnorm=f=250:g=3.5,pan=stereo|FL=0.6*FL+0.7*FC|FR=0.6*FR+0.7*FC,anequalizer=c0 f=100 w=50 g=-1.5 t=1|c1 f=100 w=50 g=-1.5 t=1|c0 f=1200 w=300 g=+2.5 t=1|c1 f=1200 w=300 g=+2.5 t=1|c0 f=3500 w=800 g=+2.0 t=1|c1 f=3500 w=800 g=+2.0 t=1,acompressor=threshold=-20dB:ratio=3.0:makeup=2.5dB]'
                    },
                    child: const Text('🎤 Anime & Clear Vocals'),
                  ),
                ],
                onSelected: (val) {
                  dsp.applyCustomFilter(val['name']!, val['filter']!);
                },
              ),
              const SizedBox(width: 8),
              // Auto-apply toggle
              Row(
                children: [
                  Text(
                    'Auto-apply',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Switch(
                    value: dsp.autoApply,
                    onChanged: dsp.setAutoApply,
                    activeColor: AppTheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Manual apply button
              FilledButton.icon(
                icon: const Icon(Icons.send, size: 14),
                label: const Text('Apply Now'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: dsp.applyNow,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PresetChip extends StatelessWidget {
  final Preset preset;
  final bool isActive;
  final VoidCallback onTap;

  const _PresetChip({
    required this.preset,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: preset.description,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppTheme.primary : AppTheme.border,
              width: 1.5,
            ),
            boxShadow: isActive
                ? [BoxShadow(color: AppTheme.primary.withOpacity(0.20), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(preset.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                preset.name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
