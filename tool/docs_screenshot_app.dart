import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:zmp3chart/analytics_dashboard_screen.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/data/listening_analytics_repository.dart';
import 'package:zmp3chart/main.dart';
import 'package:zmp3chart/models/listening_analytics.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_screen.dart';
import 'package:zmp3chart/services/companion_surface_bridge.dart';
import 'package:zmp3chart/services/playback_audio_player.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/wrapped_screen.dart';
import 'package:zmp3chart/zing_chart_screen.dart';

/// Deterministic documentation-only entry point used to capture README images.
///
/// It never calls the proxy or a platform media service. Choose a surface with
/// `?screen=home|search|player|library|for-you|analytics|wrapped|tv`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final audioPlayer = _DocsAudioPlayer();
  final controller = PlaybackService(
    playbackAudioPlayer: audioPlayer,
    sourceResolver: (code) async => 'https://audio.example/$code.mp3',
    libraryRepository: MemoryLibraryRepository(_librarySnapshot()),
    analyticsRepository: MemoryListeningAnalyticsRepository(
      _analyticsSnapshot(),
    ),
    systemMediaBridge: NoopSystemMediaBridge(),
    companionSurfaceBridge: NoopCompanionSurfaceBridge(),
  );
  await controller.initialize();
  controller.updateCatalog(_songs);
  await controller.playSong(_songs.first, queue: _songs);
  audioPlayer
    ..emitDuration(const Duration(minutes: 3, seconds: 42))
    ..emitPosition(const Duration(minutes: 1, seconds: 18));

  final screen = Uri.base.queryParameters['screen'] ?? 'home';
  final tvMode = screen == 'tv';
  runApp(
    MyApp(
      playerController: controller,
      tvMode: tvMode,
      home: switch (screen) {
        'player' => const MusicPlayerScreen(),
        'analytics' => const AnalyticsDashboardScreen(),
        'wrapped' => const WrappedScreen(),
        'search' => ZingChartScreen(loadSongs: _loadSongs, initialTab: 1),
        'for-you' => ZingChartScreen(loadSongs: _loadSongs, initialTab: 2),
        'library' => ZingChartScreen(loadSongs: _loadSongs, initialTab: 3),
        'tv' => ZingChartScreen(
          loadSongs: _loadSongs,
          initialTab: 2,
          tvMode: true,
        ),
        _ => ZingChartScreen(loadSongs: _loadSongs),
      },
    ),
  );
}

Future<List<Song>> _loadSongs() async => _songs;

const _songs = [
  Song(
    id: 'mot-doi',
    name: 'mot-doi',
    title: 'Một Đời',
    thumbnail: '',
    artistsNames: '14 Casper & Bon Nghiêm',
    code: 'mot-doi',
  ),
  Song(
    id: 'nang-tho',
    name: 'nang-tho',
    title: 'Nàng Thơ',
    thumbnail: '',
    artistsNames: 'Hoàng Dũng',
    code: 'nang-tho',
  ),
  Song(
    id: 'muon-roi-ma-sao-con',
    name: 'muon-roi-ma-sao-con',
    title: 'Muộn Rồi Mà Sao Còn',
    thumbnail: '',
    artistsNames: 'Sơn Tùng M-TP',
    code: 'muon-roi-ma-sao-con',
  ),
  Song(
    id: 'buoc-qua-mua-co-don',
    name: 'buoc-qua-mua-co-don',
    title: 'Bước Qua Mùa Cô Đơn',
    thumbnail: '',
    artistsNames: 'Vũ.',
    code: 'buoc-qua-mua-co-don',
  ),
  Song(
    id: 'see-tinh',
    name: 'see-tinh',
    title: 'See Tình',
    thumbnail: '',
    artistsNames: 'Hoàng Thùy Linh',
    code: 'see-tinh',
  ),
  Song(
    id: 'waiting-for-you',
    name: 'waiting-for-you',
    title: 'Waiting For You',
    thumbnail: '',
    artistsNames: 'MONO',
    code: 'waiting-for-you',
  ),
  Song(
    id: 'co-hen-voi-thanh-xuan',
    name: 'co-hen-voi-thanh-xuan',
    title: 'Có Hẹn Với Thanh Xuân',
    thumbnail: '',
    artistsNames: 'MONSTAR',
    code: 'co-hen-voi-thanh-xuan',
  ),
  Song(
    id: 'thich-em-hoi-nhieu',
    name: 'thich-em-hoi-nhieu',
    title: 'Thích Em Hơi Nhiều',
    thumbnail: '',
    artistsNames: 'Wren Evans',
    code: 'thich-em-hoi-nhieu',
  ),
];

