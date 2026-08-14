import 'package:flutter/material.dart';

import '../music_player_scope.dart';
import '../music_player_screen.dart';
import 'album_art.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final song = controller.currentSong;
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: song == null
              ? const SizedBox.shrink()
              : SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Material(
                    color: const Color(0xFF242529),
                    elevation: 16,
                    shadowColor: Colors.black54,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MusicPlayerScreen(),
                        ),
                      ),
                      child: SizedBox(
                        height: 88,
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: controller.duration == Duration.zero
                                  ? 0
                                  : controller.progress,
                              minHeight: 3,
                              color: const Color(0xFFFF6B4A),
                              backgroundColor: const Color(0xFF38393D),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                                child: Row(
                                  children: [
                                    Hero(
                                      tag: 'album-${song.id}',
                                      child: AlbumArt(
                                        imageUrl: song.thumbnail,
                                        semanticLabel:
                                            'Bìa album ${song.displayTitle}',
                                        size: 56,
                                        borderRadius: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            song.displayTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            controller.isLoading
                                                ? 'Đang chuẩn bị nguồn phát…'
                                                : song.artistsNames,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFFB5B6BA),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: controller.isPlaying
                                          ? 'Tạm dừng'
                                          : 'Phát',
                                      onPressed: controller.isLoading
                                          ? null
                                          : controller.togglePlayPause,
                                      icon: controller.isLoading
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
                                              size: 30,
                                            ),
                                    ),
                                    IconButton(
                                      tooltip: 'Dừng',
                                      onPressed: controller.stop,
                                      icon: const Icon(Icons.stop_rounded),
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
                ),
        );
      },
    );
  }
}
