import 'dart:async';

import 'package:flutter/material.dart';

import '../music_player_controller.dart';
import '../music_player_scope.dart';
import '../music_player_screen.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

enum DesktopDockSongAction { detail, radio, playlist, share }

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    this.desktop = false,
    this.onOpenQueue,
    this.onOpenLyrics,
    this.onOpenMv,
    this.onSongAction,
    this.mvLoading = false,
  });

  final bool desktop;
  final VoidCallback? onOpenQueue;
  final VoidCallback? onOpenLyrics;
  final VoidCallback? onOpenMv;
  final ValueChanged<DesktopDockSongAction>? onSongAction;
  final bool mvLoading;

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerScope.read(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final song = controller.currentSong;
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: song == null
              ? const SizedBox.shrink()
              : desktop
              ? _DesktopPlaybackDock(
                  controller: controller,
                  onOpenQueue: onOpenQueue,
                  onOpenLyrics: onOpenLyrics,
                  onOpenMv: onOpenMv,
                  onSongAction: onSongAction,
                  mvLoading: mvLoading,
                )
              : _CompactMiniPlayer(controller: controller),
        );
      },
    );
  }
}

class _CompactMiniPlayer extends StatelessWidget {
  const _CompactMiniPlayer({required this.controller});

  final MusicPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final song = controller.currentSong!;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Material(
        key: const ValueKey('mobile-mini-player'),
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('mobile-mini-open-player'),
          onTap: () => _openNowPlaying(context),
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 76,
            child: Column(
              children: [
                _PlaybackProgressLine(controller: controller),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 6, 4, 7),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'album-${song.id}',
                          child: AlbumArt(
                            imageUrl: song.thumbnail,
                            semanticLabel: 'Bìa album ${song.displayTitle}',
                            size: 52,
                            borderRadius: controller.isLiveRadio ? 999 : 11,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _playbackSubtitle(controller),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _PlayPauseButton(
                          key: const ValueKey('mobile-mini-play-pause'),
                          controller: controller,
                          compact: true,
                        ),
                        IconButton(
                          key: const ValueKey('mobile-mini-next'),
                          tooltip: 'Bài tiếp theo',
                          onPressed: controller.canGoNext
                              ? controller.next
                              : null,
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(44),
                          ),
                          icon: const Icon(Icons.skip_next_rounded, size: 27),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopPlaybackDock extends StatelessWidget {
  const _DesktopPlaybackDock({
    required this.controller,
    this.onOpenQueue,
    this.onOpenLyrics,
    this.onOpenMv,
    this.onSongAction,
    required this.mvLoading,
  });

  final MusicPlayerController controller;
  final VoidCallback? onOpenQueue;
  final VoidCallback? onOpenLyrics;
  final VoidCallback? onOpenMv;
  final ValueChanged<DesktopDockSongAction>? onSongAction;
  final bool mvLoading;

  @override
  Widget build(BuildContext context) {
    final song = controller.currentSong!;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        key: const ValueKey('desktop-playback-dock'),
        color: scheme.surfaceContainer,
        elevation: 20,
        shadowColor: Colors.black.withValues(alpha: 0.42),
        child: Container(
          height: 106,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.48),
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 1080;
              return Row(
                children: [
                  SizedBox(
                    width: compact ? 220 : 324,
                    child: Row(
                      children: [
                        InkWell(
                          key: const ValueKey('desktop-dock-open-player'),
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openNowPlaying(context),
                          child: Row(
                            children: [
                              Hero(
                                tag: 'album-${song.id}',
                                child: AlbumArt(
                                  imageUrl: song.thumbnail,
                                  semanticLabel:
                                      'Bìa album ${song.displayTitle}',
                                  size: 58,
                                  borderRadius: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: compact ? 126 : 154,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.displayTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.25,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _playbackSubtitle(controller),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!compact && !controller.isLiveRadio) ...[
                          IconButton(
                            tooltip: controller.isLiked(song)
                                ? 'Bỏ yêu thích'
                                : 'Yêu thích',
                            onPressed: () => controller.toggleLike(song),
                            color: controller.isLiked(song)
                                ? ZingColors.coral
                                : null,
                            icon: Icon(
                              controller.isLiked(song)
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                            ),
                          ),
                          PopupMenuButton<DesktopDockSongAction>(
                            key: const ValueKey('desktop-dock-song-more'),
                            tooltip: 'Tùy chọn khác',
                            enabled: onSongAction != null,
                            onSelected: onSongAction,
                            icon: const Icon(Icons.more_horiz_rounded),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: DesktopDockSongAction.detail,
                                child: ListTile(
                                  key: ValueKey(
                                    'desktop-dock-song-action-detail',
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.info_outline_rounded),
                                  title: Text('Thông tin bài hát'),
                                ),
                              ),
                              PopupMenuItem(
                                value: DesktopDockSongAction.radio,
                                child: ListTile(
                                  key: ValueKey(
                                    'desktop-dock-song-action-radio',
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.radio_rounded),
                                  title: Text('Bắt đầu Song Radio'),
                                ),
                              ),
                              PopupMenuItem(
                                value: DesktopDockSongAction.playlist,
                                child: ListTile(
                                  key: ValueKey(
                                    'desktop-dock-song-action-playlist',
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.library_add_rounded),
                                  title: Text('Thêm vào playlist'),
                                ),
                              ),
                              PopupMenuItem(
                                value: DesktopDockSongAction.share,
                                child: ListTile(
                                  key: ValueKey(
                                    'desktop-dock-song-action-share',
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.ios_share_rounded),
                                  title: Text('Chia sẻ liên kết'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Ngẫu nhiên',
                              onPressed: controller.isLiveRadio
                                  ? null
                                  : controller.toggleShuffle,
                              color: controller.shuffleEnabled
                                  ? ZingColors.lime
                                  : null,
                              icon: const Icon(Icons.shuffle_rounded, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Bài trước',
                              onPressed: controller.canGoPrevious
                                  ? controller.previous
                                  : null,
                              icon: const Icon(Icons.skip_previous_rounded),
                            ),
                            _PlayPauseButton(controller: controller),
                            IconButton(
                              tooltip: 'Bài tiếp theo',
                              onPressed: controller.canGoNext
                                  ? controller.next
                                  : null,
                              icon: const Icon(Icons.skip_next_rounded),
                            ),
                            IconButton(
                              tooltip: _repeatTooltip(controller),
                              onPressed: controller.isLiveRadio
                                  ? null
                                  : controller.cycleRepeatMode,
                              color:
                                  controller.repeatMode == PlayerRepeatMode.off
                                  ? null
                                  : ZingColors.lime,
                              icon: Icon(
                                controller.repeatMode == PlayerRepeatMode.one
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 26,
                          child: Row(
                            children: [
                              Text(
                                controller.isLiveRadio
                                    ? 'LIVE'
                                    : _formatDuration(controller.position),
                                style: TextStyle(
                                  color: controller.isLiveRadio
                                      ? ZingColors.coral
                                      : scheme.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 3,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 5,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 12,
                                    ),
                                  ),
                                  child: Semantics(
                                    label: 'Tiến độ phát',
                                    child: Slider(
                                      key: const ValueKey(
                                        'desktop-dock-progress',
                                      ),
                                      value: controller.progress,
                                      onChanged:
                                          controller.isLiveRadio ||
                                              controller.duration ==
                                                  Duration.zero
                                          ? null
                                          : (value) => unawaited(
                                              controller.seek(
                                                Duration(
                                                  milliseconds:
                                                      (controller
                                                                  .duration
                                                                  .inMilliseconds *
                                                              value)
                                                          .round(),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                controller.isLiveRadio
                                    ? 'TRỰC TIẾP'
                                    : _formatDuration(controller.duration),
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: compact ? 216 : 416,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!compact && !controller.isLiveRadio) ...[
                          IconButton(
                            key: const ValueKey('desktop-dock-open-mv'),
                            tooltip: mvLoading
                                ? 'Đang tải MV chính thức'
                                : 'Mở MV chính thức',
                            onPressed: mvLoading ? null : onOpenMv,
                            icon: mvLoading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.video_library_outlined,
                                    size: 20,
                                  ),
                          ),
                          IconButton(
                            key: const ValueKey('desktop-dock-open-lyrics'),
                            tooltip: 'Mở lời bài hát',
                            onPressed: onOpenLyrics,
                            icon: const Icon(Icons.lyrics_rounded, size: 20),
                          ),
                          IconButton(
                            key: const ValueKey('desktop-dock-expand-player'),
                            tooltip: 'Mở Now Playing',
                            onPressed: () => _openNowPlaying(context),
                            icon: const Icon(
                              Icons.open_in_full_rounded,
                              size: 20,
                            ),
                          ),
                        ],
                        IconButton(
                          tooltip: 'Dừng',
                          onPressed: controller.stop,
                          icon: const Icon(Icons.stop_rounded, size: 20),
                        ),
                        IconButton(
                          key: const ValueKey('desktop-dock-mute'),
                          tooltip: controller.isMuted
                              ? 'Bật âm thanh'
                              : 'Tắt âm',
                          onPressed: () => unawaited(controller.toggleMute()),
                          icon: Icon(
                            controller.isMuted
                                ? Icons.volume_off_rounded
                                : controller.volume < 0.5
                                ? Icons.volume_down_rounded
                                : Icons.volume_up_rounded,
                            size: 20,
                          ),
                        ),
                        SizedBox(
                          width: compact ? 72 : 96,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                            ),
                            child: Semantics(
                              label:
                                  'Âm lượng ${(controller.volume * 100).round()} phần trăm',
                              child: Slider(
                                key: const ValueKey('desktop-dock-volume'),
                                value: controller.volume,
                                onChanged: (value) =>
                                    unawaited(controller.setVolume(value)),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('desktop-dock-open-queue'),
                          tooltip: 'Đang phát · ${controller.queue.length} bài',
                          onPressed:
                              onOpenQueue ?? () => _openNowPlaying(context),
                          icon: const Icon(Icons.queue_music_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    super.key,
    required this.controller,
    this.compact = false,
  });

  final MusicPlayerController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    key: compact ? null : const ValueKey('desktop-dock-play-pause'),
    tooltip: controller.isPlaying ? 'Tạm dừng' : 'Phát',
    onPressed: controller.isLoading ? null : controller.togglePlayPause,
    style: IconButton.styleFrom(
      backgroundColor: ZingColors.coral,
      foregroundColor: const Color(0xFF101113),
      minimumSize: Size.square(compact ? 44 : 46),
    ),
    icon: controller.isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Icon(
            controller.isPlaying
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            size: compact ? 30 : 31,
          ),
  );
}

class _PlaybackProgressLine extends StatelessWidget {
  const _PlaybackProgressLine({required this.controller});

  final MusicPlayerController controller;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    key: const ValueKey('mobile-mini-progress'),
    value: controller.isLiveRadio
        ? null
        : controller.duration == Duration.zero
        ? 0
        : controller.progress,
    minHeight: 3,
    color: ZingColors.coral,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
  );
}

void _openNowPlaying(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const MusicPlayerScreen()));
}

String _playbackSubtitle(MusicPlayerController controller) {
  final song = controller.currentSong!;
  if (controller.isLoading) return 'Đang chuẩn bị nguồn phát…';
  if (controller.isLiveRadio) return 'LIVE · ${song.artistsNames}';
  return song.artistsNames;
}

String _repeatTooltip(MusicPlayerController controller) =>
    switch (controller.repeatMode) {
      PlayerRepeatMode.off => 'Bật lặp hàng đợi',
      PlayerRepeatMode.all => 'Lặp một bài',
      PlayerRepeatMode.one => 'Tắt lặp',
    };

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
