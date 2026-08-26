import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/data/music_repository.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/new_release_chart.dart';
import 'package:zmp3chart/models/release_catalog.dart';
import 'package:zmp3chart/models/search_suggestions.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/zing_chart_screen.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auto-loads near the end, deduplicates page two, and caches it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);
    final calls = <({CatalogSearchSection section, int page})>[];

    await _pumpSearch(
      tester,
      controller,
      pageLoader: (query, section, page, limit) async {
        calls.add((section: section, page: page));
        if (page == 1) {
          return _songPage(
            query,
            page: 1,
            hasMore: true,
            total: 9,
            songs: [
              for (var index = 0; index < 7; index++)
                _song('page-one-$index', 'Kết quả trang một $index'),
              _song('dupe', 'Bản gốc'),
            ],
          );
        }
        return _songPage(
          query,
          page: 2,
          hasMore: false,
          total: 9,
          songs: [
            _song('dupe', 'Bản trùng'),
            _song('page-two', 'Kết quả trang hai'),
          ],
        );
      },
    );
    await _finishInitialSearch(tester);

    expect(calls, [(section: CatalogSearchSection.songs, page: 1)]);
    expect(find.byKey(const ValueKey('page-one-0')), findsOneWidget);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -2400),
      2600,
    );
    await tester.pumpAndSettle();

    expect(calls, [
      (section: CatalogSearchSection.songs, page: 1),
      (section: CatalogSearchSection.songs, page: 2),
    ]);
    expect(find.text('Bản trùng'), findsNothing);
    expect(find.byKey(const ValueKey('dupe')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-two')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-page-complete')), findsOneWidget);

    final allTab = find.byKey(const ValueKey('search-section-all'));
    await tester.ensureVisible(allTab);
    await tester.pumpAndSettle();
    await tester.tap(allTab);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-two')), findsNothing);

    final songsTab = find.byKey(const ValueKey('search-section-songs'));
    await tester.tap(songsTab);
    await tester.pumpAndSettle();

    expect(calls, [
      (section: CatalogSearchSection.songs, page: 1),
      (section: CatalogSearchSection.songs, page: 2),
    ]);
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -2400),
      2600,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-page-complete')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-two')), findsOneWidget);
  });

  testWidgets('ignores a stale typed response after changing sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);
    final staleSongs = Completer<CatalogSearchPage>();
    final calls = <CatalogSearchSection>[];

    await _pumpSearch(
      tester,
      controller,
      pageLoader: (query, section, page, limit) {
        calls.add(section);
        if (section == CatalogSearchSection.songs) return staleSongs.future;
        return Future.value(
          CatalogArtistSearchPage(
            query: query,
            page: 1,
            limit: 18,
            total: 1,
            hasMore: false,
            catalogPlaybackEnabled: false,
            items: const [
              CatalogArtist(
                id: 'new-artist',
                name: 'Nghệ sĩ mới nhất',
                aliasName: 'Nghe-Si-Moi-Nhat',
                avatar: '',
                externalUrl: 'https://zingmp3.vn/nghe-si/Nghe-Si-Moi-Nhat',
              ),
            ],
          ),
        );
      },
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();
    await _dismissSearchOverlay(tester);
    expect(calls, [CatalogSearchSection.songs]);

    await tester.tap(
      find.byKey(const ValueKey('search-section-artists')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(calls, [CatalogSearchSection.songs, CatalogSearchSection.artists]);
    expect(find.text('Nghệ sĩ mới nhất'), findsOneWidget);

    staleSongs.complete(
      _songPage(
        'mix',
        page: 1,
        hasMore: false,
        total: 1,
        songs: [_song('stale-song', 'Kết quả đã cũ')],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Nghệ sĩ mới nhất'), findsOneWidget);
    expect(find.text('Kết quả đã cũ'), findsNothing);
  });

  testWidgets('enforces the page-level playback gate for playable song rows', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpSearch(
      tester,
      controller,
      pageLoader: (query, section, page, limit) async => _songPage(
        query,
        page: 1,
        hasMore: false,
        total: 1,
        playbackEnabled: false,
        songs: [_song('gated-song', 'Bài hát chưa được cấp quyền')],
      ),
    );
    await _finishInitialSearch(tester);

    final song = find.byKey(const ValueKey('gated-song'));
    await tester.ensureVisible(song);
    await tester.tap(song);
    await tester.pump();

    expect(controller.currentSong, isNull);
    expect(controller.queue, isEmpty);
    expect(
      find.textContaining('chưa có nguồn phát được phép trên proxy'),
      findsOneWidget,
    );
  });

  testWidgets('announces the global playback gate on all-search highlights', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    final gated = _song('gated-highlight', 'Bài hát chưa được cấp quyền');

    await _pumpSearch(
      tester,
      controller,
      initialSearchSection: CatalogSearchSection.all,
      aggregateResult: CatalogSearchResult(
        query: 'mix',
        songs: [gated],
        artists: const [],
        catalogPlaybackEnabled: false,
      ),
      pageLoader: (query, section, page, limit) async =>
          throw StateError('Aggregate search must not request a typed page'),
    );
    await _finishInitialSearch(tester);

    expect(find.text('Bài hát · Bị giới hạn'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Mở thông tin bài hát bị giới hạn Bài hát chưa được cấp quyền',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Phát Bài hát chưa được cấp quyền'),
      findsNothing,
    );
  });

  testWidgets('keeps the load-more control remote friendly at TV size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);
    final calls = <int>[];

    await _pumpSearch(
      tester,
      controller,
      tvMode: true,
      pageLoader: (query, section, page, limit) async {
        calls.add(page);
        return _songPage(
          query,
          page: page,
          hasMore: page == 1,
          total: 2,
          songs: [_song('tv-song-$page', 'Kết quả trên TV $page')],
        );
      },
    );
    await _finishInitialSearch(tester);

    final loadMore = find.byKey(const ValueKey('search-page-load-more'));
    await tester.ensureVisible(loadMore);
    await tester.pumpAndSettle();

    expect(calls, [1]);
    expect(loadMore, findsOneWidget);
    expect(tester.getSize(loadMore).width, greaterThanOrEqualTo(220));
    expect(tester.getSize(loadMore).height, greaterThanOrEqualTo(56));
    expect(find.text('XEM THÊM · 1 / 2 kết quả'), findsOneWidget);
  });

  testWidgets(
    'shows a typed deep-link page when aggregate search is unavailable',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await _createController();
      addTearDown(controller.dispose);
      final pageCalls = <CatalogSearchSection>[];
      final typedPage = Completer<CatalogSearchPage>();

      await _pumpSearch(
        tester,
        controller,
        initialOfficialUrl:
            'https://zingmp3.vn/tim-kiem/bai-hat?q=typed%20only',
        searchLoader: (_) async => throw StateError('aggregate unavailable'),
        pageLoader: (query, section, page, limit) {
          pageCalls.add(section);
          return typedPage.future;
        },
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      expect(pageCalls, [CatalogSearchSection.songs]);
      expect(
        find.byKey(const ValueKey('catalog-search-error')),
        findsOneWidget,
      );

      typedPage.complete(
        _songPage(
          'typed only',
          page: 1,
          hasMore: false,
          total: 1,
          songs: [_song('typed-only', 'Kết quả typed độc lập')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('catalog-search-error')), findsNothing);
      expect(find.textContaining('aggregate unavailable'), findsNothing);
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, -1200),
        1800,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('search-page-complete')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('typed-only')), findsOneWidget);
    },
  );

  testWidgets('uses the official Zing search result title', (tester) async {
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpSearch(
      tester,
      controller,
      pageLoader: (query, section, page, limit) async => _songPage(
        query,
        page: 1,
        hasMore: false,
        total: 1,
        songs: [_song('title-song', 'Kết quả có tiêu đề')],
      ),
    );
    await _finishInitialSearch(tester);

    expect(find.text('Kết Quả Tìm Kiếm'), findsOneWidget);
  });

  testWidgets(
    'search tabs expose selected semantics and mobile touch targets',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await _createController();
      addTearDown(controller.dispose);

      await _pumpSearch(
        tester,
        controller,
        pageLoader: (query, section, page, limit) async => _songPage(
          query,
          page: 1,
          hasMore: false,
          total: 1,
          songs: [_song('tab-song', 'Kết quả kiểm tra tab')],
        ),
      );
      await _finishInitialSearch(tester);
      final songsTab = find.byKey(const ValueKey('search-section-songs'));
      final allTab = find.byKey(const ValueKey('search-section-all'));

      expect(tester.getSize(songsTab).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(songsTab).height, greaterThanOrEqualTo(48));
      expect(
        find.bySemanticsLabel('BÀI HÁT, tab kết quả tìm kiếm'),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(songsTab)
            .getSemanticsData()
            .flagsCollection
            .isButton,
        isTrue,
      );
      expect(
        tester
            .getSemantics(songsTab)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        tester
            .getSemantics(songsTab)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(allTab)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );

      await tester.tap(allTab);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(allTab)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    },
  );

  testWidgets('warm official search link records and restores Back origin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);
    final warmLink = ValueNotifier<({String? url, int revision})>((
      url: null,
      revision: 0,
    ));
    addTearDown(warmLink.dispose);

    await tester.pumpWidget(
      _WarmSearchHarness(controller: controller, warmLink: warmLink),
    );
    await _finishInitialSearch(tester);
    final field = find.byKey(const ValueKey('chart-search-field'));
    expect(tester.widget<TextField>(field).controller?.text, 'old mix');
    expect(find.byKey(const ValueKey('old-song')), findsOneWidget);

    warmLink.value = (
      url: 'https://zingmp3.vn/tim-kiem/video?q=new%20video',
      revision: 1,
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field).controller?.text, 'new video');
    expect(find.text('MV từ warm link'), findsOneWidget);

    final back = find.byKey(const ValueKey('catalog-history-back'));
    await tester.ensureVisible(back);
    await tester.pumpAndSettle();
    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(field).controller?.text, 'old mix');
    expect(find.byKey(const ValueKey('old-song')), findsOneWidget);
    expect(find.text('MV từ warm link'), findsNothing);
  });

  testWidgets(
    'warm non-search official link also preserves search Back state',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await _createController();
      addTearDown(controller.dispose);
      final warmLink = ValueNotifier<({String? url, int revision})>((
        url: null,
        revision: 0,
      ));
      addTearDown(warmLink.dispose);

      await tester.pumpWidget(
        _WarmSearchHarness(controller: controller, warmLink: warmLink),
      );
      await _finishInitialSearch(tester);
      final field = find.byKey(const ValueKey('chart-search-field'));
      expect(tester.widget<TextField>(field).controller?.text, 'old mix');
      expect(find.byKey(const ValueKey('old-song')), findsOneWidget);

      warmLink.value = (url: 'https://zingmp3.vn/zing-chart', revision: 1);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(field).controller?.text, isEmpty);
      expect(find.text('#zingchart'), findsWidgets);

      final back = find.byKey(const ValueKey('catalog-history-back'));
      await tester.ensureVisible(back);
      await tester.pumpAndSettle();
      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(field).controller?.text, 'old mix');
      expect(find.byKey(const ValueKey('old-song')), findsOneWidget);
    },
  );

  testWidgets('warm official route resets a deep content offset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);
    final warmLink = ValueNotifier<({String? url, int revision})>((
      url: null,
      revision: 0,
    ));
    addTearDown(warmLink.dispose);

    await tester.pumpWidget(
      _WarmSearchHarness(controller: controller, warmLink: warmLink),
    );
    await _finishInitialSearch(tester);
    final scrollController = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, -1400),
      2200,
    );
    await tester.pumpAndSettle();
    expect(scrollController.offset, greaterThan(200));

    warmLink.value = (url: 'https://zingmp3.vn/zing-chart', revision: 1);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(scrollController.offset, closeTo(0, 0.1));
  });

  testWidgets('keeps aggregate results when typed pagination is unavailable', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);
    final fallbackSong = _song('aggregate-fallback', 'Kết quả dự phòng');

    await _pumpSearch(
      tester,
      controller,
      aggregateResult: CatalogSearchResult(
        query: 'mix',
        songs: [fallbackSong],
        artists: const [],
        catalogPlaybackEnabled: true,
      ),
      pageLoader: (query, section, page, limit) async =>
          throw const MusicRepositoryException(
            'Tìm kiếm phân trang chưa khả dụng.',
            code: 'SEARCH_PAGINATION_UNAVAILABLE',
          ),
    );
    await _finishInitialSearch(tester);

    expect(find.byKey(const ValueKey('aggregate-fallback')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-page-load-more')), findsNothing);
    expect(find.byKey(const ValueKey('search-page-retry')), findsNothing);
  });
}

