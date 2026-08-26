import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/listening_analytics.dart';
import '../models/catalog_search.dart';
import '../models/local_library.dart';
import '../models/playback_origin.dart';
import '../models/song.dart';

class PlayerSnapshot {
  const PlayerSnapshot({
    this.likedSongs = const [],
    this.followedArtists = const [],
    this.savedCollections = const [],
    this.queue = const [],
    this.currentSong,
    this.playbackOrigin = const PlaybackOrigin.chart(),
    this.currentIndex = -1,
    this.position = Duration.zero,
    this.shuffleEnabled = false,
    this.smartShuffleEnabled = false,
    this.smartShuffleSongIds = const [],
    this.playbackOrderIds = const [],
    this.playbackHistoryIds = const [],
    this.playbackUpcomingIds = const [],
    this.playbackUpcomingRepeatAllFlags = const [],
    this.playbackCursor = -1,
    this.playbackHistoryCursor = -1,
    this.repeatModeIndex = 0,
    this.autoplayRecommendationsEnabled = true,
    this.alwaysOpenFullscreenPlayer = false,
    this.carModeEnabled = false,
    this.volume = 1,
    this.streamingQualityPreferenceIndex = 0,
    this.radioSongIds = const [],
    this.playlists = const [],
    this.history = const [],
    this.recentSearches = const [],
    this.themePreferenceIndex = 0,
  });

  final List<Song> likedSongs;
  final List<CatalogArtist> followedArtists;
  final List<CatalogCollection> savedCollections;
  final List<Song> queue;
  final Song? currentSong;
  final PlaybackOrigin playbackOrigin;
  final int currentIndex;
  final Duration position;
  final bool shuffleEnabled;
  final bool smartShuffleEnabled;
  final List<String> smartShuffleSongIds;
  final List<String> playbackOrderIds;
  final List<String> playbackHistoryIds;
  final List<String> playbackUpcomingIds;
  final List<bool> playbackUpcomingRepeatAllFlags;
  final int playbackCursor;
  final int playbackHistoryCursor;
  final int repeatModeIndex;
  final bool autoplayRecommendationsEnabled;
  final bool alwaysOpenFullscreenPlayer;
  final bool carModeEnabled;
  final double volume;
  final int streamingQualityPreferenceIndex;
  final List<String> radioSongIds;
  final List<LocalPlaylist> playlists;
  final List<ListeningRecord> history;
  final List<String> recentSearches;
  final int themePreferenceIndex;

