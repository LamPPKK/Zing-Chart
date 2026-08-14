import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/listening_analytics_repository.dart';
import '../models/listening_analytics.dart';
import '../models/local_library.dart';
import '../models/song.dart';

typedef AnalyticsClock = DateTime Function();
typedef InstallationIdFactory = String Function();

class ListeningAnalyticsService extends ChangeNotifier {
  ListeningAnalyticsService({
    ListeningAnalyticsRepository? repository,
    AnalyticsClock? clock,
    InstallationIdFactory? installationIdFactory,
  }) : _repository =
           repository ?? SharedPreferencesListeningAnalyticsRepository(),
       _clock = clock ?? DateTime.now,
       _installationIdFactory = installationIdFactory ?? _createInstallationId;

  static const recentSongDays = 62;
  static const retainedMonths = 24;

  final ListeningAnalyticsRepository _repository;
  final AnalyticsClock _clock;
  final InstallationIdFactory _installationIdFactory;

  String _installationId = '';
  final Map<String, DailyListeningBucket> _dailyBuckets = {};
  final Map<String, DailyListeningTotal> _dailyTotals = {};
  final Map<String, MonthlySongAggregate> _monthlyBuckets = {};
  final Map<String, MoodAssignment> _moodAssignments = {};
  _ActiveListeningSession? _activeSession;
  Future<void> _saveQueue = Future<void>.value();
  ListeningAnalyticsSnapshot? _pendingSnapshot;
  bool _saveScheduled = false;

  String get installationId => _installationId;
  bool get hasActivity => snapshot.hasActivity;
  bool get hasActiveSession => _activeSession != null;

  ListeningAnalyticsSnapshot get snapshot => ListeningAnalyticsSnapshot(
    installationId: _installationId,
    dailyBuckets: _dailyBuckets.values.toList(growable: false),
    dailyTotals: _dailyTotals.values.toList(growable: false),
    monthlyBuckets: _monthlyBuckets.values.toList(growable: false),
    moodAssignments: Map.unmodifiable(_moodAssignments),
  );

  Future<void> initialize({
    List<ListeningRecord> legacyHistory = const [],
  }) async {
    final restored = await _repository.load();
    _installationId = restored?.installationId.trim().isNotEmpty == true
        ? restored!.installationId
        : _installationIdFactory();
    if (restored != null) _restore(restored);
    if (restored == null && legacyHistory.isNotEmpty) {
      _backfillLegacyHistory(legacyHistory);
    }
    _prune();
    await _scheduleSave();
  }

  void startSession(Song song) {
    if (song.id.isEmpty) return;
    finishSession(earlySkip: true);
    final now = _clock();
    _activeSession = _ActiveListeningSession(song: song);
    _increment(song, now, starts: 1);
    _changed();
  }

  void updateDuration(Duration duration) {
    final session = _activeSession;
    if (session == null || duration <= Duration.zero) return;
    session.duration = duration;
    _qualifyIfNeeded(session);
  }

  void recordProgress(Duration position) {
    final session = _activeSession;
    if (session == null) return;
    if (session.seekInProgress) return;
    final delta = position - session.lastPosition;
    session.lastPosition = position;
    if (delta <= Duration.zero) return;

    session.listened += delta;
    _increment(session.song, _clock(), listened: delta);
    final qualifiedBefore = session.qualified;
    _qualifyIfNeeded(session);
    final persistBucket = session.listened.inSeconds ~/ 5;
    if (qualifiedBefore != session.qualified ||
        persistBucket != session.lastPersistedBucket) {
      session.lastPersistedBucket = persistBucket;
      _changed();
    }
  }

  void beginSeek(Duration position) {
    final session = _activeSession;
    if (session == null) return;
    session.seekInProgress = true;
    session.lastPosition = position < Duration.zero ? Duration.zero : position;
  }

  void finishSeek(Duration position) {
    final session = _activeSession;
    if (session == null) return;
    session.lastPosition = position < Duration.zero ? Duration.zero : position;
    session.seekInProgress = false;
  }

  void completeSession() {
    final session = _activeSession;
    if (session == null) return;
    if (!session.qualified) {
      session.qualified = true;
      _increment(session.song, _clock(), qualifiedPlays: 1);
    }
    if (!session.completed) {
      session.completed = true;
      _increment(session.song, _clock(), completions: 1);
    }
    _activeSession = null;
    _changed();
  }

