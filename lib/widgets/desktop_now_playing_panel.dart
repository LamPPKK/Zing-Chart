import 'dart:async';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../music_player_controller.dart';
import '../music_player_scope.dart';
import 'album_art.dart';
import 'artwork_backdrop.dart';
import 'clear_playback_queue_dialog.dart';
import 'mood_selector.dart';
import 'playback_queue_item_key.dart';
import 'song_detail_panel.dart';
import 'song_lyrics_panel.dart';
import 'song_radio_controls.dart';
import 'smart_shuffle_controls.dart';
import 'up_next_preview.dart';

class DesktopNowPlayingPanel extends StatelessWidget {
  const DesktopNowPlayingPanel({
    super.key,
    this.tvMode = false,
    this.onClose,
    this.lyricsLoader,
    this.songDetailLoader,
    this.songDetailExternalLauncher = launchSongDetailExternalPage,
  });

  final bool tvMode;
  final VoidCallback? onClose;
  final SongLyricsLoader? lyricsLoader;
  final SongDetailLoader? songDetailLoader;
  final SongDetailExternalLauncher songDetailExternalLauncher;

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerScope.read(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final song = controller.currentSong;
        final scheme = Theme.of(context).colorScheme;
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          width: tvMode ? 420 : 340,
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(left: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ArtworkBackdrop(
                    key: const ValueKey('desktop-artwork-atmosphere'),
                    imageUrl: song?.thumbnail ?? '',
                    opacity: dark ? 0.2 : 0.12,
                    blurSigma: 36,
                    cacheWidth: 112,
                  ),
                ),
                if ((song?.thumbnail ?? '').isNotEmpty)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: dark
                              ? const [
                                  Color(0x66101113),
                                  Color(0xE6101113),
                                  Color(0xFF101113),
                                ]
                              : const [
                                  Color(0x8CFFF8F2),
                                  Color(0xEBF8F1E7),
                                  Color(0xFFF5F0E8),
                                ],
                        ),
                      ),
                    ),
                  ),
                song == null
                    ? _DesktopIdleState(tvMode: tvMode, onClose: onClose)
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          tvMode ? 34 : 26,
                          tvMode ? 36 : 30,
                          tvMode ? 34 : 26,
                          tvMode ? 30 : 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'ĐANG PHÁT TỪ',
                                        style: TextStyle(
                                          color: Color(0xFFB8F43D),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        controller.playbackOrigin.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: tvMode ? 16 : 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (onClose != null)
                                  IconButton(
                                    key: const ValueKey(
                                      'desktop-close-player-panel',
                                    ),
                                    tooltip: 'Đóng Đang phát',
                                    onPressed: onClose,
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Center(
                              child: AlbumArt(
                                imageUrl: song.thumbnail,
                                semanticLabel: 'Bìa album ${song.displayTitle}',
                                size: tvMode ? 320 : 260,
                                borderRadius: controller.isLiveRadio
                                    ? 999
                                    : tvMode
                                    ? 34
                                    : 28,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.displayTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: tvMode ? 28 : 23,
                                          height: 1.05,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        song.artistsNames,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFFB8F43D),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (controller.isLiveRadio)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF6B4A),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: const Text(
                                      'LIVE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  )
                                else
                                  IconButton(
                                    tooltip: controller.isLiked(song)
                                        ? 'Bỏ yêu thích'
                                        : 'Yêu thích',
                                    onPressed: () =>
                                        controller.toggleLike(song),
                                    icon: Icon(
                                      controller.isLiked(song)
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      color: controller.isLiked(song)
                                          ? const Color(0xFFFF6B4A)
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (!controller.isLiveRadio) ...[
                              MoodSelector(
                                controller: controller,
                                song: song,
                                compact: true,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _DesktopProgress(controller: controller),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  tooltip: 'Ngẫu nhiên',
                                  onPressed: controller.isLiveRadio
                                      ? null
                                      : controller.toggleShuffle,
                                  color: controller.shuffleEnabled
                                      ? const Color(0xFFB8F43D)
                                      : null,
                                  icon: const Icon(Icons.shuffle_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Bài trước',
                                  onPressed: controller.canGoPrevious
                                      ? controller.previous
                                      : null,
                                  icon: const Icon(Icons.skip_previous_rounded),
                                ),
                                SizedBox.square(
                                  dimension: tvMode ? 72 : 58,
                                  child: FilledButton(
                                    onPressed: controller.isLoading
                                        ? null
                                        : controller.togglePlayPause,
                                    style: FilledButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      shape: const CircleBorder(),
                                      backgroundColor: const Color(0xFFFF6B4A),
                                      foregroundColor: const Color(0xFF101113),
                                    ),
                                    child: controller.isLoading
                                        ? const SizedBox.square(
                                            dimension: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Icon(
                                            controller.isPlaying
                                                ? Icons.pause_rounded
                                                : Icons.play_arrow_rounded,
                                            size: tvMode ? 42 : 34,
                                          ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Bài tiếp theo',
                                  onPressed: controller.canGoNext
                                      ? controller.next
                                      : null,
                                  icon: const Icon(Icons.skip_next_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Dừng',
                                  onPressed: controller.stop,
                                  icon: const Icon(Icons.stop_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _DesktopVolumeControl(controller: controller),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!controller.isLiveRadio) ...[
                                  IconButton(
                                    key: const ValueKey(
                                      'desktop-open-song-detail',
                                    ),
                                    tooltip: 'Thông tin bài hát',
                                    onPressed: () => showSongDetail(
                                      context,
                                      controller: controller,
                                      detailLoader: songDetailLoader,
                                      externalLauncher:
                                          songDetailExternalLauncher,
                                      tvMode: tvMode,
                                    ),
                                    icon: const Icon(
                                      Icons.info_outline_rounded,
                                    ),
                                  ),
                                  IconButton(
                                    key: const ValueKey(
                                      'desktop-start-song-radio',
                                    ),
                                    tooltip: 'Bắt đầu Song Radio',
                                    onPressed:
                                        controller.songRadioAvailable &&
                                            !controller.isRadioLoading
                                        ? () => unawaited(
                                            startSongRadioWithFeedback(
                                              context,
                                              controller,
                                            ),
                                          )
                                        : null,
                                    icon: controller.isRadioLoading
                                        ? const SizedBox.square(
                                            dimension: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.radio_rounded),
                                  ),
                                  IconButton(
                                    key: const ValueKey(
                                      'desktop-open-song-lyrics',
                                    ),
                                    tooltip: 'Lời bài hát',
                                    onPressed: () => showSongLyrics(
                                      context,
                                      controller: controller,
                                      lyricsLoader: lyricsLoader,
                                      tvMode: tvMode,
                                    ),
                                    icon: const Icon(Icons.lyrics_rounded),
                                  ),
                                ],
                                IconButton(
                                  tooltip: controller.hasSleepTimer
                                      ? 'Đổi hẹn giờ tắt'
                                      : 'Hẹn giờ tắt',
                                  onPressed: () =>
                                      _showSleepTimer(context, controller),
                                  color: controller.hasSleepTimer
                                      ? const Color(0xFFFF6B4A)
                                      : null,
                                  icon: Icon(
                                    controller.hasSleepTimer
                                        ? Icons.bedtime_rounded
                                        : Icons.bedtime_outlined,
                                  ),
                                ),
                                if (!controller.isLiveRadio)
                                  IconButton(
                                    tooltip:
                                        controller.repeatMode ==
                                            PlayerRepeatMode.off
                                        ? 'Bật lặp hàng đợi'
                                        : 'Đổi chế độ lặp',
                                    onPressed: controller.cycleRepeatMode,
                                    color:
                                        controller.repeatMode ==
                                            PlayerRepeatMode.off
                                        ? null
                                        : const Color(0xFFB8F43D),
                                    icon: Icon(
                                      controller.repeatMode ==
                                              PlayerRepeatMode.one
                                          ? Icons.repeat_one_rounded
                                          : Icons.repeat_rounded,
                                    ),
                                  ),
                              ],
                            ),
                            if (!controller.isLiveRadio) ...[
                              const SizedBox(height: 26),
                              SongRadioControlCard(
                                controller: controller,
                                compact: true,
                                tvMode: tvMode,
                              ),
                              if (controller.radioErrorMessage != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  controller.radioErrorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B4A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.queue_music_rounded,
                                    color: Color(0xFFFF6B4A),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Hàng đợi · ${controller.queue.length} bài',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (controller.canClearPlaybackQueue)
                                    TextButton(
                                      key: const ValueKey(
                                        'tv-clear-playback-queue',
                                      ),
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
                              const SizedBox(height: 8),
                              if (controller.nextSong != null) ...[
                                UpNextPreview(
                                  controller: controller,
                                  compact: !tvMode,
                                  tvMode: tvMode,
                                ),
                                const SizedBox(height: 10),
                              ],
                              _DesktopQueue(
                                controller: controller,
                                tvMode: tvMode,
                              ),
                            ],
                          ],
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DesktopQueue extends StatelessWidget {
  const _DesktopQueue({required this.controller, required this.tvMode});

  final MusicPlayerController controller;
  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final currentSong = controller.currentSong;
    final upNextSongs = controller.upNextSongs;
    final upNextRevision = controller.upNextRevision;
    return ReorderableListView.builder(
      key: const ValueKey('now-playing-up-next-list'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: !tvMode,
      header: currentSong == null
          ? null
          : _NowPlayingQueueTile(
              key: ValueKey('desktop-current-${currentSong.id}'),
              controller: controller,
              song: currentSong,
              current: true,
              tvMode: tvMode,
            ),
      itemCount: upNextSongs.length,
      onReorderItem: controller.reorderUpNext,
      itemBuilder: (context, index) {
        final queuedSong = upNextSongs[index];
        return _NowPlayingQueueTile(
          key: playbackQueueItemKey('desktop-queue', upNextSongs, index),
          controller: controller,
          song: queuedSong,
          position: index + 1,
          tvMode: tvMode,
          moveUpKey: playbackQueueItemKey(
            'tv-up-next-move-up',
            upNextSongs,
            index,
          ),
          moveDownKey: playbackQueueItemKey(
            'tv-up-next-move-down',
            upNextSongs,
            index,
          ),
          removeKey: playbackQueueItemKey(
            'tv-up-next-remove',
            upNextSongs,
            index,
          ),
          onMoveUp: index > 0
              ? () => controller.reorderUpNext(index, index - 1)
              : null,
          onMoveDown: index + 1 < upNextSongs.length
              ? () => controller.reorderUpNext(index, index + 1)
              : null,
          onRemove: queuedSong.id == currentSong?.id
              ? null
              : () => controller.removeFromQueue(queuedSong),
          onTap: () => unawaited(controller.playUpNext(index, upNextRevision)),
        );
      },
    );
  }
}

class _NowPlayingQueueTile extends StatelessWidget {
  const _NowPlayingQueueTile({
    super.key,
    required this.controller,
    required this.song,
    required this.tvMode,
    this.position,
    this.current = false,
    this.moveUpKey,
    this.moveDownKey,
    this.removeKey,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
    this.onTap,
  });

  final MusicPlayerController controller;
  final Song song;
  final bool tvMode;
  final int? position;
  final bool current;
  final Key? moveUpKey;
  final Key? moveDownKey;
  final Key? removeKey;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: current
        ? const Icon(Icons.graphic_eq_rounded, color: Color(0xFFB8F43D))
        : Text('${position ?? 0}'.padLeft(2, '0')),
    title: Text(
      song.displayTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(song.artistsNames, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (controller.isRadioSong(song)) ...[
          const SizedBox(height: 3),
          const SongRadioBadge(compact: true),
        ],
        if (controller.isSmartShuffleSong(song)) ...[
          const SizedBox(height: 3),
          const SmartShuffleBadge(compact: true),
        ],
      ],
    ),
    trailing: current
        ? const Text('Đang phát')
        : tvMode
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: moveUpKey,
                tooltip: 'Đưa lên trước',
                onPressed: onMoveUp,
                icon: const Icon(Icons.keyboard_arrow_up_rounded),
              ),
              IconButton(
                key: moveDownKey,
                tooltip: 'Đưa xuống sau',
                onPressed: onMoveDown,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              IconButton(
                key: removeKey,
                tooltip: 'Xóa khỏi hàng đợi',
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          )
        : onRemove == null
        ? null
        : IconButton(
            tooltip: 'Xóa khỏi hàng đợi',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
    onTap: onTap,
  );
}

void _showSleepTimer(BuildContext context, MusicPlayerController controller) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
        children: [
          const ListTile(
            title: Text(
              'Hẹn giờ tắt',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          for (final minutes in const [15, 30, 45, 60])
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text('$minutes phút'),
              onTap: () {
                controller.setSleepTimer(Duration(minutes: minutes));
                Navigator.pop(sheetContext);
              },
            ),
          if (!controller.isLiveRadio)
            ListTile(
              leading: const Icon(Icons.skip_next_rounded),
              title: const Text('Sau khi phát xong bài này'),
              onTap: () {
                controller.setSleepAfterCurrentSong();
                Navigator.pop(sheetContext);
              },
            ),
          if (controller.hasSleepTimer)
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: const Text('Hủy hẹn giờ'),
              onTap: () {
                controller.cancelSleepTimer();
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    ),
  );
}

class _DesktopProgress extends StatelessWidget {
  const _DesktopProgress({required this.controller});

  final MusicPlayerController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLiveRadio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LinearProgressIndicator(minHeight: 4, color: Color(0xFFFF6B4A)),
          const SizedBox(height: 8),
          Text(
            controller.isPlaying ? 'Đang phát trực tiếp' : 'LIVE đã tạm dừng',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    final durationMs = controller.duration.inMilliseconds;
    final positionMs = controller.position.inMilliseconds.clamp(
      0,
      durationMs > 0 ? durationMs : 0,
    );
    return Slider(
      min: 0,
      max: durationMs > 0 ? durationMs.toDouble() : 1,
      value: durationMs > 0 ? positionMs.toDouble() : 0,
      onChanged: durationMs > 0
          ? (value) => controller.seek(Duration(milliseconds: value.round()))
          : null,
    );
  }
}

class _DesktopVolumeControl extends StatelessWidget {
  const _DesktopVolumeControl({required this.controller});

  final MusicPlayerController controller;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Âm lượng ${(controller.volume * 100).round()} phần trăm',
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('desktop-player-mute'),
          tooltip: controller.isMuted ? 'Bật âm thanh' : 'Tắt âm',
          onPressed: () => unawaited(controller.toggleMute()),
          icon: Icon(
            controller.isMuted
                ? Icons.volume_off_rounded
                : controller.volume < 0.5
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded,
          ),
        ),
        Expanded(
          child: Slider(
            key: const ValueKey('desktop-player-volume'),
            value: controller.volume,
            onChanged: (value) => unawaited(controller.setVolume(value)),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '${(controller.volume * 100).round()}%',
            textAlign: TextAlign.end,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DesktopIdleState extends StatelessWidget {
  const _DesktopIdleState({required this.tvMode, this.onClose});

  final bool tvMode;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.headphones_rounded,
                  size: tvMode ? 74 : 58,
                  color: const Color(0xFFB8F43D),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chọn một bài để bắt đầu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: tvMode ? 23 : 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onClose != null)
          Positioned(
            top: 14,
            right: 14,
            child: IconButton(
              key: const ValueKey('desktop-close-player-panel'),
              tooltip: 'Đóng Đang phát',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
      ],
    );
  }
}
