import 'package:flutter/material.dart';

import '../music_player_controller.dart';
import '../music_player_scope.dart';
import 'album_art.dart';
import 'mood_selector.dart';

class DesktopNowPlayingPanel extends StatelessWidget {
  const DesktopNowPlayingPanel({super.key, this.tvMode = false});

  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final song = controller.currentSong;
        final scheme = Theme.of(context).colorScheme;
        return Container(
          width: tvMode ? 420 : 340,
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(left: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Material(
            color: Colors.transparent,
            child: song == null
                ? _DesktopIdleState(tvMode: tvMode)
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
                        const Text(
                          'ĐANG PHÁT',
                          style: TextStyle(
                            color: Color(0xFFB8F43D),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Center(
                          child: AlbumArt(
                            imageUrl: song.thumbnail,
                            semanticLabel: 'Bìa album ${song.displayTitle}',
                            size: tvMode ? 320 : 260,
                            borderRadius: tvMode ? 34 : 28,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                            IconButton(
                              tooltip: controller.isLiked(song)
                                  ? 'Bỏ yêu thích'
                                  : 'Yêu thích',
                              onPressed: () => controller.toggleLike(song),
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
                        MoodSelector(
                          controller: controller,
                          song: song,
                          compact: true,
                        ),
                        const SizedBox(height: 16),
                        _DesktopProgress(controller: controller),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              tooltip: 'Ngẫu nhiên',
                              onPressed: controller.toggleShuffle,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
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
                            IconButton(
                              tooltip:
                                  controller.repeatMode == PlayerRepeatMode.off
                                  ? 'Bật lặp hàng đợi'
                                  : 'Đổi chế độ lặp',
                              onPressed: controller.cycleRepeatMode,
                              color:
                                  controller.repeatMode == PlayerRepeatMode.off
                                  ? null
                                  : const Color(0xFFB8F43D),
                              icon: Icon(
                                controller.repeatMode == PlayerRepeatMode.one
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            const Icon(
                              Icons.queue_music_rounded,
                              color: Color(0xFFFF6B4A),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Hàng đợi · ${controller.queue.length} bài',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _DesktopQueue(controller: controller),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _DesktopQueue extends StatelessWidget {
  const _DesktopQueue({required this.controller});

  final MusicPlayerController controller;

  @override
  Widget build(BuildContext context) => ReorderableListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    buildDefaultDragHandles: true,
    itemCount: controller.queue.length,
    onReorderItem: controller.reorderQueueItem,
    itemBuilder: (context, index) {
      final queuedSong = controller.queue[index];
      final isCurrent = index == controller.currentIndex;
      return ListTile(
        key: ValueKey('desktop-queue-${queuedSong.id}'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: isCurrent
            ? const Icon(Icons.graphic_eq_rounded, color: Color(0xFFB8F43D))
            : Text('${index + 1}'.padLeft(2, '0')),
        title: Text(
          queuedSong.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          queuedSong.artistsNames,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isCurrent
            ? null
            : IconButton(
                tooltip: 'Xóa khỏi hàng đợi',
                onPressed: () => controller.removeFromQueue(queuedSong),
                icon: const Icon(Icons.close_rounded),
              ),
        onTap: isCurrent ? null : () => controller.playSong(queuedSong),
      );
    },
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

class _DesktopIdleState extends StatelessWidget {
  const _DesktopIdleState({required this.tvMode});

  final bool tvMode;

  @override
  Widget build(BuildContext context) {
    return Center(
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
    );
  }
}
