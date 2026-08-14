import 'package:flutter/material.dart';

import '../music_player_controller.dart';
import '../music_player_scope.dart';
import 'album_art.dart';

class DesktopNowPlayingPanel extends StatelessWidget {
  const DesktopNowPlayingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final song = controller.currentSong;
        return Container(
          width: 340,
          decoration: const BoxDecoration(
            color: Color(0xFF17181B),
            border: Border(left: BorderSide(color: Color(0xFF303136))),
          ),
          child: song == null
              ? const _DesktopIdleState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
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
                          size: 260,
                          borderRadius: 28,
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
                                  style: const TextStyle(
                                    fontSize: 23,
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
                            dimension: 58,
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
                                      size: 34,
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: controller.repeatMode == PlayerRepeatMode.off
                              ? 'Bật lặp hàng đợi'
                              : 'Đổi chế độ lặp',
                          onPressed: controller.cycleRepeatMode,
                          color: controller.repeatMode == PlayerRepeatMode.off
                              ? null
                              : const Color(0xFFB8F43D),
                          icon: Icon(
                            controller.repeatMode == PlayerRepeatMode.one
                                ? Icons.repeat_one_rounded
                                : Icons.repeat_rounded,
                          ),
                        ),
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
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...controller.queue.asMap().entries.map((entry) {
                        final queuedSong = entry.value;
                        final isCurrent = entry.key == controller.currentIndex;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: isCurrent
                              ? const Icon(
                                  Icons.graphic_eq_rounded,
                                  color: Color(0xFFB8F43D),
                                )
                              : Text('${entry.key + 1}'.padLeft(2, '0')),
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
                                  onPressed: () =>
                                      controller.removeFromQueue(queuedSong),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          onTap: isCurrent
                              ? null
                              : () => controller.playSong(queuedSong),
                        );
                      }),
                    ],
                  ),
                ),
        );
      },
    );
  }
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
  const _DesktopIdleState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.headphones_rounded, size: 58, color: Color(0xFFB8F43D)),
            SizedBox(height: 16),
            Text(
              'Chọn một bài để bắt đầu',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
