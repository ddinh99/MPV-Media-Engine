// lib/widgets/tab_sound.dart
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'filter_preview.dart';
import 'preset_selector.dart';
import 'tab_ambience.dart';
import 'tab_channels.dart';
import 'tab_eq.dart';
import 'tab_loudness.dart';
import 'tab_safety.dart';

/// The whole audio-DSP experience (preset bar, sub-tabs, filter preview),
/// consolidated into a single tab now that Video Engine is the app's main
/// focus — this used to be the top-level layout of the entire app.
class TabSound extends StatelessWidget {
  const TabSound({super.key});

  static const _subTabs = [
    Tab(text: 'Loudness & Dynamics', icon: Icon(Icons.show_chart, size: 14)),
    Tab(text: 'Channels & Stereo', icon: Icon(Icons.surround_sound, size: 14)),
    Tab(text: 'Ambience & Space', icon: Icon(Icons.spatial_audio, size: 14)),
    Tab(text: 'EQ & Tone', icon: Icon(Icons.equalizer, size: 14)),
    Tab(text: 'Safety', icon: Icon(Icons.security, size: 14)),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _subTabs.length,
      child: Column(
        children: [
          const PresetSelector(),
          Container(
            color: AppTheme.surface,
            child: const TabBar(
              isScrollable: false,
              tabs: _subTabs,
              labelPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              indicatorWeight: 2,
            ),
          ),
          const Divider(height: 1),
          const Expanded(
            child: TabBarView(
              children: [
                TabLoudness(),
                TabChannels(),
                TabAmbience(),
                TabEq(),
                TabSafety(),
              ],
            ),
          ),
          const FilterPreview(),
        ],
      ),
    );
  }
}
