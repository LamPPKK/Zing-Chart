import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/song_detail.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/music_player_screen.dart';
import 'package:zmp3chart/services/official_content_share_service.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/widgets/desktop_now_playing_panel.dart';
import 'package:zmp3chart/widgets/collection_detail_hero.dart';
import 'package:zmp3chart/widgets/official_content_share_dialog.dart';
import 'package:zmp3chart/widgets/song_detail_panel.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('accepts only official Zing content URLs for each share kind', () {
    expect(
      isTrustedOfficialContentUrl(
        const OfficialContentShare(
          kind: OfficialContentKind.song,
          title: 'Bài hát',
          subtitle: '',
          externalUrl: 'https://zingmp3.vn/bai-hat/bai-hat/SONG1.html',
        ),
      ),
      isTrue,
    );
    expect(
      isTrustedOfficialContentUrl(
        const OfficialContentShare(
          kind: OfficialContentKind.collection,
          title: 'Album cũ',
          subtitle: '',
          externalUrl: 'https://zingmp3.vn/link/album/ALBUM_1-test',
        ),
      ),
      isTrue,
    );
    for (final url in [
      'https://zingmp3.vn/link/album/ALBUM1/extra',
      'https://zingmp3.vn/link/album/ALBUM%201',
    ]) {
      expect(
        isTrustedOfficialContentUrl(
          OfficialContentShare(
            kind: OfficialContentKind.collection,
            title: 'Album không hợp lệ',
            subtitle: '',
            externalUrl: url,
          ),
        ),
        isFalse,
      );
    }
    expect(
      isTrustedOfficialContentUrl(
        const OfficialContentShare(
          kind: OfficialContentKind.song,
          title: 'Sai loại',
          subtitle: '',
          externalUrl: 'https://zingmp3.vn/link/album/ALBUM1',
        ),
      ),
      isFalse,
    );
    expect(
      isTrustedOfficialContentUrl(
        const OfficialContentShare(
          kind: OfficialContentKind.artist,
          title: 'Nghệ sĩ',
          subtitle: '',
          externalUrl: 'https://m.zingmp3.vn/nghe-si/Nghe-Si',
        ),
      ),
      isTrue,
    );
    expect(
      isTrustedOfficialContentUrl(
        const OfficialContentShare(
          kind: OfficialContentKind.collection,
          title: 'Album',
          subtitle: '',
          externalUrl: 'https://zingmp3.vn/album/album/ALBUM1.html',
        ),
      ),
      isTrue,
    );
    for (final url in [
      'https://evil.example/bai-hat/bai-hat/SONG1.html',
      'https://zingmp3.vn.evil.example/nghe-si/Nghe-Si',
      'https://user@zingmp3.vn/album/album/ALBUM1.html',
      'http://zingmp3.vn/bai-hat/bai-hat/SONG1.html',
    ]) {
      expect(
        isTrustedOfficialContentUrl(
          OfficialContentShare(
            kind: OfficialContentKind.song,
            title: 'Không hợp lệ',
            subtitle: '',
            externalUrl: url,
          ),
        ),
        isFalse,
      );
    }
  });

  testWidgets('opens official song information from mobile Now Playing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await controller.playSong(_firstSong);
    Uri? launched;
    String? requestedSongId;

    await tester.pumpWidget(
      _app(
        controller,
        MusicPlayerScreen(
          songDetailLoader: (songId) async {
            requestedSongId = songId;
            return _firstDetail;
          },
          songDetailExternalLauncher: (uri) async {
            launched = uri;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final infoButton = find.byKey(const ValueKey('open-song-detail'));
    await tester.ensureVisible(infoButton);
    await tester.tap(infoButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('song-detail-scroll')), findsOneWidget);
    expect(find.text('THÔNG TIN BÀI HÁT'), findsOneWidget);
    expect(find.text('Zing Music Distribution'), findsOneWidget);
    expect(find.text('Một Bài Hát (Single)'), findsOneWidget);
    expect(find.text('Việt Nam · V-Pop'), findsOneWidget);
    expect(find.text('LƯỢT NGHE'), findsOneWidget);
    expect(find.text('BÌNH LUẬN'), findsOneWidget);
    expect(requestedSongId, _firstSong.id);
    expect(tester.takeException(), isNull);

    final mvButton = find.byKey(const ValueKey('song-detail-open-mv-compact'));
    await tester.ensureVisible(mvButton);
    await tester.tap(mvButton);
    await tester.pumpAndSettle();
    expect(launched, Uri.parse(_firstDetail.mv!.externalUrl));
    expect(
      find.byKey(const ValueKey('catalog-video-handoff-dialog')),
      findsNothing,
    );
  });

  testWidgets('opens official artist and album targets from song metadata', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await controller.playSong(_firstSong);
    final openedArtists = <CatalogArtist>[];
    CatalogCollection? openedAlbum;

    await tester.pumpWidget(
      _app(
        controller,
        Scaffold(
          body: SongDetailPanel(
            controller: controller,
            detailLoader: (_) async => _firstDetail,
            onOpenArtist: openedArtists.add,
            onOpenAlbum: (album) => openedAlbum = album,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final artist = find.byKey(const ValueKey('song-detail-artist-artist-one'));
    await tester.ensureVisible(artist);
    await tester.tap(artist);
    await tester.pump();
    expect(openedArtists, [_firstDetail.artists.single]);

    final composer = find.byKey(
      const ValueKey('song-detail-composer-composer-one'),
    );
    await tester.ensureVisible(composer);
    await tester.tap(composer);
    await tester.pump();
    expect(openedArtists, [
      _firstDetail.artists.single,
      _firstDetail.composers.single,
    ]);

    final album = find.byKey(const ValueKey('song-detail-open-album'));
    await tester.ensureVisible(album);
    final albumSemantics = tester.widget<Semantics>(
      find.ancestor(of: album, matching: find.byType(Semantics)).first,
    );
    expect(
      albumSemantics.properties.label,
      'Mở album Một Bài Hát (Single), Ca Sĩ',
    );
    expect(albumSemantics.properties.button, isTrue);
    await tester.tap(album);
    await tester.pump();
    expect(openedAlbum, _firstDetail.album);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores stale song-detail responses after the track changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await controller.playSong(_firstSong);
    final first = Completer<SongDetail>();
    final second = Completer<SongDetail>();

    await tester.pumpWidget(
      _app(
        controller,
        Scaffold(
          body: SongDetailPanel(
            controller: controller,
            detailLoader: (songId) =>
                songId == _firstSong.id ? first.future : second.future,
          ),
        ),
      ),
    );
    await tester.pump();
    await controller.playSong(_secondSong);
    await tester.pump();
    second.complete(_secondDetail);
    await tester.pumpAndSettle();
    expect(find.text(_secondSong.displayTitle), findsOneWidget);

    first.complete(_firstDetail);
    await tester.pumpAndSettle();
    expect(find.text(_secondSong.displayTitle), findsOneWidget);
    expect(find.text(_firstSong.displayTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shares only the official song link through the platform sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await controller.playSong(_firstSong);
    final shareService = _RecordingShareService();

    await tester.pumpWidget(
      _app(
        controller,
        Scaffold(
          body: SongDetailPanel(
            controller: controller,
            detailLoader: (_) async => _firstDetail,
            shareService: shareService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final shareButton = find.byKey(const ValueKey('song-detail-share'));
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    expect(shareService.contents, hasLength(1));
    expect(shareService.contents.single.kind, OfficialContentKind.song);
    expect(shareService.contents.single.title, _firstSong.displayTitle);
    expect(shareService.contents.single.subtitle, _firstSong.artistsNames);
    expect(
      shareService.contents.single.externalUrl,
      _firstDetail.catalogSong.externalUrl,
    );
    expect(shareService.contents.single.message, isNot(contains('history')));
    expect(
      find.byKey(const ValueKey('official-content-share-dialog')),
      findsNothing,
    );
  });

  testWidgets('uses QR and copy handoff for song sharing on TV', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await controller.playSong(_firstSong);
    final shareService = _RecordingShareService();

    await tester.pumpWidget(
      _app(
        controller,
        Scaffold(
          body: SongDetailPanel(
            controller: controller,
            detailLoader: (_) async => _firstDetail,
            shareService: shareService,
            tvMode: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('song-detail-share')));
    await tester.pumpAndSettle();

    expect(shareService.contents, isEmpty);
    expect(
      find.byKey(const ValueKey('official-content-share-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('official-content-share-qr')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('official-content-copy-link')),
      findsOneWidget,
    );
    expect(find.text(_firstDetail.catalogSong.externalUrl), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses QR handoff for a legacy collection link on TV', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final shareService = _RecordingShareService();
    const collection = CatalogCollection(
      id: 'legacy-album',
      title: 'Album chính thức',
      artist: 'Nghệ sĩ',
      thumbnail: '',
      kind: CatalogCollectionKind.album,
      externalUrl: 'https://zingmp3.vn/link/album/LEGACY_ALBUM-1',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => CollectionDetailHero(
              collection: collection,
              detail: const CatalogCollectionDetail(
                collection: collection,
                description: '',
                year: '2024',
                genres: [],
                songs: [],
                catalogPlaybackEnabled: true,
              ),
              loading: false,
              onPlay: null,
              tvMode: true,
              onShare: () => shareOfficialContent(
                context,
                OfficialContentShare(
                  kind: OfficialContentKind.collection,
                  title: collection.title,
                  subtitle: collection.artist,
                  externalUrl: collection.externalUrl,
                ),
                service: shareService,
                forceHandoff: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('collection-share-button')));
    await tester.pumpAndSettle();

    expect(shareService.contents, isEmpty);
    expect(
      find.byKey(const ValueKey('official-content-share-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('official-content-share-qr')),
      findsOneWidget,
    );
    expect(find.text(collection.externalUrl), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falls back to QR when a platform share adapter is unavailable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await controller.playSong(_firstSong);
    final shareService = _RecordingShareService(
      result: OfficialContentShareResult.unavailable,
    );

    await tester.pumpWidget(
      _app(
        controller,
        Scaffold(
          body: SongDetailPanel(
            controller: controller,
            detailLoader: (_) async => _firstDetail,
            shareService: shareService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('song-detail-share')));
    await tester.pumpAndSettle();

    expect(shareService.contents, hasLength(1));
    expect(
      find.byKey(const ValueKey('official-content-share-dialog')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps retry available after a detail request fails', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await controller.playSong(_firstSong);
    var calls = 0;

    await tester.pumpWidget(
      _app(
        controller,
        Scaffold(
          body: SongDetailPanel(
            controller: controller,
            detailLoader: (_) async {
              calls++;
              if (calls == 1) throw StateError('upstream unavailable');
              return _firstDetail;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa tải được thông tin bài hát'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('song-detail-retry')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Zing Music Distribution'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a QR handoff for official MV on TV', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await controller.playSong(_firstSong);
    var launchCalls = 0;

    await tester.pumpWidget(
      _app(
        controller,
        Scaffold(
          body: SongDetailPanel(
            controller: controller,
            detailLoader: (_) async => _firstDetail,
            externalLauncher: (_) async {
              launchCalls++;
              return true;
            },
            tvMode: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('song-detail-open-mv')));
    await tester.pumpAndSettle();

    expect(launchCalls, 0);
    expect(
      find.byKey(const ValueKey('catalog-video-handoff-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('catalog-video-qr')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens song information from the desktop Now Playing panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await controller.playSong(_firstSong);

    await tester.pumpWidget(
      _app(
        controller,
        Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: DesktopNowPlayingPanel(
              songDetailLoader: (_) async => _firstDetail,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('desktop-artwork-atmosphere')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('desktop-open-song-detail')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('song-detail-scroll')), findsOneWidget);
    expect(find.text('Zing Music Distribution'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [
    (size: const Size(360, 844), tvMode: false),
    (size: const Size(768, 1024), tvMode: false),
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'song information is responsive at ${viewport.size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = await _controller();
        addTearDown(controller.dispose);
        await controller.playSong(_firstSong);

        await tester.pumpWidget(
          _app(
            controller,
            Scaffold(
              body: SongDetailPanel(
                controller: controller,
                detailLoader: (_) async => _firstDetail,
                onOpenArtist: (_) {},
                onOpenAlbum: (_) {},
                tvMode: viewport.tvMode,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('song-detail-scroll')),
          findsOneWidget,
        );
        expect(find.text('Thông Tin'), findsOneWidget);
        expect(find.text('PHÁT ĐƯỢC'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('song-detail-artist-artist-one')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('song-detail-open-album')),
          findsOneWidget,
        );
        expect(FocusManager.instance.primaryFocus, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _app(PlaybackService controller, Widget home) => MusicPlayerScope(
  controller: controller,
  child: MaterialApp(theme: ThemeData.dark(useMaterial3: true), home: home),
);

Future<PlaybackService> _controller() async {
  final controller = PlaybackService(
    playbackAudioPlayer: FakePlaybackAudioPlayer(),
    sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  return controller;
}

const _firstSong = Song(
  id: 'song-one',
  name: 'song-one',
  title: 'Một Bài Hát',
  thumbnail: '',
  artistsNames: 'Ca Sĩ',
  code: 'code-one',
);

const _secondSong = Song(
  id: 'song-two',
  name: 'song-two',
  title: 'Bài Hát Tiếp Theo',
  thumbnail: '',
  artistsNames: 'Nghệ Sĩ B',
  code: 'code-two',
);

const _firstDetail = SongDetail(
  catalogSong: CatalogSong(
    song: _firstSong,
    duration: Duration(minutes: 3, seconds: 42),
    externalUrl: 'https://zingmp3.vn/bai-hat/mot-bai-hat/code-one.html',
    playable: true,
    hasLyrics: true,
  ),
  artists: [
    CatalogArtist(
      id: 'artist-one',
      name: 'Ca Sĩ',
      aliasName: 'Ca-Si',
      avatar: '',
    ),
  ],
  album: CatalogCollection(
    id: 'album-one',
    title: 'Một Bài Hát (Single)',
    artist: 'Ca Sĩ',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: 'https://zingmp3.vn/album/mot-bai-hat/album-one.html',
  ),
  releasedAt: null,
  distributor: 'Zing Music Distribution',
  genres: ['Việt Nam', 'V-Pop'],
  composers: [
    CatalogArtist(
      id: 'composer-one',
      name: 'Nhạc Sĩ',
      aliasName: 'Nhac-Si',
      avatar: '',
    ),
  ],
  listenCount: 1234567,
  likeCount: 45678,
  commentCount: 321,
  mv: CatalogVideo(
    id: 'code-one',
    title: 'Một Bài Hát',
    artist: 'Ca Sĩ',
    thumbnail: '',
    duration: Duration(minutes: 3, seconds: 42),
    externalUrl: 'https://zingmp3.vn/video-clip/mot-bai-hat/code-one.html',
  ),
  catalogPlaybackEnabled: true,
);

const _secondDetail = SongDetail(
  catalogSong: CatalogSong(
    song: _secondSong,
    duration: Duration(minutes: 4),
    externalUrl: 'https://zingmp3.vn/bai-hat/bai-hat-tiep-theo/code-two.html',
    playable: true,
  ),
  artists: [],
  album: null,
  releasedAt: null,
  distributor: 'Nhà phát hành B',
  genres: ['V-Pop'],
  composers: [],
  listenCount: 0,
  likeCount: 10,
  commentCount: 2,
  mv: null,
  catalogPlaybackEnabled: true,
);

class _RecordingShareService implements OfficialContentShareService {
  _RecordingShareService({this.result = OfficialContentShareResult.shared});

  final List<OfficialContentShare> contents = [];
  final OfficialContentShareResult result;

  @override
  Future<OfficialContentShareResult> share(
    OfficialContentShare content, {
    Rect? origin,
  }) async {
    contents.add(content);
    return result;
  }
}
