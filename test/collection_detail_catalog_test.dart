import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/collection_detail_catalog.dart';
import 'package:zmp3chart/widgets/collection_detail_hero.dart';

void main() {
  for (final size in const [
    Size(360, 844),
    Size(768, 1024),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets(
      'collection information is adaptive at ${size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_app(size.width >= 1800));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('collection-detail-catalog')),
          findsOne,
        );
        expect(find.text('THÔNG TIN'), findsOneWidget);
        expect(find.text('03/08/2026'), findsOneWidget);
        expect(find.text('VIVI ENM'), findsOneWidget);
        expect(find.text('Sơn Tùng M-TP Xuất Hiện Trong'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('related collection cards open the exact official collection', (
    tester,
  ) async {
    CatalogCollection? opened;
    await tester.pumpWidget(_app(false, onTap: (value) => opened = value));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('collection-related-related-1')),
    );
    await tester.pump();

    expect(opened?.id, 'related-1');
    expect(opened?.title, '100% Năng Lượng Tích Cực');
  });

  testWidgets('TV focuses and activates a related collection with Enter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CatalogCollection? opened;
    await tester.pumpWidget(_app(true, onTap: (value) => opened = value));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final card = find.byKey(const ValueKey('collection-related-related-1'));
    expect(Focus.of(tester.element(card), scopeOk: true).hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened?.id, 'related-1');
  });

  testWidgets('desktop collection information matches its golden', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(false));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/collection_information_desktop_1440.png'),
    );
  });

  testWidgets('desktop collection preface expands without losing context', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final detail = CatalogCollectionDetail(
      collection: _collection,
      description: List.filled(
        8,
        'Tuyển tập chính thức tổng hợp những ca khúc nổi bật và thông tin được Zing MP3 công bố.',
      ).join(' '),
      year: '2026',
      genres: const ['V-Pop'],
      songs: const [],
      catalogPlaybackEnabled: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 760,
              child: CollectionDetailDesktopOverview(
                detail: detail,
                loading: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overview = find.byKey(const ValueKey('collection-desktop-overview'));
    expect(overview, findsOneWidget);
    final description = find.textContaining('Tuyển tập chính thức');
    expect(tester.widget<Text>(description).maxLines, 4);
    expect(find.text('XEM THÊM'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('collection-description-toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.text('RÚT GỌN'), findsOneWidget);
    expect(tester.widget<Text>(description).maxLines, isNull);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(bool tvMode, {ValueChanged<CatalogCollection>? onTap}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildZingDarkTheme(tvMode: tvMode),
      home: Scaffold(
        body: SingleChildScrollView(
          child: CollectionDetailCatalog(
            detail: _detail,
            onCollectionTap: onTap ?? (_) {},
            tvMode: tvMode,
          ),
        ),
      ),
    );

const _collection = CatalogCollection(
  id: 'album-1',
  title: 'm-tp M-TP',
  artist: 'Sơn Tùng M-TP',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: 'https://zingmp3.vn/album/m-tp/album-1.html',
);

const _related = CatalogCollection(
  id: 'related-1',
  title: '100% Năng Lượng Tích Cực',
  artist: 'Sơn Tùng M-TP, HIEUTHUHAI',
  thumbnail: '',
  kind: CatalogCollectionKind.playlist,
  externalUrl: 'https://zingmp3.vn/album/nang-luong/related-1.html',
);

final _detail = CatalogCollectionDetail(
  collection: _collection,
  description: 'Album chính thức của Sơn Tùng M-TP.',
  year: '2017',
  releasedAt: DateTime.utc(2026, 8, 3, 12),
  distributor: 'VIVI ENM',
  likeCount: 877,
  genres: const ['Việt Nam', 'V-Pop'],
  songs: const [
    CatalogSong(
      song: Song(
        id: 'song-1',
        name: 'Cơn Mưa Ngang Qua',
        title: 'Cơn Mưa Ngang Qua',
        thumbnail: '',
        artistsNames: 'Sơn Tùng M-TP',
        code: 'song-1',
      ),
      duration: Duration(minutes: 3, seconds: 54),
      externalUrl: 'https://zingmp3.vn/link/song/song-1',
      playable: true,
    ),
  ],
  sections: const [
    CatalogCollectionSection(
      id: 'appears-in',
      title: 'Sơn Tùng M-TP Xuất Hiện Trong',
      collections: [_related],
    ),
    CatalogCollectionSection(
      id: 'you-may-care',
      title: 'Có Thể Bạn Quan Tâm',
      collections: [_collection],
    ),
  ],
  catalogPlaybackEnabled: true,
);
