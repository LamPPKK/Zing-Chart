import 'package:flutter/material.dart';

import '../models/listening_analytics.dart';
import '../models/song.dart';
import '../music_player_controller.dart';
import '../theme/app_theme.dart';
import 'album_art.dart';

class ForYouHub extends StatelessWidget {
  const ForYouHub({
    super.key,
    required this.controller,
    required this.onPlaySongs,
    required this.onOpenAnalytics,
    required this.onOpenWrapped,
    this.now,
  });

  final MusicPlayerController controller;
  final ValueChanged<List<Song>> onPlaySongs;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onOpenWrapped;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final localNow = now ?? DateTime.now();
    final mobilePersonalMode = MediaQuery.sizeOf(context).width < 720;
    final daily = controller.dailyMixCollection;
    final moods = MoodTag.values
        .map(controller.moodMix)
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mobilePersonalMode) ...[
            _LocalProfileSummary(
              likedSongs: controller.likedSongs.length,
              playlists: controller.playlists.length,
              followedArtists: controller.followedArtists.length,
              onOpenAnalytics: onOpenAnalytics,
            ),
            const SizedBox(height: 18),
          ],
          _DailyMixHero(
            mix: daily,
            now: localNow,
            onPlay: daily.songs.isEmpty ? null : () => onPlaySongs(daily.songs),
          ),
          const SizedBox(height: 30),
          _SectionHeading(
            eyebrow: 'MOOD, DO BẠN CHỌN',
            title: 'Ba nhịp cho một ngày',
            trailing: TextButton.icon(
              onPressed: onOpenAnalytics,
              icon: const Icon(Icons.insights_rounded),
              label: const Text('Xem thống kê'),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 960
                  ? 3
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final gap = 12.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: moods
                    .map(
                      (mix) => SizedBox(
                        width: width,
                        child: _MoodCard(
                          mix: mix,
                          onPlay: mix.songs.isEmpty
                              ? null
                              : () => onPlaySongs(mix.songs),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 30),
          _WrappedBanner(
            onOpen: onOpenWrapped,
            seasonal: localNow.month == 12 || localNow.month == 1,
          ),
        ],
      ),
    );
  }
}

class _LocalProfileSummary extends StatelessWidget {
  const _LocalProfileSummary({
    required this.likedSongs,
    required this.playlists,
    required this.followedArtists,
    required this.onOpenAnalytics,
  });

  final int likedSongs;
  final int playlists;
  final int followedArtists;
  final VoidCallback onOpenAnalytics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label:
          'Cá nhân trên thiết bị, $likedSongs bài thích, '
          '$playlists playlist, $followedArtists nghệ sĩ. Mở thống kê.',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Card(
          key: const ValueKey('mobile-personal-summary'),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpenAnalytics,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [ZingColors.purpleBright, ZingColors.coral],
                          ),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CÁ NHÂN TRÊN THIẾT BỊ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ZingColors.lime,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.25,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Không cần đăng nhập',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.6,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Mix và lịch sử chỉ lưu cục bộ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _LocalProfileStat(
                          key: const ValueKey('personal-liked-stat'),
                          value: likedSongs,
                          label: 'Bài thích',
                        ),
                      ),
                      Expanded(
                        child: _LocalProfileStat(
                          key: const ValueKey('personal-playlist-stat'),
                          value: playlists,
                          label: 'Playlist',
                        ),
                      ),
                      Expanded(
                        child: _LocalProfileStat(
                          key: const ValueKey('personal-artist-stat'),
                          value: followedArtists,
                          label: 'Nghệ sĩ',
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
    );
  }
}

class _LocalProfileStat extends StatelessWidget {
  const _LocalProfileStat({
    super.key,
    required this.value,
    required this.label,
  });

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        '$value',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ],
  );
}

class _DailyMixHero extends StatelessWidget {
  const _DailyMixHero({
    required this.mix,
    required this.now,
    required this.onPlay,
  });

