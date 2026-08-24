import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/listening_analytics_repository.dart';
import 'package:zmp3chart/models/listening_analytics.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/services/listening_analytics_service.dart';
import 'package:zmp3chart/services/local_mix_engine.dart';

void main() {
  final now = DateTime(2026, 8, 15, 10);
  final songs = List.generate(
    10,
    (index) => Song(
      id: 'song-$index',
      name: 'song-$index',
      title: 'Bài $index',
      thumbnail: '',
      artistsNames: index < 4 ? 'Cùng nghệ sĩ' : 'Nghệ sĩ $index',
      code: 'code-$index',
    ),
  );

  test('daily mix is deterministic, unique and artist-diverse', () async {
    final analytics = ListeningAnalyticsService(
      repository: MemoryListeningAnalyticsRepository(),
      clock: () => now,
      installationIdFactory: () => 'install-a',
    );
    await analytics.initialize();
    final engine = LocalMixEngine();

    final first = engine.buildDailyMix(
      candidates: songs,
      likedSongIds: songs.map((song) => song.id).toSet(),
      analytics: analytics,
      now: now,
    );
    final second = engine.buildDailyMix(
      candidates: songs,
      likedSongIds: songs.map((song) => song.id).toSet(),
      analytics: analytics,
      now: now,
    );

    expect(
      first.songs.map((song) => song.id),
      second.songs.map((song) => song.id),
    );
    expect(
      first.songs.map((song) => song.id).toSet(),
      hasLength(first.songs.length),
    );
    expect(
      first.songs.where((song) => song.artistsNames == 'Cùng nghệ sĩ'),
      hasLength(2),
    );
    analytics.dispose();
  });

  test('cold start keeps favorites first then follows chart order', () async {
    final analytics = ListeningAnalyticsService(
      repository: MemoryListeningAnalyticsRepository(),
      clock: () => now,
      installationIdFactory: () => 'install-a',
    );
    await analytics.initialize();

    final mix = const LocalMixEngine().buildDailyMix(
      candidates: songs,
      likedSongIds: {songs[4].id, songs[6].id},
      analytics: analytics,
      now: now,
    );

    expect(mix.isColdStart, isTrue);
    expect(mix.songs.take(2).map((song) => song.id), ['song-4', 'song-6']);
    expect(mix.songs[2].id, 'song-0');
    analytics.dispose();
  });

  test('profile signals refresh the deterministic order', () async {
    final analytics = ListeningAnalyticsService(
      repository: MemoryListeningAnalyticsRepository(),
      clock: () => now,
      installationIdFactory: () => 'install-a',
    );
    await analytics.initialize();
    final engine = LocalMixEngine();
    final liked = songs.take(4).map((song) => song.id).toSet();
    final beforeMix = engine.buildDailyMix(
      candidates: songs,
      likedSongIds: liked,
      analytics: analytics,
      now: now,
    );
    final before = beforeMix.songs.map((song) => song.id).toList();

    analytics.toggleMood(songs[8], MoodTag.focus);
    final afterMix = engine.buildDailyMix(
      candidates: songs,
      likedSongIds: liked,
      analytics: analytics,
      now: now,
    );
    final after = afterMix.songs.map((song) => song.id).toList();

    expect(afterMix.id, isNot(beforeMix.id));
    expect(after, isNot(before));
    analytics.dispose();
  });

  test(
    'smart shuffle uses only current catalog, excludes queue and stays stable',
    () async {
      final analytics = ListeningAnalyticsService(
        repository: MemoryListeningAnalyticsRepository(),
        clock: () => now,
        installationIdFactory: () => 'install-smart',
      );
      await analytics.initialize();
      final engine = LocalMixEngine();
      final queue = songs.take(3).toList(growable: false);

      final first = engine.buildSmartShuffle(
        queue: queue,
        catalog: songs,
        likedSongIds: {songs[7].id},
        analytics: analytics,
        now: now,
      );
      final second = engine.buildSmartShuffle(
        queue: queue,
        catalog: songs,
        likedSongIds: {songs[7].id},
        analytics: analytics,
        now: now,
      );

      expect(first, hasLength(1));
      expect(first.map((song) => song.id), second.map((song) => song.id));
      expect(
        first.map((song) => song.id).toSet().intersection({
          ...queue.map((song) => song.id),
        }),
        isEmpty,
      );
      expect(songs.map((song) => song.id), contains(first.single.id));
      analytics.dispose();
    },
  );

  test(
    'smart shuffle rejects catalog entries without a playable code',
    () async {
      final analytics = ListeningAnalyticsService(
        repository: MemoryListeningAnalyticsRepository(),
        clock: () => now,
        installationIdFactory: () => 'install-smart-locked',
      );
      await analytics.initialize();
      final locked = Song(
        id: 'locked',
        name: 'locked',
        title: 'Bị giới hạn',
        thumbnail: '',
        artistsNames: 'Nghệ sĩ khóa',
        code: '',
      );

      final suggestions = const LocalMixEngine().buildSmartShuffle(
        queue: [songs.first],
        catalog: [locked],
        likedSongIds: const {},
        analytics: analytics,
        now: now,
      );

      expect(suggestions, isEmpty);
      analytics.dispose();
    },
  );

  test(
    'mood mix starts with explicit tags and expands positive artists',
    () async {
      final analytics = ListeningAnalyticsService(
        repository: MemoryListeningAnalyticsRepository(),
        clock: () => now,
        installationIdFactory: () => 'install-a',
      );
      await analytics.initialize();
      analytics.toggleMood(songs.first, MoodTag.chill);
      analytics.startSession(songs[1]);
      analytics.updateDuration(const Duration(seconds: 8));
      analytics.recordProgress(const Duration(seconds: 4));
      analytics.completeSession();

      final mix = const LocalMixEngine().buildMoodMix(
        mood: MoodTag.chill,
        candidates: songs,
        likedSongIds: const {},
        analytics: analytics,
        now: now,
      );

      expect(mix.songs.first.id, songs.first.id);
      expect(mix.songs.map((song) => song.id), contains(songs[1].id));
      expect(mix.mood, MoodTag.chill);
      analytics.dispose();
    },
  );
}
