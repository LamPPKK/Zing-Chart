import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/catalog_artist_detail.dart';
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

  testWidgets(
    'collection participants follow locally and return from artist without refetch',
    (tester) async {
      await _setViewport(tester);
      final controller = await _createController();
      addTearDown(controller.dispose);
      var collectionLoads = 0;
      var artistLoads = 0;

      await _pumpApp(
        tester,
        controller,
        loadCollection: (id) async {
          collectionLoads++;
          expect(id, _mainCollection.id);
          return _mainDetail;
        },
        loadArtistDetail: (alias) async {
          artistLoads++;
          expect(alias, _participant.aliasName);
          return _participantDetail;
        },
      );
      await tester.pumpAndSettle();

      final participant = find.byKey(
        const ValueKey('collection-participant-participant'),
      );
      final follow = find.byKey(
        const ValueKey('collection-participant-follow-participant'),
      );
      expect(participant, findsOneWidget);
      expect(follow, findsOneWidget);

      await tester.ensureVisible(follow);
      await tester.pumpAndSettle();
      await tester.tap(follow);
      await tester.pump();

      expect(controller.followedArtists.map((artist) => artist.id), [
        _participant.id,
      ]);
      expect(find.text('Đang quan tâm'), findsOneWidget);

      await tester.ensureVisible(participant);
      await tester.pumpAndSettle();
      await tester.tap(participant);
      await tester.pumpAndSettle();

      expect(artistLoads, 1);
      expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
      expect(find.text(_participant.name), findsWidgets);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(collectionLoads, 1);
      expect(
        find.byKey(const ValueKey('collection-detail-catalog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collection-participant-participant')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('related collection actions save and play the exact collection', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    final audioPlayer = FakePlaybackAudioPlayer();
    final requestedSources = <String>[];
    final controller = await _createController(
      audioPlayer: audioPlayer,
      sourceResolver: (code) async {
        requestedSources.add(code);
        return 'https://audio.example.com/$code.mp3';
      },
    );
    addTearDown(controller.dispose);
    final loadedIds = <String>[];

    await _pumpApp(
      tester,
      controller,
      loadCollection: (id) async {
        loadedIds.add(id);
        return id == _relatedCollection.id ? _relatedDetail : _mainDetail;
      },
    );
    await tester.pumpAndSettle();

    final relatedCard = find.byKey(
      const ValueKey('collection-related-related'),
    );
    await tester.dragUntilVisible(
      relatedCard,
      find.byType(CustomScrollView),
      const Offset(0, -420),
    );
    await tester.ensureVisible(relatedCard);
    await tester.pumpAndSettle();
    final save = find.byKey(const ValueKey('collection-related-save-related'));
    expect(save, findsOneWidget);
    await tester.tap(save);
    await tester.pump();

    expect(controller.isCollectionSaved(_relatedCollection), isTrue);

    final play = find.byKey(const ValueKey('collection-related-play-related'));
    expect(play, findsOneWidget);
    await tester.tap(play);
    await tester.pumpAndSettle();

    expect(loadedIds, [_mainCollection.id, _relatedCollection.id]);
    expect(controller.currentSong?.id, _relatedSong.id);
    expect(controller.queue.map((song) => song.id), [_relatedSong.id]);
    expect(requestedSources, [_relatedSong.code]);
    expect(audioPlayer.playedSources, hasLength(1));
    expect(tester.takeException(), isNull);
  });
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
        sourceResolver ?? (code) async => 'https://audio.example.com/$code.mp3',
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  return controller;
}

Future<void> _pumpApp(
  WidgetTester tester,
  PlaybackService controller, {
  required Future<CatalogCollectionDetail> Function(String id) loadCollection,
  Future<CatalogArtistDetail> Function(String alias)? loadArtistDetail,
}) => tester.pumpWidget(
  MusicPlayerScope(
    controller: controller,
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ZingChartScreen(
        initialOfficialUrl: _mainCollection.externalUrl,
        chartRefreshInterval: null,
        loadSongs: () async => const [],
        loadDiscoveryHome: () async => const DiscoveryHome.empty(),
        loadDiscoveryCategories: () async => const DiscoveryCategories.empty(),
        loadCollection: loadCollection,
        loadArtistDetail: loadArtistDetail ?? (_) async => _participantDetail,
      ),
    ),
  ),
);

const _participant = CatalogArtist(
  id: 'participant',
  name: 'Nghệ Sĩ Tham Gia',
  aliasName: 'Nghe-Si-Tham-Gia',
  avatar: '',
  externalUrl: 'https://zingmp3.vn/nghe-si/Nghe-Si-Tham-Gia',
  totalFollow: 12400,
);

const _mainCollection = CatalogCollection(
  id: 'main-collection',
  title: 'Album Chính Thức',
  artist: 'Nghệ Sĩ Tham Gia',
  artists: [_participant],
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: 'https://zingmp3.vn/album/album-chinh-thuc/main-collection.html',
);

const _relatedCollection = CatalogCollection(
  id: 'related',
  title: 'Tuyển Tập Liên Quan',
  artist: 'Nghệ Sĩ Tham Gia',
  artists: [_participant],
  thumbnail: '',
  kind: CatalogCollectionKind.playlist,
  externalUrl: 'https://zingmp3.vn/playlist/lien-quan/related.html',
);

const _mainSong = Song(
  id: 'main-song',
  name: 'main-song',
  title: 'Bài Trong Album',
  thumbnail: '',
  artistsNames: 'Nghệ Sĩ Tham Gia',
  code: 'main-code',
);

const _relatedSong = Song(
  id: 'related-song',
  name: 'related-song',
  title: 'Bài Trong Tuyển Tập Liên Quan',
  thumbnail: '',
  artistsNames: 'Nghệ Sĩ Tham Gia',
  code: 'related-code',
);

const _mainDetail = CatalogCollectionDetail(
  collection: _mainCollection,
  artists: [_participant],
  description: 'Album chính thức với danh sách nghệ sĩ tham gia.',
  year: '2026',
  distributor: 'Zing Music Distribution',
  genres: ['V-Pop'],
  songs: [
    CatalogSong(
      song: _mainSong,
      duration: Duration(minutes: 3),
      externalUrl: '',
      playable: true,
      artists: [_participant],
      album: _mainCollection,
    ),
  ],
  sections: [
    CatalogCollectionSection(
      id: 'related-section',
      title: 'Có Thể Bạn Quan Tâm',
      collections: [_relatedCollection],
    ),
  ],
  catalogPlaybackEnabled: true,
);

const _relatedDetail = CatalogCollectionDetail(
  collection: _relatedCollection,
  artists: [_participant],
  description: '',
  year: '2026',
  genres: ['V-Pop'],
  songs: [
    CatalogSong(
      song: _relatedSong,
      duration: Duration(minutes: 3, seconds: 20),
      externalUrl: '',
      playable: true,
      artists: [_participant],
      album: _relatedCollection,
    ),
  ],
  catalogPlaybackEnabled: true,
);

const _participantDetail = CatalogArtistDetail(
  artist: _participant,
  cover: '',
  biography: 'Hồ sơ nghệ sĩ chính thức.',
  realName: '',
  national: 'Việt Nam',
  birthday: '',
  totalFollow: 12400,
  awardCount: 0,
  songs: [
    CatalogSong(
      song: _mainSong,
      duration: Duration(minutes: 3),
      externalUrl: '',
      playable: true,
      artists: [_participant],
      album: _mainCollection,
    ),
  ],
  collectionSections: [],
  relatedArtists: [],
  catalogPlaybackEnabled: true,
);