  void finishSession({required bool earlySkip}) {
    final session = _activeSession;
    if (session == null) return;
    if (earlySkip && !session.qualified && !session.completed) {
      _increment(session.song, _clock(), earlySkips: 1);
    }
    _activeSession = null;
    _changed();
  }

  Set<MoodTag> moodsFor(Song song) =>
      Set.unmodifiable(_moodAssignments[song.id]?.tags ?? const {});

  List<Song> songsForMood(MoodTag mood) => _moodAssignments.values
      .where((assignment) => assignment.tags.contains(mood))
      .map((assignment) => assignment.song)
      .toList(growable: false);

  bool toggleMood(Song song, MoodTag mood) {
    final current = _moodAssignments[song.id];
    final tags = {...?current?.tags};
    final added = tags.add(mood);
    if (!added) tags.remove(mood);
    if (tags.isEmpty) {
      _moodAssignments.remove(song.id);
    } else {
      _moodAssignments[song.id] = MoodAssignment(song: song, tags: tags);
    }
    _changed();
    return added;
  }

  AnalyticsSummary summary(AnalyticsPeriod period, {int? year, DateTime? now}) {
    final localNow = now ?? _clock();
    final end = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
      23,
      59,
      59,
    );
    final start = switch (period) {
      AnalyticsPeriod.sevenDays => DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
      ).subtract(const Duration(days: 6)),
      AnalyticsPeriod.thirtyDays => DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
      ).subtract(const Duration(days: 29)),
      AnalyticsPeriod.year => DateTime(year ?? localNow.year),
    };
    final rangeEnd = period == AnalyticsPeriod.year
        ? DateTime(
            (year ?? localNow.year) + 1,
          ).subtract(const Duration(microseconds: 1))
        : end;

    final totals = _combinedTotals(start, rangeEnd);
    final songs = period == AnalyticsPeriod.year
        ? _combinedMonthlySongs(start.year)
        : _combinedDailySongs(start, rangeEnd);
    final rankedSongs =
        songs.values
            .map((aggregate) => AnalyticsSongStat(aggregate: aggregate))
            .toList()
          ..sort((a, b) => _compareAggregates(a.aggregate, b.aggregate));
    final artists = _artistStats(songs.values);
    final busiestDay = totals.entries.isEmpty
        ? null
        : (totals.entries.toList()
                ..sort((a, b) => b.value.listened.compareTo(a.value.listened)))
              .first
              .key;

    final totalListened = totals.values.fold(
      Duration.zero,
      (total, bucket) => total + bucket.listened,
    );
    return AnalyticsSummary(
      period: period,
      start: start,
      end: rangeEnd,
      listened: totalListened,
      starts: totals.values.fold(0, (total, bucket) => total + bucket.starts),
      qualifiedPlays: totals.values.fold(
        0,
        (total, bucket) => total + bucket.qualifiedPlays,
      ),
      completions: totals.values.fold(
        0,
        (total, bucket) => total + bucket.completions,
      ),
      earlySkips: totals.values.fold(
        0,
        (total, bucket) => total + bucket.earlySkips,
      ),
      topSongs: List.unmodifiable(rankedSongs),
      topArtists: List.unmodifiable(artists),
      busiestDay: busiestDay == null ? null : DateTime.tryParse(busiestDay),
    );
  }

  WrappedSummary wrapped(int year) {
    final analytics = summary(AnalyticsPeriod.year, year: year);
    return WrappedSummary(
      year: year,
      listened: analytics.listened,
      qualifiedPlays: analytics.qualifiedPlays,
      completionRate: analytics.completionRate,
      topSongs: analytics.topSongs.take(5).toList(growable: false),
      topArtists: analytics.topArtists.take(5).toList(growable: false),
      busiestDay: analytics.busiestDay,
    );
  }

  SongAnalyticsAggregate? aggregateForSong(String songId) {
    SongAnalyticsAggregate? result;
    for (final bucket in _monthlyBuckets.values) {
      final aggregate = bucket.songs[songId];
      if (aggregate == null) continue;
      result = result == null ? aggregate : result.combine(aggregate);
    }
    return result;
  }

  Future<void> clearActivity() async {
    _activeSession = null;
    _dailyBuckets.clear();
    _dailyTotals.clear();
    _monthlyBuckets.clear();
    notifyListeners();
    await _scheduleSave();
  }

  Future<void> mergeSnapshot(ListeningAnalyticsSnapshot incoming) async {
    _mergeDailyBuckets(incoming.dailyBuckets);
    _mergeDailyTotals(incoming.dailyTotals);
    _mergeMonthlyBuckets(incoming.monthlyBuckets);
    for (final entry in incoming.moodAssignments.entries) {
      final current = _moodAssignments[entry.key];
      _moodAssignments[entry.key] = MoodAssignment(
        song: entry.value.song,
        tags: {...?current?.tags, ...entry.value.tags},
      );
    }
    _prune();
    notifyListeners();
    await _scheduleSave();
  }

  Future<void> overwriteSnapshot(ListeningAnalyticsSnapshot incoming) async {
    _dailyBuckets
      ..clear()
      ..addEntries(
        incoming.dailyBuckets.map((bucket) => MapEntry(bucket.key, bucket)),
      );
    _dailyTotals
      ..clear()
      ..addEntries(
        incoming.dailyTotals.map((bucket) => MapEntry(bucket.key, bucket)),
      );
    _monthlyBuckets
      ..clear()
      ..addEntries(
        incoming.monthlyBuckets.map((bucket) => MapEntry(bucket.key, bucket)),
      );
    _moodAssignments
      ..clear()
      ..addAll(incoming.moodAssignments);
    _activeSession = null;
    _prune();
    notifyListeners();
    await _scheduleSave();
  }

  void _qualifyIfNeeded(_ActiveListeningSession session) {
    if (session.qualified) return;
    final duration = session.duration;
    final threshold = duration > Duration.zero
        ? Duration(
            milliseconds: min(
              const Duration(seconds: 30).inMilliseconds,
              max(1, duration.inMilliseconds ~/ 2),
            ),
          )
        : const Duration(seconds: 30);
    if (session.listened < threshold) return;
    session.qualified = true;
    _increment(session.song, _clock(), qualifiedPlays: 1);
  }

  void _increment(
    Song song,
    DateTime occurredAt, {
    int starts = 0,
    int qualifiedPlays = 0,
    int completions = 0,
    int earlySkips = 0,
    Duration listened = Duration.zero,
  }) {
    final date = _dateKey(occurredAt);
    final month = _monthKey(occurredAt);
    final dailyKey = '$_installationId|$date';
    final monthlyKey = '$_installationId|$month';
    final lastPlayedAt = occurredAt.toUtc();

    final daily =
        _dailyBuckets[dailyKey] ??
        DailyListeningBucket(sourceId: _installationId, date: date);
    final dailySongs = {...daily.songs};
    dailySongs[song.id] =
        (dailySongs[song.id] ?? SongAnalyticsAggregate(song: song)).add(
          starts: starts,
          qualifiedPlays: qualifiedPlays,
          completions: completions,
          earlySkips: earlySkips,
          listened: listened,
          lastPlayedAt: lastPlayedAt,
        );
    _dailyBuckets[dailyKey] = DailyListeningBucket(
      sourceId: daily.sourceId,
      date: daily.date,
      songs: Map.unmodifiable(dailySongs),
    );

    _dailyTotals[dailyKey] =
        (_dailyTotals[dailyKey] ??
                DailyListeningTotal(sourceId: _installationId, date: date))
            .add(
              starts: starts,
              qualifiedPlays: qualifiedPlays,
              completions: completions,
              earlySkips: earlySkips,
              listened: listened,
            );

    final monthly =
        _monthlyBuckets[monthlyKey] ??
        MonthlySongAggregate(sourceId: _installationId, month: month);
    final monthlySongs = {...monthly.songs};
    monthlySongs[song.id] =
        (monthlySongs[song.id] ?? SongAnalyticsAggregate(song: song)).add(
          starts: starts,
          qualifiedPlays: qualifiedPlays,
          completions: completions,
          earlySkips: earlySkips,
          listened: listened,
          lastPlayedAt: lastPlayedAt,
        );
    _monthlyBuckets[monthlyKey] = MonthlySongAggregate(
      sourceId: monthly.sourceId,
      month: monthly.month,
      songs: Map.unmodifiable(monthlySongs),
    );
  }

  void _backfillLegacyHistory(List<ListeningRecord> history) {
    for (final record in history) {
      if (record.song.id.isEmpty) continue;
      _increment(
        record.song,
        record.playedAt.toLocal(),
        starts: 1,
        listened: record.listened,
      );
    }
  }

  void _restore(ListeningAnalyticsSnapshot restored) {
    _dailyBuckets.addEntries(
      restored.dailyBuckets.map((bucket) => MapEntry(bucket.key, bucket)),
    );
    _dailyTotals.addEntries(
      restored.dailyTotals.map((bucket) => MapEntry(bucket.key, bucket)),
    );
    _monthlyBuckets.addEntries(
      restored.monthlyBuckets.map((bucket) => MapEntry(bucket.key, bucket)),
    );
    _moodAssignments.addAll(restored.moodAssignments);
  }

  void _prune() {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final dailySongCutoff = today.subtract(
      const Duration(days: recentSongDays - 1),
    );
    final monthCutoff = DateTime(now.year, now.month - (retainedMonths - 1));
    _dailyBuckets.removeWhere(
      (_, bucket) => (DateTime.tryParse(bucket.date) ?? DateTime(1970))
          .isBefore(dailySongCutoff),
    );
    _dailyTotals.removeWhere(
      (_, bucket) => (DateTime.tryParse(bucket.date) ?? DateTime(1970))
          .isBefore(monthCutoff),
    );
    _monthlyBuckets.removeWhere(
      (_, bucket) => (DateTime.tryParse('${bucket.month}-01') ?? DateTime(1970))
          .isBefore(monthCutoff),
    );
  }

  Map<String, DailyListeningTotal> _combinedTotals(
    DateTime start,
    DateTime end,
  ) {
    final result = <String, DailyListeningTotal>{};
    for (final bucket in _dailyTotals.values) {
      final date = DateTime.tryParse(bucket.date);
      if (date == null || date.isBefore(start) || date.isAfter(end)) continue;
      final current = result[bucket.date];
      result[bucket.date] = current == null
          ? bucket
          : DailyListeningTotal(
              sourceId: 'combined',
              date: bucket.date,
              starts: current.starts + bucket.starts,
              qualifiedPlays: current.qualifiedPlays + bucket.qualifiedPlays,
              completions: current.completions + bucket.completions,
              earlySkips: current.earlySkips + bucket.earlySkips,
              listened: current.listened + bucket.listened,
            );
    }
    return result;
  }

  Map<String, SongAnalyticsAggregate> _combinedDailySongs(
    DateTime start,
    DateTime end,
  ) {
    final result = <String, SongAnalyticsAggregate>{};
    for (final bucket in _dailyBuckets.values) {
      final date = DateTime.tryParse(bucket.date);
      if (date == null || date.isBefore(start) || date.isAfter(end)) continue;
      _combineSongMap(result, bucket.songs);
    }
    return result;
  }

  Map<String, SongAnalyticsAggregate> _combinedMonthlySongs(int year) {
    final result = <String, SongAnalyticsAggregate>{};
    for (final bucket in _monthlyBuckets.values) {
      if (!bucket.month.startsWith('$year-')) continue;
      _combineSongMap(result, bucket.songs);
    }
    return result;
  }

  List<AnalyticsArtistStat> _artistStats(
    Iterable<SongAnalyticsAggregate> songs,
  ) {
    final values = <String, _MutableArtistAnalytics>{};
    for (final aggregate in songs) {
      final artists = aggregate.song.artistsNames
          .split(RegExp(r'\s*[,;&]\s*'))
          .where((artist) => artist.trim().isNotEmpty);
      for (final artist in artists) {
        final value = values.putIfAbsent(
          artist.toLowerCase(),
          () => _MutableArtistAnalytics(artist),
        );
        value.qualifiedPlays += aggregate.qualifiedPlays;
        value.completions += aggregate.completions;
        value.earlySkips += aggregate.earlySkips;
        value.listened += aggregate.listened;
      }
    }
    final result =
        values.values
            .map(
              (value) => AnalyticsArtistStat(
                artist: value.artist,
                qualifiedPlays: value.qualifiedPlays,
                completions: value.completions,
                earlySkips: value.earlySkips,
                listened: value.listened,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byPlays = b.qualifiedPlays.compareTo(a.qualifiedPlays);
            return byPlays != 0 ? byPlays : b.listened.compareTo(a.listened);
          });
    return result;
  }

  void _mergeDailyBuckets(Iterable<DailyListeningBucket> buckets) {
    for (final incoming in buckets) {
      final current = _dailyBuckets[incoming.key];
      if (current == null) {
        _dailyBuckets[incoming.key] = incoming;
        continue;
      }
      final songs = {...current.songs};
      for (final entry in incoming.songs.entries) {
        songs[entry.key] =
            songs[entry.key]?.mergeMonotonic(entry.value) ?? entry.value;
      }
      _dailyBuckets[incoming.key] = DailyListeningBucket(
        sourceId: incoming.sourceId,
        date: incoming.date,
        songs: Map.unmodifiable(songs),
      );
    }
  }

  void _mergeDailyTotals(Iterable<DailyListeningTotal> buckets) {
    for (final incoming in buckets) {
      _dailyTotals[incoming.key] =
          _dailyTotals[incoming.key]?.mergeMonotonic(incoming) ?? incoming;
    }
  }

  void _mergeMonthlyBuckets(Iterable<MonthlySongAggregate> buckets) {
    for (final incoming in buckets) {
      final current = _monthlyBuckets[incoming.key];
      if (current == null) {
        _monthlyBuckets[incoming.key] = incoming;
        continue;
      }
      final songs = {...current.songs};
      for (final entry in incoming.songs.entries) {
        songs[entry.key] =
            songs[entry.key]?.mergeMonotonic(entry.value) ?? entry.value;
      }
      _monthlyBuckets[incoming.key] = MonthlySongAggregate(
        sourceId: incoming.sourceId,
        month: incoming.month,
        songs: Map.unmodifiable(songs),
      );
    }
  }

  void _changed() {
    _prune();
    notifyListeners();
    unawaited(_scheduleSave());
  }

  Future<void> _scheduleSave() {
    _pendingSnapshot = snapshot;
    if (!_saveScheduled) {
      _saveScheduled = true;
      _saveQueue = _saveQueue.then((_) => _drainSaves());
    }
    return _saveQueue;
  }

  Future<void> _drainSaves() async {
    while (_pendingSnapshot != null) {
      final next = _pendingSnapshot!;
      _pendingSnapshot = null;
      try {
        await _repository.save(next);
      } catch (_) {
        // Analytics must never make playback unavailable.
      }
    }
    _saveScheduled = false;
  }

  @override
  void dispose() {
    finishSession(earlySkip: false);
    unawaited(_scheduleSave());
    super.dispose();
  }
}