Future<PlaybackService> _createController() async {
  final controller = PlaybackService(
    playbackAudioPlayer: FakePlaybackAudioPlayer(),
    sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  return controller;
}

Future<void> _pumpSearch(
  WidgetTester tester,
  PlaybackService controller, {
  required CatalogSearchPageLoader pageLoader,
  bool tvMode = false,
  CatalogSearchResult? aggregateResult,
  CatalogSearchLoader? searchLoader,
  String? initialOfficialUrl,
  CatalogSearchSection initialSearchSection = CatalogSearchSection.songs,
}) => tester.pumpWidget(
  MusicPlayerScope(
    controller: controller,
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ZingChartScreen(
        tvMode: tvMode,
        initialTab: 1,
        initialSearchQuery: initialOfficialUrl == null ? 'mix' : '',
        initialSearchSection: initialSearchSection,
        initialOfficialUrl: initialOfficialUrl,
        chartRefreshInterval: null,
        loadSongs: () async => const [],
        searchCatalog:
            searchLoader ??
            (query) async =>
                aggregateResult ?? CatalogSearchResult.empty(query),
        searchCatalogPage: pageLoader,
        searchSuggestions: (query) async =>
            SearchSuggestionSnapshot.empty(query),
        loadDiscoveryCategories: () async => const DiscoveryCategories.empty(),
        loadDiscoveryRecommendations: () async =>
            const DiscoveryRecommendations.empty(),
        loadDiscoveryHome: () async => const DiscoveryHome.empty(),
        loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
        loadNewReleases: () async => const NewReleaseChart.empty(),
      ),
    ),
  ),
);

