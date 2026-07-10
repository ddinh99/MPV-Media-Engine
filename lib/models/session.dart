// lib/models/session.dart
import 'dsp_state.dart';
import 'video_state.dart';

/// The user's last-used audio DSP configuration.
///
/// Persisted on every change and restored at launch, so whatever the user was
/// last listening with becomes the default for every future video. This is
/// distinct from a [Preset]: a preset is a named thing the user picked, while
/// a session is just "wherever the sliders happened to be left".
class DspSession {
  final DspState state;

  /// Which preset chip to light up. Null once the user hand-edits a slider.
  final String? activePresetId;

  /// A raw filter string from Favorites / Import, which overrides [state]
  /// when set. Must be persisted alongside the state — restoring the state
  /// without it would silently drop the filter the user actually hears.
  final String? customFilter;

  final bool autoApply;

  const DspSession({
    required this.state,
    this.activePresetId,
    this.customFilter,
    this.autoApply = true,
  });

  Map<String, dynamic> toJson() => {
    'state': state.toJson(),
    'activePresetId': activePresetId,
    'customFilter': customFilter,
    'autoApply': autoApply,
  };

  factory DspSession.fromJson(Map<String, dynamic> json) => DspSession(
    state: DspState.fromJson(json['state'] as Map<String, dynamic>),
    activePresetId: json['activePresetId'] as String?,
    customFilter: json['customFilter'] as String?,
    autoApply: json['autoApply'] as bool? ?? true,
  );
}

/// The user's last-used video configuration. See [DspSession].
class VideoSession {
  final VideoState state;
  final String? activePresetId;

  const VideoSession({required this.state, this.activePresetId});

  Map<String, dynamic> toJson() => {
    'state': state.toJson(),
    'activePresetId': activePresetId,
  };

  factory VideoSession.fromJson(Map<String, dynamic> json) => VideoSession(
    state: VideoState.fromJson(json['state'] as Map<String, dynamic>),
    activePresetId: json['activePresetId'] as String?,
  );
}
