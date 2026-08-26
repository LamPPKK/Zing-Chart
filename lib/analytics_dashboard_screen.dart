import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/listening_analytics.dart';
import 'models/song.dart';
import 'music_player_controller.dart';
import 'music_player_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/album_art.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.thirtyDays;
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerScope.of(context);
    final summary = controller.analyticsSummary(_period, year: _year);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Thống kê tại máy'),
            actions: [
              IconButton(
                tooltip: 'Xóa lịch sử và thống kê',
                onPressed: () => _confirmClear(controller),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? const [Color(0xFF202125), ZingColors.ink]
                    : const [Color(0xFFFFFBF4), ZingColors.paper],
              ),
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<AnalyticsPeriod>(
                      segments: const [
                        ButtonSegment(
                          value: AnalyticsPeriod.sevenDays,
                          label: Text('7 ngày'),
                        ),
                        ButtonSegment(
                          value: AnalyticsPeriod.thirtyDays,
                          label: Text('30 ngày'),
                        ),
                        ButtonSegment(
                          value: AnalyticsPeriod.year,
                          label: Text('Theo năm'),
                        ),
                      ],
                      selected: {_period},
                      onSelectionChanged: (values) =>
                          setState(() => _period = values.first),
                    ),
                    if (_period == AnalyticsPeriod.year)
                      DropdownButton<int>(
                        value: _year,
                        items: [DateTime.now().year, DateTime.now().year - 1]
                            .map(
                              (year) => DropdownMenuItem(
                                value: year,
                                child: Text('$year'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => _year = value);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _Metrics(summary: summary),
                const SizedBox(height: 28),
                _RankedSongs(
                  songs: summary.topSongs.take(5).toList(growable: false),
                  onPlay: (song) {
                    final queue = summary.topSongs
                        .map((stat) => stat.song)
                        .where((item) => item.isPlaybackEligible)
                        .toList(growable: false);
                    if (!song.isPlaybackEligible || queue.isEmpty) return;
                    controller.playSong(song, queue: queue);
                  },
                ),
                const SizedBox(height: 28),
                _RankedArtists(
                  artists: summary.topArtists.take(5).toList(growable: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear(MusicPlayerController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa lịch sử và thống kê?'),
        content: const Text(
          'Favorites, playlist và mood đã gắn vẫn được giữ lại. Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa dữ liệu nghe'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.clearListeningHistoryAndStats();
    if (mounted) setState(() {});
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final values = [
      ('${summary.listened.inMinutes}', 'phút nghe', ZingColors.coral),
      ('${summary.qualifiedPlays}', 'lượt hợp lệ', ZingColors.lime),
      (
        '${(summary.completionRate * 100).round()}%',
        'hoàn thành',
        ZingColors.blue,
      ),
      (
        summary.busiestDay == null
            ? '—'
            : '${summary.busiestDay!.day}/${summary.busiestDay!.month}',
        'ngày nghe nhiều',
        const Color(0xFFFFB86B),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 800 ? 4 : 2;
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: values
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 126),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: item.$3.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: item.$3.withValues(alpha: 0.26),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          item.$1,
                          style: TextStyle(
                            color: item.$3,
                            fontSize: 34,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(item.$2),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _RankedSongs extends StatelessWidget {
  const _RankedSongs({required this.songs, required this.onPlay});

  final List<AnalyticsSongStat> songs;
  final ValueChanged<Song> onPlay;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Top 5 bài hát', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 10),
      if (songs.isEmpty)
        const _EmptyAnalytics(message: 'Chưa có lượt nghe hợp lệ trong kỳ này.')
      else
        ...songs.indexed.map((entry) {
          final song = entry.$2.song;
          final canPlay = song.isPlaybackEligible;
          return Card(
            child: ListTile(
              key: ValueKey('analytics-song-${song.id}'),
              enabled: canPlay,
              onTap: canPlay ? () => onPlay(song) : null,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${entry.$1 + 1}'.padLeft(2, '0'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  AlbumArt(
                    imageUrl: song.thumbnail,
                    semanticLabel: 'Bìa ${song.displayTitle}',
                    size: 46,
                    borderRadius: 12,
                  ),
                ],
              ),
              title: Text(song.displayTitle),
              subtitle: Text(song.artistsNames),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!canPlay) ...[
                    const Icon(
                      Icons.lock_outline_rounded,
                      semanticLabel: 'Bị giới hạn phát',
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '${entry.$2.aggregate.qualifiedPlays} lượt',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          );
        }),
    ],
  );
}

class _RankedArtists extends StatelessWidget {
  const _RankedArtists({required this.artists});

  final List<AnalyticsArtistStat> artists;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Top 5 nghệ sĩ', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 10),
      if (artists.isEmpty)
        const _EmptyAnalytics(message: 'Chưa đủ dữ liệu nghệ sĩ trong kỳ này.')
      else
        ...artists.indexed.map(
          (entry) => ListTile(
            leading: CircleAvatar(
              backgroundColor: ZingColors.lime.withValues(alpha: 0.15),
              foregroundColor: ZingColors.lime,
              child: Text('${entry.$1 + 1}'),
            ),
            title: Text(entry.$2.artist),
            subtitle: Text('${entry.$2.listened.inMinutes} phút'),
            trailing: Text('${entry.$2.qualifiedPlays} lượt'),
          ),
        ),
    ],
  );
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          const Icon(Icons.insights_outlined),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
