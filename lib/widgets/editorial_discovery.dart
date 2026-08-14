import 'package:flutter/material.dart';

import '../models/song.dart';
import '../music_player_controller.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

class EditorialDiscovery extends StatelessWidget {
  const EditorialDiscovery({
    super.key,
    required this.songs,
    required this.controller,
    required this.onPlay,
  });

  final List<Song> songs;
  final MusicPlayerController controller;
  final void Function(Song song, List<Song> queue) onPlay;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();
    final lead = songs.first;
    final personalized = controller.dailyMix
        .where((song) => song.id != lead.id)
        .toList(growable: false);
    final localMix = personalized.isEmpty
        ? songs.skip(1).take(12).toList(growable: false)
        : personalized;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final copy = _HeroCopy(
                song: lead,
                onPlay: () => onPlay(lead, songs),
              );
              final art = AlbumArt(
                imageUrl: lead.thumbnail,
                semanticLabel: 'Bìa album ${lead.displayTitle}',
                size: compact ? 138 : 218,
                borderRadius: compact ? 26 : 34,
              );
              return Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: const Color(0xFF24231F),
                  border: Border.all(
                    color: ZingColors.coral.withValues(alpha: 0.3),
                  ),
                ),
                child: Stack(
                  children: [
                    const Positioned(top: -90, right: -40, child: _PulseDisc()),
                    Padding(
                      padding: EdgeInsets.all(compact ? 18 : 28),
                      child: compact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    art,
                                    const Spacer(),
                                    const _ChartStamp(),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                copy,
                              ],
                            )
                          : Row(
                              children: [
                                art,
                                const SizedBox(width: 30),
                                Expanded(child: copy),
                                const SizedBox(width: 24),
                                const _ChartStamp(),
                              ],
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PICKED ON DEVICE',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.dailyMix.isEmpty
                          ? 'Bắt đầu khám phá'
                          : 'Mix mỗi ngày',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: localMix.isEmpty
                    ? null
                    : () => onPlay(localMix.first, localMix),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Phát mix'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 122,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: localMix.take(8).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final song = localMix[index];
                return SizedBox(
                  width: 246,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => onPlay(song, localMix),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            AlbumArt(
                              imageUrl: song.thumbnail,
                              semanticLabel: 'Bìa album ${song.displayTitle}',
                              size: 78,
                              borderRadius: 18,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    song.displayTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    song.artistsNames,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.song, required this.onPlay});

  final Song song;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onPlay,
    borderRadius: BorderRadius.circular(18),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _LiveMark(),
              Text(
                'REALTIME · #01',
                style: TextStyle(
                  color: ZingColors.coral,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            song.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ZingColors.paper,
              fontSize: 31,
              height: 0.98,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            song.artistsNames,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFC7C4BC), fontSize: 14),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('hero-play-button'),
            onPressed: onPlay,
            style: FilledButton.styleFrom(
              backgroundColor: ZingColors.coral,
              foregroundColor: ZingColors.ink,
              minimumSize: const Size(126, 48),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Phát ngay'),
          ),
        ],
      ),
    ),
  );
}

class _LiveMark extends StatelessWidget {
  const _LiveMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: const BoxDecoration(
      color: ZingColors.coral,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Color(0xAAFF6B4A), blurRadius: 8)],
    ),
  );
}

class _PulseDisc extends StatelessWidget {
  const _PulseDisc();

  @override
  Widget build(BuildContext context) => Container(
    width: 260,
    height: 260,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          ZingColors.coral.withValues(alpha: 0.34),
          ZingColors.coral.withValues(alpha: 0),
        ],
      ),
    ),
  );
}

class _ChartStamp extends StatelessWidget {
  const _ChartStamp();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.06,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: ZingColors.lime, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '#zing\nCHART',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: ZingColors.lime,
          fontWeight: FontWeight.w900,
          height: 0.9,
          letterSpacing: -0.8,
        ),
      ),
    ),
  );
}
