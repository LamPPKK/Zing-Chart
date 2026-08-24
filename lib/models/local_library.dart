import '../models/song.dart';

enum AppThemePreference { system, light, dark }

enum StreamingQualityPreference { automatic, standard, high }

extension StreamingQualityPreferenceLabel on StreamingQualityPreference {
  String get apiValue => switch (this) {
    StreamingQualityPreference.automatic => 'auto',
    StreamingQualityPreference.standard => '128',
    StreamingQualityPreference.high => '320',
  };

  String get label => switch (this) {
    StreamingQualityPreference.automatic => 'Tự động',
    StreamingQualityPreference.standard => '128 kbps',
    StreamingQualityPreference.high => '320 kbps',
  };
}

enum BackupImportMode { merge, overwrite }

class LocalPlaylist {
  const LocalPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.songs = const [],
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Song> songs;

  LocalPlaylist copyWith({
    String? name,
    DateTime? updatedAt,
    List<Song>? songs,
  }) => LocalPlaylist(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    songs: songs ?? this.songs,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'songs': songs.map((song) => song.toJson()).toList(),
  };

  factory LocalPlaylist.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final name = json['name'] as String? ?? '';
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    return LocalPlaylist(
      id: id,
      name: name,
      createdAt:
          createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          updatedAt ??
          createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      songs: _readSongs(json['songs']),
    );
  }
}

class ListeningRecord {
  const ListeningRecord({
    required this.id,
    required this.song,
    required this.playedAt,
    this.listened = Duration.zero,
  });

  final String id;
  final Song song;
  final DateTime playedAt;
  final Duration listened;

  ListeningRecord copyWith({Duration? listened}) => ListeningRecord(
    id: id,
    song: song,
    playedAt: playedAt,
    listened: listened ?? this.listened,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'song': song.toJson(),
    'playedAt': playedAt.toUtc().toIso8601String(),
    'listenedMs': listened.inMilliseconds,
  };

  factory ListeningRecord.fromJson(Map<String, dynamic> json) {
    final songJson = json['song'];
    final parsedDate = DateTime.tryParse(json['playedAt'] as String? ?? '');
    return ListeningRecord(
      id: json['id'] as String? ?? '',
      song: songJson is Map<String, dynamic>
          ? Song.fromJson(songJson)
          : const Song(
              id: '',
              name: '',
              title: '',
              thumbnail: '',
              artistsNames: '',
              code: '',
            ),
      playedAt:
          parsedDate ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      listened: Duration(
        milliseconds: ((json['listenedMs'] as num?)?.toInt() ?? 0).clamp(
          0,
          86400000,
        ),
      ),
    );
  }
}

class SongListeningStat {
  const SongListeningStat({
    required this.song,
    required this.playCount,
    required this.listened,
  });

  final Song song;
  final int playCount;
  final Duration listened;
}

class ArtistListeningStat {
  const ArtistListeningStat({
    required this.artist,
    required this.playCount,
    required this.listened,
  });

  final String artist;
  final int playCount;
  final Duration listened;
}

class BackupImportResult {
  const BackupImportResult({
    required this.likedSongs,
    this.followedArtists = 0,
    this.savedCollections = 0,
    required this.playlists,
    required this.historyRecords,
  });

  final int likedSongs;
  final int followedArtists;
  final int savedCollections;
  final int playlists;
  final int historyRecords;
}

List<Song> _readSongs(Object? value) => value is List
    ? value
          .whereType<Map<String, dynamic>>()
          .map(Song.fromJson)
          .where((song) => song.id.isNotEmpty)
          .toList(growable: false)
    : const [];