  final MixCollection mix;
  final DateTime now;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final date =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}';
    return Container(
      key: const ValueKey('for-you-daily-mix'),
      constraints: const BoxConstraints(minHeight: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B4A), Color(0xFF912F25), ZingColors.ink],
          stops: [0, 0.55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: ZingColors.coral.withValues(alpha: 0.18),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -44,
              child: Text(
                date,
                style: const TextStyle(
                  color: Color(0x22FFFFFF),
                  fontSize: 108,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -8,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(26),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'LOCAL SIGNAL / DAILY',
                        style: TextStyle(
                          color: ZingColors.lime,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Gu của bạn,\nkhông phải thuật toán đám mây.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          height: 0.98,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.8,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        mix.subtitle,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE7D8D2),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: onPlay,
                        style: FilledButton.styleFrom(
                          backgroundColor: ZingColors.lime,
                          foregroundColor: ZingColors.ink,
                          minimumSize: const Size(144, 48),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(
                          mix.songs.isEmpty
                              ? 'Chưa đủ dữ liệu'
                              : 'Phát ${mix.songs.length} bài',
                        ),
                      ),
                    ],
                  );
                  if (compact) return copy;
                  return Row(
                    children: [
                      Expanded(child: copy),
                      const SizedBox(width: 22),
                      _CoverStack(songs: mix.songs.take(3).toList()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverStack extends StatelessWidget {
  const _CoverStack({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    height: 190,
    child: Stack(
      alignment: Alignment.center,
      children: [
        for (var index = songs.length - 1; index >= 0; index--)
          Transform.translate(
            offset: Offset(index * 20 - 20, index * 7 - 7),
            child: Transform.rotate(
              angle: (index - 1) * 0.08,
              child: AlbumArt(
                imageUrl: songs[index].thumbnail,
                semanticLabel: 'Bìa ${songs[index].displayTitle}',
                size: 142,
                borderRadius: 24,
              ),
            ),
          ),
        if (songs.isEmpty)
          const Icon(Icons.blur_on_rounded, size: 112, color: ZingColors.lime),
      ],
    ),
  );
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.mix, required this.onPlay});

  final MixCollection mix;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final accent = switch (mix.mood) {
      MoodTag.chill => ZingColors.blue,
      MoodTag.gym => ZingColors.coral,
      MoodTag.focus => ZingColors.lime,
      null => ZingColors.coral,
    };
    final icon = switch (mix.mood) {
      MoodTag.chill => Icons.water_rounded,
      MoodTag.gym => Icons.bolt_rounded,
      MoodTag.focus => Icons.center_focus_strong_rounded,
      null => Icons.music_note_rounded,
    };
    return Card(
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: accent),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: 'Phát ${mix.title}',
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                mix.title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                mix.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                '${mix.songs.length.toString().padLeft(2, '0')} TRACKS',
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WrappedBanner extends StatelessWidget {
  const _WrappedBanner({required this.onOpen, required this.seasonal});

  final VoidCallback onOpen;
  final bool seasonal;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('open-wrapped-card'),
    decoration: BoxDecoration(
      color: ZingColors.lime,
      borderRadius: BorderRadius.circular(28),
      boxShadow: seasonal
          ? [
              BoxShadow(
                color: ZingColors.lime.withValues(alpha: 0.3),
                blurRadius: 32,
                spreadRadius: 3,
              ),
            ]
          : null,
    ),
    padding: const EdgeInsets.all(22),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                seasonal ? 'WRAPPED SEASON / LOCAL' : 'MINI WRAPPED / LOCAL',
                style: const TextStyle(
                  color: ZingColors.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Một năm nghe nhạc\nthu gọn trong sáu khung hình.',
                style: TextStyle(
                  color: ZingColors.ink,
                  fontSize: 25,
                  height: 1.02,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: onOpen,
          style: FilledButton.styleFrom(
            backgroundColor: ZingColors.ink,
            foregroundColor: ZingColors.paper,
          ),
          child: const Text('Mở Wrapped'),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: ZingColors.coral,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 5),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
      if (trailing != null) trailing!,
    ],
  );
}
