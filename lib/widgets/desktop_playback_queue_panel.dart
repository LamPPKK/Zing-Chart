import 'dart:async';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../music_player_controller.dart';
import '../models/playback_origin.dart';
import '../music_player_scope.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';
import 'clear_playback_queue_dialog.dart';
import 'smart_shuffle_controls.dart';
import 'song_lyrics_panel.dart';
import 'song_radio_controls.dart';
import 'up_next_preview.dart';
import '../zing_mp3_api.dart';

enum DesktopPlaybackPanelTab { queue, recent, lyrics }

/// Catalog-friendly desktop drawer for the active queue and local history.
class DesktopPlaybackQueuePanel extends StatefulWidget {
  const DesktopPlaybackQueuePanel({
    super.key,
    required this.onClose,
    this.lyricsLoader,
    this.initialTab = DesktopPlaybackPanelTab.queue,
    this.onTabChanged,
  });

  final VoidCallback onClose;
  final SongLyricsLoader? lyricsLoader;
  final DesktopPlaybackPanelTab initialTab;
  final ValueChanged<DesktopPlaybackPanelTab>? onTabChanged;

  @override
  State<DesktopPlaybackQueuePanel> createState() =>
      _DesktopPlaybackQueuePanelState();
}

class _DesktopPlaybackQueuePanelState extends State<DesktopPlaybackQueuePanel> {
  late DesktopPlaybackPanelTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(covariant DesktopPlaybackQueuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _selectedTab = widget.initialTab;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerScope.read(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('desktop-playback-queue-panel'),
      color: scheme.surface,
      child: Container(
        width: 356,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.68),
            ),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 10, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'TRÌNH PHÁT',
                      style: TextStyle(
                        color: ZingColors.lime,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.45,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('desktop-close-player-panel'),
                    tooltip: 'Đóng danh sách phát',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _QueueTabs(
                selected: _selectedTab,
                onSelected: (tab) {
                  setState(() => _selectedTab = tab);
                  widget.onTabChanged?.call(tab);
                },
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: switch (_selectedTab) {
                    DesktopPlaybackPanelTab.queue => _PlayingQueue(
                      key: const ValueKey('desktop-playing-queue-tab'),
                      controller: controller,
                    ),
                    DesktopPlaybackPanelTab.recent => _RecentQueue(
                      key: const ValueKey('desktop-recent-queue-tab'),
                      controller: controller,
                    ),
                    DesktopPlaybackPanelTab.lyrics =>
                      controller.isLiveRadio
                          ? const _QueueEmptyState(
                              key: ValueKey('desktop-live-lyrics-unavailable'),
                              icon: Icons.sensors_rounded,
                              title: 'LIVE không có lời đồng bộ',
                              message:
                                  'Hãy chọn một bài hát trong catalog để theo dõi lời ngay tại đây.',
                            )
                          : SongLyricsPanel(
                              key: const ValueKey('desktop-lyrics-queue-tab'),
                              controller: controller,
                              lyricsLoader:
                                  widget.lyricsLoader ??
                                  ZingMP3API.getSongLyrics,
                              onClose: widget.onClose,
                              embedded: true,
                              onExpand: () => showSongLyrics(
                                context,
                                controller: controller,
                                lyricsLoader: widget.lyricsLoader,
                              ),
                            ),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueTabs extends StatelessWidget {
  const _QueueTabs({required this.selected, required this.onSelected});

  final DesktopPlaybackPanelTab selected;
  final ValueChanged<DesktopPlaybackPanelTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _QueueTabButton(
              key: const ValueKey('desktop-queue-tab-playing'),
              label: 'Hàng đợi',
              selected: selected == DesktopPlaybackPanelTab.queue,
              onPressed: () => onSelected(DesktopPlaybackPanelTab.queue),
            ),
          ),
          Expanded(
            child: _QueueTabButton(
              key: const ValueKey('desktop-queue-tab-recent'),
              label: 'Gần đây',
              selected: selected == DesktopPlaybackPanelTab.recent,
              onPressed: () => onSelected(DesktopPlaybackPanelTab.recent),
            ),
          ),
          Expanded(
            child: _QueueTabButton(
              key: const ValueKey('desktop-queue-tab-lyrics'),
              label: 'Lời bài hát',
              selected: selected == DesktopPlaybackPanelTab.lyrics,
              onPressed: () => onSelected(DesktopPlaybackPanelTab.lyrics),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueTabButton extends StatelessWidget {
  const _QueueTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: TextButton(
        onPressed: onPressed,
        style:
            TextButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: selected
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant,
              backgroundColor: selected ? scheme.primary : Colors.transparent,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.focused)
                      ? ZingColors.lime
                      : Colors.transparent,
                  width: states.contains(WidgetState.focused) ? 2 : 0,
                ),
              ),
            ),
        child: Text(label),
      ),
    );
  }
}

class _PlayingQueue extends StatelessWidget {
  const _PlayingQueue({super.key, required this.controller});

  final MusicPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final current = controller.currentSong;
    if (current == null) {
      return const _QueueEmptyState(
        icon: Icons.queue_music_rounded,
        title: 'Hàng đợi đang trống',
        message: 'Chọn một bài trong catalog để bắt đầu nghe.',
      );
    }

