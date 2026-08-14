import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
  });

  final List<Song> likedSongs;
  final List<Song> queue;
  final Song? currentSong;
  final int currentIndex;
  final Duration position;
  final bool shuffleEnabled;
  final int repeatModeIndex;

  Map<String, dynamic> toJson() => {
    'likedSongs': likedSongs.map((song) => song.toJson()).toList(),
    'queue': queue.map((song) => song.toJson()).toList(),
    'currentSong': currentSong?.toJson(),
    'currentIndex': currentIndex,
    'positionMs': position.inMilliseconds,
    'shuffleEnabled': shuffleEnabled,
    'repeatModeIndex': repeatModeIndex,
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
    );
  }
}

abstract interface class LibraryRepository {
  Future<PlayerSnapshot> load();

  Future<void> save(PlayerSnapshot snapshot);
}

class SharedPreferencesLibraryRepository implements LibraryRepository {
  SharedPreferencesLibraryRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  static const _snapshotKey = 'player_snapshot_v2';
  SharedPreferencesAsync? _preferences;

  @override
  Future<PlayerSnapshot> load() async {
    try {
      final preferences = _preferences ??= SharedPreferencesAsync();
      final encoded = await preferences.getString(_snapshotKey);
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
