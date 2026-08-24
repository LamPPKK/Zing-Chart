import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_hub.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/release_catalog.dart';
import 'package:zmp3chart/widgets/catalog_hub_browser.dart';
import 'package:zmp3chart/widgets/release_catalog_view.dart';

void main() {
  const artist = CatalogArtist(
    id: 'artist-one',
    name: 'Sơn Tùng M-TP',
    aliasName: 'Son-Tung-M-TP',
    avatar: '',
    externalUrl: 'https://zingmp3.vn/nghe-si/Son-Tung-M-TP',
  );
  const collection = CatalogCollection(
    id: 'collection-one',
    title: 'Top 100 Nhạc Trẻ',
    artist: 'Sơn Tùng M-TP',
    artists: [artist],
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: 'https://zingmp3.vn/album/top-100/collection-one.html',
  );
  const discoveryCollection = DiscoveryCollection(
    collection: collection,
    description: 'Tuyển tập chính thức từ Zing MP3.',
  );

  testWidgets('Top 100 card keeps artist and artwork actions independent', (
    tester,
  ) async {
    CatalogArtist? openedArtist;
    CatalogCollection? openedCollection;
    CatalogCollection? playedCollection;
    CatalogCollection? savedCollection;
    CatalogCollection? sharedCollection;
    await _pumpAt(
      tester,
      const Size(1440, 900),
      Top100CatalogView(
        catalog: const Top100Catalog(
          updatedAt: null,
          sections: [
            DiscoverySection(
              id: 'vietnam',
              title: 'Việt Nam',
              collections: [discoveryCollection],
            ),
          ],
        ),
        loading: false,
        errorMessage: null,
        onBack: () {},
        onRetry: () {},
        onCollectionTap: (value) => openedCollection = value,
        onCollectionPlay: (value) => playedCollection = value,
        onCollectionToggleSaved: (value) => savedCollection = value,
        onCollectionShare: (value) => sharedCollection = value,
        onArtistTap: (value) => openedArtist = value,
        savedCollectionIds: const {'collection-one'},
      ),
    );

    final artistLink = find.byKey(
      const ValueKey('hub-collection-artist-collection-one-artist-one'),
    );
    expect(artistLink, findsOneWidget);
    await tester.tap(artistLink);
    await tester.pump();

    expect(openedArtist?.id, artist.id);
    expect(openedCollection, isNull);

    final play = find.byKey(
      const ValueKey('hub-collection-play-collection-one'),
    );
    final save = find.byKey(
      const ValueKey('hub-collection-save-collection-one'),
    );
    expect(play, findsOneWidget);
    expect(save, findsOneWidget);
    expect(
      find.descendant(of: save, matching: find.byIcon(Icons.favorite_rounded)),
      findsOneWidget,
    );
    await tester.tap(play);
    await tester.pump();
    await tester.tap(save);
    await tester.pump();
    expect(playedCollection?.id, collection.id);
    expect(savedCollection?.id, collection.id);
    expect(openedCollection, isNull);

    await tester.tap(
      find.byKey(const ValueKey('hub-collection-more-collection-one')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('hub-collection-menu-share-collection-one')),
    );
    await tester.pumpAndSettle();
    expect(sharedCollection?.id, collection.id);
    expect(openedCollection, isNull);

    playedCollection = null;
    await tester.tap(
      find.byKey(const ValueKey('hub-collection-collection-one')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    final contextPlay = find.byKey(
      const ValueKey('hub-collection-menu-play-collection-one'),
    );
    expect(contextPlay, findsOneWidget);
    expect(
      find.byKey(const ValueKey('hub-collection-menu-save-collection-one')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('hub-collection-menu-share-collection-one')),
      findsOneWidget,
    );
    await tester.tap(contextPlay);
    await tester.pumpAndSettle();
    expect(playedCollection?.id, collection.id);
    expect(openedCollection, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new-release album artist link is adaptive and independent', (
    tester,
  ) async {
    CatalogArtist? openedArtist;
    CatalogCollection? openedCollection;
    CatalogCollection? playedCollection;
    CatalogCollection? savedCollection;
    CatalogCollection? sharedCollection;
    await _pumpAt(
      tester,
      const Size(360, 844),
      ReleaseCatalogView(
        catalog: const ReleaseCatalog(
          updatedAt: null,
          songs: [],
          albums: [
            ReleaseAlbum(
              collection: collection,
              releasedAt: null,
              region: ReleaseRegion.vietnam,
            ),
          ],
          catalogPlaybackEnabled: true,
        ),
        loading: false,
        errorMessage: null,
        contentType: ReleaseContentType.albums,
        region: ReleaseRegion.all,
        onBack: () {},
        onRetry: () {},
        onContentTypeChanged: (_) {},
        onRegionChanged: (_) {},
        onCollectionTap: (value) => openedCollection = value,
        onCollectionPlay: (value) => playedCollection = value,
        onCollectionToggleSaved: (value) => savedCollection = value,
        onCollectionShare: (value) => sharedCollection = value,
        onArtistTap: (value) => openedArtist = value,
        songCount: 0,
        playableSongCount: 0,
        onPlayAll: null,
      ),
    );

    final artistLink = find.byKey(
      const ValueKey('release-album-artist-collection-one-artist-one'),
    );
    expect(artistLink, findsOneWidget);
    await tester.ensureVisible(artistLink);
    await tester.tap(artistLink);
    await tester.pump();

    expect(openedArtist?.id, artist.id);
    expect(openedCollection, isNull);

    await tester.tap(
      find.byKey(const ValueKey('release-album-play-collection-one')),
    );
    await tester.pump();
    expect(playedCollection?.id, collection.id);
    expect(openedCollection, isNull);

    await tester.tap(
      find.byKey(const ValueKey('release-album-more-collection-one')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('release-album-menu-save-collection-one')),
    );
    await tester.pumpAndSettle();
    expect(savedCollection?.id, collection.id);

    await tester.tap(
      find.byKey(const ValueKey('release-album-more-collection-one')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('release-album-menu-share-collection-one')),
    );
    await tester.pumpAndSettle();
    expect(sharedCollection?.id, collection.id);
    expect(openedCollection, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection play action exposes an in-card loading state', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      const Size(1440, 900),
      Top100CatalogView(
        catalog: const Top100Catalog(
          updatedAt: null,
          sections: [
            DiscoverySection(
              id: 'vietnam',
              title: 'Việt Nam',
              collections: [discoveryCollection],
            ),
          ],
        ),
        loading: false,
        errorMessage: null,
        onBack: () {},
        onRetry: () {},
        onCollectionTap: (_) {},
        onCollectionPlay: (_) {},
        quickPlayingCollectionId: 'collection-one',
      ),
      settle: false,
    );
    await tester.pump();

    final play = find.byKey(
      const ValueKey('hub-collection-play-collection-one'),
    );
    expect(tester.widget<IconButton>(play).onPressed, isNull);
    expect(
      find.descendant(
        of: play,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop release album exposes the shared right-click menu', (
    tester,
  ) async {
    CatalogCollection? openedCollection;
    CatalogCollection? savedCollection;
    await _pumpAt(
      tester,
      const Size(1440, 900),
      ReleaseCatalogView(
        catalog: const ReleaseCatalog(
          updatedAt: null,
          songs: [],
          albums: [
            ReleaseAlbum(
              collection: collection,
              releasedAt: null,
              region: ReleaseRegion.vietnam,
            ),
          ],
          catalogPlaybackEnabled: true,
        ),
        loading: false,
        errorMessage: null,
        contentType: ReleaseContentType.albums,
        region: ReleaseRegion.all,
        onBack: () {},
        onRetry: () {},
        onContentTypeChanged: (_) {},
        onRegionChanged: (_) {},
        onCollectionTap: (value) => openedCollection = value,
        onCollectionPlay: (_) {},
        onCollectionToggleSaved: (value) => savedCollection = value,
        onCollectionShare: (_) {},
        songCount: 0,
        playableSongCount: 0,
        onPlayAll: null,
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('release-album-collection-one')),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('release-album-menu-play-collection-one')),
      findsOneWidget,
    );
    final contextSave = find.byKey(
      const ValueKey('release-album-menu-save-collection-one'),
    );
    expect(contextSave, findsOneWidget);
    await tester.tap(contextSave);
    await tester.pumpAndSettle();
    expect(savedCollection?.id, collection.id);
    expect(openedCollection, isNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget child, {
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}
