import 'catalog_search.dart';
import 'song.dart';

class ChartPoint {
  const ChartPoint({
    required this.time,
    required this.hour,
    required this.counter,
  });

  final DateTime time;
  final String hour;
  final double counter;

  Map<String, dynamic> toJson() => {
    'time': time.millisecondsSinceEpoch,
    'hour': hour,
    'counter': counter,
  };

  factory ChartPoint.fromJson(Map<String, dynamic> json) {
    final milliseconds = (json['time'] as num?)?.toInt() ?? 0;
    return ChartPoint(
      time: DateTime.fromMillisecondsSinceEpoch(milliseconds),
      hour: json['hour']?.toString() ?? '',
      counter: (json['counter'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ChartSongMetadata {
  const ChartSongMetadata({
    this.albumTitle = '',
    this.duration = Duration.zero,
    this.rankChange,
    this.artists = const [],
    this.album,
  });

  final String albumTitle;
  final Duration duration;
  final int? rankChange;
  final List<CatalogArtist> artists;
  final CatalogCollection? album;

  Map<String, dynamic> toJson() => {
    'albumTitle': albumTitle,
    'durationMs': duration.inMilliseconds,
    'rankChange': rankChange,
    'artists': artists
        .map(
          (artist) => {
            'id': artist.id,
            'name': artist.name,
            'aliasName': artist.aliasName,
            'avatar': artist.avatar,
            'externalUrl': artist.externalUrl,
          },
        )
        .toList(growable: false),
    'album': album == null
        ? null
        : {
            'id': album!.id,
            'title': album!.title,
            'artist': album!.artist,
            'thumbnail': album!.thumbnail,
            'kind': album!.kind.name,
            'externalUrl': album!.externalUrl,
          },
  };

  factory ChartSongMetadata.fromJson(Map<String, dynamic> json) {
    final durationMs = (json['durationMs'] as num?)?.toInt() ?? 0;
    final rankChange = (json['rankChange'] as num?)?.toInt();
    final rawArtists = json['artists'];
    final rawAlbum = json['album'];
    return ChartSongMetadata(
      albumTitle: json['albumTitle']?.toString() ?? '',
      duration: Duration(milliseconds: durationMs.clamp(0, 86_400_000).toInt()),
      rankChange: rankChange?.clamp(-100, 100).toInt(),
      artists: rawArtists is List
          ? rawArtists
                .whereType<Map<String, dynamic>>()
                .map(
                  (artist) => CatalogArtist(
                    id: artist['id']?.toString() ?? '',
                    name: artist['name']?.toString() ?? '',
                    aliasName: artist['aliasName']?.toString() ?? '',
                    avatar: artist['avatar']?.toString() ?? '',
                    externalUrl: artist['externalUrl']?.toString() ?? '',
                  ),
                )
                .where(
                  (artist) => artist.id.isNotEmpty && artist.name.isNotEmpty,
                )
                .toList(growable: false)
          : const [],
      album: rawAlbum is Map<String, dynamic>
          ? CatalogCollection(
              id: rawAlbum['id']?.toString() ?? '',
              title: rawAlbum['title']?.toString() ?? '',
              artist: rawAlbum['artist']?.toString() ?? '',
              thumbnail: rawAlbum['thumbnail']?.toString() ?? '',
              kind: rawAlbum['kind']?.toString() == 'album'
                  ? CatalogCollectionKind.album
                  : CatalogCollectionKind.playlist,
              externalUrl: rawAlbum['externalUrl']?.toString() ?? '',
            )
          : null,
    );
  }
}

class ChartSnapshot {
  const ChartSnapshot({
    required this.songs,
    this.series = const {},
    this.songMetadata = const {},
    this.minScore = 0,
    this.maxScore = 0,
    this.updatedAt,
  });

  final List<Song> songs;
  final Map<String, List<ChartPoint>> series;
  final Map<String, ChartSongMetadata> songMetadata;
  final double minScore;
  final double maxScore;
  final DateTime? updatedAt;

  bool get hasRealtimeSeries =>
      series.values.any((points) => points.length > 1);

  Map<String, dynamic> toJson() => {
    'songs': songs.map((song) => song.toJson()).toList(growable: false),
    'series': series.map(
      (songId, points) => MapEntry(
        songId,
        points.map((point) => point.toJson()).toList(growable: false),
      ),
    ),
    'songMetadata': songMetadata.map(
      (songId, metadata) => MapEntry(songId, metadata.toJson()),
    ),
    'minScore': minScore,
    'maxScore': maxScore,
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
  };

  factory ChartSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSongs = json['songs'];
    final rawSeries = json['series'];
    final rawSongMetadata = json['songMetadata'];
    final updatedAt = (json['updatedAt'] as num?)?.toInt();
    return ChartSnapshot(
      songs: rawSongs is List
          ? rawSongs
                .whereType<Map<String, dynamic>>()
                .map(Song.fromJson)
                .where((song) => song.id.isNotEmpty)
                .toList(growable: false)
          : const [],
      series: rawSeries is Map<String, dynamic>
          ? rawSeries.map(
              (songId, rawPoints) => MapEntry(
                songId,
                rawPoints is List
                    ? rawPoints
                          .whereType<Map<String, dynamic>>()
                          .map(ChartPoint.fromJson)
                          .toList(growable: false)
                    : const <ChartPoint>[],
              ),
            )
          : const {},
      songMetadata: rawSongMetadata is Map<String, dynamic>
          ? rawSongMetadata.map(
              (songId, rawMetadata) => MapEntry(
                songId,
                rawMetadata is Map<String, dynamic>
                    ? ChartSongMetadata.fromJson(rawMetadata)
                    : const ChartSongMetadata(),
              ),
            )
          : const {},
      minScore: (json['minScore'] as num?)?.toDouble() ?? 0,
      maxScore: (json['maxScore'] as num?)?.toDouble() ?? 0,
      updatedAt: updatedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
  }
}
