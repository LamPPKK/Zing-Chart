import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/widgets/search_discovery_summary.dart';

void main() {
  for (final viewport in const [
    (size: Size(320, 760), tvMode: false, highlights: 1, collections: 2),
    (size: Size(360, 844), tvMode: false, highlights: 1, collections: 2),
    (size: Size(768, 1024), tvMode: false, highlights: 2, collections: 3),
    (size: Size(1440, 900), tvMode: false, highlights: 3, collections: 5),
    (size: Size(1920, 1080), tvMode: true, highlights: 3, collections: 5),
  ]) {
    testWidgets('catalog search loading skeleton stays adaptive at '
        '${viewport.size.width}px', (tester) async {
      await _pumpLoadingSearch(tester, viewport.size, tvMode: viewport.tvMode);

      expect(
        find.byKey(const ValueKey('catalog-search-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('catalog-search-loading-highlights')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('catalog-search-loading-collections')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey(
            'catalog-search-loading-highlight-'
            '${viewport.highlights - 1}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey(
            'catalog-search-loading-collection-'
            '${viewport.collections - 1}',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('catalog search loading skeleton honors reduced motion', (
    tester,
  ) async {
    await _pumpLoadingSearch(
      tester,
      const Size(360, 844),
      disableAnimations: true,
    );

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('catalog-search-loading-progress')),
    );
    expect(progress.value, 0.42);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('catalog-search-loading')))
          .label,
      'Đang tìm trên Zing MP3',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog search tail mirrors the official all-results order', (
    tester,
  ) async {
    final selectedSections = <CatalogSearchSection>[];
    await _pumpSearchResults(
      tester,
      const Size(1440, 900),
      onSectionSelected: selectedSections.add,
    );

    final summary = find.byKey(const ValueKey('catalog-search-result-summary'));
    final tail = find.byKey(
      const ValueKey('catalog-search-secondary-sections'),
    );
    expect(summary, findsOneWidget);
    expect(tail, findsOneWidget);
    expect(
      find.descendant(
        of: summary,
        matching: find.byKey(const ValueKey('catalog-video-video-0')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: tail,
        matching: find.byKey(const ValueKey('catalog-collection-collection-7')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tail,
        matching: find.byKey(const ValueKey('catalog-collection-collection-8')),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: tail,
        matching: find.byKey(const ValueKey('catalog-video-video-7')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tail,
        matching: find.byKey(const ValueKey('catalog-artist-artist-5')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tail,
        matching: find.byKey(const ValueKey('catalog-artist-artist-6')),
      ),
      findsNothing,
    );

    final seeAllButtons = find.descendant(
      of: tail,
      matching: find.widgetWithText(TextButton, 'TẤT CẢ'),
    );
    expect(seeAllButtons, findsNWidgets(3));
    await tester.tap(seeAllButtons.first);
    expect(selectedSections, [CatalogSearchSection.collections]);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    (size: Size(320, 760), tvMode: false, artistColumns: 2),
    (size: Size(360, 844), tvMode: false, artistColumns: 2),
    (size: Size(768, 1024), tvMode: false, artistColumns: 3),
    (size: Size(1024, 900), tvMode: false, artistColumns: 4),
    (size: Size(1440, 900), tvMode: false, artistColumns: 5),
    (size: Size(1920, 1080), tvMode: true, artistColumns: 5),
  ]) {
    testWidgets(
      'catalog search tail stays responsive at ${viewport.size.width}px',
      (tester) async {
        await _pumpSearchResults(
          tester,
          viewport.size,
          tvMode: viewport.tvMode,
          onSectionSelected: (_) {},
        );

        expect(
          find.byKey(const ValueKey('catalog-search-secondary-sections')),
          findsOneWidget,
        );
        final tail = find.byKey(
          const ValueKey('catalog-search-secondary-sections'),
        );
        Finder artistAt(int index) => find.descendant(
          of: tail,
          matching: find.byKey(ValueKey('catalog-artist-artist-$index')),
        );
        final first = tester.getTopLeft(artistAt(0));
        final lastInRow = tester.getTopLeft(
          artistAt(viewport.artistColumns - 1),
        );
        final nextRow = tester.getTopLeft(artistAt(viewport.artistColumns));
        expect(lastInRow.dy, closeTo(first.dy, 0.5));
        expect(nextRow.dy, greaterThan(first.dy));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('artist profiles expose follower counts and TV activation', (
    tester,
  ) async {
    CatalogArtist? selectedArtist;
    await _pumpArtistResults(
      tester,
      const Size(1920, 1080),
      tvMode: true,
      onArtistTap: (artist) => selectedArtist = artist,
    );

    final firstArtist = find.byKey(const ValueKey('catalog-artist-artist-0'));
    expect(firstArtist, findsOneWidget);
    expect(
      tester.getSemantics(firstArtist).label,
      'Mở nghệ sĩ Nghệ sĩ 0, 2.6M quan tâm',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'catalog-search-artist-artist-0',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selectedArtist?.id, 'artist-0');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpLoadingSearch(
  WidgetTester tester,
  Size viewport, {
  bool tvMode = false,
  bool disableAnimations = false,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SearchDiscoverySummary(
            query: 'Sơn Tùng',
            isLoading: true,
            result: null,
            errorMessage: null,
            section: CatalogSearchSection.all,
            onSuggestion: (_) {},
            onArtistTap: (_) {},
            onSongTap: (_) {},
            onCollectionTap: (_) {},
            onVideoTap: (_) {},
            onRetry: () {},
            tvMode: tvMode,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpSearchResults(
  WidgetTester tester,
  Size viewport, {
  required ValueChanged<CatalogSearchSection> onSectionSelected,
  bool tvMode = false,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final result = _richSearchResult();

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              SearchDiscoverySummary(
                query: result.query,
                isLoading: false,
                result: result,
                errorMessage: null,
                section: CatalogSearchSection.all,
                onSuggestion: (_) {},
                onArtistTap: (_) {},
                onSongTap: (_) {},
                onCollectionTap: (_) {},
                onVideoTap: (_) {},
                onRetry: () {},
                tvMode: tvMode,
              ),
              SearchDiscoverySecondarySections(
                result: result,
                onArtistTap: (_) {},
                onCollectionTap: (_) {},
                onVideoTap: (_) {},
                onSectionSelected: onSectionSelected,
                tvMode: tvMode,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpArtistResults(
  WidgetTester tester,
  Size viewport, {
  required ValueChanged<CatalogArtist> onArtistTap,
  bool tvMode = false,
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final richResult = _richSearchResult();
  final artistResult = CatalogSearchResult(
    query: richResult.query,
    songs: const [],
    catalogPlaybackEnabled: richResult.catalogPlaybackEnabled,
    artists: richResult.artists,
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SingleChildScrollView(
          child: SearchDiscoverySecondarySections(
            result: artistResult,
            onArtistTap: onArtistTap,
            onCollectionTap: (_) {},
            onVideoTap: (_) {},
            tvMode: tvMode,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CatalogSearchResult _richSearchResult() => CatalogSearchResult(
  query: 'Sơn Tùng',
  catalogPlaybackEnabled: true,
  songs: List.generate(
    8,
    (index) => CatalogSong(
      song: Song(
        id: 'song-$index',
        name: 'song-$index',
        title: 'Bài hát $index',
        thumbnail: '',
        artistsNames: 'Nghệ sĩ $index',
        code: 'song-code-$index',
      ),
      duration: Duration(minutes: 3, seconds: index),
      externalUrl: 'https://zingmp3.vn/bai-hat/song-$index',
      playable: true,
    ),
  ),
  artists: List.generate(
    7,
    (index) => CatalogArtist(
      id: 'artist-$index',
      name: 'Nghệ sĩ $index',
      aliasName: 'nghe-si-$index',
      avatar: '',
      totalFollow: switch (index) {
        0 => 2600000,
        1 => 800,
        _ => 44000 + index * 100,
      },
    ),
  ),
  collections: List.generate(
    9,
    (index) => CatalogCollection(
      id: 'collection-$index',
      title: 'Playlist $index',
      artist: 'Nhiều nghệ sĩ',
      thumbnail: '',
      kind: CatalogCollectionKind.playlist,
      externalUrl: 'https://zingmp3.vn/album/playlist-$index',
    ),
  ),
  videos: List.generate(
    9,
    (index) => CatalogVideo(
      id: 'video-$index',
      title: 'MV $index',
      artist: 'Nghệ sĩ $index',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: index),
      externalUrl: 'https://zingmp3.vn/video-clip/mv-$index',
    ),
  ),
);
