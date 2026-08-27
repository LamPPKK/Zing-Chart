import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/data/music_repository.dart';
import 'package:zmp3chart/models/catalog_artist_detail.dart';
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

  testWidgets('touch artist catalog auto-loads, dedupes, and completes', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 844));
    final controller = await _controller();
    addTearDown(controller.dispose);
    final requestedPages = <int>[];
    final firstItems = [_song('song-1'), _song('song-2'), _song('song-3')];

    await tester.pumpWidget(
      _app(
        controller,
        detail: _detail(items: firstItems, total: 4, hasMore: true),
        loadArtistSongs: (artistId, {required page, required limit}) async {
          requestedPages.add(page);
          return _page(
            page: page,
            total: 4,
            hasMore: false,
            items: [_song('song-1'), _song('song-4')],
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
    expect(requestedPages, [2]);
    expect(find.byKey(const ValueKey('song-row-song-1')), findsOneWidget);
    final contentScroll = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('song-row-song-4')),
      260,
      scrollable: contentScroll.first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('song-row-song-4')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('artist-song-page-complete')),
      180,
      scrollable: contentScroll.first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('artist-song-page-complete')),
      findsOneWidget,
    );
    expect(find.text('4 bài hát'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('direct song deep link bootstraps legacy profile page one', (
    tester,
  ) async {
    _setViewport(tester, const Size(768, 900));
    final controller = await _controller();
    addTearDown(controller.dispose);
    final requestedPages = <int>[];

    await tester.pumpWidget(
      _app(
        controller,
        detail: _detail(
          items: [_song('legacy-1'), _song('legacy-2')],
          total: 3,
          hasMore: true,
          includePage: false,
        ),
        loadArtistSongs: (artistId, {required page, required limit}) async {
          requestedPages.add(page);
          return _page(
            page: page,
            total: 3,
            hasMore: false,
            items: [_song('legacy-1'), _song('legacy-2'), _song('page-1-new')],
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedPages, [1]);
    expect(find.byKey(const ValueKey('song-row-page-1-new')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('artist-song-page-complete')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty normalized page stops auto-fill and retains songs', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 844));
    final controller = await _controller();
    addTearDown(controller.dispose);
    final requestedPages = <int>[];

    await tester.pumpWidget(
      _app(
        controller,
        detail: _detail(items: [_song('retained')], total: 150, hasMore: true),
        loadArtistSongs: (artistId, {required page, required limit}) async {
          requestedPages.add(page);
          return page == 2
              ? _page(page: page, total: 150, hasMore: true, items: const [])
              : _page(
                  page: page,
                  total: 2,
                  hasMore: false,
                  items: [_song('manual-recovery')],
                );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedPages, [2]);
    expect(find.byKey(const ValueKey('song-row-retained')), findsOneWidget);
    final contentScroll = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('artist-song-page-load-more')),
      180,
      scrollable: contentScroll.first,
    );
    await tester.pumpAndSettle();
    expect(requestedPages, [2]);
    expect(
      find.byKey(const ValueKey('artist-song-page-load-more')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('artist-song-page-load-more')));
    await tester.pumpAndSettle();

    expect(requestedPages, [2, 3]);
    expect(
      find.byKey(const ValueKey('song-row-manual-recovery')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('artist-song-page-complete')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused auto-load survives local Back and Forward navigation', (
    tester,
  ) async {
    _setViewport(tester, const Size(1440, 900));
    final controller = await _controller();
    addTearDown(controller.dispose);
    final requestedPages = <int>[];

    await tester.pumpWidget(
      _app(
        controller,
        detail: _detail(
          items: [_song('history-retained')],
          total: 150,
          hasMore: true,
        ),
        loadArtistSongs: (artistId, {required page, required limit}) async {
          requestedPages.add(page);
          return _page(page: page, total: 150, hasMore: true, items: const []);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedPages, [2]);
    await tester.tap(find.byKey(const ValueKey('desktop-nav-chart')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('artist-profile-hero')), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
    expect(requestedPages, [2]);

    await tester.tap(find.byKey(const ValueKey('catalog-history-forward')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('artist-profile-hero')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('catalog-history-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
    expect(requestedPages, [2]);
    final contentScroll = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('artist-song-page-load-more')),
      180,
      scrollable: contentScroll.first,
    );
    await tester.pumpAndSettle();
    expect(requestedPages, [2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused auto-load survives an artist collection round-trip', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 844));
    final controller = await _controller();
    addTearDown(controller.dispose);
    final requestedPages = <int>[];

    await tester.pumpWidget(
      _app(
        controller,
        detail: _detail(
          items: [_song('collection-retained')],
          total: 150,
          hasMore: true,
          collectionSections: const [
            CatalogArtistCollectionSection(
              id: 'single-section',
              title: 'Single & EP',
              collections: [_artistCollection],
            ),
          ],
        ),
        loadArtistSongs: (artistId, {required page, required limit}) async {
          requestedPages.add(page);
          return _page(page: page, total: 150, hasMore: true, items: const []);
        },
        loadCollection: (_) async => _artistCollectionDetail,
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedPages, [2]);
    await tester.tap(
      find.byKey(const ValueKey('artist-profile-section-tab-profile')),
    );
    await tester.pumpAndSettle();
    final contentScroll = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('artist-collection-artist-single')),
      240,
      scrollable: contentScroll.first,
    );
    await tester.drag(contentScroll.first, const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('artist-collection-artist-single')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collection-detail-hero')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('collection-back-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('artist-profile-section-tab-songs')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('artist-song-page-load-more')),
      180,
      scrollable: contentScroll.first,
    );
    await tester.pumpAndSettle();

    expect(requestedPages, [2]);
    expect(
      find.byKey(const ValueKey('artist-song-page-load-more')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty page one preserves highlighted profile songs', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 844));
    final controller = await _controller();
    addTearDown(controller.dispose);
    final requestedPages = <int>[];

    await tester.pumpWidget(
      _app(
        controller,
        detail: _detail(
          items: [_song('profile-highlight')],
          total: 80,
          hasMore: true,
          includePage: false,
        ),
        loadArtistSongs: (artistId, {required page, required limit}) async {
          requestedPages.add(page);
          return _page(page: page, total: 80, hasMore: true, items: const []);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedPages, [1]);
    expect(
      find.byKey(const ValueKey('song-row-profile-highlight')),
      findsOneWidget,
    );
    final contentScroll = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('artist-song-page-load-more')),
      180,
      scrollable: contentScroll.first,
    );
    await tester.pumpAndSettle();
    expect(requestedPages, [1]);
    expect(
      find.byKey(const ValueKey('artist-song-page-load-more')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable page adapter keeps the legacy catalog', (
    tester,
  ) async {
    _setViewport(tester, const Size(768, 900));
    final controller = await _controller();
    addTearDown(controller.dispose);
    var calls = 0;

    await tester.pumpWidget(
      _app(
        controller,
        detail: _detail(
          items: [_song('legacy-only')],
          total: 1,
          hasMore: true,
          includePage: false,
        ),
        loadArtistSongs: (artistId, {required page, required limit}) async {
          calls++;
          throw const MusicRepositoryException(
            'Chưa hỗ trợ phân trang.',
            code: 'NOT_FOUND',
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.byKey(const ValueKey('song-row-legacy-only')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('artist-song-page-load-more')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('artist-song-page-retry')), findsNothing);

    await tester.tap(find.text('#zingchart').first);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
    expect(calls, 1);
    expect(
      find.byKey(const ValueKey('artist-song-page-load-more')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TV keeps loaded songs, retries locally, and restores footer focus',
    (tester) async {
      _setViewport(tester, const Size(1920, 1080));
      final controller = await _controller();
      addTearDown(controller.dispose);
      var calls = 0;

      await tester.pumpWidget(
        _app(
          controller,
          tvMode: true,
          detail: _detail(
            items: [_song('song-1'), _song('song-2')],
            total: 120,
            hasMore: true,
          ),
          loadArtistSongs: (artistId, {required page, required limit}) async {
            calls++;
            if (calls == 1) {
              throw const MusicRepositoryException('Mạng tạm thời gián đoạn.');
            }
            return _page(
              page: page,
              total: 120,
              hasMore: false,
              items: [_song('song-3')],
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
      expect(calls, 0);
      final loadMore = find.byKey(const ValueKey('artist-song-page-load-more'));
      expect(loadMore, findsOneWidget);
      final firstButton = tester.widget<OutlinedButton>(loadMore);
      expect(firstButton.style?.minimumSize?.resolve({}), const Size(220, 56));
      firstButton.focusNode!.requestFocus();
      await tester.pump();
      await tester.tap(loadMore);
      await tester.pumpAndSettle();

      expect(calls, 1);
      expect(find.byKey(const ValueKey('song-row-song-1')), findsOneWidget);
      final retry = find.byKey(const ValueKey('artist-song-page-retry'));
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.byKey(const ValueKey('song-row-song-3')), findsOneWidget);
      final completion = find.byKey(
        const ValueKey('artist-song-page-complete'),
      );
      expect(completion, findsOneWidget);
      expect(tester.widget<Focus>(completion).focusNode?.hasFocus, isTrue);
      expect(find.text('3 bài hát'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('artist-level playback gate disables hero, rows, and queue', (
    tester,
  ) async {
    _setViewport(tester, const Size(768, 900));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        controller,
        detail: _detail(
          items: [_song('locked-by-surface')],
          total: 1,
          hasMore: false,
          playbackEnabled: false,
        ),
        loadArtistSongs: (artistId, {required page, required limit}) async =>
            throw StateError('Pagination must not run for a complete page.'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
    final play = tester.widget<FilledButton>(
      find.byKey(const ValueKey('artist-play-button')),
    );
    expect(play.onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('song-row-locked-by-surface')));
    await tester.pump();

    expect(controller.currentSong, isNull);
    expect(controller.queue, isEmpty);
    expect(find.textContaining('chưa có nguồn phát'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'warm artist route discards a late page from the previous artist',
    (tester) async {
      _setViewport(tester, const Size(1920, 1080));
      final controller = await _controller();
      addTearDown(controller.dispose);
      final route = ValueNotifier((
        url: 'https://zingmp3.vn/Artist-One/bai-hat',
        revision: 0,
      ));
      addTearDown(route.dispose);
      final latePage = Completer<CatalogArtistSongPage>();
      var pageCalls = 0;

      await tester.pumpWidget(
        _WarmArtistHarness(
          controller: controller,
          route: route,
          loadArtistDetail: (alias) async => alias == _artist.aliasName
              ? _detail(items: [_song('old-song')], total: 2, hasMore: true)
              : _detail(
                  artist: _secondArtist,
                  items: [_song('new-song', artist: _secondArtist)],
                  total: 1,
                  hasMore: false,
                ),
          loadArtistSongs: (artistId, {required page, required limit}) {
            pageCalls++;
            return latePage.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('artist-song-page-load-more')),
      );
      await tester.pump();
      expect(pageCalls, 1);

      route.value = (url: 'https://zingmp3.vn/Artist-Two/bai-hat', revision: 1);
      await tester.pumpAndSettle();
      expect(find.text(_secondArtist.name), findsWidgets);

      latePage.complete(
        _page(page: 2, total: 2, hasMore: false, items: [_song('stale-song')]),
      );
      await tester.pumpAndSettle();

      expect(find.text(_secondArtist.name), findsWidgets);
      expect(find.byKey(const ValueKey('song-row-new-song')), findsOneWidget);
      expect(find.byKey(const ValueKey('song-row-stale-song')), findsNothing);
      expect(pageCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

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

Widget _app(
  PlaybackService controller, {
  required CatalogArtistDetail detail,
  required CatalogArtistSongPageLoader loadArtistSongs,
  CatalogCollectionLoader? loadCollection,
  bool tvMode = false,
}) => MusicPlayerScope(
  controller: controller,
  child: MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: ZingChartScreen(
      tvMode: tvMode,
      initialOfficialUrl: 'https://zingmp3.vn/Artist-One/bai-hat',
      chartRefreshInterval: null,
      loadSongs: () async => const [],
      loadArtistDetail: (_) async => detail,
      loadArtistSongs: loadArtistSongs,
      loadCollection:
          loadCollection ??
          (_) async => throw StateError('Collection loading is not expected.'),
      searchCatalog: (query) async => CatalogSearchResult.empty(query),
      searchSuggestions: (query) async => SearchSuggestionSnapshot.empty(query),
      loadDiscoveryCategories: () async => const DiscoveryCategories.empty(),
      loadDiscoveryRecommendations: () async =>
          const DiscoveryRecommendations.empty(),
      loadDiscoveryHome: () async => const DiscoveryHome.empty(),
      loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
      loadNewReleases: () async => const NewReleaseChart.empty(),
    ),
  ),
);

CatalogArtistDetail _detail({
  CatalogArtist artist = _artist,
  required List<CatalogSong> items,
  required int total,
  required bool hasMore,
  bool playbackEnabled = true,
  bool includePage = true,
  List<CatalogArtistCollectionSection> collectionSections = const [],
}) => CatalogArtistDetail(
  artist: artist,
  cover: '',
  biography: '',
  realName: '',
  national: '',
  birthday: '',
  totalFollow: 1200,
  awardCount: 0,
  songs: items,
  songPage: includePage
      ? CatalogArtistSongPage(
          artistId: artist.id,
          page: 1,
          limit: 50,
          total: total,
          hasMore: hasMore,
          items: items,
          catalogPlaybackEnabled: playbackEnabled,
        )
      : null,
  featuredSongs: items.take(3).toList(growable: false),
  collectionSections: collectionSections,
  relatedArtists: const [],
  catalogPlaybackEnabled: playbackEnabled,
);

CatalogArtistSongPage _page({
  String artistId = 'ARTIST1',
  required int page,
  required int total,
  required bool hasMore,
  required List<CatalogSong> items,
}) => CatalogArtistSongPage(
  artistId: artistId,
  page: page,
  limit: 50,
  total: total,
  hasMore: hasMore,
  items: items,
  catalogPlaybackEnabled: true,
);

CatalogSong _song(String id, {CatalogArtist artist = _artist}) => CatalogSong(
  song: Song(
    id: id,
    name: id,
    title: 'Bài hát $id',
    thumbnail: '',
    artistsNames: artist.name,
    code: 'source-$id',
  ),
  duration: const Duration(minutes: 3),
  externalUrl: 'https://zingmp3.vn/bai-hat/$id/$id.html',
  playable: true,
);

const _artist = CatalogArtist(
  id: 'ARTIST1',
  name: 'Nghệ sĩ',
  aliasName: 'Artist-One',
  avatar: '',
  externalUrl: 'https://zingmp3.vn/nghe-si/Artist-One',
);

const _secondArtist = CatalogArtist(
  id: 'ARTIST2',
  name: 'Nghệ sĩ thứ hai',
  aliasName: 'Artist-Two',
  avatar: '',
  externalUrl: 'https://zingmp3.vn/nghe-si/Artist-Two',
);

const _artistCollection = CatalogCollection(
  id: 'artist-single',
  title: 'Single Nghệ Sĩ',
  artist: 'Nghệ sĩ',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: 'https://zingmp3.vn/album/single-nghe-si/artist-single.html',
);

final _artistCollectionDetail = CatalogCollectionDetail(
  collection: _artistCollection,
  description: 'Single chính thức.',
  year: '2026',
  genres: const ['V-Pop'],
  songs: [_song('collection-song')],
  catalogPlaybackEnabled: true,
);

class _WarmArtistHarness extends StatelessWidget {
  const _WarmArtistHarness({
    required this.controller,
    required this.route,
    required this.loadArtistDetail,
    required this.loadArtistSongs,
  });

  final PlaybackService controller;
  final ValueNotifier<({String url, int revision})> route;
  final CatalogArtistDetailLoader loadArtistDetail;
  final CatalogArtistSongPageLoader loadArtistSongs;

  @override
  Widget build(BuildContext context) => MusicPlayerScope(
    controller: controller,
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ValueListenableBuilder<({String url, int revision})>(
        valueListenable: route,
        builder: (context, value, _) => ZingChartScreen(
          key: const ValueKey('warm-artist-screen'),
          tvMode: true,
          initialOfficialUrl: value.url,
          officialUrlRevision: value.revision,
          chartRefreshInterval: null,
          loadSongs: () async => const [],
          loadArtistDetail: loadArtistDetail,
          loadArtistSongs: loadArtistSongs,
          searchCatalog: (query) async => CatalogSearchResult.empty(query),
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

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
