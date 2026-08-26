import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import 'models/song.dart';
import 'models/local_library.dart';
import 'music_player_controller.dart';
import 'music_player_scope.dart';
import 'widgets/album_art.dart';
import 'widgets/artwork_backdrop.dart';
import 'widgets/clear_playback_queue_dialog.dart';
import 'widgets/mood_selector.dart';
import 'widgets/playback_queue_item_key.dart';
import 'widgets/smart_shuffle_controls.dart';
import 'widgets/song_lyrics_panel.dart';
import 'widgets/song_detail_panel.dart';
import 'widgets/song_radio_controls.dart';
import 'widgets/streaming_quality_controls.dart';
import 'widgets/up_next_preview.dart';

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({
    super.key,
    this.song,
    this.lyricsLoader,
    this.songDetailLoader,
    this.songDetailExternalLauncher = launchSongDetailExternalPage,
  });

  /// Kept for compatibility with legacy routes. New chart selections start
  /// playback before opening this screen.
  final Song? song;
  final SongLyricsLoader? lyricsLoader;
  final SongDetailLoader? songDetailLoader;
  final SongDetailExternalLauncher songDetailExternalLauncher;

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
    final controller = MusicPlayerScope.read(context);
    if (controller.currentSong?.id != widget.song!.id) {
      unawaited(controller.playSong(widget.song!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerScope.read(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final song = controller.currentSong;
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.45, -0.6),
                      radius: 1.25,
                      colors: dark
                          ? const [
                              Color(0xFF35302C),
                              Color(0xFF151618),
                              Color(0xFF101113),
                            ]
                          : const [
                              Color(0xFFFFDCCE),
                              Color(0xFFF8F1E7),
                              Color(0xFFF5F0E8),
                            ],
                      stops: const [0, 0.52, 1],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: ArtworkBackdrop(
                  key: const ValueKey('now-playing-artwork-atmosphere'),
                  imageUrl: song?.thumbnail ?? '',
                  opacity: dark ? 0.34 : 0.2,
                  blurSigma: 38,
                  cacheWidth: 160,
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
                                Color(0x1A101113),
                                Color(0xB8151618),
                                Color(0xF2101113),
                              ]
                            : const [
                                Color(0x33FFF8F2),
                                Color(0xC2F8F1E7),
                                Color(0xF2F5F0E8),
                              ],
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: song == null
                    ? const _NoSongState()
                    : controller.carModeEnabled
                    ? _CarModePlayer(
                        controller: controller,
                        song: song,
                        onClose: () => Navigator.pop(context),
                        onExit: () => controller.setCarModeEnabled(false),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: 520,
                                minHeight: constraints.maxHeight - 36,
                              ),
                              child: Column(
                                children: [
                                  _PlayerHeader(
                                    onClose: () => Navigator.pop(context),
                                    onStop: controller.stop,
                                    originLabel:
                                        controller.playbackOrigin.label,
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
                                            borderRadius: controller.isLiveRadio
                                                ? 999
                                                : 30,
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
                                      if (controller.isLiveRadio)
                                        const _LiveBadge()
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
                                            size: 30,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          song.artistsNames,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                      if (!controller.isLiveRadio) ...[
                                        const SizedBox(width: 12),
                                        _PlaybackQualityBadge(
                                          preference: controller
                                              .streamingQualityPreference,
                                          onTap: () =>
                                              showStreamingQualityPicker(
                                                context,
                                                controller: controller,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (!controller.isLiveRadio) ...[
                                    const SizedBox(height: 16),
                                    MoodSelector(
                                      controller: controller,
                                      song: song,
                                    ),
                                  ],
                                  const SizedBox(height: 26),
                                  _ProgressSection(controller: controller),
                                  if (controller.errorMessage != null) ...[
                                    const SizedBox(height: 14),
                                    _PlaybackError(
                                      message: controller.errorMessage!,
                                      onRetry: () =>
                                          unawaited(controller.retryPlayback()),
                                      onUseAutomatic:
                                          !controller.isLiveRadio &&
                                              controller
                                                      .streamingQualityPreference !=
                                                  StreamingQualityPreference
                                                      .automatic
                                          ? () => unawaited(
                                              controller.retryPlayback(
                                                useAutomaticQuality: true,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ],
                                  if (!controller.isLiveRadio &&
                                      controller.radioErrorMessage != null) ...[
                                    const SizedBox(height: 10),
                                    _PlaybackError(
                                      message: controller.radioErrorMessage!,
                                    ),
                                  ],
                                  const SizedBox(height: 22),
                                  _PlayerControls(controller: controller),
                                  const SizedBox(height: 20),
                                  _NowPlayingActionDock(
                                    controller: controller,
                                    onOpenDetails: () => showSongDetail(
                                      context,
                                      controller: controller,
                                      detailLoader: widget.songDetailLoader,
                                      externalLauncher:
                                          widget.songDetailExternalLauncher,
                                    ),
                                    onOpenLyrics: () => showSongLyrics(
                                      context,
                                      controller: controller,
                                      lyricsLoader: widget.lyricsLoader,
                                    ),
                                    onStartRadio: () => unawaited(
                                      startSongRadioWithFeedback(
                                        context,
                                        controller,
                                      ),
                                    ),
                                    onOpenQueue: () =>
                                        _showQueue(context, controller),
                                    onOpenSleepTimer: () =>
                                        _showSleepTimer(context, controller),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.screen_lock_portrait_rounded,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 7),
                                      Flexible(
                                        child: Text(
                                          'Tiếp tục phát khi khóa màn hình',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
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
            ],
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
        builder: (context, _) {
          final currentSong = controller.currentSong;
          final upNextSongs = controller.upNextSongs;
          final upNextRevision = controller.upNextRevision;
          return FractionallySizedBox(
            heightFactor: 0.9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Danh sách phát · ${controller.queue.length} bài',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Đang phát từ ${controller.playbackOrigin.label}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (controller.canClearPlaybackQueue)
                            TextButton(
                              key: const ValueKey(
                                'mobile-clear-playback-queue',
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
                      const SizedBox(height: 12),
                      SmartShuffleControlCard(controller: controller),
                      const SizedBox(height: 10),
                      SongRadioControlCard(controller: controller),
                      if (controller.nextSong != null) ...[
                        const SizedBox(height: 10),
                        UpNextPreview(controller: controller),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    key: const ValueKey('mobile-up-next-list'),
                    scrollCacheExtent: const ScrollCacheExtent.pixels(320),
                    header: currentSong == null
                        ? null
                        : _MobileQueueSongTile(
                            key: ValueKey('queue-current-${currentSong.id}'),
                            controller: controller,
                            song: currentSong,
                            current: true,
                          ),
                    itemCount: upNextSongs.length,
                    onReorderItem: controller.reorderUpNext,
                    itemBuilder: (context, index) {
                      final queuedSong = upNextSongs[index];
                      return _MobileQueueSongTile(
                        key: playbackQueueItemKey('queue', upNextSongs, index),
                        controller: controller,
                        song: queuedSong,
                        position: index + 1,
                        onRemove: queuedSong.id == currentSong?.id
                            ? null
                            : () => controller.removeFromQueue(queuedSong),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          unawaited(
                            controller.playUpNext(index, upNextRevision),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
              subtitle: Text('Nhạc sẽ dừng, không chỉ tạm dừng.'),
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
}

class _MobileQueueSongTile extends StatelessWidget {
  const _MobileQueueSongTile({
    super.key,
    required this.controller,
    required this.song,
    this.position,
    this.current = false,
    this.onRemove,
    this.onTap,
  });

  final MusicPlayerController controller;
  final Song song;
  final int? position;
  final bool current;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
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
          const SizedBox(height: 4),
          const SongRadioBadge(compact: true),
        ],
        if (controller.isSmartShuffleSong(song)) ...[
          const SizedBox(height: 4),
          const SmartShuffleBadge(compact: true),
        ],
      ],
    ),
    trailing: current
        ? const Text('Đang phát')
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

String _sleepTimerLabel(MusicPlayerController controller) {
  if (controller.sleepAfterCurrentSong) return 'Tắt sau bài này';
  final remaining = controller.sleepTimerRemaining;
  if (remaining == null) return 'Hẹn giờ';
  final minutes = remaining.inMinutes;
  final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
  return 'Còn $minutes:$seconds';
}

class _CarModePlayer extends StatelessWidget {
  const _CarModePlayer({
    required this.controller,
    required this.song,
    required this.onClose,
    required this.onExit,
  });

  final MusicPlayerController controller;
  final Song song;
  final VoidCallback onClose;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 800;
      final horizontalPadding = wide ? 48.0 : 22.0;
      final artSize = wide
          ? ((constraints.maxWidth - horizontalPadding * 2) * 0.38)
                .clamp(280.0, 440.0)
                .toDouble()
          : (constraints.maxWidth - horizontalPadding * 2)
                .clamp(220.0, 360.0)
                .toDouble();
      final artwork = Hero(
        tag: 'album-${song.id}',
        child: SizedBox.square(
          key: const ValueKey('car-mode-artwork'),
          dimension: artSize,
          child: AlbumArt(
            imageUrl: song.thumbnail,
            semanticLabel: 'Bìa album ${song.displayTitle}',
            size: artSize,
            borderRadius: controller.isLiveRadio
                ? 999
                : wide
                ? 34
                : 28,
          ),
        ),
      );
      final information = _CarModeInformation(
        controller: controller,
        song: song,
        wide: wide,
      );

      return SingleChildScrollView(
        key: const ValueKey('car-mode-player'),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          wide ? 18 : 10,
          horizontalPadding,
          30,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 40).clamp(0, double.infinity),
          ),
          child: Column(
            children: [
              _CarModeHeader(onClose: onClose, onExit: onExit),
              SizedBox(height: wide ? 38 : 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Center(child: artwork)),
                    const SizedBox(width: 54),
                    Expanded(child: information),
                  ],
                )
              else ...[
                artwork,
                const SizedBox(height: 26),
                information,
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _CarModeHeader extends StatelessWidget {
  const _CarModeHeader({required this.onClose, required this.onExit});

  final VoidCallback onClose;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox.square(
        dimension: 56,
        child: IconButton.filledTonal(
          key: const ValueKey('car-mode-close'),
          tooltip: 'Quay lại',
          onPressed: onClose,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 34),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _RoadMarker(color: Color(0xFFFF6B4A)),
                SizedBox(width: 6),
                _RoadMarker(color: Color(0xFFB8F43D)),
                SizedBox(width: 6),
                _RoadMarker(color: Color(0xFFFF6B4A)),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'CHẾ ĐỘ LÁI XE',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      SizedBox(
        height: 56,
        child: FilledButton.tonalIcon(
          key: const ValueKey('exit-car-mode'),
          onPressed: onExit,
          icon: const Icon(Icons.close_fullscreen_rounded),
          label: const Text('THOÁT'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    ],
  );
}

class _RoadMarker extends StatelessWidget {
  const _RoadMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(99),
    ),
    child: const SizedBox(width: 28, height: 4),
  );
}

class _CarModeInformation extends StatelessWidget {
  const _CarModeInformation({
    required this.controller,
    required this.song,
    required this.wide,
  });

  final MusicPlayerController controller;
  final Song song;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label:
          '${controller.isPlaying ? 'Đang phát' : 'Đã tạm dừng'} ${song.displayTitle} của ${song.artistsNames}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(wide ? 30 : 24),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.46),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(wide ? 28 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: controller.isPlaying
                          ? const Color(0xFFB8F43D)
                          : scheme.onSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      controller.isPlaying ? 'ĐANG PHÁT' : 'ĐÃ TẠM DỪNG',
                      style: TextStyle(
                        color: controller.isPlaying
                            ? const Color(0xFFB8F43D)
                            : scheme.onSurfaceVariant,
                        fontSize: wide ? 14 : 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  if (controller.isLiveRadio) const _LiveBadge(),
                ],
              ),
              SizedBox(height: wide ? 18 : 14),
              Text(
                song.displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: wide ? 38 : 28,
                  height: 1.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: wide ? -1.4 : -0.9,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                song.artistsNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.secondary,
                  fontSize: wide ? 19 : 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: wide ? 28 : 22),
              _CarModeProgress(controller: controller),
              if (controller.errorMessage != null) ...[
                const SizedBox(height: 16),
                _PlaybackError(
                  message: controller.errorMessage!,
                  onRetry: () => unawaited(controller.retryPlayback()),
                  onUseAutomatic:
                      !controller.isLiveRadio &&
                          controller.streamingQualityPreference !=
                              StreamingQualityPreference.automatic
                      ? () => unawaited(
                          controller.retryPlayback(useAutomaticQuality: true),
                        )
                      : null,
                ),
              ],
              SizedBox(height: wide ? 26 : 22),
              _CarModeTransport(controller: controller, wide: wide),
              const SizedBox(height: 18),
              SizedBox(
                height: 58,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('car-mode-stop'),
                  onPressed: controller.stop,
                  icon: const Icon(Icons.stop_rounded, size: 28),
                  label: const Text('DỪNG PHÁT'),
                  style: FilledButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Giữ mắt trên đường · dùng nút lớn hoặc điều khiển trên vô-lăng',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: wide ? 13 : 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarModeProgress extends StatelessWidget {
  const _CarModeProgress({required this.controller});

  final MusicPlayerController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLiveRadio) {
      return const Column(
        children: [
          LinearProgressIndicator(
            minHeight: 8,
            color: Color(0xFFFF6B4A),
            backgroundColor: Color(0xFF3C3D41),
          ),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'PHÁT TRỰC TIẾP',
              style: TextStyle(fontWeight: FontWeight.w900),
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
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFFF6B4A),
            inactiveTrackColor: Theme.of(context).colorScheme.outlineVariant,
            thumbColor: const Color(0xFFF5F0E8),
            overlayColor: const Color(0x33FF6B4A),
            trackHeight: 8,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            key: const ValueKey('car-mode-progress-slider'),
            min: 0,
            max: durationMs <= 0 ? 1 : durationMs.toDouble(),
            value: durationMs <= 0 ? 0 : positionMs.toDouble(),
            onChanged: durationMs <= 0
                ? null
                : (value) =>
                      controller.seek(Duration(milliseconds: value.round())),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _carModeDuration(controller.position),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              '-${_carModeDuration(_carModeRemaining(controller))}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ],
    );
  }
}

class _CarModeTransport extends StatelessWidget {
  const _CarModeTransport({required this.controller, required this.wide});

  final MusicPlayerController controller;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final secondarySize = wide ? 88.0 : 72.0;
    final primarySize = wide ? 116.0 : 96.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox.square(
          dimension: secondarySize,
          child: FilledButton.tonal(
            key: const ValueKey('car-mode-previous'),
            onPressed: controller.canGoPrevious ? controller.previous : null,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: Icon(
              Icons.skip_previous_rounded,
              semanticLabel: 'Bài trước',
              size: wide ? 48 : 40,
            ),
          ),
        ),
        SizedBox(width: wide ? 20 : 12),
        SizedBox.square(
          dimension: primarySize,
          child: FilledButton(
            key: const ValueKey('car-mode-play-pause'),
            onPressed: controller.isLoading ? null : controller.togglePlayPause,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: const Color(0xFFFF6B4A),
              foregroundColor: const Color(0xFF101113),
              disabledBackgroundColor: const Color(0xFF393A3E),
            ),
            child: controller.isLoading
                ? SizedBox.square(
                    dimension: wide ? 38 : 32,
                    child: const CircularProgressIndicator(strokeWidth: 4),
                  )
                : Icon(
                    controller.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    semanticLabel: controller.isPlaying ? 'Tạm dừng' : 'Phát',
                    size: wide ? 66 : 54,
                  ),
          ),
        ),
        SizedBox(width: wide ? 20 : 12),
        SizedBox.square(
          dimension: secondarySize,
          child: FilledButton.tonal(
            key: const ValueKey('car-mode-next'),
            onPressed: controller.canGoNext ? controller.next : null,
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: Icon(
              Icons.skip_next_rounded,
              semanticLabel: 'Bài tiếp theo',
              size: wide ? 48 : 40,
            ),
          ),
        ),
      ],
    );
  }
}

Duration _carModeRemaining(MusicPlayerController controller) {
  final remaining = controller.duration - controller.position;
  return remaining.isNegative ? Duration.zero : remaining;
}

String _carModeDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({
    required this.onClose,
    required this.onStop,
    required this.originLabel,
  });

  final VoidCallback onClose;
  final VoidCallback onStop;
  final String originLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Quay lại bảng xếp hạng',
          onPressed: onClose,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                'ĐANG PHÁT TỪ',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                originLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
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

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFFF6B4A),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      'LIVE',
      style: TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1,
      ),
    ),
  );
}

class _PlaybackQualityBadge extends StatelessWidget {
  const _PlaybackQualityBadge({required this.preference, required this.onTap});

  final StreamingQualityPreference preference;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (preference) {
      StreamingQualityPreference.automatic => 'AUTO',
      StreamingQualityPreference.standard => '128 KBPS',
      StreamingQualityPreference.high => '320 KBPS',
    };
    return Tooltip(
      message: 'Chất lượng phát · ${preference.label}',
      child: InkWell(
        key: const ValueKey('open-streaming-quality'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x24B8F43D),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x66B8F43D)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: Color(0xFFB8F43D),
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFB8F43D),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NowPlayingActionDock extends StatelessWidget {
  const _NowPlayingActionDock({
    required this.controller,
    required this.onOpenDetails,
    required this.onOpenLyrics,
    required this.onStartRadio,
    required this.onOpenQueue,
    required this.onOpenSleepTimer,
  });

  final MusicPlayerController controller;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenLyrics;
  final VoidCallback onStartRadio;
  final VoidCallback onOpenQueue;
  final VoidCallback onOpenSleepTimer;

  @override
  Widget build(BuildContext context) {
    final shortcuts = <Widget>[
      if (!controller.isLiveRadio)
        _NowPlayingShortcut(
          key: const ValueKey('open-song-lyrics'),
          icon: Icons.lyrics_rounded,
          label: 'Lời bài hát',
          onTap: onOpenLyrics,
        ),
      if (!controller.isLiveRadio)
        _NowPlayingShortcut(
          key: const ValueKey('open-playback-queue'),
          icon: Icons.queue_music_rounded,
          label: 'Hàng đợi · ${controller.queue.length} bài',
          onTap: onOpenQueue,
        ),
      if (!controller.isLiveRadio)
        _NowPlayingShortcut(
          key: const ValueKey('start-song-radio'),
          icon: Icons.radio_rounded,
          label: 'Song Radio',
          loading: controller.isRadioLoading,
          onTap: controller.songRadioAvailable && !controller.isRadioLoading
              ? onStartRadio
              : null,
        ),
      _NowPlayingShortcut(
        key: const ValueKey('sleep-timer-button'),
        icon: controller.hasSleepTimer
            ? Icons.bedtime_rounded
            : Icons.bedtime_outlined,
        label: _sleepTimerLabel(controller),
        active: controller.hasSleepTimer,
        onTap: onOpenSleepTimer,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const ValueKey('now-playing-action-dock'),
          height: 92,
          child: shortcuts.length == 1
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(width: 112, child: shortcuts.first),
                )
              : Row(
                  children: [
                    for (var index = 0; index < shortcuts.length; index++) ...[
                      if (index > 0) const SizedBox(width: 7),
                      Expanded(child: shortcuts[index]),
                    ],
                  ],
                ),
        ),
        if (!controller.isLiveRadio) ...[
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _NowPlayingUtilityPill(
                key: const ValueKey('open-song-detail'),
                icon: Icons.info_outline_rounded,
                label: 'Thông tin',
                onTap: onOpenDetails,
              ),
              _NowPlayingUtilityPill(
                key: const ValueKey('toggle-smart-shuffle'),
                icon: Icons.auto_awesome_rounded,
                label: controller.smartShuffleEnabled
                    ? 'Smart · ${controller.smartShuffleSongCount}'
                    : 'Smart Shuffle',
                active: controller.smartShuffleEnabled,
                onTap: controller.queue.isEmpty
                    ? null
                    : () => setSmartShuffleWithFeedback(
                        context,
                        controller,
                        !controller.smartShuffleEnabled,
                      ),
              ),
              _NowPlayingUtilityPill(
                key: const ValueKey('enter-car-mode'),
                icon: Icons.directions_car_filled_rounded,
                label: 'Lái xe',
                onTap: () => controller.setCarModeEnabled(true),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _NowPlayingShortcut extends StatelessWidget {
  const _NowPlayingShortcut({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foreground = active
        ? const Color(0xFFB8F43D)
        : enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).disabledColor;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 9, 8, 7),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0x1FB8F43D)
                  : Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active
                    ? const Color(0x55B8F43D)
                    : Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(icon, color: foreground, size: 23),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10.5,
                    height: 1.05,
                    fontWeight: FontWeight.w700,
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

class _NowPlayingUtilityPill extends StatelessWidget {
  const _NowPlayingUtilityPill({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: active ? const Color(0xFFB8F43D) : null,
      side: BorderSide(
        color: active
            ? const Color(0x66B8F43D)
            : Theme.of(context).colorScheme.outlineVariant,
      ),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    ),
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.controller});

  final MusicPlayerController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLiveRadio) {
      return Column(
        children: [
          const LinearProgressIndicator(
            minHeight: 4,
            color: Color(0xFFFF6B4A),
            backgroundColor: Color(0xFF3C3D41),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('LIVE', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  controller.isPlaying ? 'Đang phát trực tiếp' : 'Đã tạm dừng',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      );
    }
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
          onPressed: controller.isLiveRadio ? null : controller.toggleShuffle,
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
          onPressed: controller.isLiveRadio ? null : controller.cycleRepeatMode,
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
  const _PlaybackError({
    required this.message,
    this.onRetry,
    this.onUseAutomatic,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onUseAutomatic;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFFF8A70)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFFFC7BA),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null || onUseAutomatic != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (onRetry != null)
                  TextButton.icon(
                    key: const ValueKey('playback-error-retry'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Thử lại'),
                  ),
                if (onUseAutomatic != null)
                  FilledButton.tonalIcon(
                    key: const ValueKey('playback-error-use-auto'),
                    onPressed: onUseAutomatic,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Dùng Tự động'),
                  ),
              ],
            ),
          ],
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
