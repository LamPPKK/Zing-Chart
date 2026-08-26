import '../models/listening_analytics.dart';
import '../models/song.dart';
import 'listening_analytics_service.dart';

class LocalMixEngine {
  const LocalMixEngine();

  List<Song> buildSmartShuffle({
    required List<Song> queue,
    required List<Song> catalog,
    required Set<String> likedSongIds,
    required ListeningAnalyticsService analytics,
    DateTime? now,
    int maxSuggestions = 10,
  }) {
    if (queue.isEmpty || maxSuggestions <= 0) return const [];
    final today = now ?? DateTime.now();
    final queueIds = queue.map((song) => song.id).toSet();
    final queueArtists = queue
        .expand(_artists)
        .map((artist) => artist.toLowerCase())
        .toSet();
    final candidates = _uniqueSongs(
      catalog.where(
        (song) => song.isPlaybackEligible && !queueIds.contains(song.id),
      ),
    );
    if (candidates.isEmpty) return const [];

    final eligibleLikedSongIds = candidates
        .where((song) => likedSongIds.contains(song.id))
        .map((song) => song.id)
        .toSet();
    final profileSeed = _profileSeed(analytics, eligibleLikedSongIds, today);
    final queueSeed = queue.map((song) => song.id).join('|');
    final scored =
        candidates.map((song) {
          final sharesQueueArtist = _artists(
            song,
          ).any((artist) => queueArtists.contains(artist.toLowerCase()));
          return _ScoredSong(
            song,
            _score(
                  song,
                  liked: eligibleLikedSongIds.contains(song.id),
                  aggregate: analytics.aggregateForSong(song.id),
                  now: today,
                  dailySeed: 'smart|$profileSeed|$queueSeed',
                ) +
                (sharesQueueArtist ? 5 : 0),
          );
        }).toList()..sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          return byScore != 0
              ? byScore
              : a.song.displayTitle.compareTo(b.song.displayTitle);
        });

    final desired = ((queue.length + 2) ~/ 3).clamp(1, maxSuggestions);
    return _withArtistDiversity(scored, limit: desired);
  }

  MixCollection buildDailyMix({
    required List<Song> candidates,
    required Set<String> likedSongIds,
    required ListeningAnalyticsService analytics,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final unique = _uniqueSongs(
      candidates.where((song) => song.isPlaybackEligible),
    );
    final eligibleLikedIds = unique
        .where((song) => likedSongIds.contains(song.id))
        .map((song) => song.id)
        .toSet();
    final recent = analytics.summary(AnalyticsPeriod.thirtyDays, now: today);
    final coldStart = recent.qualifiedPlays < 5 && eligibleLikedIds.length < 3;
    final profileSeed = _profileSeed(analytics, eligibleLikedIds, today);
    final songs = coldStart
        ? _withArtistDiversitySongs([
            ...unique.where((song) => eligibleLikedIds.contains(song.id)),
            ...unique.where((song) => !eligibleLikedIds.contains(song.id)),
          ], limit: 25)
        : _rankPersonalized(
            unique,
            likedSongIds: eligibleLikedIds,
            analytics: analytics,
            now: today,
            profileSeed: profileSeed,
          );
    return MixCollection(
      id: 'daily-${_dateSeed(today)}-${_stableHash(profileSeed)}',
      title: 'Daily Mix',
      subtitle: coldStart
          ? 'Nghe hoặc thả tim thêm để mix hiểu gu của bạn.'
          : 'Xếp hạng từ lượt nghe, hoàn thành và yêu thích trên thiết bị.',
      songs: songs,
      isColdStart: coldStart,
    );
  }

  List<Song> _rankPersonalized(
    List<Song> songs, {
    required Set<String> likedSongIds,
    required ListeningAnalyticsService analytics,
    required DateTime now,
    required String profileSeed,
  }) {
    final scored =
        songs
            .map(
              (song) => _ScoredSong(
                song,
                _score(
                  song,
                  liked: likedSongIds.contains(song.id),
                  aggregate: analytics.aggregateForSong(song.id),
                  now: now,
                  dailySeed: profileSeed,
                ),
              ),
            )
            .toList()
          ..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            return byScore != 0
                ? byScore
                : a.song.displayTitle.compareTo(b.song.displayTitle);
          });
    return _withArtistDiversity(scored, limit: 25);
  }

  MixCollection buildMoodMix({
    required MoodTag mood,
    required List<Song> candidates,
    required Set<String> likedSongIds,
    required ListeningAnalyticsService analytics,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final storedTagged = analytics.songsForMood(mood);
    final taggedIds = storedTagged.map((song) => song.id).toSet();
    final currentCandidates = {for (final song in candidates) song.id: song};
    final tagged = storedTagged
        .map((song) => currentCandidates[song.id] ?? song)
        .where((song) => song.isPlaybackEligible)
        .toList(growable: false);
    final taggedArtists = tagged
        .expand(_artists)
        .map((artist) => artist.toLowerCase())
        .toSet();
    final unique = _uniqueSongs([
      ...tagged,
      ...candidates.where((song) => song.isPlaybackEligible),
    ]);
    final eligibleLikedIds = unique
        .where((song) => likedSongIds.contains(song.id))
        .map((song) => song.id)
        .toSet();
    final scored = <_ScoredSong>[];
    for (final song in unique) {
      final aggregate = analytics.aggregateForSong(song.id);
      final explicitlyTagged = taggedIds.contains(song.id);
      final relatedArtist = _artists(
        song,
      ).any((artist) => taggedArtists.contains(artist.toLowerCase()));
      final positiveEngagement =
          aggregate != null && aggregate.qualifiedPlays > aggregate.earlySkips;
      if (!explicitlyTagged && (!relatedArtist || !positiveEngagement)) {
        continue;
      }
      scored.add(
        _ScoredSong(
          song,
          _score(
                song,
                liked: eligibleLikedIds.contains(song.id),
                aggregate: aggregate,
                now: today,
                dailySeed: '${mood.name}-${_dateSeed(today)}',
              ) +
              (explicitlyTagged ? 100 : 0),
        ),
      );
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    final songs = _withArtistDiversity(scored, limit: 25);
    return MixCollection(
      id: 'mood-${mood.name}',
      title: _moodTitle(mood),
      subtitle: tagged.isEmpty
          ? 'Gắn mood cho bài hát để bắt đầu mix này.'
          : '${tagged.length} bài được gắn mood trên thiết bị.',
      songs: songs,
      mood: mood,
      isColdStart: tagged.length < 3,
    );
  }

  double _score(
    Song song, {
    required bool liked,
    required SongAnalyticsAggregate? aggregate,
    required DateTime now,
    required String dailySeed,
  }) {
    var score = liked ? 8.0 : 0.0;
    if (aggregate != null) {
      score += (aggregate.qualifiedPlays * 4).clamp(0, 20);
      score += (aggregate.completions * 3).clamp(0, 15);
      score -= (aggregate.earlySkips * 6).clamp(0, 24);
      final lastPlayed = aggregate.lastPlayedAt?.toLocal();
      if (lastPlayed != null) {
        final age = now.difference(lastPlayed).inDays;
        if (age <= 1) {
          score -= 6;
        } else if (age <= 7) {
          score -= 2;
        } else if (age > 30) {
          score += 2;
        }
      }
    }
    score += (_stableHash('$dailySeed|${song.id}') % 201) / 100;
    return score;
  }

  List<Song> _withArtistDiversity(
    List<_ScoredSong> scored, {
    required int limit,
  }) {
    final result = <Song>[];
    final artistCounts = <String, int>{};
    for (final entry in scored) {
      final artists = _artists(
        entry.song,
      ).map((artist) => artist.toLowerCase()).toList();
      if (artists.any((artist) => (artistCounts[artist] ?? 0) >= 2)) continue;
      result.add(entry.song);
      for (final artist in artists) {
        artistCounts[artist] = (artistCounts[artist] ?? 0) + 1;
      }
      if (result.length == limit) break;
    }
    return List.unmodifiable(result);
  }

  List<Song> _withArtistDiversitySongs(
    List<Song> songs, {
    required int limit,
  }) => _withArtistDiversity(
    songs.map((song) => _ScoredSong(song, 0)).toList(growable: false),
    limit: limit,
  );
}

class _ScoredSong {
  const _ScoredSong(this.song, this.score);

  final Song song;
  final double score;
}

List<Song> _uniqueSongs(Iterable<Song> songs) {
  final result = <String, Song>{};
  for (final song in songs) {
    if (song.id.isNotEmpty) result.putIfAbsent(song.id, () => song);
  }
  return result.values.toList(growable: false);
}

Iterable<String> _artists(Song song) => song.artistsNames
    .split(RegExp(r'\s*[,;&]\s*'))
    .map((artist) => artist.trim())
    .where((artist) => artist.isNotEmpty);

String _dateSeed(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

String _profileSeed(
  ListeningAnalyticsService analytics,
  Set<String> likedSongIds,
  DateTime now,
) {
  final moods = analytics.snapshot.moodAssignments.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final moodSignal = moods
      .map((entry) {
        final tags = entry.value.tags.map((tag) => tag.name).toList()..sort();
        return '${entry.key}:${tags.join(',')}';
      })
      .join('|');
  final likes = likedSongIds.toList()..sort();
  final recent = analytics.summary(AnalyticsPeriod.thirtyDays, now: now);
  return '${_dateSeed(now)}|${likes.join(',')}|$moodSignal|'
      '${recent.qualifiedPlays}:${recent.completions}:${recent.earlySkips}';
}

String _moodTitle(MoodTag mood) => switch (mood) {
  MoodTag.chill => 'Chill chậm lại',
  MoodTag.gym => 'Gym tăng nhịp',
  MoodTag.focus => 'Tập trung sâu',
};
