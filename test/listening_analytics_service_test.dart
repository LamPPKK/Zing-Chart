import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/listening_analytics_repository.dart';
import 'package:zmp3chart/models/listening_analytics.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/services/listening_analytics_service.dart';

void main() {
  const song = Song(
    id: 'song-one',
    name: 'song-one',
    title: 'Bài Một',
    thumbnail: '',
    artistsNames: 'Ca sĩ A',
    code: 'code-one',
  );
  final now = DateTime(2026, 8, 15, 10);

  test('qualifies at 30 seconds and records completion once', () async {
    final repository = MemoryListeningAnalyticsRepository();
    final analytics = ListeningAnalyticsService(
      repository: repository,
      clock: () => now,
      installationIdFactory: () => 'install-a',
    );
    await analytics.initialize();

    analytics.startSession(song);
    analytics.updateDuration(const Duration(minutes: 2));
    for (var seconds = 5; seconds <= 30; seconds += 5) {
      analytics.recordProgress(Duration(seconds: seconds));
    }
    analytics.completeSession();
    analytics.completeSession();

    final summary = analytics.summary(AnalyticsPeriod.sevenDays, now: now);
    expect(summary.listened, const Duration(seconds: 30));
    expect(summary.starts, 1);
    expect(summary.qualifiedPlays, 1);
    expect(summary.completions, 1);
    expect(summary.earlySkips, 0);
    analytics.dispose();
  });

  test('ignores seek jumps and only marks an early explicit skip', () async {
    final analytics = ListeningAnalyticsService(
      repository: MemoryListeningAnalyticsRepository(),
      clock: () => now,
      installationIdFactory: () => 'install-a',
    );
    await analytics.initialize();

    analytics.startSession(song);
    analytics.updateDuration(const Duration(minutes: 3));
    analytics.recordProgress(const Duration(seconds: 5));
    analytics.beginSeek(const Duration(seconds: 80));
    analytics.recordProgress(const Duration(seconds: 80));
    analytics.finishSeek(const Duration(seconds: 80));
    analytics.recordProgress(const Duration(seconds: 83));
    analytics.finishSession(earlySkip: true);

    final summary = analytics.summary(AnalyticsPeriod.sevenDays, now: now);
    expect(summary.listened, const Duration(seconds: 8));
    expect(summary.qualifiedPlays, 0);
    expect(summary.earlySkips, 1);
    analytics.dispose();
  });

  test(
    'pause gaps add no time and resume continues from player position',
    () async {
      final analytics = ListeningAnalyticsService(
        repository: MemoryListeningAnalyticsRepository(),
        clock: () => now,
        installationIdFactory: () => 'install-a',
      );
      await analytics.initialize();

      analytics.startSession(song);
      analytics.updateDuration(const Duration(minutes: 3));
      analytics.recordProgress(const Duration(seconds: 5));
      // Paused time emits no position changes and therefore adds nothing.
      analytics.recordProgress(const Duration(seconds: 10));
      analytics.beginSeek(const Duration(seconds: 90));
      analytics.recordProgress(const Duration(seconds: 90)); // seek
      analytics.finishSeek(const Duration(seconds: 90));
      analytics.recordProgress(const Duration(seconds: 95));
      analytics.finishSession(earlySkip: false); // stop is neutral

      final summary = analytics.summary(AnalyticsPeriod.sevenDays, now: now);
      expect(summary.listened, const Duration(seconds: 15));
      expect(summary.earlySkips, 0);
      analytics.dispose();
    },
  );

  test(
    'splits listened time by local day when a session crosses midnight',
    () async {
      var clock = DateTime(2026, 8, 15, 23, 59, 58);
      final analytics = ListeningAnalyticsService(
        repository: MemoryListeningAnalyticsRepository(),
        clock: () => clock,
        installationIdFactory: () => 'install-a',
      );
      await analytics.initialize();

      analytics.startSession(song);
      analytics.updateDuration(const Duration(minutes: 2));
      analytics.recordProgress(const Duration(seconds: 5));
      clock = DateTime(2026, 8, 16, 0, 0, 3);
      analytics.recordProgress(const Duration(seconds: 10));
      analytics.finishSession(earlySkip: false);

      final buckets = {
        for (final bucket in analytics.snapshot.dailyTotals)
          bucket.date: bucket,
      };
      expect(buckets['2026-08-15']?.listened, const Duration(seconds: 5));
      expect(buckets['2026-08-16']?.listened, const Duration(seconds: 5));
      analytics.dispose();
    },
  );

  test(
    'counts delayed background progress events when no seek occurred',
    () async {
      final analytics = ListeningAnalyticsService(
        repository: MemoryListeningAnalyticsRepository(),
        clock: () => now,
        installationIdFactory: () => 'install-a',
      );
      await analytics.initialize();

      analytics.startSession(song);
      analytics.updateDuration(const Duration(minutes: 3));
      analytics.recordProgress(const Duration(seconds: 5));
      analytics.recordProgress(const Duration(seconds: 20));
      analytics.finishSession(earlySkip: false);

      expect(
        analytics.summary(AnalyticsPeriod.sevenDays, now: now).listened,
        const Duration(seconds: 20),
      );
      analytics.dispose();
    },
  );

  test('backfills legacy time without inventing completion or skip', () async {
    final analytics = ListeningAnalyticsService(
      repository: MemoryListeningAnalyticsRepository(),
      clock: () => now,
      installationIdFactory: () => 'install-a',
    );
    await analytics.initialize(
      legacyHistory: [
        ListeningRecord(
          id: 'legacy',
          song: song,
          playedAt: now.toUtc(),
          listened: const Duration(minutes: 3),
        ),
      ],
    );

    final summary = analytics.summary(AnalyticsPeriod.year, year: 2026);
    expect(summary.listened, const Duration(minutes: 3));
    expect(summary.starts, 1);
    expect(summary.qualifiedPlays, 0);
    expect(summary.completions, 0);
    expect(summary.earlySkips, 0);
    analytics.dispose();
  });

  test('retains 62 daily-song days and 24 aggregate months', () async {
    SongAnalyticsAggregate aggregate(String id) => SongAnalyticsAggregate(
      song: Song(
        id: id,
        name: id,
        title: id,
        thumbnail: '',
        artistsNames: 'Artist',
        code: id,
      ),
      starts: 1,
      listened: const Duration(minutes: 1),
    );

    final snapshot = ListeningAnalyticsSnapshot(
      installationId: 'install-a',
      dailyBuckets: [
        DailyListeningBucket(
          sourceId: 'install-a',
          date: '2026-06-14',
          songs: {'old-day': aggregate('old-day')},
        ),
        DailyListeningBucket(
          sourceId: 'install-a',
          date: '2026-06-15',
          songs: {'kept-day': aggregate('kept-day')},
        ),
      ],
      dailyTotals: const [
        DailyListeningTotal(sourceId: 'install-a', date: '2024-08-31'),
        DailyListeningTotal(sourceId: 'install-a', date: '2024-09-01'),
      ],
      monthlyBuckets: [
        MonthlySongAggregate(
          sourceId: 'install-a',
          month: '2024-08',
          songs: {'old-month': aggregate('old-month')},
        ),
        MonthlySongAggregate(
          sourceId: 'install-a',
          month: '2024-09',
          songs: {'kept-month': aggregate('kept-month')},
        ),
      ],
    );
    final repository = MemoryListeningAnalyticsRepository(snapshot);
    final analytics = ListeningAnalyticsService(
      repository: repository,
      clock: () => now,
    );
    await analytics.initialize();

    expect(analytics.snapshot.dailyBuckets.map((bucket) => bucket.date), [
      '2026-06-15',
    ]);
    expect(analytics.snapshot.dailyTotals.map((bucket) => bucket.date), [
      '2024-09-01',
    ]);
    expect(analytics.snapshot.monthlyBuckets.map((bucket) => bucket.month), [
      '2024-09',
    ]);
    analytics.dispose();
  });

  test('backup merge is idempotent and unions mood tags', () async {
    final analytics = ListeningAnalyticsService(
      repository: MemoryListeningAnalyticsRepository(),
      clock: () => now,
      installationIdFactory: () => 'install-local',
    );
    await analytics.initialize();
    const aggregate = SongAnalyticsAggregate(
      song: song,
      starts: 2,
      qualifiedPlays: 1,
      listened: Duration(minutes: 2),
    );
    const incoming = ListeningAnalyticsSnapshot(
      installationId: 'install-remote',
      dailyBuckets: [
        DailyListeningBucket(
          sourceId: 'install-remote',
          date: '2026-08-15',
          songs: {'song-one': aggregate},
        ),
      ],
      dailyTotals: [
        DailyListeningTotal(
          sourceId: 'install-remote',
          date: '2026-08-15',
          starts: 2,
          qualifiedPlays: 1,
          listened: Duration(minutes: 2),
        ),
      ],
      monthlyBuckets: [
        MonthlySongAggregate(
          sourceId: 'install-remote',
          month: '2026-08',
          songs: {'song-one': aggregate},
        ),
      ],
      moodAssignments: {
        'song-one': MoodAssignment(song: song, tags: {MoodTag.chill}),
      },
    );

    await analytics.mergeSnapshot(incoming);
    await analytics.mergeSnapshot(incoming);

    final summary = analytics.summary(AnalyticsPeriod.sevenDays, now: now);
    expect(summary.listened, const Duration(minutes: 2));
    expect(summary.qualifiedPlays, 1);
    expect(analytics.moodsFor(song), {MoodTag.chill});
    expect(analytics.installationId, 'install-local');
    analytics.dispose();
  });

  test('backup overwrite keeps the active installation identity', () async {
    final analytics = ListeningAnalyticsService(
      repository: MemoryListeningAnalyticsRepository(),
      clock: () => now,
      installationIdFactory: () => 'install-local',
    );
    await analytics.initialize();
    const incoming = ListeningAnalyticsSnapshot(
      installationId: 'install-remote',
      dailyTotals: [
        DailyListeningTotal(
          sourceId: 'install-remote',
          date: '2026-08-15',
          qualifiedPlays: 2,
          listened: Duration(minutes: 3),
        ),
      ],
    );

    await analytics.overwriteSnapshot(incoming);

    expect(analytics.installationId, 'install-local');
    expect(
      analytics.summary(AnalyticsPeriod.sevenDays, now: now).qualifiedPlays,
      2,
    );
    analytics.dispose();
  });
}