Future<void> _finishInitialSearch(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
  await _dismissSearchOverlay(tester);
}

Future<void> _dismissSearchOverlay(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
}

CatalogSongSearchPage _songPage(
  String query, {
  required int page,
  required bool hasMore,
  required int total,
  bool playbackEnabled = true,
  required List<CatalogSong> songs,
}) => CatalogSongSearchPage(
  query: query,
  page: page,
  limit: 18,
  total: total,
  hasMore: hasMore,
  catalogPlaybackEnabled: playbackEnabled,
  items: songs,
);

CatalogSong _song(String id, String title) => CatalogSong(
  song: Song(
    id: id,
    name: id,
    title: title,
    thumbnail: '',
    artistsNames: 'Nghệ sĩ',
    code: 'source-$id',
  ),
  duration: const Duration(minutes: 3),
  externalUrl: 'https://zingmp3.vn/bai-hat/$id/$id.html',
  playable: true,
);

CatalogVideo _video(String id, String title) => CatalogVideo(
  id: id,
  title: title,
  artist: 'Nghệ sĩ',
  thumbnail: '',
  duration: const Duration(minutes: 3),
  externalUrl: 'https://zingmp3.vn/video-clip/$id/$id.html',
);

class _WarmSearchHarness extends StatelessWidget {
  const _WarmSearchHarness({required this.controller, required this.warmLink});

