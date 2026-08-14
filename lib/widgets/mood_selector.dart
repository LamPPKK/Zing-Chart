import 'package:flutter/material.dart';

import '../models/listening_analytics.dart';
import '../models/song.dart';
import '../music_player_controller.dart';

class MoodSelector extends StatelessWidget {
  const MoodSelector({
    super.key,
    required this.controller,
    required this.song,
    this.compact = false,
  });

  final MusicPlayerController controller;
  final Song song;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selected = controller.moodsFor(song);
    return Semantics(
      container: true,
      label: 'Gắn mood cho ${song.displayTitle}',
      child: Wrap(
        alignment: compact ? WrapAlignment.start : WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: MoodTag.values
            .map(
              (mood) => FilterChip(
                key: ValueKey('mood-${mood.name}-${song.id}'),
                selected: selected.contains(mood),
                onSelected: (_) => controller.toggleMood(song, mood),
                avatar: Icon(_icon(mood), size: compact ? 16 : 18),
                label: Text(_label(mood)),
                visualDensity: compact
                    ? VisualDensity.compact
                    : VisualDensity.standard,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  static String _label(MoodTag mood) => switch (mood) {
    MoodTag.chill => 'Chill',
    MoodTag.gym => 'Gym',
    MoodTag.focus => 'Tập trung',
  };

  static IconData _icon(MoodTag mood) => switch (mood) {
    MoodTag.chill => Icons.water_rounded,
    MoodTag.gym => Icons.bolt_rounded,
    MoodTag.focus => Icons.center_focus_strong_rounded,
  };
}
