import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/official_content_share_service.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/album_art.dart';
import 'package:zmp3chart/zing_chart_screen.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in const [320.0, 360.0, 390.0, 719.0, 720.0, 768.0]) {
    testWidgets(
      'Android collection shell keeps compact actions and long metadata safe '
      'at ${width.toInt()}px',
      (tester) async {
        final harness = await _pumpCollection(tester, size: Size(width, 844));

        expect(
          find.byKey(const ValueKey('collection-detail-hero')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('collection-play-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('collection-save-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('collection-more-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('collection-share-button')),
          findsNothing,
        );
        final hero = find.byKey(const ValueKey('collection-detail-hero'));
        final artwork = find
            .descendant(of: hero, matching: find.byType(AlbumArt))
            .first;
        final play = find.byKey(const ValueKey('collection-play-button'));
        if (width >= 719) {
          expect(
            tester.getCenter(play).dx,
            greaterThan(tester.getCenter(artwork).dx),
            reason: '719/720/768 must keep the same horizontal hero rhythm.',
          );
        } else {
          expect(
            tester.getCenter(play).dy,
            greaterThan(tester.getCenter(artwork).dy),
          );
        }
        final artistLink = find.byKey(
          const ValueKey('collection-artist-mobile-collection-artist'),
        );
        expect(artistLink, findsOneWidget);
        expect(tester.getSize(artistLink).height, greaterThanOrEqualTo(44));
        final trackArtistLink = find
            .descendant(
              of: find.byKey(const ValueKey('song-artist-link-$_firstSongId')),
              matching: find.byType(TextButton),
            )
            .first;
        expect(trackArtistLink, findsOneWidget);
        expect(
          tester.getSize(trackArtistLink).height,
          greaterThanOrEqualTo(44),
        );
        expect(
          find.descendant(
            of: hero,
            matching: find.byKey(
              const ValueKey('collection-artist-mobile-guest-artist'),
            ),
          ),
          findsNothing,
          reason: 'Participant artists belong after the track list.',
        );
        expect(harness.controller.savedCollections, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('360x844 shows the first collection track before any scroll', (
    tester,
  ) async {
    await _pumpCollection(tester, size: const Size(360, 844));

    final firstTrack = find.byKey(const ValueKey(_firstSongId));
    final navigation = find.byKey(const ValueKey('mobile-primary-navigation'));
    expect(firstTrack, findsOneWidget);
    expect(navigation, findsOneWidget);

    final trackRect = tester.getRect(firstTrack);
    final navigationRect = tester.getRect(navigation);
    expect(trackRect.bottom, greaterThan(0));
    expect(
      trackRect.top,
      lessThan(navigationRect.top),
      reason:
          'At least the first track must enter the initial content viewport.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact collection Play Save and More actions stay isolated', (
    tester,
  ) async {
    final harness = await _pumpCollection(tester, size: const Size(390, 844));

    await tester.tap(find.byKey(const ValueKey('collection-save-button')));
    await tester.pumpAndSettle();

    expect(harness.controller.savedCollections, hasLength(1));
    expect(harness.controller.savedCollections.single.id, _collectionId);
    expect(harness.controller.currentSong, isNull);
    expect(harness.audioPlayer.playedSources, isEmpty);
    expect(harness.shareService.contents, isEmpty);

    await tester.tap(find.byKey(const ValueKey('collection-more-button')));
    await tester.pumpAndSettle();

    final shareAction = find.byKey(
      const ValueKey('collection-hero-menu-share-$_collectionId'),
    );
    expect(shareAction, findsOneWidget);
    expect(harness.controller.savedCollections, hasLength(1));
    expect(harness.controller.currentSong, isNull);
    expect(harness.audioPlayer.playedSources, isEmpty);
    expect(harness.shareService.contents, isEmpty);

    await tester.tap(shareAction);
    await tester.pumpAndSettle();

    expect(harness.shareService.contents, hasLength(1));
    expect(
      harness.shareService.contents.single.kind,
      OfficialContentKind.collection,
    );
    expect(harness.shareService.contents.single.externalUrl, _collectionUrl);
    expect(harness.controller.savedCollections, hasLength(1));
    expect(harness.controller.currentSong, isNull);
    expect(harness.audioPlayer.playedSources, isEmpty);

    await tester.tap(find.byKey(const ValueKey('collection-play-button')));
    await tester.pumpAndSettle();

    expect(harness.controller.savedCollections, hasLength(1));
    expect(harness.shareService.contents, hasLength(1));
    expect(harness.controller.currentSong?.id, _firstSongId);
    expect(
      harness.controller.queue.map((song) => song.id),
      _catalogSongs.map((item) => item.song.id),
    );
    expect(harness.audioPlayer.playedSources, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final width in const [320.0, 360.0, 390.0]) {
    testWidgets(
      'every track has one persistent trailing More and Like stays in its '
      'menu at ${width.toInt()}px',
      (tester) async {
        await _pumpCollection(tester, size: Size(width, 844));

        for (final catalogSong in _catalogSongs) {
          final song = catalogSong.song;
          final row = find.byKey(ValueKey(song.id));
          await tester.ensureVisible(row);
          await tester.pumpAndSettle();

          final more = find.descendant(
            of: row,
            matching: find.byKey(ValueKey('song-action-menu-${song.id}')),
          );
          expect(more, findsOneWidget);
          expect(more.hitTestable(), findsOneWidget);
          expect(
            tester.getCenter(more).dx,
            greaterThan(tester.getCenter(row).dx),
          );
          expect(
            find.descendant(of: row, matching: find.byTooltip('Yêu thích')),
            findsNothing,
            reason: 'Like must not consume a second persistent row action.',
          );

          await tester.tap(more);
          await tester.pumpAndSettle();
          expect(
            find.byKey(ValueKey('song-action-menu-item-like-${song.id}')),
            findsOneWidget,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('catalog playback gate disables hero and row playback globally', (
    tester,
  ) async {
    final harness = await _pumpCollection(
      tester,
      size: const Size(390, 844),
      catalogPlaybackEnabled: false,
    );

    await tester.tap(
      find.byKey(const ValueKey('collection-play-button')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(harness.controller.currentSong, isNull);
    expect(harness.controller.queue, isEmpty);
    expect(harness.sourceCalls, 0);
    expect(harness.audioPlayer.playedSources, isEmpty);

    await tester.tap(find.byKey(const ValueKey('collection-more-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collection-hero-menu-play-$_collectionId')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('collection-hero-menu-share-$_collectionId')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    final firstRow = find.byKey(const ValueKey(_firstSongId));
    await tester.ensureVisible(firstRow);
    await tester.pumpAndSettle();
    final firstRowRect = tester.getRect(firstRow);
    await tester.tapAt(Offset(firstRowRect.left + 16, firstRowRect.center.dy));
    await tester.pumpAndSettle();

    expect(harness.controller.currentSong, isNull);
    expect(harness.controller.queue, isEmpty);
    expect(harness.sourceCalls, 0);
    expect(harness.audioPlayer.playedSources, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('song-action-menu-$_firstSongId')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('song-action-menu-item-play-$_firstSongId')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('song-action-menu-item-queue-$_firstSongId')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('song-action-menu-item-radio-$_firstSongId')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('song-action-menu-item-share-$_firstSongId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('song-action-menu-item-like-$_firstSongId')),
      findsOneWidget,
    );
    expect(harness.controller.currentSong, isNull);
    expect(harness.controller.queue, isEmpty);
    expect(harness.sourceCalls, 0);
    expect(harness.audioPlayer.playedSources, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

Future<_CollectionHarness> _pumpCollection(
  WidgetTester tester, {
  required Size size,
  bool catalogPlaybackEnabled = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final audioPlayer = FakePlaybackAudioPlayer();
  var sourceCalls = 0;
  final controller = PlaybackService(
    playbackAudioPlayer: audioPlayer,
    sourceResolver: (code) async {
      sourceCalls++;
      return 'https://audio.example.com/$code.mp3';
    },
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  addTearDown(controller.dispose);
  final shareService = _RecordingOfficialContentShareService();
  final detail = _detail(catalogPlaybackEnabled: catalogPlaybackEnabled);

  await tester.pumpWidget(
    MusicPlayerScope(
      controller: controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(
          tvMode: false,
        ).copyWith(platform: TargetPlatform.android),
        home: ZingChartScreen(
          loadSongs: () async =>
              _catalogSongs.map((item) => item.song).toList(growable: false),
          loadDiscoveryHome: () async => const DiscoveryHome.empty(),
          loadCollection: (id) async {
            expect(id, _collectionId);
            return detail;
          },
          chartRefreshInterval: null,
          initialOfficialUrl: _collectionUrl,
          officialContentShareService: shareService,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _CollectionHarness(
    controller: controller,
    audioPlayer: audioPlayer,
    shareService: shareService,
    sourceCalls: () => sourceCalls,
  );
}

class _CollectionHarness {
  const _CollectionHarness({
    required this.controller,
    required this.audioPlayer,
    required this.shareService,
    required int Function() sourceCalls,
  }) : _sourceCalls = sourceCalls;

  final PlaybackService controller;
  final FakePlaybackAudioPlayer audioPlayer;
  final _RecordingOfficialContentShareService shareService;
  final int Function() _sourceCalls;

  int get sourceCalls => _sourceCalls();
}

class _RecordingOfficialContentShareService
    implements OfficialContentShareService {
  final List<OfficialContentShare> contents = [];

  @override
  Future<OfficialContentShareResult> share(
    OfficialContentShare content, {
    Rect? origin,
  }) async {
    contents.add(content);
    return OfficialContentShareResult.shared;
  }
}

CatalogCollectionDetail _detail({required bool catalogPlaybackEnabled}) =>
    CatalogCollectionDetail(
      collection: _collection,
      artists: const [_artist, _guestArtist],
      description:
          'Tuyển tập chính thức với phần mô tả rất dài để xác nhận giao diện '
          'mobile luôn cắt dòng an toàn, không đẩy hành động hoặc bài hát đầu '
          'tiên ra khỏi vùng xem ban đầu trên những màn hình hẹp nhất.',
      year: '2026',
      releasedAt: DateTime(2026, 8, 25),
      distributor:
          'Nhà phát hành có tên rất dài dùng để kiểm thử metadata responsive',
      likeCount: 9876543,
      genres: const [
        'V-Pop đương đại',
        'Nhạc trẻ Việt Nam có tên thể loại rất dài',
      ],
      songs: _catalogSongs,
      catalogPlaybackEnabled: catalogPlaybackEnabled,
    );

const _collectionId = 'mobile-collection';
const _collectionUrl =
    'https://zingmp3.vn/album/bo-suu-tap-mobile/mobile-collection.html';
const _firstSongId = 'mobile-collection-song-1';

const _artist = CatalogArtist(
  id: 'mobile-collection-artist',
  name: 'Nghệ Sĩ Có Tên Rất Dài Để Kiểm Thử Giao Diện Mobile',
  aliasName: 'Nghe-Si-Mobile',
  avatar: '',
);

const _guestArtist = CatalogArtist(
  id: 'mobile-guest-artist',
  name: 'Nghệ Sĩ Khách Mời',
  aliasName: 'Nghe-Si-Khach-Moi',
  avatar: '',
);

const _collection = CatalogCollection(
  id: _collectionId,
  title:
      'Tuyển Tập Có Tiêu Đề Rất Dài Nhưng Vẫn Phải Hiển Thị Gọn Gàng Trên Mobile',
  artist:
      'Nghệ Sĩ Có Tên Rất Dài Để Kiểm Thử Giao Diện Mobile, '
      'Nghệ Sĩ Khách Mời',
  artists: [_artist],
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: _collectionUrl,
);

const _catalogSongs = <CatalogSong>[
  CatalogSong(
    song: Song(
      id: _firstSongId,
      name: 'mobile-collection-song-1',
      title: 'Bài Hát Đầu Tiên Có Tiêu Đề Rất Dài Để Kiểm Thử Cắt Dòng An Toàn',
      thumbnail: '',
      artistsNames:
          'Nghệ Sĩ Chính, Nghệ Sĩ Khách Mời Có Tên Rất Dài, Một Nghệ Sĩ Khác',
      code: 'mobile-source-1',
    ),
    duration: Duration(minutes: 4, seconds: 32),
    externalUrl:
        'https://zingmp3.vn/bai-hat/mobile-collection-song-1/mobile-collection-song-1.html',
    playable: true,
    artists: [_artist],
    album: _collection,
  ),
  CatalogSong(
    song: Song(
      id: 'mobile-collection-song-2',
      name: 'mobile-collection-song-2',
      title: 'Bài Hát Thứ Hai',
      thumbnail: '',
      artistsNames: 'Nghệ Sĩ Mobile',
      code: 'mobile-source-2',
    ),
    duration: Duration(minutes: 3, seconds: 58),
    externalUrl:
        'https://zingmp3.vn/bai-hat/mobile-collection-song-2/mobile-collection-song-2.html',
    playable: true,
    artists: [_artist],
    album: _collection,
  ),
  CatalogSong(
    song: Song(
      id: 'mobile-collection-song-3',
      name: 'mobile-collection-song-3',
      title: 'Bài Hát Thứ Ba',
      thumbnail: '',
      artistsNames: 'Nghệ Sĩ Mobile',
      code: 'mobile-source-3',
    ),
    duration: Duration(minutes: 5, seconds: 4),
    externalUrl:
        'https://zingmp3.vn/bai-hat/mobile-collection-song-3/mobile-collection-song-3.html',
    playable: true,
    artists: [_artist],
    album: _collection,
  ),
];
