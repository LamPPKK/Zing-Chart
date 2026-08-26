import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/app_navigation_route.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/new_release_chart.dart';
import 'package:zmp3chart/models/official_zing_link.dart';
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

  testWidgets(
    'browser Back and Forward restore cached catalog state without recreating playback',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audio = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      addTearDown(controller.dispose);
      await controller.playSong(_song);

      final harnessKey = GlobalKey<_RouteHarnessState>();
      await tester.pumpWidget(
        _RouteHarness(key: harnessKey, controller: controller),
      );
      await tester.pumpAndSettle();

      expect(harnessKey.currentState!.updates.single.replace, isTrue);
      expect(
        harnessKey
            .currentState!
            .updates
            .single
            .route
            .officialLink
            ?.canonicalUri,
        Uri.parse('https://zingmp3.vn/zing-chart'),
      );

      await tester.tap(find.text('Khám phá').first);
      await tester.pumpAndSettle();
      final collectionTitle = find.text(_collection.title).first;
      await tester.ensureVisible(collectionTitle);
      await tester.pumpAndSettle();
      await tester.tap(collectionTitle);
      await tester.pumpAndSettle();

      final state = harnessKey.currentState!;
      expect(state.collectionLoads, 1);
      expect(
        state.updates.map((update) => update.route.identity),
        containsAllInOrder([
          'catalog:chart',
          'shell:discovery',
          'collection:album:ALBUM-HISTORY',
        ]),
      );
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      expect(controller.currentSong?.id, _song.id);
      expect(audio.playedSources, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('catalog-history-back')));
      await tester.pumpAndSettle();
      expect(state.backRequests, 1);
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );

      state.applyIncoming(const AppNavigationRoute.discovery());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsNothing,
      );
      expect(find.text(_collection.title), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('catalog-history-forward')));
      await tester.pumpAndSettle();
      expect(state.forwardRequests, 1);

      state.applyIncoming(
        AppNavigationRoute.fromOfficialUrl(_collection.externalUrl)!,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      expect(state.collectionLoads, 1);
      expect(controller.currentSong?.id, _song.id);
      expect(audio.playedSources, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('system Back uses catalog history on wide desktop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _RouteHarness(controller: controller, interceptPlatformHistory: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khám phá').first);
    await tester.pumpAndSettle();
    final collectionTitle = find.text(_collection.title).first;
    await tester.ensureVisible(collectionTitle);
    await tester.pumpAndSettle();
    await tester.tap(collectionTitle);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collection-detail-hero')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('collection-detail-hero')), findsNothing);
    expect(find.text(_collection.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cold official route does not create synthetic browser history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final harnessKey = GlobalKey<_RouteHarnessState>();

    await tester.pumpWidget(
      _RouteHarness(
        key: harnessKey,
        controller: controller,
        initialRoute: AppNavigationRoute.fromOfficialUrl(
          _collection.externalUrl,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collection-detail-hero')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('collection-back-button')));
    await tester.pumpAndSettle();

    expect(harnessKey.currentState!.backRequests, 0);
    expect(find.byKey(const ValueKey('collection-detail-hero')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settled typing coalesces into one browser history entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final harnessKey = GlobalKey<_RouteHarnessState>();

    await tester.pumpWidget(
      _RouteHarness(key: harnessKey, controller: controller),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khám phá').first);
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('chart-search-field'));
    for (final query in const ['n', 'nhac', 'nhac tre']) {
      await tester.enterText(field, query);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    final searchUpdates = harnessKey.currentState!.updates
        .where(
          (update) =>
              update.route.officialLink?.kind == OfficialZingLinkKind.search,
        )
        .toList(growable: false);
    expect(
      searchUpdates
          .map((update) => update.route.officialLink!.searchQuery)
          .toList(),
      const ['n', 'nhac', 'nhac tre'],
    );
    expect(searchUpdates.map((update) => update.replace).toList(), const [
      false,
      true,
      true,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fast typing keeps the Discovery browser entry', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final harnessKey = GlobalKey<_RouteHarnessState>();

    await tester.pumpWidget(
      _RouteHarness(key: harnessKey, controller: controller),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khám phá').first);
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('chart-search-field'));
    await tester.enterText(field, 'n');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'nhac');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final searchUpdates = harnessKey.currentState!.updates
        .where(
          (update) =>
              update.route.officialLink?.kind == OfficialZingLinkKind.search,
        )
        .toList(growable: false);
    expect(searchUpdates, hasLength(1));
    expect(searchUpdates.single.route.officialLink?.searchQuery, 'nhac');
    expect(searchUpdates.single.replace, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('local-only Discovery state uses local Back and Forward first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final harnessKey = GlobalKey<_RouteHarnessState>();

    await tester.pumpWidget(
      _RouteHarness(
        key: harnessKey,
        controller: controller,
        withDiscoveryCategories: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khám phá').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discovery-category-relax')));
    await tester.pumpAndSettle();
    expect(find.text('Nội dung Thư giãn'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('catalog-history-back')));
    await tester.pumpAndSettle();
    expect(harnessKey.currentState!.backRequests, 0);
    expect(find.text('Tuyển tập route'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('catalog-history-forward')));
    await tester.pumpAndSettle();
    expect(harnessKey.currentState!.forwardRequests, 0);
    expect(find.text('Nội dung Thư giãn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incoming Discovery cancels an older collection load', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final collectionResult = Completer<CatalogCollectionDetail>();
    final harnessKey = GlobalKey<_RouteHarnessState>();

    await tester.pumpWidget(
      _RouteHarness(
        key: harnessKey,
        controller: controller,
        collectionLoader: (_) => collectionResult.future,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khám phá').first);
    await tester.pumpAndSettle();
    final collectionTitle = find.text(_collection.title).first;
    await tester.ensureVisible(collectionTitle);
    await tester.tap(collectionTitle);
    await tester.pump();

    harnessKey.currentState!.applyIncoming(
      const AppNavigationRoute.discovery(),
    );
    await tester.pumpAndSettle();
    collectionResult.complete(_collectionDetail);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('collection-detail-hero')), findsNothing);
    expect(find.text('Tuyển tập route'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('warm route race does not replace the next real navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final collectionResult = Completer<CatalogCollectionDetail>();
    final harnessKey = GlobalKey<_RouteHarnessState>();

    await tester.pumpWidget(
      _RouteHarness(
        key: harnessKey,
        controller: controller,
        initialRoute: AppNavigationRoute.fromOfficialUrl(
          _collection.externalUrl,
        ),
        collectionLoader: (_) => collectionResult.future,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(harnessKey.currentState!.collectionLoads, 1);

    harnessKey.currentState!.applyIncoming(
      const AppNavigationRoute.discovery(),
    );
    await tester.pumpAndSettle();
    collectionResult.complete(_collectionDetail);
    await tester.pumpAndSettle();
    expect(harnessKey.currentState!.updates, isEmpty);

    await tester.tap(find.text('Dành cho bạn').first);
    await tester.pumpAndSettle();

    final update = harnessKey.currentState!.updates.single;
    expect(update.route.identity, 'shell:for-you');
    expect(update.replace, isFalse);
    expect(tester.takeException(), isNull);
  });
}

class _RouteHarness extends StatefulWidget {
  const _RouteHarness({
    super.key,
    required this.controller,
    this.interceptPlatformHistory = true,
    this.withDiscoveryCategories = false,
    this.collectionLoader,
    this.initialRoute,
  });

  final PlaybackService controller;
  final bool interceptPlatformHistory;
  final bool withDiscoveryCategories;
  final Future<CatalogCollectionDetail> Function(String id)? collectionLoader;
  final AppNavigationRoute? initialRoute;

  @override
  State<_RouteHarness> createState() => _RouteHarnessState();
}

class _RouteHarnessState extends State<_RouteHarness> {
  final updates = <({AppNavigationRoute route, bool replace})>[];
  AppNavigationRoute? _incoming;
  int _revision = 0;
  int backRequests = 0;
  int forwardRequests = 0;
  int collectionLoads = 0;

  @override
  void initState() {
    super.initState();
    _incoming = widget.initialRoute;
  }

  void applyIncoming(AppNavigationRoute route) {
    setState(() {
      _incoming = route;
      _revision++;
    });
  }

  @override
  Widget build(BuildContext context) => MusicPlayerScope(
    controller: widget.controller,
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ZingChartScreen(
        navigationRoute: _incoming,
        navigationRouteRevision: _revision,
        onNavigationRouteChanged: (route, {required replace}) {
          updates.add((route: route, replace: replace));
        },
        onPlatformHistoryBack: widget.interceptPlatformHistory
            ? () {
                backRequests++;
                return true;
              }
            : null,
        onPlatformHistoryForward: widget.interceptPlatformHistory
            ? () {
                forwardRequests++;
                return true;
              }
            : null,
        loadSongs: () async => const [_song],
        loadDiscoveryHome: () async => _home,
        loadDiscoveryCategoryHome: (categoryId) async => DiscoveryHome(
          categoryId: categoryId,
          updatedAt: null,
          banners: const [],
          sections: const [
            DiscoverySection(
              id: 'relax-section',
              title: 'Nội dung Thư giãn',
              collections: [],
            ),
          ],
        ),
        loadDiscoveryCategories: () async => widget.withDiscoveryCategories
            ? const DiscoveryCategories(
                updatedAt: null,
                items: [DiscoveryCategory(id: 'relax', name: 'Thư giãn')],
              )
            : const DiscoveryCategories.empty(),
        loadDiscoveryRecommendations: () async =>
            const DiscoveryRecommendations.empty(),
        searchCatalog: (query) async => CatalogSearchResult.empty(query),
        searchSuggestions: (query) async =>
            SearchSuggestionSnapshot.empty(query),
        loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
        loadNewReleases: () async => const NewReleaseChart.empty(),
        loadCollection: (id) async {
          collectionLoads++;
          return widget.collectionLoader?.call(id) ?? _collectionDetail;
        },
      ),
    ),
  );
}

const _song = Song(
  id: 'ROUTE-SONG',
  name: 'route-song',
  title: 'Bài Hát Không Bị Khởi Tạo Lại',
  thumbnail: '',
  artistsNames: 'Nghệ sĩ Route',
  code: 'route-code',
);

const _collection = CatalogCollection(
  id: 'ALBUM-HISTORY',
  title: 'Album Route Chính Thức',
  artist: 'Nghệ sĩ Route',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl:
      'https://zingmp3.vn/album/Album-Route-Chinh-Thuc/ALBUM-HISTORY.html',
);

const _collectionDetail = CatalogCollectionDetail(
  collection: _collection,
  description: 'Khôi phục từ cache route trong RAM.',
  year: '2026',
  genres: [],
  songs: [],
  catalogPlaybackEnabled: false,
);

const _home = DiscoveryHome(
  updatedAt: null,
  banners: [],
  sections: [
    DiscoverySection(
      id: 'route-section',
      title: 'Tuyển tập route',
      collections: [
        DiscoveryCollection(
          collection: _collection,
          description: 'Kiểm thử browser history',
        ),
      ],
    ),
  ],
);