  Map<String, dynamic> toJson() => {
    'likedSongs': likedSongs.map((song) => song.toJson()).toList(),
    'followedArtists': followedArtists.map(_artistToJson).toList(),
    'savedCollections': savedCollections.map(_collectionToJson).toList(),
    'queue': queue.map((song) => song.toJson()).toList(),
    'currentSong': currentSong?.toJson(),
    'playbackOrigin': playbackOrigin.toJson(),
    'currentIndex': currentIndex,
    'positionMs': position.inMilliseconds,
    'shuffleEnabled': shuffleEnabled,
    'smartShuffleEnabled': smartShuffleEnabled,
    'smartShuffleSongIds': smartShuffleSongIds,
    'playbackOrderIds': playbackOrderIds,
    'playbackHistoryIds': playbackHistoryIds,
    'playbackUpcomingIds': playbackUpcomingIds,
    'playbackUpcomingRepeatAllFlags': playbackUpcomingRepeatAllFlags,
    'playbackCursor': playbackCursor,
    'playbackHistoryCursor': playbackHistoryCursor,
    'repeatModeIndex': repeatModeIndex,
    'autoplayRecommendationsEnabled': autoplayRecommendationsEnabled,
    'alwaysOpenFullscreenPlayer': alwaysOpenFullscreenPlayer,
    'carModeEnabled': carModeEnabled,
    'volume': volume,
    'streamingQualityPreferenceIndex': streamingQualityPreferenceIndex,
    'radioSongIds': radioSongIds,
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
    final queue = readSongs(json['queue']);
    final playbackOrderState = _readPlaybackNavigatorState(
      json['playbackOrderIds'],
      json['playbackCursor'],
      unique: true,
    );
    final playbackHistoryState = _readPlaybackNavigatorState(
      json['playbackHistoryIds'],
      json['playbackHistoryCursor'],
      maxIds: _maxPlaybackHistoryIds,
    );
    final playbackUpcomingIds = _readPlaybackUpcomingIds(
      json['playbackUpcomingIds'],
      queueIds: queue.map((song) => song.id),
    );
    final playbackUpcomingRepeatAllFlags = _readPlaybackUpcomingRepeatAllFlags(
      json['playbackUpcomingRepeatAllFlags'],
      playbackUpcomingIds.length,
    );
    return PlayerSnapshot(
      likedSongs: readSongs(json['likedSongs']),
      followedArtists: _readArtistList(json['followedArtists']),
      savedCollections: _readCollectionList(json['savedCollections']),
      queue: queue,
      currentSong: currentSongJson is Map<String, dynamic>
          ? Song.fromJson(currentSongJson)
          : null,
      playbackOrigin: PlaybackOrigin.fromJson(json['playbackOrigin']),
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? -1,
      position: Duration(
        milliseconds: (json['positionMs'] as num?)?.toInt() ?? 0,
      ),
      shuffleEnabled: json['shuffleEnabled'] == true,
      smartShuffleEnabled: json['smartShuffleEnabled'] == true,
      smartShuffleSongIds: _readQueueMarkerIds(json['smartShuffleSongIds']),
      playbackOrderIds: playbackOrderState.ids,
      playbackHistoryIds: playbackHistoryState.ids,
      playbackUpcomingIds: playbackUpcomingIds,
      playbackUpcomingRepeatAllFlags: playbackUpcomingRepeatAllFlags,
      playbackCursor: playbackOrderState.cursor,
      playbackHistoryCursor: playbackHistoryState.cursor,
      repeatModeIndex: (json['repeatModeIndex'] as num?)?.toInt() ?? 0,
      autoplayRecommendationsEnabled:
          json['autoplayRecommendationsEnabled'] != false,
      alwaysOpenFullscreenPlayer: json['alwaysOpenFullscreenPlayer'] == true,
      carModeEnabled: json['carModeEnabled'] == true,
      volume: _readVolume(json['volume']),
      streamingQualityPreferenceIndex:
          (json['streamingQualityPreferenceIndex'] as num?)?.toInt() ?? 0,
      radioSongIds: json['radioSongIds'] is List
          ? (json['radioSongIds'] as List)
                .whereType<String>()
                .map((id) => id.trim())
                .where((id) => RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id))
                .toSet()
                .take(100)
                .toList(growable: false)
          : const [],
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

double _readVolume(Object? value) {
  if (value is! num || !value.isFinite) return 1;
  return value.toDouble().clamp(0, 1);
}

class LibraryBackupData {
  const LibraryBackupData({
    this.likedSongs = const [],
    this.followedArtists = const [],
    this.savedCollections = const [],
    this.playlists = const [],
    this.history = const [],
    this.recentSearches = const [],
    this.themePreferenceIndex = 0,
    this.analytics,
  });

  final List<Song> likedSongs;
  final List<CatalogArtist> followedArtists;
  final List<CatalogCollection> savedCollections;
  final List<LocalPlaylist> playlists;
  final List<ListeningRecord> history;
  final List<String> recentSearches;
  final int themePreferenceIndex;
  final ListeningAnalyticsSnapshot? analytics;

  static const maxEncodedBytes = 5 * 1024 * 1024;

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'schema': 'zingchart-library',
    'version': 3,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'library': {
      'likedSongs': likedSongs.map((song) => song.toJson()).toList(),
      'followedArtists': followedArtists.map(_artistToJson).toList(),
      'savedCollections': savedCollections.map(_collectionToJson).toList(),
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
          (decoded['version'] != 1 &&
              decoded['version'] != 2 &&
              decoded['version'] != 3) ||
          decoded['library'] is! Map<String, dynamic>) {
        throw const FormatException('File backup #zingChart không hợp lệ.');
      }
      final library = decoded['library'] as Map<String, dynamic>;
      final analyticsJson = library['analytics'];
      if ((decoded['version'] == 2 || decoded['version'] == 3) &&
          library.containsKey('analytics') &&
          analyticsJson is! Map<String, dynamic>) {
        throw const FormatException(
          'File backup #zingChart có analytics không hợp lệ.',
        );
      }
      return LibraryBackupData(
        likedSongs: _readSongList(library['likedSongs']),
        followedArtists: _readArtistList(
          library['followedArtists'],
          strict: true,
        ),
        savedCollections: _readCollectionList(
          library['savedCollections'],
          strict: true,
        ),
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
            decoded['version'] != 1 && analyticsJson is Map<String, dynamic>
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

  static const _snapshotKey = 'player_snapshot_v11';
  static const _legacySnapshotKey = 'player_snapshot_v10';
  static const _legacySnapshotKeyV9 = 'player_snapshot_v9';
  static const _legacySnapshotKeyV8 = 'player_snapshot_v8';
  static const _legacySnapshotKeyV7 = 'player_snapshot_v7';
  static const _legacySnapshotKeyV6 = 'player_snapshot_v6';
  static const _legacySnapshotKeyV5 = 'player_snapshot_v5';
  static const _legacySnapshotKeyV4 = 'player_snapshot_v4';
  static const _legacySnapshotKeyV3 = 'player_snapshot_v3';
  static const _legacySnapshotKeyV2 = 'player_snapshot_v2';
  SharedPreferencesAsync? _preferences;

  @override
  Future<PlayerSnapshot> load() async {
    try {
      final preferences = _preferences ??= SharedPreferencesAsync();
      final encoded =
          await preferences.getString(_snapshotKey) ??
          await preferences.getString(_legacySnapshotKey) ??
          await preferences.getString(_legacySnapshotKeyV9) ??
          await preferences.getString(_legacySnapshotKeyV8) ??
          await preferences.getString(_legacySnapshotKeyV7) ??
          await preferences.getString(_legacySnapshotKeyV6) ??
          await preferences.getString(_legacySnapshotKeyV5) ??
          await preferences.getString(_legacySnapshotKeyV4) ??
          await preferences.getString(_legacySnapshotKeyV3) ??
          await preferences.getString(_legacySnapshotKeyV2);
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

List<String> _readQueueMarkerIds(Object? value) => value is List
    ? value
          .whereType<String>()
          .map((id) => id.trim())
          .where((id) => RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id))
          .toSet()
          .take(100)
          .toList(growable: false)
    : const [];

const _maxPlaybackHistoryIds = 500;
final _safePlaybackIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

List<String> _readPlaybackUpcomingIds(
  Object? value, {
  required Iterable<String> queueIds,
}) {
  if (value is! List) return const [];
  final validQueueIds = queueIds.toSet();
  if (validQueueIds.isEmpty) return const [];
  final maxIds = _maxPlaybackHistoryIds + validQueueIds.length;
  return List<String>.unmodifiable(
    value
        .whereType<String>()
        .map((id) => id.trim())
        .where(
          (id) =>
              _safePlaybackIdPattern.hasMatch(id) && validQueueIds.contains(id),
        )
        .take(maxIds),
  );
}

List<bool> _readPlaybackUpcomingRepeatAllFlags(Object? value, int length) {
  if (value is! List || value.length != length) {
    return List<bool>.unmodifiable(List<bool>.filled(length, false));
  }
  final flags = value.whereType<bool>().toList(growable: false);
  if (flags.length != length) {
    return List<bool>.unmodifiable(List<bool>.filled(length, false));
  }
  return List<bool>.unmodifiable(flags);
}

class _SanitizedPlaybackIds {
  const _SanitizedPlaybackIds(this.ids, this.cursor);

  final List<String> ids;
  final int cursor;
}

_SanitizedPlaybackIds _readPlaybackNavigatorState(
  Object? value,
  Object? cursorValue, {
  bool unique = false,
  int? maxIds,
}) {
  if (value is! List) return const _SanitizedPlaybackIds([], -1);
  final requestedCursor =
      cursorValue is num &&
          cursorValue.isFinite &&
          cursorValue.toInt() == cursorValue
      ? cursorValue.toInt()
      : -1;
  final ids = <String>[];
  final seen = unique ? <String, int>{} : null;
  var sanitizedCursor = -1;
  for (var rawIndex = 0; rawIndex < value.length; rawIndex++) {
    final rawId = value[rawIndex];
    if (rawId is! String) continue;
    final id = rawId.trim();
    if (!_safePlaybackIdPattern.hasMatch(id)) continue;
    final existingIndex = seen?[id];
    if (existingIndex != null) {
      if (rawIndex == requestedCursor) sanitizedCursor = existingIndex;
      continue;
    }
    ids.add(id);
    seen?[id] = ids.length - 1;
    if (rawIndex == requestedCursor) sanitizedCursor = ids.length - 1;
  }
  if (maxIds == null || ids.length <= maxIds) {
    return _SanitizedPlaybackIds(
      List<String>.unmodifiable(ids),
      sanitizedCursor,
    );
  }

  final start = sanitizedCursor < 0
      ? 0
      : (sanitizedCursor - maxIds + 1).clamp(0, ids.length - maxIds);
  return _SanitizedPlaybackIds(
    List<String>.unmodifiable(ids.sublist(start, start + maxIds)),
    sanitizedCursor < 0 ? -1 : sanitizedCursor - start,
  );
}

List<Map<String, dynamic>> _readMaps(Object? value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

List<Song> _readSongList(Object? value) => _readMaps(value)
    .map(Song.fromJson)
    .where((song) => song.id.isNotEmpty)
    .toList(growable: false);

Map<String, dynamic> _artistToJson(CatalogArtist artist) => {
  'id': artist.id,
  'name': artist.name,
  'aliasName': artist.aliasName,
  'avatar': artist.avatar,
  'externalUrl': artist.externalUrl,
};

List<CatalogArtist> _readArtistList(Object? value, {bool strict = false}) {
  if (value == null) return const [];
  if (value is! List) {
    if (strict) {
      throw const FormatException(
        'Danh sách nghệ sĩ đã quan tâm không hợp lệ.',
      );
    }
    return const [];
  }
  final artists = <CatalogArtist>[];
  final seen = <String>{};
  for (final item in value.take(200)) {
    try {
      if (item is! Map<String, dynamic>) throw const FormatException();
      final id = item['id'];
      final name = item['name'];
      final aliasName = item['aliasName'];
      final avatar = item['avatar'];
      final externalUrl = item['externalUrl'];
      if (id is! String ||
          name is! String ||
          aliasName is! String ||
          avatar is! String ||
          externalUrl is! String) {
        throw const FormatException();
      }
      final normalizedId = id.trim();
      final normalizedName = name.trim();
      final normalizedAlias = aliasName.trim();
      final normalizedAvatar = avatar.trim();
      final normalizedUrl = externalUrl.trim();
      if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalizedId) ||
          normalizedName.isEmpty ||
          normalizedName.length > 200 ||
          !RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(normalizedAlias) ||
          !_isSafeHttpsResource(normalizedAvatar) ||
          !_isTrustedArtistPage(normalizedUrl)) {
        throw const FormatException();
      }
      if (!seen.add(normalizedId)) continue;
      artists.add(
        CatalogArtist(
          id: normalizedId,
          name: normalizedName,
          aliasName: normalizedAlias,
          avatar: normalizedAvatar,
          externalUrl: normalizedUrl,
        ),
      );
    } catch (_) {
      if (strict) {
        throw const FormatException(
          'Dữ liệu nghệ sĩ đã quan tâm không hợp lệ.',
        );
      }
    }
  }
  return List<CatalogArtist>.unmodifiable(artists);
}

bool _isSafeHttpsResource(String value) {
  if (value.isEmpty) return true;
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.host.isNotEmpty &&
      uri.port == 443;
}

bool _isTrustedArtistPage(String value) {
  if (value.isEmpty) return true;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443 ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host != 'zingmp3.vn' && !host.endsWith('.zingmp3.vn')) return false;
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  if (segments.length == 2 && segments.first == 'nghe-si') {
    return RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(segments.last);
  }
  return segments.length == 1 &&
      RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(segments.single);
}

Map<String, dynamic> _collectionToJson(CatalogCollection collection) => {
  'id': collection.id,
  'title': collection.title,
  'artist': collection.artist,
  'artists': collection.artists.map(_artistToJson).toList(),
  'thumbnail': collection.thumbnail,
  'kind': collection.kind.name,
  'externalUrl': collection.externalUrl,
};

List<CatalogCollection> _readCollectionList(
  Object? value, {
  bool strict = false,
}) {
  if (value == null) return const [];
  if (value is! List) {
    if (strict) {
      throw const FormatException(
        'Danh sách album/playlist đã lưu không hợp lệ.',
      );
    }
    return const [];
  }
  final collections = <CatalogCollection>[];
  final seen = <String>{};
  for (final item in value.take(200)) {
    try {
      if (item is! Map<String, dynamic>) throw const FormatException();
      final id = item['id'];
      final title = item['title'];
      final artist = item['artist'];
      final thumbnail = item['thumbnail'];
      final kind = item['kind'];
      final externalUrl = item['externalUrl'];
      if (id is! String ||
          title is! String ||
          artist is! String ||
          thumbnail is! String ||
          kind is! String ||
          externalUrl is! String) {
        throw const FormatException();
      }
      final normalizedId = id.trim();
      final normalizedTitle = title.trim();
      final normalizedArtist = artist.trim();
      final normalizedThumbnail = thumbnail.trim();
      final normalizedUrl = externalUrl.trim();
      final artists = _readArtistList(item['artists'], strict: strict);
      if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalizedId) ||
          normalizedTitle.isEmpty ||
          normalizedTitle.length > 300 ||
          normalizedArtist.length > 300 ||
          (kind != CatalogCollectionKind.album.name &&
              kind != CatalogCollectionKind.playlist.name) ||
          !_isSafeHttpsResource(normalizedThumbnail) ||
          !_isTrustedCollectionPage(normalizedUrl)) {
        throw const FormatException();
      }
      if (!seen.add(normalizedId)) continue;
      collections.add(
        CatalogCollection(
          id: normalizedId,
          title: normalizedTitle,
          artist: normalizedArtist,
          artists: artists,
          thumbnail: normalizedThumbnail,
          kind: kind == CatalogCollectionKind.album.name
              ? CatalogCollectionKind.album
              : CatalogCollectionKind.playlist,
          externalUrl: normalizedUrl,
        ),
      );
    } catch (_) {
      if (strict) {
        throw const FormatException(
          'Dữ liệu album/playlist đã lưu không hợp lệ.',
        );
      }
    }
  }
  return List<CatalogCollection>.unmodifiable(collections);
}

bool _isTrustedCollectionPage(String value) {
  if (value.isEmpty) return true;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443 ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host != 'zingmp3.vn' && !host.endsWith('.zingmp3.vn')) return false;
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  if (segments.length >= 2 &&
      (segments.first == 'album' || segments.first == 'playlist')) {
    return true;
  }
  return segments.length == 3 &&
      segments[0] == 'link' &&
      segments[1] == 'album' &&
      RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(segments[2]);
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
