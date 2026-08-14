import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/listening_analytics.dart';
import '../models/local_library.dart';
import '../models/song.dart';

class PlayerSnapshot {
  const PlayerSnapshot({
    this.likedSongs = const [],
    this.queue = const [],
    this.currentSong,
    this.currentIndex = -1,
    this.position = Duration.zero,
    this.shuffleEnabled = false,
    this.repeatModeIndex = 0,
    this.playlists = const [],
    this.history = const [],
    this.recentSearches = const [],
    this.themePreferenceIndex = 0,
  });

  final List<Song> likedSongs;
  final List<Song> queue;
  final Song? currentSong;
  final int currentIndex;
  final Duration position;
  final bool shuffleEnabled;
  final int repeatModeIndex;
  final List<LocalPlaylist> playlists;
  final List<ListeningRecord> history;
  final List<String> recentSearches;
  final int themePreferenceIndex;

  Map<String, dynamic> toJson() => {
    'likedSongs': likedSongs.map((song) => song.toJson()).toList(),
    'queue': queue.map((song) => song.toJson()).toList(),
    'currentSong': currentSong?.toJson(),
    'currentIndex': currentIndex,
    'positionMs': position.inMilliseconds,
    'shuffleEnabled': shuffleEnabled,
    'repeatModeIndex': repeatModeIndex,
    'playlists': playlists.map((playlist) => playlist.toJson()).toList(),
    'history': history.map((record) => record.toJson()).toList(),
    'recentSearches': recentSearches,
    'themePreferenceIndex': themePreferenceIndex,
  };

  factory PlayerSnapshot.fromJson(Map<String, dynamic> json) {
    List<Song> readSongs(Object? value) => value is List
        ? value
              .whereType<Map<String, dynamic>>()
              .map(Song.fromJson)
              .where((song) => song.id.isNotEmpty)
              .toList(growable: false)
        : const [];

    final currentSongJson = json['currentSong'];
    return PlayerSnapshot(
      likedSongs: readSongs(json['likedSongs']),
      queue: readSongs(json['queue']),
      currentSong: currentSongJson is Map<String, dynamic>
          ? Song.fromJson(currentSongJson)
          : null,
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? -1,
      position: Duration(
        milliseconds: (json['positionMs'] as num?)?.toInt() ?? 0,
      ),
      shuffleEnabled: json['shuffleEnabled'] == true,
      repeatModeIndex: (json['repeatModeIndex'] as num?)?.toInt() ?? 0,
      playlists: _readMaps(json['playlists'])
          .map(LocalPlaylist.fromJson)
          .where(
            (playlist) =>
                playlist.id.isNotEmpty && playlist.name.trim().isNotEmpty,
          )
          .toList(growable: false),
      history: _readMaps(json['history'])
          .map(ListeningRecord.fromJson)
          .where((record) => record.id.isNotEmpty && record.song.id.isNotEmpty)
          .take(500)
          .toList(growable: false),
      recentSearches: json['recentSearches'] is List
          ? (json['recentSearches'] as List)
                .whereType<String>()
                .map((query) => query.trim())
                .where((query) => query.isNotEmpty)
                .take(8)
                .toList(growable: false)
          : const [],
      themePreferenceIndex:
          (json['themePreferenceIndex'] as num?)?.toInt() ?? 0,
    );
  }
}

class LibraryBackupData {
  const LibraryBackupData({
    this.likedSongs = const [],
    this.playlists = const [],
    this.history = const [],
    this.recentSearches = const [],
    this.themePreferenceIndex = 0,
    this.analytics,
  });

  final List<Song> likedSongs;
  final List<LocalPlaylist> playlists;
  final List<ListeningRecord> history;
  final List<String> recentSearches;
  final int themePreferenceIndex;
  final ListeningAnalyticsSnapshot? analytics;