class _ActiveListeningSession {
  _ActiveListeningSession({required this.song});

  final Song song;
  Duration duration = Duration.zero;
  Duration listened = Duration.zero;
  Duration lastPosition = Duration.zero;
  bool qualified = false;
  bool completed = false;
  int lastPersistedBucket = -1;
  bool seekInProgress = false;
}

class _MutableArtistAnalytics {
  _MutableArtistAnalytics(this.artist);

  final String artist;
  int qualifiedPlays = 0;
  int completions = 0;
  int earlySkips = 0;
  Duration listened = Duration.zero;
}

void _combineSongMap(
  Map<String, SongAnalyticsAggregate> target,
  Map<String, SongAnalyticsAggregate> source,
) {
  for (final entry in source.entries) {
    target[entry.key] = target[entry.key]?.combine(entry.value) ?? entry.value;
  }
}

int _compareAggregates(
  SongAnalyticsAggregate first,
  SongAnalyticsAggregate second,
) {
  final byPlays = second.qualifiedPlays.compareTo(first.qualifiedPlays);
  if (byPlays != 0) return byPlays;
  return second.listened.compareTo(first.listened);
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _monthKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}';

String _createInstallationId() {
  final random = Random.secure();
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final entropy = List.generate(
    12,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  return 'install-$time-$entropy';
}
