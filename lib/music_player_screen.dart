import 'dart:async';

import 'package:flutter/material.dart';

import 'models/song.dart';
import 'music_player_controller.dart';
import 'music_player_scope.dart';
import 'widgets/album_art.dart';

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key, this.song});

  /// Kept for compatibility with legacy routes. New chart selections start
  /// playback before opening this screen.
  final Song? song;

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  bool _handledInitialSong = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledInitialSong || widget.song == null) return;
    _handledInitialSong = true;
    final controller = MusicPlayerScope.of(context);
    if (controller.currentSong?.id != widget.song!.id) {
      unawaited(controller.playSong(widget.song!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final song = controller.currentSong;
        return Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.45, -0.6),
                radius: 1.25,
                colors: [
                  Color(0xFF35302C),
                  Color(0xFF151618),
                  Color(0xFF101113),
                ],
                stops: [0, 0.52, 1],
              ),
            ),
            child: SafeArea(
              child: song == null
                  ? const _NoSongState()
                  : LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 36,
                          ),
                          child: Column(
                            children: [
                              _PlayerHeader(
                                onClose: () => Navigator.pop(context),
                                onStop: controller.stop,
                              ),
                              const SizedBox(height: 28),
                              Hero(
                                tag: 'album-${song.id}',
                                child: LayoutBuilder(
                                  builder: (context, artConstraints) =>
                                      AlbumArt(
                                        imageUrl: song.thumbnail,
                                        semanticLabel:
                                            'Bìa album ${song.displayTitle}',
                                        size: artConstraints.maxWidth
                                            .clamp(1, 360)
                                            .toDouble(),
                                        borderRadius: 30,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      song.displayTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 29,
                                        height: 1.08,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.1,
                                      ),
                                    ),
                                  ),
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
                                      size: 30,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  song.artistsNames,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFB8F43D),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 26),
                              _ProgressSection(controller: controller),
                              if (controller.errorMessage != null) ...[
                                const SizedBox(height: 14),
                                _PlaybackError(
                                  message: controller.errorMessage!,
                                ),
                              ],
                              const SizedBox(height: 22),
                              _PlayerControls(controller: controller),
                              const SizedBox(height: 14),
                              TextButton.icon(
                                onPressed: () =>
                                    _showQueue(context, controller),
                                icon: const Icon(Icons.queue_music_rounded),
                                label: Text(
                                  'Hàng đợi · ${controller.queue.length} bài',
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.screen_lock_portrait_rounded,
                                    color: Color(0xFF77787D),
                                    size: 16,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    'Tiếp tục phát khi khóa màn hình',
                                    style: TextStyle(
                                      color: Color(0xFF8E8F94),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  void _showQueue(BuildContext context, MusicPlayerController controller) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => FractionallySizedBox(
          heightFactor: 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Text(
                  'Hàng đợi phát',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: controller.queue.length,
                  itemBuilder: (context, index) {
                    final queuedSong = controller.queue[index];
                    final isCurrent =
                        queuedSong.id == controller.currentSong?.id;
                    return ListTile(
                      leading: isCurrent
                          ? const Icon(
                              Icons.graphic_eq_rounded,
                              color: Color(0xFFB8F43D),
                            )
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
                          ? const Text('Đang phát')
                          : IconButton(
                              tooltip: 'Xóa khỏi hàng đợi',
                              onPressed: () =>
                                  controller.removeFromQueue(queuedSong),
                              icon: const Icon(Icons.close_rounded),
                            ),
                      onTap: isCurrent
                          ? null
                          : () {
                              Navigator.pop(sheetContext);
                              unawaited(controller.playSong(queuedSong));
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({required this.onClose, required this.onStop});

  final VoidCallback onClose;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Quay lại bảng xếp hạng',
          onPressed: onClose,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
        ),
        const Expanded(
          child: Column(
            children: [
              Text(
                'ĐANG PHÁT TỪ',
                style: TextStyle(
                  color: Color(0xFF8E8F94),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: 3),
              Text(
                '#zingChart',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Dừng phát',
          onPressed: onStop,
          icon: const Icon(Icons.stop_rounded),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.controller});

  final MusicPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final durationMs = controller.duration.inMilliseconds;
    final positionMs = controller.position.inMilliseconds.clamp(
      0,
      durationMs > 0 ? durationMs : 0,
    );

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFFF6B4A),
            inactiveTrackColor: const Color(0xFF3C3D41),
            thumbColor: const Color(0xFFF5F0E8),
            overlayColor: const Color(0x33FF6B4A),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            key: const ValueKey('player-progress-slider'),
            min: 0,
            max: durationMs <= 0 ? 1 : durationMs.toDouble(),
            value: durationMs <= 0 ? 0 : positionMs.toDouble(),
            onChanged: durationMs <= 0
                ? null
                : (value) =>
                      controller.seek(Duration(milliseconds: value.round())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(controller.position)),
              Text('-${_formatDuration(_remaining(controller))}'),
            ],
          ),
        ),
      ],
    );
  }

  Duration _remaining(MusicPlayerController controller) {
    final remaining = controller.duration - controller.position;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({required this.controller});

  final MusicPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: controller.shuffleEnabled
              ? 'Tắt phát ngẫu nhiên'
              : 'Phát ngẫu nhiên',
          onPressed: controller.toggleShuffle,
          color: controller.shuffleEnabled ? const Color(0xFFB8F43D) : null,
          icon: const Icon(Icons.shuffle_rounded),
        ),
        IconButton(
          tooltip: 'Bài trước',
          onPressed: controller.canGoPrevious ? controller.previous : null,
          icon: const Icon(Icons.skip_previous_rounded, size: 36),
        ),
        SizedBox.square(
          dimension: 72,
          child: FilledButton(
            key: const ValueKey('primary-play-pause-button'),
            onPressed: controller.isLoading ? null : controller.togglePlayPause,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: const Color(0xFFFF6B4A),
              foregroundColor: const Color(0xFF101113),
              disabledBackgroundColor: const Color(0xFF393A3E),
            ),
            child: controller.isLoading
                ? const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(
                    controller.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    semanticLabel: controller.isPlaying ? 'Tạm dừng' : 'Phát',
                    size: 40,
                  ),
          ),
        ),
        IconButton(
          tooltip: 'Bài tiếp theo',
          onPressed: controller.canGoNext ? controller.next : null,
          icon: const Icon(Icons.skip_next_rounded, size: 36),
        ),
        IconButton(
          tooltip: _repeatTooltip(controller.repeatMode),
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
      ],
    );
  }

  String _repeatTooltip(PlayerRepeatMode mode) => switch (mode) {
    PlayerRepeatMode.off => 'Bật lặp hàng đợi',
    PlayerRepeatMode.all => 'Lặp một bài',
    PlayerRepeatMode.one => 'Tắt lặp',
  };
}

class _PlaybackError extends StatelessWidget {
  const _PlaybackError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0x22FF6B4A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x55FF6B4A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF8A70)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFFC7BA), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSongState extends StatelessWidget {
  const _NoSongState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.queue_music_rounded,
            size: 58,
            color: Color(0xFFB8F43D),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chọn một bài hát từ #zingChart',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại'),
          ),
        ],
      ),
    );
  }
}