  static const maxEncodedBytes = 5 * 1024 * 1024;

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'schema': 'zingchart-library',
    'version': 2,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'library': {
      'likedSongs': likedSongs.map((song) => song.toJson()).toList(),
      'playlists': playlists.map((playlist) => playlist.toJson()).toList(),
      'history': history.map((record) => record.toJson()).toList(),
      'recentSearches': recentSearches,
      'themePreferenceIndex': themePreferenceIndex,
      if (analytics != null) 'analytics': analytics!.toJson(),
    },
  });

  factory LibraryBackupData.decode(String source) {
    try {
      if (source.length > maxEncodedBytes ||
          utf8.encode(source).length > maxEncodedBytes) {
        throw const FormatException('File backup lớn hơn giới hạn 5 MB.');
      }
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic> ||
          decoded['schema'] != 'zingchart-library' ||
          (decoded['version'] != 1 && decoded['version'] != 2) ||
          decoded['library'] is! Map<String, dynamic>) {
        throw const FormatException('File backup #zingChart không hợp lệ.');
      }
      final library = decoded['library'] as Map<String, dynamic>;
      final analyticsJson = library['analytics'];
      if (decoded['version'] == 2 &&
          library.containsKey('analytics') &&
          analyticsJson is! Map<String, dynamic>) {
        throw const FormatException(
          'File backup #zingChart có analytics không hợp lệ.',
        );
      }
      return LibraryBackupData(
        likedSongs: _readSongList(library['likedSongs']),
        playlists: _readMaps(library['playlists'])
            .map(LocalPlaylist.fromJson)
            .where(
              (playlist) =>
                  playlist.id.isNotEmpty && playlist.name.trim().isNotEmpty,
            )
            .toList(growable: false),
        history: _readMaps(library['history'])
            .map(ListeningRecord.fromJson)
            .where(
              (record) => record.id.isNotEmpty && record.song.id.isNotEmpty,
            )
            .take(500)
            .toList(growable: false),
        recentSearches: library['recentSearches'] is List
            ? (library['recentSearches'] as List)
                  .whereType<String>()
                  .map((query) => query.trim())
                  .where((query) => query.isNotEmpty)
                  .take(8)
                  .toList(growable: false)
            : const [],
        themePreferenceIndex:
            (library['themePreferenceIndex'] as num?)?.toInt() ?? 0,
        analytics:
            decoded['version'] == 2 && analyticsJson is Map<String, dynamic>
            ? ListeningAnalyticsSnapshot.fromJson(analyticsJson)
            : null,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'File backup #zingChart có dữ liệu không hợp lệ.',
      );
    }
  }
}

abstract interface class LibraryRepository {
  Future<PlayerSnapshot> load();

  Future<void> save(PlayerSnapshot snapshot);
}

class SharedPreferencesLibraryRepository implements LibraryRepository {
  SharedPreferencesLibraryRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  static const _snapshotKey = 'player_snapshot_v3';
  static const _legacySnapshotKey = 'player_snapshot_v2';
  SharedPreferencesAsync? _preferences;

  @override
  Future<PlayerSnapshot> load() async {
    try {
      final preferences = _preferences ??= SharedPreferencesAsync();
      final encoded =
          await preferences.getString(_snapshotKey) ??
          await preferences.getString(_legacySnapshotKey);
      if (encoded == null || encoded.isEmpty) return const PlayerSnapshot();
      final json = jsonDecode(encoded);
      return json is Map<String, dynamic>
          ? PlayerSnapshot.fromJson(json)
          : const PlayerSnapshot();
    } catch (_) {
      return const PlayerSnapshot();
    }
  }

  @override
  Future<void> save(PlayerSnapshot snapshot) async {
    final preferences = _preferences ??= SharedPreferencesAsync();
    await preferences.setString(_snapshotKey, jsonEncode(snapshot.toJson()));
  }
}

List<Map<String, dynamic>> _readMaps(Object? value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

List<Song> _readSongList(Object? value) => _readMaps(value)
    .map(Song.fromJson)
    .where((song) => song.id.isNotEmpty)
    .toList(growable: false);

class MemoryLibraryRepository implements LibraryRepository {
  MemoryLibraryRepository([this.snapshot = const PlayerSnapshot()]);

  PlayerSnapshot snapshot;

  @override
  Future<PlayerSnapshot> load() async => snapshot;

  @override
  Future<void> save(PlayerSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}
