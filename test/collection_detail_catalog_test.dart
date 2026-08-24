import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/collection_detail_catalog.dart';
import 'package:zmp3chart/widgets/collection_detail_hero.dart';

void main() {
  late GoldenFileComparator previousGoldenComparator;

  setUpAll(() {
    previousGoldenComparator = goldenFileComparator;
    final localComparator = previousGoldenComparator as LocalFileComparator;
    goldenFileComparator = _CollectionGoldenComparator(
      localComparator.basedir.resolve('collection_detail_catalog_test.dart'),
    );
  });

  tearDownAll(() => goldenFileComparator = previousGoldenComparator);

  test('collection golden tolerance only accepts measured raster drift', () {
    expect(_CollectionGoldenComparator.acceptsDiff(0.009), isTrue);
    expect(_CollectionGoldenComparator.acceptsDiff(0.011), isFalse);
  });

  for (final size in const [
    Size(360, 844),
    Size(390, 844),
    Size(768, 1024),
    Size(1180, 820),
    Size(1200, 820),
    Size(1320, 860),
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

        await tester.pumpWidget(
          _app(
            size.width >= 1800,
            platform: size.width < 720
                ? TargetPlatform.android
                : TargetPlatform.macOS,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('collection-detail-catalog')),
          findsOne,
        );
        expect(find.text('THÔNG TIN'), findsOneWidget);
        expect(find.text('03/08/2026'), findsOneWidget);
        expect(find.text('VIVI ENM'), findsOneWidget);
        expect(find.text('NGHỆ SĨ THAM GIA'), findsOneWidget);
        expect(find.text('10 nghệ sĩ'), findsOneWidget);
        expect(find.text('Sơn Tùng M-TP Xuất Hiện Trong'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('THÔNG TIN')).dy,
          lessThan(tester.getTopLeft(find.text('NGHỆ SĨ THAM GIA')).dy),
        );
        expect(
          tester.getTopLeft(find.text('NGHỆ SĨ THAM GIA')).dy,
          lessThan(
            tester.getTopLeft(find.text('Sơn Tùng M-TP Xuất Hiện Trong')).dy,
          ),
        );
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

    final card = find.byKey(const ValueKey('collection-related-related-1'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pump();

    expect(opened?.id, 'related-1');
    expect(opened?.title, '100% Năng Lượng Tích Cực');
  });

  testWidgets('participant rail opens and follows the exact credited artist', (
    tester,
  ) async {
    CatalogArtist? opened;
    CatalogArtist? toggled;
    await tester.pumpWidget(
      _app(
        false,
        onArtistTap: (value) => opened = value,
        onArtistToggleFollow: (value) => toggled = value,
        followedArtistIds: const {'artist-1'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10 nghệ sĩ'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('collection-participant-artist-1')),
      findsOneWidget,
    );
    final followedButton = find.byKey(
      const ValueKey('collection-participant-follow-artist-1'),
    );
    await tester.ensureVisible(followedButton);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: followedButton, matching: find.text('Đang quan tâm')),
      findsOneWidget,
    );

    await tester.tap(followedButton);
    await tester.pump();
    expect(toggled?.id, 'artist-1');
    expect(opened, isNull);

    final artistName = find.descendant(
      of: find.byKey(const ValueKey('collection-participant-artist-1')),
      matching: find.text('Sơn Tùng M-TP'),
    );
    await tester.ensureVisible(artistName);
    await tester.pumpAndSettle();
    await tester.tap(artistName);
    await tester.pump();
    expect(opened?.id, 'artist-1');
  });

  testWidgets('related cards expose play save share and context actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final played = <String>[];
    final toggled = <String>[];
    final shared = <String>[];
    final opened = <String>[];
    await tester.pumpWidget(
      _app(
        false,
        onTap: (value) => opened.add(value.id),
        onCollectionPlay: (value) => played.add(value.id),
        onCollectionToggleSaved: (value) => toggled.add(value.id),
        onCollectionShare: (value) => shared.add(value.id),
        savedCollectionIds: const {'related-1'},
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('collection-related-related-1'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(card).label,
      'Mở PLAYLIST 100% Năng Lượng Tích Cực',
    );

    final play = find.byKey(
      const ValueKey('collection-related-play-related-1'),
    );
    expect(
      _semanticsTreeContainsTooltip(
        tester.getSemantics(card),
        'Phát ngay 100% Năng Lượng Tích Cực',
      ),
      isTrue,
    );
    semantics.dispose();
    expect(tester.widget<IconButton>(play).onPressed, isNotNull);
    await tester.tap(play);
    await tester.tap(
      find.byKey(const ValueKey('collection-related-save-related-1')),
    );
    await tester.pump();
    expect(played, ['related-1']);
    expect(toggled, ['related-1']);
    expect(opened, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('collection-related-more-related-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('collection-related-menu-share-related-1')),
    );
    await tester.pumpAndSettle();
    expect(shared, ['related-1']);
    expect(opened, isEmpty);

    final title = find.text('100% Năng Lượng Tích Cực');
    await tester.tapAt(tester.getCenter(title), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collection-related-menu-open-related-1')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('collection-related-menu-open-related-1')),
    );
    await tester.pumpAndSettle();
    expect(opened, ['related-1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop related actions reveal on hover', (tester) async {
    await tester.pumpWidget(_app(false, onCollectionPlay: (_) {}));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('collection-related-related-1'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    final actions = find.byKey(
      const ValueKey('collection-related-actions-related-1'),
    );
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await tester.pump();
    await mouse.moveTo(tester.getCenter(card));
    await tester.pumpAndSettle();

    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('related share stays fail-closed without an official URL', (
    tester,
  ) async {
    const unshareable = CatalogCollection(
      id: 'no-url',
      title: 'Collection Chưa Có Link',
      artist: 'Nghệ sĩ',
      thumbnail: '',
      kind: CatalogCollectionKind.album,
      externalUrl: '',
    );
    final detail = CatalogCollectionDetail(
      collection: _collection,
      description: '',
      year: '2026',
      genres: const [],
      songs: const [],
      sections: const [
        CatalogCollectionSection(
          id: 'no-url-section',
          title: 'LIÊN QUAN',
          collections: [unshareable],
        ),
      ],
      catalogPlaybackEnabled: true,
    );
    var shareCalls = 0;
    await tester.pumpWidget(
      _app(
        false,
        detail: detail,
        onCollectionShare: (_) => shareCalls += 1,
        catalogWidth: 500,
      ),
    );
    await tester.pumpAndSettle();

    final more = find.byKey(const ValueKey('collection-related-more-no-url'));
    await tester.ensureVisible(more);
    await tester.pumpAndSettle();
    await tester.tap(more);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('collection-related-menu-share-no-url')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('collection-related-menu-open-no-url')),
      findsOneWidget,
    );
    expect(shareCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('related rail uses local width and desktop arrows page content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(false));
    await tester.pumpAndSettle();

    final next = find.byKey(
      const ValueKey('collection-related-next-appears-in'),
    );
    final previous = find.byKey(
      const ValueKey('collection-related-prev-appears-in'),
    );
    expect(next, findsOneWidget);
    expect(previous, findsOneWidget);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();

    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('collection-related-list-appears-in')),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, 0);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('related rail resets when same-size official content changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(false));
    await tester.pumpAndSettle();

    final next = find.byKey(
      const ValueKey('collection-related-next-appears-in'),
    );
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();

    final list = find.descendant(
      of: find.byKey(const ValueKey('collection-related-list-appears-in')),
      matching: find.byType(Scrollable),
    );
    expect(tester.state<ScrollableState>(list).position.pixels, greaterThan(0));

    final replacements = List<CatalogCollection>.generate(
      _relatedCollections.length,
      (index) => CatalogCollection(
        id: 'replacement-${index + 1}',
        title: 'Tuyển Tập Thay Thế ${index + 1}',
        artist: 'Nghệ sĩ mới',
        thumbnail: '',
        kind: CatalogCollectionKind.playlist,
        externalUrl:
            'https://zingmp3.vn/playlist/thay-the/replacement-${index + 1}.html',
      ),
    );
    final replacementDetail = CatalogCollectionDetail(
      collection: _collection,
      artists: _detail.artists,
      description: _detail.description,
      year: _detail.year,
      releasedAt: _detail.releasedAt,
      distributor: _detail.distributor,
      likeCount: _detail.likeCount,
      genres: _detail.genres,
      songs: _detail.songs,
      sections: [
        CatalogCollectionSection(
          id: 'appears-in',
          title: 'Sơn Tùng M-TP Xuất Hiện Trong',
          collections: replacements,
        ),
      ],
      catalogPlaybackEnabled: true,
    );
    await tester.pumpWidget(_app(false, detail: replacementDetail));
    await tester.pumpAndSettle();

    final updatedList = find.descendant(
      of: find.byKey(const ValueKey('collection-related-list-appears-in')),
      matching: find.byType(Scrollable),
    );
    expect(tester.state<ScrollableState>(updatedList).position.pixels, 0);
    expect(
      find.byKey(const ValueKey('collection-related-replacement-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact desktop rail keeps working paging arrows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(false, catalogWidth: 500));
    await tester.pumpAndSettle();

    final next = find.byKey(
      const ValueKey('collection-related-next-appears-in'),
    );
    expect(next, findsOneWidget);
    final list = find.descendant(
      of: find.byKey(const ValueKey('collection-related-list-appears-in')),
      matching: find.byType(Scrollable),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('collection-related-related-1')))
          .width,
      156,
    );
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(tester.state<ScrollableState>(list).position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
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

    final card = find.byKey(const ValueKey('collection-related-related-1'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    final cardInkWell = find
        .descendant(of: card, matching: find.byType(InkWell))
        .first;
    expect(tester.widget<InkWell>(cardInkWell).canRequestFocus, isFalse);
    Focus.of(tester.element(cardInkWell)).requestFocus();
    await tester.pump();
    expect(Focus.of(tester.element(cardInkWell)).hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened?.id, 'related-1');
    expect(
      find.byKey(const ValueKey('collection-related-next-appears-in')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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

bool _semanticsTreeContainsTooltip(SemanticsNode node, String tooltip) {
  if (node.getSemanticsData().tooltip == tooltip) return true;
  var containsTooltip = false;
  node.visitChildren((child) {
    if (_semanticsTreeContainsTooltip(child, tooltip)) {
      containsTooltip = true;
      return false;
    }
    return true;
  });
  return containsTooltip;
}

class _CollectionGoldenComparator extends LocalFileComparator {
  _CollectionGoldenComparator(super.testFile);

  // The Ubuntu runner differs from the macOS baseline by 0.70%. A 1%
  // ceiling absorbs that renderer-only delta while retaining strict layout
  // regression coverage for this focused component golden.
  static const _tolerance = 0.01;

  static bool acceptsDiff(double diffPercent) => diffPercent <= _tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || acceptsDiff(result.diffPercent)) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Widget _app(
  bool tvMode, {
  CatalogCollectionDetail? detail,
  ValueChanged<CatalogCollection>? onTap,
  ValueChanged<CatalogArtist>? onArtistTap,
  ValueChanged<CatalogArtist>? onArtistToggleFollow,
  Set<String> followedArtistIds = const {},
  ValueChanged<CatalogCollection>? onCollectionPlay,
  ValueChanged<CatalogCollection>? onCollectionToggleSaved,
  ValueChanged<CatalogCollection>? onCollectionShare,
  Set<String> savedCollectionIds = const {},
  String? quickPlayingCollectionId,
  double? catalogWidth,
  TargetPlatform platform = TargetPlatform.macOS,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildZingDarkTheme(tvMode: tvMode).copyWith(platform: platform),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: catalogWidth,
          child: CollectionDetailCatalog(
            detail: detail ?? _detail,
            onCollectionTap: onTap ?? (_) {},
            onArtistTap: onArtistTap ?? (_) {},
            onArtistToggleFollow: onArtistToggleFollow,
            followedArtistIds: followedArtistIds,
            onCollectionPlay: onCollectionPlay,
            onCollectionToggleSaved: onCollectionToggleSaved,
            onCollectionShare: onCollectionShare,
            savedCollectionIds: savedCollectionIds,
            quickPlayingCollectionId: quickPlayingCollectionId,
            tvMode: tvMode,
          ),
        ),
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

final _relatedCollections = List<CatalogCollection>.generate(9, (index) {
  if (index == 0) return _related;
  final number = index + 1;
  return CatalogCollection(
    id: 'related-$number',
    title: 'Tuyển Tập Chính Thức $number',
    artist: 'Nghệ sĩ $number',
    thumbnail: '',
    kind: index.isEven
        ? CatalogCollectionKind.album
        : CatalogCollectionKind.playlist,
    externalUrl:
        'https://zingmp3.vn/album/tuyen-tap-$number/related-$number.html',
  );
});

final _artists = List<CatalogArtist>.generate(9, (index) {
  final number = index + 1;
  return CatalogArtist(
    id: 'artist-$number',
    name: number == 1 ? 'Sơn Tùng M-TP' : 'Nghệ Sĩ $number',
    aliasName: number == 1 ? 'Son-Tung-M-TP' : 'Nghe-Si-$number',
    avatar: '',
    totalFollow: number * 1000,
  );
});

const _trackOnlyArtist = CatalogArtist(
  id: 'artist-10',
  name: 'Nghệ Sĩ Khách Mời',
  aliasName: 'Nghe-Si-Khach-Moi',
  avatar: '',
  totalFollow: 4800,
);

final _detail = CatalogCollectionDetail(
  collection: _collection,
  artists: _artists,
  description: 'Album chính thức của Sơn Tùng M-TP.',
  year: '2017',
  releasedAt: DateTime.utc(2026, 8, 3, 12),
  distributor: 'VIVI ENM',
  likeCount: 877,
  genres: const ['Việt Nam', 'V-Pop'],
  songs: [
    CatalogSong(
      song: const Song(
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
      artists: [_artists.first, _trackOnlyArtist],
    ),
  ],
  sections: [
    CatalogCollectionSection(
      id: 'appears-in',
      title: 'Sơn Tùng M-TP Xuất Hiện Trong',
      collections: _relatedCollections,
    ),
    const CatalogCollectionSection(
      id: 'you-may-care',
      title: 'Có Thể Bạn Quan Tâm',
      collections: [_collection],
    ),
  ],
  catalogPlaybackEnabled: true,
);
