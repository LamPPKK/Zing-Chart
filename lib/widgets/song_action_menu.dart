import 'package:flutter/material.dart';

import '../models/listening_analytics.dart';
import '../models/song.dart';
import '../theme/app_theme.dart';

enum _SongAction {
  play,
  detail,
  queue,
  radio,
  playlist,
  share,
  toggleLike,
  moodChill,
  moodGym,
  moodFocus,
}

/// The actions exposed by a song row, card or context menu.
///
/// A null callback removes that action. In particular, locked catalog songs
/// omit [onPlay] while retaining safe metadata and library actions.
class SongActionHandlers {
  const SongActionHandlers({
    this.onPlay,
    this.onOpenDetail,
    this.onAddToQueue,
    this.onStartRadio,
    this.onAddToPlaylist,
    this.onShare,
    this.onToggleLike,
    this.onToggleMood,
  });

  final VoidCallback? onPlay;
  final VoidCallback? onOpenDetail;
  final VoidCallback? onAddToQueue;
  final VoidCallback? onStartRadio;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onShare;
  final VoidCallback? onToggleLike;
  final ValueChanged<MoodTag>? onToggleMood;

  bool get hasAny =>
      onPlay != null ||
      onOpenDetail != null ||
      onAddToQueue != null ||
      onStartRadio != null ||
      onAddToPlaylist != null ||
      onShare != null ||
      onToggleLike != null ||
      onToggleMood != null;
}

/// View state paired with [SongActionHandlers] for reusable song cards.
class SongActionMenuConfiguration {
  const SongActionMenuConfiguration({
    required this.handlers,
    this.isLiked = false,
    this.moods = const {},
  });

  final SongActionHandlers handlers;
  final bool isLiked;
  final Set<MoodTag> moods;
}

/// Opens the same menu used by [SongActionOverflowButton] at a pointer
/// position. Desktop rows and cards use this for secondary-click parity.
Future<void> showSongActionContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required String keyPrefix,
  required Song song,
  required SongActionHandlers handlers,
  bool isLiked = false,
  Set<MoodTag> moods = const {},
}) async {
  if (!handlers.hasAny) return;
  final overlay = Overlay.of(context).context.findRenderObject();
  if (overlay is! RenderBox || !overlay.hasSize) return;
  final localPosition = overlay.globalToLocal(globalPosition);
  final left = localPosition.dx.clamp(0.0, overlay.size.width);
  final top = localPosition.dy.clamp(0.0, overlay.size.height);
  final action = await showMenu<_SongAction>(
    context: context,
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    position: RelativeRect.fromLTRB(
      left,
      top,
      overlay.size.width - left,
      overlay.size.height - top,
    ),
    items: _songMenuItems(
      keyPrefix: keyPrefix,
      song: song,
      handlers: handlers,
      isLiked: isLiked,
      moods: moods,
    ),
  );
  if (action == null || !context.mounted) return;
  _handleSongAction(action, handlers);
}

/// A compact overflow button that exposes the canonical song action menu.
class SongActionOverflowButton extends StatelessWidget {
  const SongActionOverflowButton({
    super.key,
    required this.keyPrefix,
    required this.song,
    required this.handlers,
    this.isLiked = false,
    this.moods = const {},
    this.iconSize = 24,
    this.iconColor,
  });

  final String keyPrefix;
  final Song song;
  final SongActionHandlers handlers;
  final bool isLiked;
  final Set<MoodTag> moods;
  final double iconSize;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_SongAction>(
    key: ValueKey('$keyPrefix-menu-${song.id}'),
    padding: EdgeInsets.zero,
    tooltip: 'Tùy chọn bài hát',
    iconSize: iconSize,
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    icon: Icon(Icons.more_horiz_rounded, color: iconColor),
    onSelected: (action) => _handleSongAction(action, handlers),
    itemBuilder: (_) => _songMenuItems(
      keyPrefix: keyPrefix,
      song: song,
      handlers: handlers,
      isLiked: isLiked,
      moods: moods,
    ),
  );
}

