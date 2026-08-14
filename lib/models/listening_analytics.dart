import 'dart:convert';

import 'song.dart';

enum AnalyticsPeriod { sevenDays, thirtyDays, year }

enum MoodTag { chill, gym, focus }

class SongAnalyticsAggregate {
  const SongAnalyticsAggregate({
    required this.song,
    this.starts = 0,
    this.qualifiedPlays = 0,
    this.completions = 0,
    this.earlySkips = 0,
    this.listened = Duration.zero,
    this.lastPlayedAt,
  });

  final Song song;
  final int starts;
  final int qualifiedPlays;
  final int completions;
  final int earlySkips;
  final Duration listened;
  final DateTime? lastPlayedAt;

  SongAnalyticsAggregate add({
    int starts = 0,
    int qualifiedPlays = 0,
    int completions = 0,
    int earlySkips = 0,
    Duration listened = Duration.zero,
    DateTime? lastPlayedAt,
  }) => SongAnalyticsAggregate(
    song: song,
    starts: this.starts + starts,
    qualifiedPlays: this.qualifiedPlays + qualifiedPlays,
    completions: this.completions + completions,
    earlySkips: this.earlySkips + earlySkips,
    listened: this.listened + listened,
    lastPlayedAt: _latest(this.lastPlayedAt, lastPlayedAt),
  );

  SongAnalyticsAggregate combine(SongAnalyticsAggregate other) =>
      SongAnalyticsAggregate(
        song: song.id.isNotEmpty ? song : other.song,
        starts: starts + other.starts,
        qualifiedPlays: qualifiedPlays + other.qualifiedPlays,
        completions: completions + other.completions,
        earlySkips: earlySkips + other.earlySkips,
        listened: listened + other.listened,
        lastPlayedAt: _latest(lastPlayedAt, other.lastPlayedAt),
      );

  SongAnalyticsAggregate mergeMonotonic(SongAnalyticsAggregate other) =>
      SongAnalyticsAggregate(
        song: other.song.id.isNotEmpty ? other.song : song,
        starts: starts > other.starts ? starts : other.starts,
        qualifiedPlays: qualifiedPlays > other.qualifiedPlays
            ? qualifiedPlays
            : other.qualifiedPlays,
        completions: completions > other.completions
            ? completions
            : other.completions,
        earlySkips: earlySkips > other.earlySkips
            ? earlySkips
            : other.earlySkips,
        listened: listened > other.listened ? listened : other.listened,
        lastPlayedAt: _latest(lastPlayedAt, other.lastPlayedAt),
      );

  Map<String, dynamic> toJson() => {
    'song': song.toJson(),
    's': starts,
    'q': qualifiedPlays,
    'c': completions,
    'k': earlySkips,
    'ms': listened.inMilliseconds,
    if (lastPlayedAt != null) 'last': lastPlayedAt!.toUtc().toIso8601String(),
  };

  factory SongAnalyticsAggregate.fromJson(Map<String, dynamic> json) {
    final songJson = json['song'];
    return SongAnalyticsAggregate(
      song: songJson is Map<String, dynamic>
          ? Song.fromJson(songJson)
          : _emptySong,
      starts: _safeCount(json['s']),
      qualifiedPlays: _safeCount(json['q']),
      completions: _safeCount(json['c']),
      earlySkips: _safeCount(json['k']),
      listened: Duration(milliseconds: _safeMilliseconds(json['ms'])),
      lastPlayedAt: DateTime.tryParse(json['last']?.toString() ?? ''),
    );
  }
}

class DailyListeningBucket {
  const DailyListeningBucket({
    required this.sourceId,
    required this.date,
    this.songs = const {},
  });

  final String sourceId;
  final String date;
  final Map<String, SongAnalyticsAggregate> songs;

  String get key => '$sourceId|$date';

  Map<String, dynamic> toJson() => {
    'source': sourceId,
    'date': date,
    'songs': songs.map((id, value) => MapEntry(id, value.toJson())),
  };

  factory DailyListeningBucket.fromJson(Map<String, dynamic> json) =>
      DailyListeningBucket(
        sourceId: json['source']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        songs: _readAggregateMap(json['songs']),
      );
}

class DailyListeningTotal {
  const DailyListeningTotal({
    required this.sourceId,
    required this.date,
    this.starts = 0,
    this.qualifiedPlays = 0,
    this.completions = 0,
    this.earlySkips = 0,
    this.listened = Duration.zero,
  });

  final String sourceId;
  final String date;
  final int starts;
  final int qualifiedPlays;
  final int completions;
  final int earlySkips;
  final Duration listened;

  String get key => '$sourceId|$date';

  DailyListeningTotal add({
    int starts = 0,
    int qualifiedPlays = 0,
    int completions = 0,
    int earlySkips = 0,
    Duration listened = Duration.zero,
  }) => DailyListeningTotal(
    sourceId: sourceId,
    date: date,
    starts: this.starts + starts,
    qualifiedPlays: this.qualifiedPlays + qualifiedPlays,
    completions: this.completions + completions,
    earlySkips: this.earlySkips + earlySkips,
    listened: this.listened + listened,
  );

