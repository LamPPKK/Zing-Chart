import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/main.dart';
import 'package:zmp3chart/models/catalog_artist_detail.dart';
import 'package:zmp3chart/models/catalog_hub.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/live_radio.dart';
import 'package:zmp3chart/models/release_catalog.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/song_detail.dart';
import 'package:zmp3chart/models/weekly_chart.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/zing_chart_screen.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pastes a legacy Zing album URL and opens its internal detail', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 844));
    final controller = await _controller();
    addTearDown(controller.dispose);
    String? requestedCollectionId;
    var searchCalls = 0;

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          loadSongs: () async => const [_song],
          searchCatalog: (query) async {
            searchCalls++;
            return CatalogSearchResult.empty(query);
          },
          clipboardTextReader: () async =>
              'https://zingmp3.vn/link/album/ALBUM1',
          loadCollection: (id) async {
            requestedCollectionId = id;
            return _collectionDetail;
          },
          loadSongDetail: (_) async => _songDetail,
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chart-search-field')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paste-zing-link-button')));
    await tester.pumpAndSettle();

    expect(requestedCollectionId, 'ALBUM1');
    expect(searchCalls, 0);
    expect(
      find.byKey(const ValueKey('collection-detail-hero')),
      findsOneWidget,
    );
    expect(find.text(_collection.title), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a song URL by public ID and waits for explicit Play', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 844));
    final controller = await _controller();
    addTearDown(controller.dispose);
    String? requestedSongId;
    var searchCalls = 0;

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          loadSongs: () async => const [_song],
          searchCatalog: (query) async {
            searchCalls++;
            return CatalogSearchResult.empty(query);
          },
          loadSongDetail: (id) async {
            requestedSongId = id;
            return _songDetail;
          },
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chart-search-field')),
      'https://zingmp3.vn/bai-hat/Mot-Bai-Hat/SONG1.html',
    );
    await tester.pump(const Duration(milliseconds: 220));
    await tester.pumpAndSettle();

    expect(requestedSongId, 'SONG1');
    expect(searchCalls, 0);
    expect(controller.currentSong, isNull);
    expect(find.byKey(const ValueKey('song-detail-scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('song-detail-play')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('song-detail-play')));
    await tester.pumpAndSettle();

    expect(controller.currentSong?.id, _song.id);
    expect(find.text(_song.displayTitle), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial song deep link opens details without autoplay', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 900));
    final controller = await _controller();
    addTearDown(controller.dispose);
    var detailCalls = 0;

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          initialOfficialUrl:
              'https://zingmp3.vn/bai-hat/Mot-Bai-Hat/SONG1.html',
          loadSongs: () async => const [_song],
          loadSongDetail: (id) async {
            detailCalls++;
            expect(id, 'SONG1');
            return _songDetail;
          },
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(detailCalls, 1);
    expect(controller.currentSong, isNull);
    expect(find.byKey(const ValueKey('song-detail-scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('song-detail-play')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial MV deep link waits for an explicit external handoff', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 844));
    final controller = await _controller();
    addTearDown(controller.dispose);
    final launched = <Uri>[];
    var searchCalls = 0;
    var detailCalls = 0;

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          initialOfficialUrl:
              'https://zingmp3.vn/video-clip/MV-Chinh-Thuc/MV1.html',
          loadSongs: () async => const [_song],
          searchCatalog: (query) async {
            searchCalls++;
            return CatalogSearchResult.empty(query);
          },
          loadSongDetail: (_) async {
            detailCalls++;
            return _songDetail;
          },
          launchExternalCatalog: (uri) async {
            launched.add(uri);
            return true;
          },
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.currentSong, isNull);
    expect(searchCalls, 0);
    expect(detailCalls, 0);
    expect(launched, isEmpty);
    expect(
      find.byKey(const ValueKey('catalog-video-handoff-dialog')),
      findsOneWidget,
    );
    expect(find.text('MV Chinh Thuc'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('catalog-video-open-external')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('catalog-video-open-external')));
    await tester.pumpAndSettle();

    expect(launched.map((uri) => uri.toString()), [
      'https://zingmp3.vn/video-clip/MV-Chinh-Thuc/MV1.html',
    ]);
    expect(
      find.byKey(const ValueKey('catalog-video-handoff-dialog')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV MV deep link uses QR without launching another app', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1920, 1080));
    final controller = await _controller();
    addTearDown(controller.dispose);
    var launchCalls = 0;

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          tvMode: true,
          initialOfficialUrl:
              'https://zingmp3.vn/video-clip/MV-Chinh-Thuc/MV1.html',
          loadSongs: () async => const [_song],
          launchExternalCatalog: (_) async {
            launchCalls++;
            return true;
          },
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.currentSong, isNull);
    expect(launchCalls, 0);
    expect(find.byKey(const ValueKey('catalog-video-qr')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('catalog-video-open-external')),
      findsNothing,
    );
    expect(
      find.text('https://zingmp3.vn/video-clip/MV-Chinh-Thuc/MV1.html'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed MV handoff keeps QR and copy fallback available', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 844));
    final controller = await _controller();
    addTearDown(controller.dispose);
    var launchCalls = 0;

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          initialOfficialUrl:
              'https://zingmp3.vn/video-clip/MV-Chinh-Thuc/MV1.html',
          loadSongs: () async => const [_song],
          launchExternalCatalog: (_) async {
            launchCalls++;
            return false;
          },
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('catalog-video-open-external')));
    await tester.pumpAndSettle();

    expect(launchCalls, 1);
    expect(
      find.byKey(const ValueKey('catalog-video-handoff-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('catalog-video-qr')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('catalog-video-copy-link')),
      findsOneWidget,
    );
    expect(
      find.text('Không mở được Zing MP3. Hãy quét hoặc sao chép link.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked song deep link still opens metadata without Play', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 844));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          initialOfficialUrl:
              'https://zingmp3.vn/bai-hat/Bai-Bi-Gioi-Han/LOCKED1.html',
          loadSongs: () async => const [_song],
          loadSongDetail: (_) async => _lockedSongDetail,
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.currentSong, isNull);
    expect(find.byKey(const ValueKey('song-detail-scroll')), findsOneWidget);
    expect(find.text('BỊ GIỚI HẠN'), findsOneWidget);
    expect(find.byKey(const ValueKey('song-detail-play')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('routes an initial weekly-chart URL to the matching region', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 900));
    final controller = await _controller();
    addTearDown(controller.dispose);
    WeeklyChartRegion? requestedRegion;

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          initialOfficialUrl:
              'https://zingmp3.vn/zing-chart-tuan/Bai-hat-US-UK/IWZ9Z0BW.html',
          loadSongs: () async => const [_song],
          loadWeeklyChart: (region, {week, year}) async {
            requestedRegion = region;
            return _weeklyChart(region);
          },
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedRegion, WeeklyChartRegion.usuk);
    expect(find.text('US-UK'), findsWidgets);
    expect(find.text(_song.displayTitle), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('routes official artist and hub URLs to internal details', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 900));
    final controller = await _controller();
    addTearDown(controller.dispose);
    String? requestedArtistAlias;
    String? requestedHubId;

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          key: const ValueKey('artist-link-screen'),
          initialOfficialUrl: 'https://zingmp3.vn/Taylor-Swift',
          loadSongs: () async => const [_song],
          loadArtistDetail: (alias) async {
            requestedArtistAlias = alias;
            return _artistDetail;
          },
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedArtistAlias, 'Taylor-Swift');
    expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
    expect(find.text(_artist.name), findsWidgets);

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          key: const ValueKey('hub-link-screen'),
          initialOfficialUrl: 'https://zingmp3.vn/hub/Nhac-Chill/HUB1.html',
          loadSongs: () async => const [_song],
          loadHubDetail: (id) async {
            requestedHubId = id;
            return _hubDetail;
          },
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedHubId, 'HUB1');
    expect(find.byKey(const ValueKey('hub-detail')), findsOneWidget);
    expect(find.text(_hub.title), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('routes official artist sections and expands featured songs', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 900));
    final controller = await _controller();
    addTearDown(controller.dispose);

    Future<void> pumpArtist(String url, Key key) async {
      await tester.pumpWidget(
        _app(
          controller,
          ZingChartScreen(
            key: key,
            initialOfficialUrl: url,
            loadSongs: () async => const [_song],
            loadArtistDetail: (_) async => _artistSectionDetail,
            loadWeeklyChart: _loadWeeklyChart,
            loadDiscoveryHome: _emptyDiscovery,
            loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
            loadDiscoveryCategories: _emptyCategories,
            loadDiscoveryRecommendations: _emptyRecommendations,
            loadReleaseCatalog: _emptyReleases,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await pumpArtist(
      'https://zingmp3.vn/Taylor-Swift',
      const ValueKey('artist-profile-route'),
    );
    expect(
      find.byKey(const ValueKey('artist-featured-songs-section-title')),
      findsOneWidget,
    );
    expect(find.text(_featuredArtistSong.displayTitle), findsWidgets);
    expect(find.text(_fullArtistSong.displayTitle), findsNothing);
    expect(
      find.byKey(const ValueKey('artist-section-show-all-artist-singles')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('artist-videos-show-all')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('artist-desktop-songs-show-all')),
    );
    await tester.pumpAndSettle();
    expect(find.text('TẤT CẢ BÀI HÁT'), findsOneWidget);
    expect(find.text(_fullArtistSong.displayTitle), findsWidgets);
    expect(find.byKey(const ValueKey('artist-profile-catalog')), findsNothing);

    await pumpArtist(
      'https://zingmp3.vn/Taylor-Swift/single',
      const ValueKey('artist-single-route'),
    );
    expect(
      find.byKey(const ValueKey('artist-section-artist-singles')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('artist-video-artist-mv')), findsNothing);
    expect(find.text(_featuredArtistSong.displayTitle), findsNothing);

    await pumpArtist(
      'https://zingmp3.vn/Taylor-Swift/video',
      const ValueKey('artist-video-route'),
    );
    expect(
      find.byKey(const ValueKey('artist-video-artist-mv')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('artist-section-artist-singles')),
      findsNothing,
    );
    expect(find.text(_featuredArtistSong.displayTitle), findsNothing);

    await pumpArtist(
      'https://zingmp3.vn/Taylor-Swift/bai-hat',
      const ValueKey('artist-songs-route'),
    );
    expect(find.text('TẤT CẢ BÀI HÁT'), findsOneWidget);
    expect(find.text(_fullArtistSong.displayTitle), findsWidgets);
  });

  testWidgets('routes Top 100 and releases URLs to their catalog views', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 900));
    final controller = await _controller();
    addTearDown(controller.dispose);
    var top100Calls = 0;
    var releaseCalls = 0;

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          key: const ValueKey('top100-link-screen'),
          initialOfficialUrl: 'https://zingmp3.vn/top100',
          loadSongs: () async => const [_song],
          loadTop100: () async {
            top100Calls++;
            return _top100;
          },
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(top100Calls, 1);
    expect(find.byKey(const ValueKey('top-100-catalog')), findsOneWidget);

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          key: const ValueKey('releases-link-screen'),
          initialOfficialUrl: 'https://zingmp3.vn/new-release/song',
          loadSongs: () async => const [_song],
          loadReleaseCatalog: () async {
            releaseCalls++;
            return _releaseCatalog;
          },
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(releaseCalls, 1);
    expect(find.byKey(const ValueKey('release-catalog')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('routes the official radio URL to internal live rooms', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 844));
    final controller = await _controller();
    addTearDown(controller.dispose);
    var liveCalls = 0;

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          initialOfficialUrl: 'https://zingmp3.vn/radio',
          loadSongs: () async => const [_song],
          loadLiveRadio: () async {
            liveCalls++;
            return _liveRadio;
          },
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(liveCalls, 1);
    expect(find.byKey(const ValueKey('live-radio-ROOM1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects an unsupported Zing URL without calling the proxy', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 844));
    final controller = await _controller();
    addTearDown(controller.dispose);
    var collectionCalls = 0;
    var searchCalls = 0;

    await tester.pumpWidget(
      _app(
        controller,
        ZingChartScreen(
          loadSongs: () async => const [_song],
          clipboardTextReader: () async =>
              'https://evil.example/link/album/ALBUM1',
          searchCatalog: (query) async {
            searchCalls++;
            return CatalogSearchResult.empty(query);
          },
          loadCollection: (_) async {
            collectionCalls++;
            return _collectionDetail;
          },
          loadWeeklyChart: _loadWeeklyChart,
          loadDiscoveryHome: _emptyDiscovery,
          loadDiscoveryCategoryHome: (_) => _emptyDiscovery(),
          loadDiscoveryCategories: _emptyCategories,
          loadDiscoveryRecommendations: _emptyRecommendations,
          loadReleaseCatalog: _emptyReleases,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chart-search-field')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('paste-zing-link-button')));
    await tester.pump();

    expect(collectionCalls, 0);
    expect(searchCalls, 0);
    expect(
      find.text('Liên kết Zing MP3 chưa được hỗ trợ hoặc không hợp lệ.'),
      findsOneWidget,
    );
  });

  testWidgets('MyApp handles a dynamic Web open route while running', (
    tester,
  ) async {
    final controller = await _controller();
    await tester.pumpWidget(
      MyApp(
        playerController: controller,
        homeBuilder: (officialUrl) =>
            Scaffold(body: Text(officialUrl ?? 'no-link')),
      ),
    );
    expect(find.text('no-link'), findsOneWidget);

    const route = <String, dynamic>{
      'location': '/?open=https%3A%2F%2Fzingmp3.vn%2Ftop100',
      'state': null,
    };
    final message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('pushRouteInformation', route),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      message,
      (_) {},
    );
    await tester.pump();

    expect(find.text('https://zingmp3.vn/top100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

Future<DiscoveryHome> _emptyDiscovery() async => const DiscoveryHome.empty();

Future<DiscoveryCategories> _emptyCategories() async =>
    const DiscoveryCategories.empty();

Future<DiscoveryRecommendations> _emptyRecommendations() async =>
    const DiscoveryRecommendations.empty();

Future<ReleaseCatalog> _emptyReleases() async => const ReleaseCatalog.empty();

Future<WeeklyChart> _loadWeeklyChart(
  WeeklyChartRegion region, {
  int? week,
  int? year,
}) async => _weeklyChart(region);

WeeklyChart _weeklyChart(WeeklyChartRegion region) => WeeklyChart(
  region: region,
  title: 'Bảng Xếp Hạng Tuần',
  week: 33,
  year: 2026,
  latestWeek: 33,
  startDate: '10/08',
  endDate: '16/08',
  updatedAt: DateTime.utc(2026, 8, 17),
  entries: const [
    WeeklyChartEntry(
      catalogSong: CatalogSong(
        song: _song,
        duration: Duration(minutes: 3),
        externalUrl: 'https://zingmp3.vn/bai-hat/Mot-Bai-Hat/SONG1.html',
        playable: true,
      ),
      albumTitle: 'Album chính thức',
      rank: 1,
      rankChange: 0,
      score: 100,
    ),
  ],
  catalogPlaybackEnabled: true,
);

const _song = Song(
  id: 'SONG1',
  name: 'mot-bai-hat',
  title: 'Một Bài Hát',
  thumbnail: '',
  artistsNames: 'Nghệ Sĩ',
  code: 'SOURCE1',
);

const _collection = CatalogCollection(
  id: 'ALBUM1',
  title: 'Album Chính Thức',
  artist: 'Nghệ Sĩ',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: 'https://zingmp3.vn/link/album/ALBUM1',
);

const _collectionDetail = CatalogCollectionDetail(
  collection: _collection,
  description: 'Album từ Zing MP3',
  year: '2026',
  genres: ['V-Pop'],
  songs: [
    CatalogSong(
      song: _song,
      duration: Duration(minutes: 3),
      externalUrl: 'https://zingmp3.vn/bai-hat/Mot-Bai-Hat/SONG1.html',
      playable: true,
    ),
  ],
  catalogPlaybackEnabled: true,
);

const _songDetail = SongDetail(
  catalogSong: CatalogSong(
    song: _song,
    duration: Duration(minutes: 3),
    externalUrl: 'https://zingmp3.vn/bai-hat/Mot-Bai-Hat/SONG1.html',
    playable: true,
  ),
  artists: [],
  album: _collection,
  releasedAt: null,
  distributor: 'Zing MP3',
  genres: ['V-Pop'],
  composers: [],
  listenCount: 1,
  likeCount: 1,
  commentCount: 0,
  mv: null,
  catalogPlaybackEnabled: true,
);

const _lockedSongDetail = SongDetail(
  catalogSong: CatalogSong(
    song: Song(
      id: 'LOCKED1',
      name: 'bai-bi-gioi-han',
      title: 'Bài Bị Giới Hạn',
      thumbnail: '',
      artistsNames: 'Nghệ Sĩ',
      code: 'LOCKED_SOURCE',
    ),
    duration: Duration(minutes: 3),
    externalUrl: 'https://zingmp3.vn/bai-hat/Bai-Bi-Gioi-Han/LOCKED1.html',
    playable: false,
  ),
  artists: [],
  album: null,
  releasedAt: null,
  distributor: 'Zing MP3',
  genres: [],
  composers: [],
  listenCount: 0,
  likeCount: 0,
  commentCount: 0,
  mv: null,
  catalogPlaybackEnabled: false,
);

const _artist = CatalogArtist(
  id: 'ARTIST1',
  name: 'Taylor Swift',
  aliasName: 'Taylor-Swift',
  avatar: '',
  externalUrl: 'https://zingmp3.vn/Taylor-Swift',
);

const _artistDetail = CatalogArtistDetail(
  artist: _artist,
  cover: '',
  biography: 'Nghệ sĩ chính thức trên Zing MP3.',
  realName: 'Taylor Swift',
  national: 'US',
  birthday: '',
  totalFollow: 1,
  awardCount: 1,
  songs: [],
  collectionSections: [],
  relatedArtists: [],
  catalogPlaybackEnabled: true,
);

const _featuredArtistSong = Song(
  id: 'ARTIST-FEATURED',
  name: 'featured-song',
  title: 'Bài Hát Nổi Bật',
  thumbnail: '',
  artistsNames: 'Taylor Swift',
  code: 'ARTIST-FEATURED',
);

const _fullArtistSong = Song(
  id: 'ARTIST-FULL',
  name: 'full-song',
  title: 'Bài Hát Trong Catalog Đầy Đủ',
  thumbnail: '',
  artistsNames: 'Taylor Swift',
  code: 'ARTIST-FULL',
);

const _artistSectionDetail = CatalogArtistDetail(
  artist: _artist,
  cover: '',
  biography: 'Nghệ sĩ chính thức trên Zing MP3.',
  realName: 'Taylor Swift',
  national: 'US',
  birthday: '',
  totalFollow: 1,
  awardCount: 1,
  featuredSongs: [
    CatalogSong(
      song: _featuredArtistSong,
      duration: Duration(minutes: 3),
      externalUrl:
          'https://zingmp3.vn/bai-hat/featured-song/ARTIST-FEATURED.html',
      playable: true,
    ),
  ],
  songs: [
    CatalogSong(
      song: _featuredArtistSong,
      duration: Duration(minutes: 3),
      externalUrl:
          'https://zingmp3.vn/bai-hat/featured-song/ARTIST-FEATURED.html',
      playable: true,
    ),
    CatalogSong(
      song: _fullArtistSong,
      duration: Duration(minutes: 4),
      externalUrl: 'https://zingmp3.vn/bai-hat/full-song/ARTIST-FULL.html',
      playable: true,
    ),
  ],
  videos: [
    CatalogVideo(
      id: 'artist-mv',
      title: 'MV Chính Thức',
      artist: 'Taylor Swift',
      thumbnail: '',
      duration: Duration(minutes: 4),
      externalUrl: 'https://zingmp3.vn/video-clip/mv-chinh-thuc/artist-mv.html',
    ),
  ],
  collectionSections: [
    CatalogArtistCollectionSection(
      id: 'artist-singles',
      title: 'Single & EP',
      collections: [
        CatalogCollection(
          id: 'artist-single-one',
          title: 'Single Chính Thức',
          artist: 'Taylor Swift',
          thumbnail: '',
          kind: CatalogCollectionKind.album,
          externalUrl:
              'https://zingmp3.vn/album/single-chinh-thuc/artist-single-one.html',
        ),
      ],
    ),
  ],
  relatedArtists: [],
  catalogPlaybackEnabled: true,
);

const _hub = CatalogHub(
  id: 'HUB1',
  title: 'Nhạc Chill',
  description: 'Chủ đề chính thức',
  image: '',
  externalUrl: 'https://zingmp3.vn/hub/Nhac-Chill/HUB1.html',
);

const _hubDetail = CatalogHubDetail(hub: _hub, sections: []);

const _top100 = Top100Catalog(
  updatedAt: null,
  sections: [
    DiscoverySection(
      id: 'top-vietnam',
      title: 'Việt Nam',
      collections: [
        DiscoveryCollection(
          collection: _collection,
          description: 'Album nổi bật',
        ),
      ],
    ),
  ],
);

const _releaseCatalog = ReleaseCatalog(
  updatedAt: null,
  songs: [
    ReleaseSong(
      catalogSong: CatalogSong(
        song: _song,
        duration: Duration(minutes: 3),
        externalUrl: 'https://zingmp3.vn/bai-hat/Mot-Bai-Hat/SONG1.html',
        playable: true,
      ),
      releasedAt: null,
      region: ReleaseRegion.vietnam,
    ),
  ],
  albums: [],
  catalogPlaybackEnabled: true,
);

const _liveRadio = LiveRadioSnapshot(
  updatedAt: null,
  rooms: [
    LiveRadioRoom(
      id: 'ROOM1',
      title: 'Chill Radio',
      description: 'Đang phát trực tiếp',
      thumbnail: '',
      listenerCount: 100,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
  ],
);
