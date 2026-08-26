import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/listening_analytics.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/playback_origin.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/services/playback_queue_navigator.dart';

void main() {
  const song = Song(
    id: 'one',
    name: 'mot-bai-hat',
    title: 'Một Bài Hát',
    thumbnail: '',
    artistsNames: 'Ca Sĩ A',
    code: 'code-one',
  );
  const artist = CatalogArtist(
    id: 'artist-a',
    name: 'Ca Sĩ A',
    aliasName: 'Ca-Si-A',
    avatar: 'https://photo-resize-zmp3.zmdcdn.me/w240/artist-a.jpg',
    externalUrl: 'https://zingmp3.vn/nghe-si/Ca-Si-A',
  );
  const collection = CatalogCollection(
    id: 'collection-a',
    title: 'Top Hits A',
    artist: 'Ca Sĩ A',
    artists: [artist],
    thumbnail: '',
    kind: CatalogCollectionKind.playlist,
    externalUrl: 'https://zingmp3.vn/playlist/Top-Hits-A/collection-a.html',
  );

  test(
    'memory repository persists the complete local player snapshot',
    () async {
      final repository = MemoryLibraryRepository();
      const snapshot = PlayerSnapshot(
        likedSongs: [song],
        followedArtists: [artist],
        savedCollections: [collection],
        queue: [song],
        currentSong: song,
        playbackOrigin: PlaybackOrigin(
          kind: PlaybackOriginKind.collection,
          label: 'Album chính thức',
        ),
        currentIndex: 0,
        position: Duration(seconds: 42),
        shuffleEnabled: true,
        smartShuffleEnabled: true,
        smartShuffleSongIds: ['one'],
        playbackOrderIds: ['two', 'one'],
        playbackHistoryIds: ['two', 'one', 'two'],
        playbackUpcomingIds: ['one'],
        playbackUpcomingRepeatAllFlags: [true],
        playbackCursor: 1,
        playbackHistoryCursor: 2,
        repeatModeIndex: 2,
        autoplayRecommendationsEnabled: false,
        alwaysOpenFullscreenPlayer: true,
        carModeEnabled: true,
        volume: 0.42,
        radioSongIds: ['one'],
      );

      await repository.save(snapshot);
      final restored = await repository.load();

      expect(restored.likedSongs.single.id, song.id);
      expect(restored.followedArtists.single.id, artist.id);
      expect(restored.savedCollections.single.id, collection.id);
      expect(restored.savedCollections.single.artists.single.id, artist.id);
      expect(restored.queue.single.id, song.id);
      expect(restored.currentSong?.id, song.id);
      expect(restored.playbackOrigin.kind, PlaybackOriginKind.collection);
      expect(restored.playbackOrigin.label, 'Album chính thức');
      expect(restored.position, const Duration(seconds: 42));
      expect(restored.shuffleEnabled, isTrue);
      expect(restored.smartShuffleEnabled, isTrue);
      expect(restored.smartShuffleSongIds, ['one']);
      expect(restored.playbackOrderIds, ['two', 'one']);
      expect(restored.playbackHistoryIds, ['two', 'one', 'two']);
      expect(restored.playbackUpcomingIds, ['one']);
      expect(restored.playbackUpcomingRepeatAllFlags, [true]);
      expect(restored.playbackCursor, 1);
      expect(restored.playbackHistoryCursor, 2);
      expect(restored.repeatModeIndex, 2);
      expect(restored.autoplayRecommendationsEnabled, isFalse);
      expect(restored.alwaysOpenFullscreenPlayer, isTrue);
      expect(restored.carModeEnabled, isTrue);
      expect(restored.volume, 0.42);
      expect(restored.radioSongIds, ['one']);
    },
  );

  test('player snapshot round-trips every persisted field', () {
    final now = DateTime.utc(2026, 8, 14, 10);
    final snapshot = PlayerSnapshot(
      likedSongs: [song],
      followedArtists: [artist],
      savedCollections: [collection],
      queue: [song],
      currentSong: song,
      playbackOrigin: const PlaybackOrigin(
        kind: PlaybackOriginKind.search,
        label: 'Tìm kiếm · Ca Sĩ A',
      ),
      currentIndex: 0,
      position: Duration(milliseconds: 42500),
      shuffleEnabled: true,
      smartShuffleEnabled: true,
      smartShuffleSongIds: const ['one'],
      playbackOrderIds: const ['two', 'one'],
      playbackHistoryIds: const ['two', 'one', 'two'],
      playbackUpcomingIds: const ['one'],
      playbackUpcomingRepeatAllFlags: const [true],
      playbackCursor: 1,
      playbackHistoryCursor: 2,
      streamingQualityPreferenceIndex: StreamingQualityPreference.high.index,
      repeatModeIndex: 2,
      autoplayRecommendationsEnabled: false,
      alwaysOpenFullscreenPlayer: true,
      carModeEnabled: true,
      volume: 0.42,
      radioSongIds: const ['one'],
      playlists: [
        LocalPlaylist(
          id: 'road-trip',
          name: 'Road trip',
          createdAt: now,
          updatedAt: now,
          songs: const [song],
        ),
      ],
      history: [
        ListeningRecord(
          id: 'listen-1',
          song: song,
          playedAt: now,
          listened: const Duration(minutes: 3),
        ),
      ],
      recentSearches: const ['Ca Sĩ A'],
      themePreferenceIndex: AppThemePreference.light.index,
    );

    final restored = PlayerSnapshot.fromJson(snapshot.toJson());

    expect(restored.likedSongs.single.id, song.id);
    expect(restored.followedArtists.single.name, artist.name);
    expect(restored.savedCollections.single.kind, collection.kind);
    expect(restored.savedCollections.single.artists.single.name, artist.name);
    expect(restored.queue.single.code, song.code);
    expect(restored.currentSong?.displayTitle, song.displayTitle);
    expect(restored.playbackOrigin.kind, PlaybackOriginKind.search);
    expect(restored.playbackOrigin.label, 'Tìm kiếm · Ca Sĩ A');
    expect(restored.currentIndex, 0);
    expect(restored.position, const Duration(milliseconds: 42500));
    expect(restored.shuffleEnabled, isTrue);
    expect(restored.smartShuffleEnabled, isTrue);
    expect(restored.smartShuffleSongIds, ['one']);
    expect(restored.playbackOrderIds, ['two', 'one']);
    expect(restored.playbackHistoryIds, ['two', 'one', 'two']);
    expect(restored.playbackUpcomingIds, ['one']);
    expect(restored.playbackUpcomingRepeatAllFlags, [true]);
    expect(restored.playbackCursor, 1);
    expect(restored.playbackHistoryCursor, 2);
    expect(
      restored.streamingQualityPreferenceIndex,
      StreamingQualityPreference.high.index,
    );
    expect(restored.repeatModeIndex, 2);
    expect(restored.autoplayRecommendationsEnabled, isFalse);
    expect(restored.alwaysOpenFullscreenPlayer, isTrue);
    expect(restored.carModeEnabled, isTrue);
    expect(restored.volume, 0.42);
    expect(restored.radioSongIds, ['one']);
    expect(restored.playlists.single.name, 'Road trip');
    expect(restored.playlists.single.songs.single.id, song.id);
    expect(restored.history.single.listened, const Duration(minutes: 3));
    expect(restored.recentSearches, ['Ca Sĩ A']);
    expect(restored.themePreferenceIndex, AppThemePreference.light.index);
  });

  test('player snapshot rejects malformed playback origins fail-closed', () {
    final restored = PlayerSnapshot.fromJson({
      'playbackOrigin': {
        'kind': 'collection',
        'label': '${List.filled(120, 'A').join()}\u0000hidden',
      },
    });

    expect(restored.playbackOrigin.kind, PlaybackOriginKind.collection);
    expect(restored.playbackOrigin.label, hasLength(96));
    expect(restored.playbackOrigin.label, isNot(contains('\u0000')));
    expect(
      PlayerSnapshot.fromJson({
        'playbackOrigin': {'kind': 'invalid', 'label': 'Fake'},
      }).playbackOrigin.label,
      '#zingChart',
    );
  });

  test('library backup validates its schema and round-trips local data', () {
    final now = DateTime.utc(2026, 8, 14, 10);
    final backup = LibraryBackupData(
      likedSongs: const [song],
      followedArtists: const [artist],
      savedCollections: const [collection],
      playlists: [
        LocalPlaylist(
          id: 'focus',
          name: 'Tập trung',
          createdAt: now,
          updatedAt: now,
          songs: const [song],
        ),
      ],
      history: [ListeningRecord(id: 'record', song: song, playedAt: now)],
      recentSearches: const ['Một Bài Hát'],
      themePreferenceIndex: AppThemePreference.dark.index,
      analytics: const ListeningAnalyticsSnapshot(
        installationId: 'install-a',
        moodAssignments: {
          'one': MoodAssignment(song: song, tags: {MoodTag.focus}),
        },
      ),
    );

    final restored = LibraryBackupData.decode(backup.encode());

    expect(restored.likedSongs.single.id, song.id);
    expect(restored.followedArtists.single.aliasName, artist.aliasName);
    expect(restored.savedCollections.single.title, collection.title);
    expect(restored.playlists.single.name, 'Tập trung');
    expect(restored.history.single.id, 'record');
    expect(restored.recentSearches.single, 'Một Bài Hát');
    expect(restored.themePreferenceIndex, AppThemePreference.dark.index);
    expect(restored.analytics?.installationId, 'install-a');
    expect(restored.analytics?.moodAssignments['one']?.tags, {MoodTag.focus});
    expect(
      () => LibraryBackupData.decode('{"version":1}'),
      throwsFormatException,
    );
    expect(
      () => LibraryBackupData.decode(
        '{"schema":"zingchart-library","version":1,'
        '"library":{"likedSongs":[{"id":1}]}}',
      ),
      throwsFormatException,
      reason:
          'Nested type errors must be reported as a recoverable format error.',
    );
  });

  test('library backup v1 remains readable without analytics', () {
    final restored = LibraryBackupData.decode(
      '{"schema":"zingchart-library","version":1,"library":{}}',
    );

    expect(restored.analytics, isNull);
    expect(restored.likedSongs, isEmpty);
    expect(restored.followedArtists, isEmpty);
    expect(restored.savedCollections, isEmpty);
  });

  test('library backup v2 migrates with an empty followed-artist list', () {
    final restored = LibraryBackupData.decode(
      '{"schema":"zingchart-library","version":2,"library":{}}',
    );

    expect(restored.followedArtists, isEmpty);
    expect(restored.savedCollections, isEmpty);
  });

  test('library backup v3 rejects unsafe followed-artist metadata', () {
    expect(
      () => LibraryBackupData.decode(
        '{"schema":"zingchart-library","version":3,"library":{'
        '"followedArtists":[{"id":"artist-a","name":"Ca Si A",'
        '"aliasName":"Ca-Si-A","avatar":"https://evil.example/a.jpg",'
        '"externalUrl":"https://evil.example/artist-a"}]}}',
      ),
      throwsFormatException,
    );
  });

  test('library backup v3 rejects unsafe saved collection URLs', () {
    expect(
      () => LibraryBackupData.decode(
        '{"schema":"zingchart-library","version":3,"library":{'
        '"savedCollections":[{"id":"collection-a","title":"Top Hits",'
        '"artist":"Ca Si A","thumbnail":"","kind":"playlist",'
        '"externalUrl":"https://evil.example/playlist/a"}]}}',
      ),
      throwsFormatException,
    );
  });

  test('library backup v2 rejects malformed analytics and files over 5 MB', () {
    expect(
      () => LibraryBackupData.decode(
        '{"schema":"zingchart-library","version":2,"library":{'
        '"analytics":{"installationId":[],"daily":"broken"}}}',
      ),
      throwsFormatException,
    );
    expect(
      () => LibraryBackupData.decode(
        'x' * (LibraryBackupData.maxEncodedBytes + 1),
      ),
      throwsFormatException,
    );
  });

  test('player snapshot safely defaults malformed optional values', () {
    final restored = PlayerSnapshot.fromJson({
      'likedSongs': 'not-a-list',
      'queue': [
        <String, dynamic>{'id': ''},
        song.toJson(),
        'not-a-song',
      ],
      'currentSong': 'not-an-object',
      'currentIndex': null,
      'positionMs': null,
      'shuffleEnabled': 'yes',
      'playbackOrderIds': 'not-a-list',
      'playbackHistoryIds': null,
      'playbackCursor': 999,
      'playbackHistoryCursor': -4,
      'repeatModeIndex': null,
      'volume': 4,
    });

    expect(restored.likedSongs, isEmpty);
    expect(restored.followedArtists, isEmpty);
    expect(restored.savedCollections, isEmpty);
    expect(restored.queue.single.id, song.id);
    expect(restored.currentSong, isNull);
    expect(restored.currentIndex, -1);
    expect(restored.position, Duration.zero);
    expect(restored.shuffleEnabled, isFalse);
    expect(restored.playbackOrderIds, isEmpty);
    expect(restored.playbackHistoryIds, isEmpty);
    expect(restored.playbackCursor, -1);
    expect(restored.playbackHistoryCursor, -1);
    expect(restored.repeatModeIndex, 0);
    expect(restored.volume, 1);
  });

  test('player snapshot sanitizes and caps playback navigator state', () {
    final restored = PlayerSnapshot.fromJson({
      'queue': [song.toJson()],
      'playbackOrderIds': [
        ' one ',
        'two',
        'one',
        'not safe',
        42,
        ...List.generate(510, (index) => 'song_$index'),
      ],
      'playbackHistoryIds': [
        ' one ',
        'one',
        'not safe',
        null,
        ...List.generate(510, (index) => 'history_$index'),
      ],
      'playbackCursor': 1,
      'playbackHistoryCursor': 1,
      'playbackUpcomingIds': [
        ' one ',
        'missing',
        'not safe',
        null,
        ...List.generate(550, (_) => 'one'),
      ],
    });

    expect(restored.playbackOrderIds, hasLength(512));
    expect(restored.playbackOrderIds.take(3), ['one', 'two', 'song_0']);
    expect(restored.playbackOrderIds.where((id) => id == 'one'), hasLength(1));
    expect(restored.playbackHistoryIds, hasLength(500));
    expect(restored.playbackHistoryIds.take(3), ['one', 'one', 'history_0']);
    expect(restored.playbackCursor, 1);
    expect(restored.playbackHistoryCursor, 1);
    expect(restored.playbackUpcomingIds, hasLength(501));
    expect(restored.playbackUpcomingIds.toSet(), {'one'});
    expect(
      restored.playbackUpcomingRepeatAllFlags,
      List<bool>.filled(501, false),
    );

    final alignedProvenance = PlayerSnapshot.fromJson({
      'queue': [song.toJson()],
      'playbackUpcomingIds': ['one', 'one'],
      'playbackUpcomingRepeatAllFlags': [true, false],
    });
    expect(alignedProvenance.playbackUpcomingIds, ['one', 'one']);
    expect(alignedProvenance.playbackUpcomingRepeatAllFlags, [true, false]);

    final longHistory = PlayerSnapshot.fromJson({
      'playbackHistoryIds': List.generate(620, (index) => 'history_$index'),
      'playbackHistoryCursor': 619,
    });
    expect(longHistory.playbackHistoryIds, hasLength(500));
    expect(longHistory.playbackHistoryIds.first, 'history_120');
    expect(longHistory.playbackHistoryIds.last, 'history_619');
    expect(longHistory.playbackHistoryCursor, 499);

    final remappedOrder = PlayerSnapshot.fromJson({
      'playbackOrderIds': ['one', 'not safe', 'two'],
      'playbackCursor': 2,
    });
    expect(remappedOrder.playbackOrderIds, ['one', 'two']);
    expect(remappedOrder.playbackCursor, 1);

    final fullTraversal = PlayerSnapshot.fromJson({
      'playbackOrderIds': List.generate(501, (index) => 'song_$index'),
      'playbackCursor': 500,
    });
    expect(fullTraversal.playbackOrderIds, hasLength(501));
    expect(fullTraversal.playbackOrderIds.last, 'song_500');
    expect(fullTraversal.playbackCursor, 500);
    final navigator = PlaybackQueueNavigator.restore(
      PlaybackQueueNavigatorState(
        queueIds: fullTraversal.playbackOrderIds,
        shuffleEnabled: true,
        traversalOrderIds: fullTraversal.playbackOrderIds,
        traversalCursor: fullTraversal.playbackCursor,
        historyIds: const ['song_500'],
        historyCursor: 0,
        currentId: 'song_500',
      ),
    );
    expect(navigator.canGoNext(), isFalse);

    final invalidCursor = PlayerSnapshot.fromJson({
      'playbackOrderIds': ['one'],
      'playbackCursor': 1,
      'playbackHistoryIds': ['one'],
      'playbackHistoryCursor': 1,
    });
    expect(invalidCursor.playbackCursor, -1);
    expect(invalidCursor.playbackHistoryCursor, -1);
  });

  group('shared preferences player snapshot v11 migration', () {
    late InMemorySharedPreferencesAsync store;
    late SharedPreferencesAsync preferences;

    setUp(() {
      store = InMemorySharedPreferencesAsync.empty();
      SharedPreferencesAsyncPlatform.instance = store;
      preferences = SharedPreferencesAsync();
    });

    tearDown(() {
      SharedPreferencesAsyncPlatform.instance = null;
    });

    test('loads a v10 snapshot with Repeat All provenance defaults', () async {
      await preferences.setString(
        'player_snapshot_v10',
        jsonEncode({
          'queue': [song.toJson()],
          'currentSong': song.toJson(),
          'currentIndex': 0,
          'shuffleEnabled': true,
          'playbackOrderIds': ['one'],
          'playbackHistoryIds': ['one'],
          'playbackUpcomingIds': ['one'],
          'playbackCursor': 0,
          'playbackHistoryCursor': 0,
        }),
      );
      final repository = SharedPreferencesLibraryRepository(
        preferences: preferences,
      );

      final restored = await repository.load();

      expect(restored.currentSong?.id, 'one');
      expect(restored.shuffleEnabled, isTrue);
      expect(restored.playbackOrderIds, ['one']);
      expect(restored.playbackHistoryIds, ['one']);
      expect(restored.playbackUpcomingIds, ['one']);
      expect(restored.playbackUpcomingRepeatAllFlags, [false]);
      expect(restored.playbackCursor, 0);
      expect(restored.playbackHistoryCursor, 0);
    });

    test('prefers v11 over v10 and restores provenance idempotently', () async {
      await preferences.setString(
        'player_snapshot_v10',
        jsonEncode({
          'playbackOrderIds': ['legacy'],
          'playbackCursor': 0,
        }),
      );
      await preferences.setString(
        'player_snapshot_v11',
        jsonEncode({
          'queue': [song.toJson()],
          'playbackOrderIds': ['one'],
          'playbackHistoryIds': ['one'],
          'playbackUpcomingIds': ['one', 'one'],
          'playbackUpcomingRepeatAllFlags': [true, false],
          'playbackCursor': 0,
          'playbackHistoryCursor': 0,
        }),
      );
      final repository = SharedPreferencesLibraryRepository(
        preferences: preferences,
      );

      final restored = await repository.load();
      expect(restored.playbackOrderIds, ['one']);
      expect(restored.playbackUpcomingIds, ['one', 'one']);
      expect(restored.playbackUpcomingRepeatAllFlags, [true, false]);
      final restoredAgain = await repository.load();
      expect(restoredAgain.playbackUpcomingIds, restored.playbackUpcomingIds);
      expect(
        restoredAgain.playbackUpcomingRepeatAllFlags,
        restored.playbackUpcomingRepeatAllFlags,
      );

      await repository.save(
        PlayerSnapshot(
          queue: const [song],
          playbackOrderIds: const ['one'],
          playbackHistoryIds: const ['one'],
          playbackUpcomingIds: const ['one', 'one'],
          playbackUpcomingRepeatAllFlags: const [true, false],
          playbackCursor: 0,
          playbackHistoryCursor: 0,
        ),
      );
      final saved =
          jsonDecode((await preferences.getString('player_snapshot_v11'))!)
              as Map<String, dynamic>;
      expect(saved['playbackOrderIds'], ['one']);
      expect(saved['playbackHistoryIds'], ['one']);
      expect(saved['playbackUpcomingIds'], ['one', 'one']);
      expect(saved['playbackUpcomingRepeatAllFlags'], [true, false]);
      expect(saved['playbackCursor'], 0);
      expect(saved['playbackHistoryCursor'], 0);
      expect(
        jsonDecode((await preferences.getString('player_snapshot_v10'))!)
            as Map<String, dynamic>,
        containsPair('playbackOrderIds', ['legacy']),
      );
    });
  });
}