PlayerSnapshot _librarySnapshot() {
  final now = DateTime.now().toUtc();
  final history = <ListeningRecord>[
    for (var index = 0; index < 12; index++)
      ListeningRecord(
        id: 'docs-history-$index',
        song: _songs[index % _songs.length],
        playedAt: now.subtract(Duration(days: index ~/ 2, hours: index)),
        listened: Duration(minutes: 3 + index),
      ),
  ];
  return PlayerSnapshot(
    likedSongs: _songs.take(4).toList(),
    queue: _songs,
    currentSong: _songs.first,
    currentIndex: 0,
    position: const Duration(minutes: 1, seconds: 18),
    playlists: [
      LocalPlaylist(
        id: 'docs-chill',
        name: 'Chill cuối ngày',
        songs: _songs.take(4).toList(),
        createdAt: now.subtract(const Duration(days: 18)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      LocalPlaylist(
        id: 'docs-focus',
        name: 'Tập trung',
        songs: _songs.skip(2).take(4).toList(),
        createdAt: now.subtract(const Duration(days: 12)),
        updatedAt: now,
      ),
    ],
    history: history,
    recentSearches: const ['Hoàng Dũng', 'Chill', 'V-Pop'],
    themePreferenceIndex: AppThemePreference.dark.index,
  );
}

ListeningAnalyticsSnapshot _analyticsSnapshot() {
  final now = DateTime.now();
  final sourceId = 'docs-installation';
  final dailyBuckets = <DailyListeningBucket>[];
  final dailyTotals = <DailyListeningTotal>[];
  for (var day = 0; day < 12; day++) {
    final date = now.subtract(Duration(days: day));
    final dateKey = _dateKey(date);
    final aggregates = <String, SongAnalyticsAggregate>{};
    for (var index = 0; index < 5; index++) {
      final song = _songs[(day + index) % _songs.length];
      aggregates[song.id] = SongAnalyticsAggregate(
        song: song,
        starts: 3 + index,
        qualifiedPlays: 2 + index,
        completions: 1 + index,
        earlySkips: index == 4 ? 1 : 0,
        listened: Duration(minutes: 12 + day + index * 4),
        lastPlayedAt: date,
      );
    }
    dailyBuckets.add(
      DailyListeningBucket(
        sourceId: sourceId,
        date: dateKey,
        songs: aggregates,
      ),
    );
    dailyTotals.add(
      DailyListeningTotal(
        sourceId: sourceId,
        date: dateKey,
        starts: 24 + day,
        qualifiedPlays: 18 + day,
        completions: 14 + day,
        earlySkips: 2,
        listened: Duration(minutes: 74 + day * 5),
      ),
    );
  }
  final month = _dateKey(now).substring(0, 7);
  return ListeningAnalyticsSnapshot(
    installationId: sourceId,
    dailyBuckets: dailyBuckets,
    dailyTotals: dailyTotals,
    monthlyBuckets: [
      MonthlySongAggregate(
        sourceId: sourceId,
        month: month,
        songs: {
          for (var index = 0; index < _songs.length; index++)
            _songs[index].id: SongAnalyticsAggregate(
              song: _songs[index],
              starts: 18 - index,
              qualifiedPlays: 15 - index,
              completions: 11 - (index ~/ 2),
              earlySkips: index ~/ 3,
              listened: Duration(minutes: 96 - index * 7),
              lastPlayedAt: now.subtract(Duration(days: index)),
            ),
        },
      ),
    ],
    moodAssignments: {
      _songs[0].id: MoodAssignment(
        song: _songs[0],
        tags: const {MoodTag.chill},
      ),
      _songs[1].id: MoodAssignment(
        song: _songs[1],
        tags: const {MoodTag.chill},
      ),
      _songs[2].id: MoodAssignment(song: _songs[2], tags: const {MoodTag.gym}),
      _songs[3].id: MoodAssignment(
        song: _songs[3],
        tags: const {MoodTag.focus},
      ),
      _songs[4].id: MoodAssignment(
        song: _songs[4],
        tags: const {MoodTag.gym, MoodTag.focus},
      ),
    },
  );
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class _DocsAudioPlayer implements PlaybackAudioPlayer {
  final _states = StreamController<PlayerState>.broadcast(sync: true);
  final _durations = StreamController<Duration>.broadcast(sync: true);
  final _positions = StreamController<Duration>.broadcast(sync: true);
  final _completions = StreamController<void>.broadcast(sync: true);

  @override
  Stream<PlayerState> get onPlayerStateChanged => _states.stream;

  @override
  Stream<Duration> get onDurationChanged => _durations.stream;

  @override
  Stream<Duration> get onPositionChanged => _positions.stream;

  @override
  Stream<void> get onPlayerComplete => _completions.stream;

  @override
  Future<void> setAudioContext(AudioContext context) async {}

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {}

  @override
  Future<void> play(Source source) async => _states.add(PlayerState.playing);

  @override
  Future<void> pause() async => _states.add(PlayerState.paused);

  @override
  Future<void> stop() async {
    _states.add(PlayerState.stopped);
    _positions.add(Duration.zero);
  }

  @override
  Future<void> resume() async => _states.add(PlayerState.playing);

  @override
  Future<void> seek(Duration position) async => _positions.add(position);

  void emitDuration(Duration duration) => _durations.add(duration);

  void emitPosition(Duration position) => _positions.add(position);

  @override
  Future<void> dispose() async {
    await Future.wait([
      _states.close(),
      _durations.close(),
      _positions.close(),
      _completions.close(),
    ]);
  }
}