    if (controller.isLiveRadio) {
      return ListView(
        key: const ValueKey('desktop-playing-queue-list'),
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
        children: [
          const _SectionEyebrow(label: 'ĐANG PHÁT TRỰC TIẾP'),
          const SizedBox(height: 10),
          _QueueSongTile(song: current, index: 0, current: true, live: true),
          const SizedBox(height: 18),
          const _QueueNotice(
            icon: Icons.sensors_rounded,
            title: 'Phòng Nhạc trực tiếp',
            message:
                'Hàng đợi không áp dụng cho luồng LIVE. Bạn vẫn điều khiển phát và âm lượng từ dock bên dưới.',
          ),
        ],
      );
    }

    final queue = controller.queue;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionEyebrow(label: 'TIẾP THEO'),
                    const SizedBox(height: 3),
                    Text(
                      'Từ ${controller.playbackOrigin.label} · ${queue.length} bài',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.canClearPlaybackQueue)
                TextButton(
                  key: const ValueKey('desktop-clear-playback-queue'),
                  onPressed: () => unawaited(
                    showClearPlaybackQueueDialog(
                      context,
                      controller: controller,
                    ),
                  ),
                  child: const Text('XÓA'),
                ),
            ],
          ),
        ),
        if (controller.songRadioAvailable)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: SongRadioControlCard(controller: controller, compact: true),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: SmartShuffleControlCard(controller: controller, compact: true),
        ),
        if (controller.nextSong != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: UpNextPreview(controller: controller, compact: true),
          ),
        Expanded(
          child: ReorderableListView.builder(
            key: const ValueKey('desktop-playing-queue-list'),
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 24),
            buildDefaultDragHandles: true,
            itemCount: queue.length,
            onReorderItem: controller.reorderQueueItem,
            itemBuilder: (context, index) {
              final song = queue[index];
              final isCurrent = song.id == current.id;
              return _QueueSongTile(
                key: ValueKey('desktop-queue-${song.id}'),
                song: song,
                index: index,
                current: isCurrent,
                radio: controller.isRadioSong(song),
                smart: controller.isSmartShuffleSong(song),
                onTap: isCurrent
                    ? null
                    : () => unawaited(controller.playSong(song)),
                onRemove: isCurrent
                    ? null
                    : () => controller.removeFromQueue(song),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentQueue extends StatelessWidget {
  const _RecentQueue({super.key, required this.controller});

  final MusicPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final recent = controller.recentlyPlayed;
    if (recent.isEmpty) {
      return const _QueueEmptyState(
        icon: Icons.history_rounded,
        title: 'Chưa có lịch sử nghe',
        message:
            'Các bài vừa nghe sẽ xuất hiện ở đây và chỉ được lưu trên thiết bị này.',
      );
    }
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: _QueueNotice(
            icon: Icons.lock_outline_rounded,
            title: 'Lịch sử trên thiết bị',
            message: 'Không gửi danh sách này lên proxy hoặc dịch vụ đồng bộ.',
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('desktop-recent-queue-list'),
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 24),
            itemCount: recent.length,
            itemBuilder: (context, index) {
              final song = recent[index];
              return _QueueSongTile(
                key: ValueKey('desktop-recent-${song.id}'),
                song: song,
                index: index,
                current: song.id == controller.currentSong?.id,
                onTap: () => unawaited(
                  controller.playSong(
                    song,
                    queue: recent,
                    origin: const PlaybackOrigin(
                      kind: PlaybackOriginKind.recentlyPlayed,
                      label: 'Nghe gần đây',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QueueSongTile extends StatelessWidget {
  const _QueueSongTile({
    super.key,
    required this.song,
    required this.index,
    required this.current,
    this.live = false,
    this.radio = false,
    this.smart = false,
    this.onTap,
    this.onRemove,
  });

  final Song song;
  final int index;
  final bool current;
  final bool live;
  final bool radio;
  final bool smart;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: current
            ? scheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 4, 7),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: current
                      ? Icon(
                          live
                              ? Icons.sensors_rounded
                              : Icons.graphic_eq_rounded,
                          size: 19,
                          color: live ? ZingColors.coral : ZingColors.lime,
                        )
                      : Text(
                          '${index + 1}'.padLeft(2, '0'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: 7),
                AlbumArt(
                  imageUrl: song.thumbnail,
                  semanticLabel: 'Bìa album ${song.displayTitle}',
                  size: 44,
                  borderRadius: 8,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: current ? ZingColors.lime : null,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              song.artistsNames,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          if (radio) ...[
                            const SizedBox(width: 6),
                            const SongRadioBadge(compact: true),
                          ],
                          if (smart) ...[
                            const SizedBox(width: 6),
                            const SmartShuffleBadge(compact: true),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Xóa khỏi hàng đợi',
                    onPressed: onRemove,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  )
                else
                  const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueNotice extends StatelessWidget {
  const _QueueNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ZingColors.lime),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.25,
    ),
  );
}

class _QueueEmptyState extends StatelessWidget {
  const _QueueEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: ZingColors.lime),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
}