  DailyListeningTotal mergeMonotonic(DailyListeningTotal other) =>
      DailyListeningTotal(
        sourceId: sourceId,
        date: date,
        starts: starts > other.starts ? starts : other.starts,
        qualifiedPlays: qualifiedPlays > other.qualifiedPlays
            ? qualifiedPlays
            : other.qualifiedPlays,
        completions: completions > other.completions
            ? completions
            : other.completions,
        earlySkips: earlySkips > other.earlySkips
            ? earlySkips
            : other.earlySkips,
        listened: listened > other.listened ? listened : other.listened,
      );

  Map<String, dynamic> toJson() => {
    'source': sourceId,
    'date': date,
    's': starts,
    'q': qualifiedPlays,
    'c': completions,
    'k': earlySkips,
    'ms': listened.inMilliseconds,
  };

  factory DailyListeningTotal.fromJson(Map<String, dynamic> json) =>
      DailyListeningTotal(
        sourceId: json['source']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        starts: _safeCount(json['s']),
        qualifiedPlays: _safeCount(json['q']),
        completions: _safeCount(json['c']),
        earlySkips: _safeCount(json['k']),
        listened: Duration(milliseconds: _safeMilliseconds(json['ms'])),
      );
}

class MonthlySongAggregate {
  const MonthlySongAggregate({
    required this.sourceId,
    required this.month,
    this.songs = const {},
  });

  final String sourceId;
  final String month;
  final Map<String, SongAnalyticsAggregate> songs;

  String get key => '$sourceId|$month';

  Map<String, dynamic> toJson() => {
    'source': sourceId,
    'month': month,
    'songs': songs.map((id, value) => MapEntry(id, value.toJson())),
  };

  factory MonthlySongAggregate.fromJson(Map<String, dynamic> json) =>
      MonthlySongAggregate(
        sourceId: json['source']?.toString() ?? '',
        month: json['month']?.toString() ?? '',
        songs: _readAggregateMap(json['songs']),
      );
}

class MoodAssignment {
  const MoodAssignment({required this.song, this.tags = const {}});

  final Song song;
  final Set<MoodTag> tags;

  Map<String, dynamic> toJson() => {
    'song': song.toJson(),
    'tags': tags.map((tag) => tag.name).toList(growable: false),
  };

  factory MoodAssignment.fromJson(Map<String, dynamic> json) {
    final songJson = json['song'];
    final rawTags = json['tags'];
    return MoodAssignment(
      song: songJson is Map<String, dynamic>
          ? Song.fromJson(songJson)
          : _emptySong,
      tags: rawTags is List
          ? rawTags
                .whereType<String>()
                .map((name) => MoodTag.values.where((tag) => tag.name == name))
                .where((matches) => matches.isNotEmpty)
                .map((matches) => matches.first)
                .toSet()
          : const {},
    );
  }
}

class ListeningAnalyticsSnapshot {
  const ListeningAnalyticsSnapshot({
    required this.installationId,
    this.dailyBuckets = const [],
    this.dailyTotals = const [],
    this.monthlyBuckets = const [],
    this.moodAssignments = const {},
  });

  final String installationId;
  final List<DailyListeningBucket> dailyBuckets;
  final List<DailyListeningTotal> dailyTotals;
  final List<MonthlySongAggregate> monthlyBuckets;
  final Map<String, MoodAssignment> moodAssignments;

  bool get hasActivity =>
      dailyTotals.any(
        (bucket) =>
            bucket.listened > Duration.zero || bucket.qualifiedPlays > 0,
      ) ||
      monthlyBuckets.any((bucket) => bucket.songs.isNotEmpty);

  Map<String, dynamic> toJson() => {
    'version': 1,
    'installationId': installationId,
    'daily': dailyBuckets.map((bucket) => bucket.toJson()).toList(),
    'totals': dailyTotals.map((bucket) => bucket.toJson()).toList(),
    'monthly': monthlyBuckets.map((bucket) => bucket.toJson()).toList(),
    'moods': moodAssignments.map(
      (id, assignment) => MapEntry(id, assignment.toJson()),
    ),
  };

