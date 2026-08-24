import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/zing_chart_screen.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('collection load failure stays inline and retries successfully', (
    tester,
  ) async {
    await _setViewport(tester);
    final controller = await _createController();
    addTearDown(controller.dispose);
    var attempts = 0;

    await _pumpCollection(
      tester,
      controller,
      loadCollection: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('proxy unavailable');
        return _playbackEnabledDetail;
      },
    );
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(find.byKey(const ValueKey('collection-load-error')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('collection-retry-button')),
      findsOneWidget,
    );
    expect(find.text('Không tìm thấy bài hát phù hợp'), findsNothing);
    expect(find.text('Tuyển tập chưa có bài hát khả dụng'), findsNothing);
    expect(find.byKey(const ValueKey(_songId)), findsNothing);

    await tester.tap(find.byKey(const ValueKey('collection-retry-button')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const ValueKey('collection-load-error')), findsNothing);
    expect(find.byKey(const ValueKey(_songId)), findsOneWidget);
    expect(find.text(_songTitle), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacked collection failure replaces the generic empty state', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    final controller = await _createController();
    addTearDown(controller.dispose);
    var attempts = 0;

    await _pumpCollection(
      tester,
      controller,
      loadCollection: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('mobile proxy unavailable');
        return _playbackEnabledDetail;
      },
    );
    await tester.pumpAndSettle();

    final inlineError = find.byKey(const ValueKey('collection-load-error'));
    final retryButton = find.byKey(const ValueKey('collection-retry-button'));
    expect(attempts, 1);
    expect(inlineError, findsOneWidget);
    expect(retryButton, findsOneWidget);
    expect(find.text('Không tìm thấy bài hát phù hợp'), findsNothing);
    expect(find.text('Tuyển tập chưa có bài hát khả dụng'), findsNothing);

    await tester.ensureVisible(retryButton);
    await tester.pumpAndSettle();
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(inlineError, findsNothing);
    expect(find.text(_songTitle), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed refresh keeps stale collection until retry succeeds', (
    tester,
  ) async {
    await _setViewport(tester);
    final controller = await _createController();
    addTearDown(controller.dispose);
    var attempts = 0;

    await _pumpCollection(
      tester,
      controller,
      loadCollection: (_) async {
        attempts++;
        if (attempts == 2) throw StateError('refresh failed');
        return _playbackEnabledDetail;
      },
    );
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(find.byKey(const ValueKey(_songId)), findsOneWidget);
    expect(find.byKey(const ValueKey('collection-load-error')), findsNothing);

    final refreshIndicator = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    unawaited(refreshIndicator.show());
    await tester.pumpAndSettle();

    final staleWarning = find.byKey(const ValueKey('collection-load-error'));
    final retryButton = find.byKey(const ValueKey('collection-retry-button'));
    expect(attempts, 2);
    expect(staleWarning, findsOneWidget);
    expect(retryButton, findsOneWidget);
    expect(find.byKey(const ValueKey(_songId)), findsOneWidget);
    expect(find.text(_songTitle), findsWidgets);

    await tester.ensureVisible(retryButton);
    await tester.pumpAndSettle();
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(attempts, 3);
    expect(staleWarning, findsNothing);
    expect(find.byKey(const ValueKey(_songId)), findsOneWidget);
    expect(find.text(_songTitle), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mismatched collection response cannot replace or play target', (
    tester,
  ) async {
    await _setViewport(tester);
    var sourceCalls = 0;
    String? requestedCollectionId;
    final audioPlayer = FakePlaybackAudioPlayer();
    final controller = await _createController(
      audioPlayer: audioPlayer,
      sourceResolver: (_) async {
        sourceCalls++;
        return 'https://audio.example.com/mismatched.mp3';
      },
    );
    addTearDown(controller.dispose);

    await _pumpCollection(
      tester,
      controller,
      loadCollection: (id) async {
        requestedCollectionId = id;
        return _mismatchedCollectionDetail;
      },
    );
    await tester.pumpAndSettle();

    expect(requestedCollectionId, _collectionId);
    expect(find.byKey(const ValueKey('collection-load-error')), findsOneWidget);
    expect(find.text('Fail Closed'), findsWidgets);
    expect(find.text(_mismatchedCollectionTitle), findsNothing);
    expect(find.byKey(const ValueKey(_mismatchedSongId)), findsNothing);
    expect(find.byKey(const ValueKey('collection-save-button')), findsNothing);

    final heroPlay = find.byKey(const ValueKey('collection-play-button'));
    expect(heroPlay, findsOneWidget);
    expect(tester.widget<FilledButton>(heroPlay).onPressed, isNull);
    final artworkPlay = find.byKey(
      const ValueKey('collection-artwork-play-button'),
    );
    expect(artworkPlay, findsNothing);
    await tester.tap(heroPlay);
    await tester.pump();

    expect(controller.currentSong, isNull);
    expect(controller.queue, isEmpty);
    expect(controller.savedCollections, isEmpty);
    expect(controller.isCollectionSaved(_mismatchedCollection), isFalse);
    expect(sourceCalls, 0);
    expect(audioPlayer.playedSources, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection playback gate disables every playback entry point', (
    tester,
  ) async {
    await _setViewport(tester);
    var sourceCalls = 0;
    final audioPlayer = FakePlaybackAudioPlayer();
    final controller = await _createController(
      audioPlayer: audioPlayer,
      sourceResolver: (_) async {
        sourceCalls++;
        return 'https://audio.example.com/should-not-play.mp3';
      },
    );
    addTearDown(controller.dispose);

    await _pumpCollection(
      tester,
      controller,
      loadCollection: (_) async => _playbackDisabledDetail,
    );
    await tester.pumpAndSettle();

    final heroPlay = find.byKey(const ValueKey('collection-play-button'));
    expect(heroPlay, findsOneWidget);
    expect(tester.widget<FilledButton>(heroPlay).onPressed, isNull);

    final songRow = find.byKey(const ValueKey(_songId));
    await tester.ensureVisible(songRow);
    await tester.pumpAndSettle();
    await tester.tap(songRow);
    await tester.pumpAndSettle();

    expect(controller.currentSong, isNull);
    expect(controller.queue, isEmpty);
    expect(sourceCalls, 0);
    expect(audioPlayer.playedSources, isEmpty);

    await tester.tap(find.byKey(const ValueKey('song-action-menu-$_songId')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('song-action-menu-item-play-$_songId')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('song-action-menu-item-queue-$_songId')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('song-action-menu-item-radio-$_songId')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('song-action-menu-item-detail-$_songId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('song-action-menu-item-playlist-$_songId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('song-action-menu-item-like-$_songId')),
      findsOneWidget,
    );
    expect(controller.currentSong, isNull);
    expect(controller.queue, isEmpty);
    expect(sourceCalls, 0);
    expect(audioPlayer.playedSources, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'save is unavailable while loading and persists authoritative metadata',
    (tester) async {
      await _setViewport(tester);
      final controller = await _createController();
      addTearDown(controller.dispose);
      final detailCompleter = Completer<CatalogCollectionDetail>();
      var loadCalls = 0;

      await _pumpCollection(
        tester,
        controller,
        loadCollection: (_) {
          loadCalls++;
          return detailCompleter.future;
        },
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(loadCalls, 1);
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collection-save-button')),
        findsNothing,
      );
      expect(controller.savedCollections, isEmpty);

      detailCompleter.complete(_playbackEnabledDetail);
      await tester.pumpAndSettle();

      final saveButton = find.byKey(const ValueKey('collection-save-button'));
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pump();

      expect(controller.savedCollections, hasLength(1));
      expect(
        controller.savedCollections.single.id,
        _authoritativeCollection.id,
      );
      expect(
        controller.savedCollections.single.title,
        _authoritativeCollection.title,
      );
      expect(
        controller.savedCollections.single.artist,
        _authoritativeCollection.artist,
      );
      expect(
        controller.savedCollections.single.kind,
        _authoritativeCollection.kind,
      );
      expect(controller.isCollectionSaved(_authoritativeCollection), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _setViewport(
  WidgetTester tester, [
  Size size = const Size(1440, 900),
]) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<PlaybackService> _createController({
  FakePlaybackAudioPlayer? audioPlayer,
  Future<String> Function(String code)? sourceResolver,
}) async {
  final controller = PlaybackService(
    playbackAudioPlayer: audioPlayer ?? FakePlaybackAudioPlayer(),
    sourceResolver:
        sourceResolver ??
        (_) async => 'https://audio.example.com/collection.mp3',
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  return controller;
}

Future<void> _pumpCollection(
  WidgetTester tester,
  PlaybackService controller, {
  required Future<CatalogCollectionDetail> Function(String id) loadCollection,
}) => tester.pumpWidget(
  MusicPlayerScope(
    controller: controller,
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ZingChartScreen(
        initialOfficialUrl: _collectionUrl,
        chartRefreshInterval: null,
        loadSongs: () async => const [],
        loadDiscoveryHome: () async => const DiscoveryHome.empty(),
        loadDiscoveryCategories: () async => const DiscoveryCategories.empty(),
        loadCollection: loadCollection,
      ),
    ),
  ),
);

const _collectionId = 'COLLECTION_FAIL_CLOSED';
const _collectionUrl =
    'https://zingmp3.vn/playlist/fail-closed/$_collectionId.html';
const _songId = 'fail-closed-song';
const _songTitle = 'Bài Hát Chính Thức';

const _authoritativeCollection = CatalogCollection(
  id: _collectionId,
  title: 'Tuyển Tập Chính Thức',
  artist: 'Nghệ Sĩ Chính Thức',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: _collectionUrl,
);

const _song = Song(
  id: _songId,
  name: 'bai-hat-chinh-thuc',
  title: _songTitle,
  thumbnail: '',
  artistsNames: 'Nghệ Sĩ Chính Thức',
  code: 'official-source-code',
);

const _catalogSongMarkedPlayable = CatalogSong(
  song: _song,
  duration: Duration(minutes: 3, seconds: 45),
  externalUrl: '',
  playable: true,
  album: _authoritativeCollection,
);

const _playbackEnabledDetail = CatalogCollectionDetail(
  collection: _authoritativeCollection,
  description: 'Metadata chính thức đã được tải từ proxy.',
  year: '2026',
  genres: ['V-Pop'],
  songs: [_catalogSongMarkedPlayable],
  catalogPlaybackEnabled: true,
);

const _playbackDisabledDetail = CatalogCollectionDetail(
  collection: _authoritativeCollection,
  description: 'Catalog đang khóa phát dù bài hát được đánh dấu playable.',
  year: '2026',
  genres: ['V-Pop'],
  songs: [_catalogSongMarkedPlayable],
  catalogPlaybackEnabled: false,
);

const _mismatchedCollectionTitle = 'Không Được Hiển Thị';
const _mismatchedSongId = 'mismatched-playable-song';

const _mismatchedCollection = CatalogCollection(
  id: 'DIFFERENT_COLLECTION',
  title: _mismatchedCollectionTitle,
  artist: 'Nghệ Sĩ Sai',
  thumbnail: '',
  kind: CatalogCollectionKind.playlist,
  externalUrl:
      'https://zingmp3.vn/playlist/different/DIFFERENT_COLLECTION.html',
);

const _mismatchedCollectionDetail = CatalogCollectionDetail(
  collection: _mismatchedCollection,
  description: 'Response hợp lệ về cấu trúc nhưng sai collection ID.',
  year: '2026',
  genres: ['V-Pop'],
  songs: [
    CatalogSong(
      song: Song(
        id: _mismatchedSongId,
        name: 'mismatched-playable-song',
        title: 'Bài Sai Có Thể Phát',
        thumbnail: '',
        artistsNames: 'Nghệ Sĩ Sai',
        code: 'mismatched-source-code',
      ),
      duration: Duration(minutes: 4),
      externalUrl: '',
      playable: true,
      album: _mismatchedCollection,
    ),
  ],
  catalogPlaybackEnabled: true,
);