  final PlaybackService controller;
  final ValueNotifier<({String? url, int revision})> warmLink;

  @override
  Widget build(BuildContext context) => MusicPlayerScope(
    controller: controller,
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ValueListenableBuilder<({String? url, int revision})>(
        valueListenable: warmLink,
        builder: (context, link, _) => ZingChartScreen(
          initialTab: 1,
          initialSearchQuery: 'old mix',
          initialSearchSection: CatalogSearchSection.songs,
          initialOfficialUrl: link.url,
          officialUrlRevision: link.revision,
          chartRefreshInterval: null,
          loadSongs: () async => const [],
          searchCatalog: (query) async => CatalogSearchResult.empty(query),
          searchCatalogPage: (query, section, page, limit) async =>
              switch (section) {
                CatalogSearchSection.songs => _songPage(
                  query,
                  page: 1,
                  hasMore: false,
                  total: 18,
                  songs: [
                    _song('old-song', 'Kết quả tìm kiếm cũ'),
                    for (var index = 1; index < 18; index++)
                      _song('old-song-$index', 'Kết quả tìm kiếm cũ $index'),
                  ],
                ),
                CatalogSearchSection.videos => CatalogVideoSearchPage(
                  query: query,
                  page: 1,
                  limit: 18,
                  total: 1,
                  hasMore: false,
                  catalogPlaybackEnabled: false,
                  items: [_video('warm-video', 'MV từ warm link')],
                ),
                _ => throw StateError('Unexpected section: $section'),
              },
          searchSuggestions: (query) async =>
              SearchSuggestionSnapshot.empty(query),
          loadDiscoveryCategories: () async =>
              const DiscoveryCategories.empty(),
          loadDiscoveryRecommendations: () async =>
              const DiscoveryRecommendations.empty(),
          loadDiscoveryHome: () async => const DiscoveryHome.empty(),
          loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
          loadNewReleases: () async => const NewReleaseChart.empty(),
        ),
      ),
    ),
  );
}