  factory ListeningAnalyticsSnapshot.fromJson(Map<String, dynamic> json) {
    final installationId = json['installationId'];
    if (json['version'] != 1 ||
        installationId is! String ||
        installationId.trim().isEmpty ||
        (json.containsKey('daily') && json['daily'] is! List) ||
        (json.containsKey('totals') && json['totals'] is! List) ||
        (json.containsKey('monthly') && json['monthly'] is! List) ||
        (json.containsKey('moods') && json['moods'] is! Map<String, dynamic>)) {
      throw const FormatException('Dữ liệu analytics local không hợp lệ.');
    }
    final moods = <String, MoodAssignment>{};
    final rawMoods = json['moods'];
    if (rawMoods is Map<String, dynamic>) {
      for (final entry in rawMoods.entries) {
        if (entry.value is! Map<String, dynamic>) continue;
        final assignment = MoodAssignment.fromJson(
          entry.value as Map<String, dynamic>,
        );
        if (assignment.song.id.isNotEmpty && assignment.tags.isNotEmpty) {
          moods[entry.key] = assignment;
        }
      }
    }
    return ListeningAnalyticsSnapshot(
      installationId: installationId,
      dailyBuckets: _readMaps(json['daily'])
          .map(DailyListeningBucket.fromJson)
          .where(
            (bucket) => bucket.sourceId.isNotEmpty && _validDate(bucket.date),
          )
          .toList(growable: false),
      dailyTotals: _readMaps(json['totals'])
          .map(DailyListeningTotal.fromJson)
          .where(
            (bucket) => bucket.sourceId.isNotEmpty && _validDate(bucket.date),
          )
          .toList(growable: false),
      monthlyBuckets: _readMaps(json['monthly'])
          .map(MonthlySongAggregate.fromJson)
          .where(
            (bucket) => bucket.sourceId.isNotEmpty && _validMonth(bucket.month),
          )
          .toList(growable: false),
      moodAssignments: moods,
    );
  }

  String encode() => jsonEncode(toJson());
}

class AnalyticsSongStat {
  const AnalyticsSongStat({required this.aggregate});

  final SongAnalyticsAggregate aggregate;
  Song get song => aggregate.song;
}

class AnalyticsArtistStat {
  const AnalyticsArtistStat({
    required this.artist,
    required this.qualifiedPlays,
    required this.completions,
    required this.earlySkips,
    required this.listened,
  });

  final String artist;
  final int qualifiedPlays;
  final int completions;
  final int earlySkips;
  final Duration listened;
}

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.period,
    required this.start,
    required this.end,
    required this.listened,
    required this.starts,
    required this.qualifiedPlays,
    required this.completions,
    required this.earlySkips,
    required this.topSongs,
    required this.topArtists,
    this.busiestDay,
  });

  final AnalyticsPeriod period;
  final DateTime start;
  final DateTime end;
  final Duration listened;
  final int starts;
  final int qualifiedPlays;
  final int completions;
  final int earlySkips;
  final List<AnalyticsSongStat> topSongs;
  final List<AnalyticsArtistStat> topArtists;
  final DateTime? busiestDay;

  double get completionRate =>
      qualifiedPlays == 0 ? 0 : (completions / qualifiedPlays).clamp(0, 1);
}

class MixCollection {
  const MixCollection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.songs,
    this.mood,
    this.isColdStart = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<Song> songs;
  final MoodTag? mood;
  final bool isColdStart;
}

class WrappedSummary {
  const WrappedSummary({
    required this.year,
    required this.listened,
    required this.qualifiedPlays,
    required this.completionRate,
    required this.topSongs,
    required this.topArtists,
    this.busiestDay,
  });

  final int year;
  final Duration listened;
  final int qualifiedPlays;
  final double completionRate;
  final List<AnalyticsSongStat> topSongs;
  final List<AnalyticsArtistStat> topArtists;
  final DateTime? busiestDay;

  bool get hasData => listened > Duration.zero || qualifiedPlays > 0;
}

class WrappedSharePayload {
  const WrappedSharePayload({
    required this.year,
    required this.minutes,
    required this.qualifiedPlays,
    required this.topSong,
    required this.topArtist,
  });

  final int year;
  final int minutes;
  final int qualifiedPlays;
  final String topSong;
  final String topArtist;

  String encode() => base64Url.encode(
    utf8.encode(
      jsonEncode({
        'v': 1,
        'y': year,
        'm': minutes,
        'p': qualifiedPlays,
        'song': topSong,
        'artist': topArtist,
      }),
    ),
  );
}

const _emptySong = Song(
  id: '',
  name: '',
  title: '',
  thumbnail: '',
  artistsNames: '',
  code: '',
);

DateTime? _latest(DateTime? first, DateTime? second) {
  if (first == null) return second;
  if (second == null) return first;
  return first.isAfter(second) ? first : second;
}

int _safeCount(Object? value) =>
    ((value as num?)?.toInt() ?? 0).clamp(0, 1 << 31);

int _safeMilliseconds(Object? value) =>
    ((value as num?)?.toInt() ?? 0).clamp(0, 24 * 366 * 2 * 60 * 60 * 1000);

List<Map<String, dynamic>> _readMaps(Object? value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

Map<String, SongAnalyticsAggregate> _readAggregateMap(Object? value) {
  if (value is! Map<String, dynamic>) return const {};
  final result = <String, SongAnalyticsAggregate>{};
  for (final entry in value.entries) {
    if (entry.value is! Map<String, dynamic>) continue;
    final aggregate = SongAnalyticsAggregate.fromJson(
      entry.value as Map<String, dynamic>,
    );
    if (aggregate.song.id.isNotEmpty) result[entry.key] = aggregate;
  }
  return result;
}

bool _validDate(String value) =>
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
    DateTime.tryParse(value) != null;

bool _validMonth(String value) =>
    RegExp(r'^\d{4}-\d{2}$').hasMatch(value) &&
    DateTime.tryParse('$value-01') != null;
