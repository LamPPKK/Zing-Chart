import 'package:flutter/material.dart';

import '../music_player_controller.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

/// Compact, read-only view of the navigator's real next item.
///
/// The editable queue keeps its source order while this card reflects shuffle,
/// forward history, Smart Shuffle and Add-to-Queue decisions exactly.
class UpNextPreview extends StatelessWidget {
  const UpNextPreview({
    super.key,
    required this.controller,
    this.compact = false,
    this.tvMode = false,
  });

  final MusicPlayerController controller;
  final bool compact;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final upcomingSongs = controller.upNextSongs;
    final song = upcomingSongs.firstOrNull;
    if (song == null || controller.isLiveRadio) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final accent = Theme.of(context).brightness == Brightness.dark
        ? ZingColors.lime
        : scheme.primary;
    final remaining = upcomingSongs.length;
    final padding = tvMode
        ? const EdgeInsets.all(16)
        : compact
        ? const EdgeInsets.all(10)
        : const EdgeInsets.all(12);
    final artSize = tvMode
        ? 58.0
        : compact
        ? 42.0
        : 48.0;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          'Tiếp theo${controller.shuffleEnabled ? ' trong chế độ trộn bài' : ''}: '
          '${song.displayTitle}, ${song.artistsNames}. Còn $remaining bài.',
      child: Container(
        key: const ValueKey('up-next-preview'),
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primary.withValues(alpha: 0.18),
              ZingColors.coral.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(tvMode ? 18 : 14),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.34)),
        ),
        child: Row(
          children: [
            Container(
              width: tvMode ? 42 : 34,
              height: tvMode ? 42 : 34,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                controller.shuffleEnabled
                    ? Icons.shuffle_rounded
                    : Icons.skip_next_rounded,
                color: accent,
                size: tvMode ? 24 : 20,
              ),
            ),
            SizedBox(width: tvMode ? 14 : 10),
            AlbumArt(
              imageUrl: song.thumbnail,
              semanticLabel: 'Bìa album ${song.displayTitle}',
              size: artSize,
              borderRadius: tvMode ? 12 : 9,
            ),
            SizedBox(width: tvMode ? 14 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.shuffleEnabled
                        ? 'TIẾP THEO · SHUFFLE'
                        : 'TIẾP THEO',
                    style: TextStyle(
                      color: accent,
                      fontSize: tvMode ? 12 : 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.displayTitle,
                    key: ValueKey('up-next-song-${song.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: tvMode ? 16 : 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    song.artistsNames,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: tvMode ? 13 : 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Text(
                '$remaining bài',
                key: const ValueKey('up-next-count'),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: tvMode ? 13 : 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