List<PopupMenuEntry<_SongAction>> _songMenuItems({
  required String keyPrefix,
  required Song song,
  required SongActionHandlers handlers,
  required bool isLiked,
  required Set<MoodTag> moods,
}) => [
  if (handlers.onPlay != null)
    PopupMenuItem(
      key: ValueKey('$keyPrefix-menu-item-play-${song.id}'),
      value: _SongAction.play,
      child: const _SongMenuLabel(
        icon: Icons.play_arrow_rounded,
        label: 'Phát ngay',
      ),
    ),
  if (handlers.onOpenDetail != null)
    PopupMenuItem(
      key: ValueKey('$keyPrefix-menu-item-detail-${song.id}'),
      value: _SongAction.detail,
      child: const _SongMenuLabel(
        icon: Icons.info_outline_rounded,
        label: 'Thông tin bài hát',
      ),
    ),
  if (handlers.onAddToQueue != null)
    PopupMenuItem(
      key: ValueKey('$keyPrefix-menu-item-queue-${song.id}'),
      value: _SongAction.queue,
      child: const _SongMenuLabel(
        icon: Icons.playlist_add_rounded,
        label: 'Thêm vào hàng đợi',
      ),
    ),
  if (handlers.onStartRadio != null)
    PopupMenuItem(
      key: ValueKey('$keyPrefix-menu-item-radio-${song.id}'),
      value: _SongAction.radio,
      child: const _SongMenuLabel(
        icon: Icons.radio_rounded,
        label: 'Bắt đầu Song Radio',
      ),
    ),
  if (handlers.onAddToPlaylist != null)
    PopupMenuItem(
      key: ValueKey('$keyPrefix-menu-item-playlist-${song.id}'),
      value: _SongAction.playlist,
      child: const _SongMenuLabel(
        icon: Icons.library_add_rounded,
        label: 'Thêm vào playlist',
      ),
    ),
  if (handlers.onShare != null)
    PopupMenuItem(
      key: ValueKey('$keyPrefix-menu-item-share-${song.id}'),
      value: _SongAction.share,
      child: const _SongMenuLabel(
        icon: Icons.ios_share_rounded,
        label: 'Chia sẻ liên kết',
      ),
    ),
  if (handlers.onToggleLike != null)
    PopupMenuItem(
      key: ValueKey('$keyPrefix-menu-item-like-${song.id}'),
      value: _SongAction.toggleLike,
      child: _SongMenuLabel(
        icon: isLiked
            ? Icons.heart_broken_outlined
            : Icons.favorite_border_rounded,
        label: isLiked ? 'Bỏ yêu thích' : 'Yêu thích',
      ),
    ),
  if (handlers.onToggleMood != null)
    for (final mood in MoodTag.values)
      PopupMenuItem(
        key: ValueKey('$keyPrefix-menu-item-mood-${mood.name}-${song.id}'),
        value: _actionForMood(mood),
        child: _SongMenuLabel(
          icon: moods.contains(mood)
              ? Icons.check_circle_rounded
              : _moodIcon(mood),
          iconColor: moods.contains(mood) ? ZingColors.lime : null,
          label:
              '${moods.contains(mood) ? 'Bỏ' : 'Gắn'} mood ${_moodLabel(mood)}',
        ),
      ),
];

void _handleSongAction(_SongAction action, SongActionHandlers handlers) {
  switch (action) {
    case _SongAction.play:
      handlers.onPlay?.call();
    case _SongAction.detail:
      handlers.onOpenDetail?.call();
    case _SongAction.queue:
      handlers.onAddToQueue?.call();
    case _SongAction.radio:
      handlers.onStartRadio?.call();
    case _SongAction.playlist:
      handlers.onAddToPlaylist?.call();
    case _SongAction.share:
      handlers.onShare?.call();
    case _SongAction.toggleLike:
      handlers.onToggleLike?.call();
    case _SongAction.moodChill:
      handlers.onToggleMood?.call(MoodTag.chill);
    case _SongAction.moodGym:
      handlers.onToggleMood?.call(MoodTag.gym);
    case _SongAction.moodFocus:
      handlers.onToggleMood?.call(MoodTag.focus);
  }
}

_SongAction _actionForMood(MoodTag mood) => switch (mood) {
  MoodTag.chill => _SongAction.moodChill,
  MoodTag.gym => _SongAction.moodGym,
  MoodTag.focus => _SongAction.moodFocus,
};

String _moodLabel(MoodTag mood) => switch (mood) {
  MoodTag.chill => 'Chill',
  MoodTag.gym => 'Gym',
  MoodTag.focus => 'Tập trung',
};

IconData _moodIcon(MoodTag mood) => switch (mood) {
  MoodTag.chill => Icons.water_rounded,
  MoodTag.gym => Icons.bolt_rounded,
  MoodTag.focus => Icons.center_focus_strong_rounded,
};

class _SongMenuLabel extends StatelessWidget {
  const _SongMenuLabel({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: iconColor),
    title: Text(label),
  );
}
