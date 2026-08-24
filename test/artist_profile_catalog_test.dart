import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_artist_detail.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/artist_profile_catalog.dart';

void main() {
  testWidgets(
    'collection Play Save More Share actions never open the collection',
    (tester) async {
      _setViewport(tester, const Size(390, 844));
      final opened = <String>[];
      final played = <String>[];
      final saved = <String>[];
      final shared = <String>[];

      await tester.pumpWidget(
        _app(
          platform: TargetPlatform.android,
          onCollectionTap: (collection) => opened.add(collection.id),
          onCollectionPlay: (collection) => played.add(collection.id),
          onCollectionToggleSaved: (collection) => saved.add(collection.id),
          onCollectionShare: (collection) => shared.add(collection.id),
          savedCollectionIds: const {'collection-1'},
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('artist-collection-collection-1'));
      expect(card, findsOneWidget);
      expect(find.byTooltip('Bỏ lưu Tuyển Tập Chính Thức 1'), findsOneWidget);
      for (final key in const [
        'artist-collection-play-collection-1',
        'artist-collection-save-collection-1',
        'artist-collection-more-collection-1',
      ]) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
        expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
      }

      await tester.tap(
        find.byKey(const ValueKey('artist-collection-play-collection-1')),
      );
      await tester.tap(
        find.byKey(const ValueKey('artist-collection-save-collection-1')),
      );
      await tester.pump();

      expect(played, ['collection-1']);
      expect(saved, ['collection-1']);
      expect(opened, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey('artist-collection-more-collection-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('artist-collection-menu-share-collection-1')),
      );
      await tester.pumpAndSettle();

      expect(shared, ['collection-1']);
      expect(opened, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey('artist-collection-more-collection-1')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('artist-collection-menu-open-collection-1')),
      );
      await tester.pumpAndSettle();

      expect(opened, ['collection-1']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('500px desktop collection rail keeps working paging controls', (
    tester,
  ) async {
    _setViewport(tester, const Size(1440, 900));
    await tester.pumpWidget(
      _app(catalogWidth: 500, platform: TargetPlatform.macOS),
    );
    await tester.pumpAndSettle();

    final previous = find.byKey(
      const ValueKey('artist-section-singles-previous'),
    );
    final next = find.byKey(const ValueKey('artist-section-singles-next'));
    final list = find.byKey(const ValueKey('artist-section-singles-list'));
    expect(previous, findsOneWidget);
    expect(next, findsOneWidget);
    expect(_iconButton(tester, previous).onPressed, isNull);
    expect(_iconButton(tester, next).onPressed, isNotNull);

    final position = _scrollableState(tester, list).position;
    expect(position.pixels, 0);
    await tester.tap(next);
    await tester.pumpAndSettle();

    final forwardOffset = position.pixels;
    expect(forwardOffset, greaterThan(0));
    expect(_iconButton(tester, previous).onPressed, isNotNull);
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(position.pixels, lessThan(forwardOffset));
    expect(tester.takeException(), isNull);
  });

  testWidgets('360px Android collection rail swipes without paging arrows', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 844));
    await tester.pumpWidget(_app(platform: TargetPlatform.android));
    await tester.pumpAndSettle();

    final list = find.byKey(const ValueKey('artist-section-singles-list'));
    final position = _scrollableState(tester, list).position;
    expect(position.pixels, 0);
    expect(
      find.byKey(const ValueKey('artist-section-singles-previous')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('artist-section-singles-next')),
      findsNothing,
    );

    await tester.drag(list, const Offset(-260, 0));
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('768px Android keeps collection actions visible and touchable', (
    tester,
  ) async {
    _setViewport(tester, const Size(768, 1024));
    await tester.pumpWidget(
      _app(
        platform: TargetPlatform.android,
        onCollectionPlay: (_) {},
        onCollectionToggleSaved: (_) {},
        onCollectionShare: (_) {},
      ),
    );
    await tester.pumpAndSettle();

    final actions = find.byKey(
      const ValueKey('artist-collection-actions-collection-1'),
    );
    final excludeFocus = find
        .ancestor(of: actions, matching: find.byType(ExcludeFocus))
        .first;
    final excludeSemantics = find
        .ancestor(of: actions, matching: find.byType(ExcludeSemantics))
        .first;
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
    expect(tester.widget<ExcludeFocus>(excludeFocus).excluding, isFalse);
    expect(
      tester.widget<ExcludeSemantics>(excludeSemantics).excluding,
      isFalse,
    );

    for (final key in const [
      'artist-collection-play-collection-1',
      'artist-collection-save-collection-1',
      'artist-collection-more-collection-1',
    ]) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width, greaterThanOrEqualTo(44), reason: '$key width');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$key height');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('related artist Follow callback and state stay independent', (
    tester,
  ) async {
    _setViewport(tester, const Size(768, 1024));
    CatalogArtist? opened;
    CatalogArtist? toggled;
    var followed = <String>{'related-1'};

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(
          tvMode: false,
        ).copyWith(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => _catalogViewport(
              detail: _detail,
              onArtistTap: (artist) => opened = artist,
              onArtistToggleFollow: (artist) {
                toggled = artist;
                setState(() {
                  followed = followed.contains(artist.id)
                      ? ({...followed}..remove(artist.id))
                      : {...followed, artist.id};
                });
              },
              followedArtistIds: followed,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final follow = find.byKey(
      const ValueKey('related-artist-follow-related-1'),
    );
    await tester.ensureVisible(follow);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: follow, matching: find.text('Đang quan tâm')),
      findsOneWidget,
    );

    await tester.tap(follow);
    await tester.pumpAndSettle();

    expect(toggled?.id, 'related-1');
    expect(opened, isNull);
    expect(
      find.descendant(of: follow, matching: find.text('Quan tâm')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('1920px TV focus scrolls to and activates a collection', (
    tester,
  ) async {
    _setViewport(tester, const Size(1920, 1080));
    CatalogCollection? opened;
    await tester.pumpWidget(
      _app(tvMode: true, onCollectionTap: (collection) => opened = collection),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('artist-collection-collection-9'));
    final list = find.byKey(const ValueKey('artist-section-singles-list'));
    await tester.tap(find.byKey(const ValueKey('artist-section-singles-next')));
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    final cardInkWell = find
        .descendant(of: card, matching: find.byType(InkWell))
        .first;
    final focusNode = Focus.of(tester.element(cardInkWell));

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);
    expect(_scrollableState(tester, list).position.pixels, greaterThan(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(opened?.id, 'collection-9');
    expect(
      find.byKey(const ValueKey('artist-section-singles-next')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus remains active after the mouse leaves a collection card', (
    tester,
  ) async {
    _setViewport(tester, const Size(1440, 900));
    final previousHighlightStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousHighlightStrategy,
    );
    await tester.pumpWidget(_app(platform: TargetPlatform.macOS));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('artist-collection-collection-1'));
    final actions = find.byKey(
      const ValueKey('artist-collection-actions-collection-1'),
    );
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 0);
    final cardInkWell = find
        .descendant(of: card, matching: find.byType(InkWell))
        .first;
    final focusNode = Focus.of(tester.element(cardInkWell));

    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: const Offset(1300, 800));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(card));
    await tester.pumpAndSettle();
    await mouse.moveTo(const Offset(1300, 800));
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isTrue);
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
    focusNode.unfocus();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(actions).opacity, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hidden desktop actions leave focus and semantics until card focus',
    (tester) async {
      _setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(
        _app(
          platform: TargetPlatform.macOS,
          onCollectionPlay: (_) {},
          onCollectionToggleSaved: (_) {},
          onCollectionShare: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('artist-collection-collection-1'));
      final actions = find.byKey(
        const ValueKey('artist-collection-actions-collection-1'),
      );
      final excludeFocus = find
          .ancestor(of: actions, matching: find.byType(ExcludeFocus))
          .first;
      final excludeSemantics = find
          .ancestor(of: actions, matching: find.byType(ExcludeSemantics))
          .first;
      expect(tester.widget<AnimatedOpacity>(actions).opacity, 0);
      expect(tester.widget<ExcludeFocus>(excludeFocus).excluding, isTrue);
      expect(
        tester.widget<ExcludeSemantics>(excludeSemantics).excluding,
        isTrue,
      );

      final detector = tester
          .widgetList<FocusableActionDetector>(
            find.descendant(
              of: card,
              matching: find.byType(FocusableActionDetector),
            ),
          )
          .firstWhere((widget) => widget.focusNode != null);
      detector.focusNode!.requestFocus();
      await tester.pumpAndSettle();

      expect(detector.focusNode!.hasFocus, isTrue);
      expect(tester.widget<AnimatedOpacity>(actions).opacity, 1);
      expect(tester.widget<ExcludeFocus>(excludeFocus).excluding, isFalse);
      expect(
        tester.widget<ExcludeSemantics>(excludeSemantics).excluding,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('500px desktop MV rail pages and opens the exact video', (
    tester,
  ) async {
    _setViewport(tester, const Size(1440, 900));
    CatalogVideo? opened;
    await tester.pumpWidget(
      _app(
        detail: _videoDetail,
        catalogWidth: 500,
        platform: TargetPlatform.macOS,
        onVideoTap: (video) => opened = video,
      ),
    );
    await tester.pumpAndSettle();

    final previous = find.byKey(const ValueKey('artist-video-previous'));
    final next = find.byKey(const ValueKey('artist-video-next'));
    final list = find.byKey(const ValueKey('artist-video-list'));
    final position = _scrollableState(tester, list).position;
    expect(previous, findsOneWidget);
    expect(next, findsOneWidget);
    expect(_iconButton(tester, previous).onPressed, isNull);
    expect(_iconButton(tester, next).onPressed, isNotNull);

    await tester.tap(next);
    await tester.pumpAndSettle();

    final forwardOffset = position.pixels;
    expect(forwardOffset, greaterThan(0));
    expect(_iconButton(tester, previous).onPressed, isNotNull);
    await tester.tap(find.byKey(const ValueKey('artist-video-video-3')));
    await tester.pump();
    expect(opened?.id, 'video-3');

    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(position.pixels, lessThan(forwardOffset));
    expect(tester.takeException(), isNull);
  });

  testWidgets('1920px TV focus reveals and activates the exact MV with Enter', (
    tester,
  ) async {
    _setViewport(tester, const Size(1920, 1080));
    CatalogVideo? opened;
    await tester.pumpWidget(
      _app(
        detail: _videoDetail,
        tvMode: true,
        onVideoTap: (video) => opened = video,
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('artist-video-video-8'));
    final list = find.byKey(const ValueKey('artist-video-list'));
    await tester.tap(find.byKey(const ValueKey('artist-video-next')));
    await tester.pumpAndSettle();
    expect(card, findsOneWidget);
    final detector = tester
        .widgetList<FocusableActionDetector>(
          find.descendant(
            of: card,
            matching: find.byType(FocusableActionDetector),
          ),
        )
        .firstWhere((widget) => widget.focusNode != null);

    detector.focusNode!.requestFocus();
    await tester.pumpAndSettle();

    expect(detector.focusNode!.hasFocus, isTrue);
    expect(_scrollableState(tester, list).position.pixels, greaterThan(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(opened?.id, 'video-8');
    expect(find.byKey(const ValueKey('artist-video-next')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  CatalogArtistDetail? detail,
  ValueChanged<CatalogCollection>? onCollectionTap,
  ValueChanged<CatalogArtist>? onArtistTap,
  ValueChanged<CatalogVideo>? onVideoTap,
  ValueChanged<CatalogCollection>? onCollectionPlay,
  ValueChanged<CatalogCollection>? onCollectionToggleSaved,
  ValueChanged<CatalogCollection>? onCollectionShare,
  Set<String> savedCollectionIds = const {},
  String? quickPlayingCollectionId,
  ValueChanged<CatalogArtist>? onArtistToggleFollow,
  Set<String> followedArtistIds = const {},
  bool tvMode = false,
  double? catalogWidth,
  TargetPlatform platform = TargetPlatform.macOS,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildZingDarkTheme(tvMode: tvMode).copyWith(platform: platform),
  home: Scaffold(
    body: _catalogViewport(
      detail: detail ?? _detail,
      onCollectionTap: onCollectionTap,
      onArtistTap: onArtistTap,
      onVideoTap: onVideoTap,
      onCollectionPlay: onCollectionPlay,
      onCollectionToggleSaved: onCollectionToggleSaved,
      onCollectionShare: onCollectionShare,
      savedCollectionIds: savedCollectionIds,
      quickPlayingCollectionId: quickPlayingCollectionId,
      onArtistToggleFollow: onArtistToggleFollow,
      followedArtistIds: followedArtistIds,
      tvMode: tvMode,
      catalogWidth: catalogWidth,
    ),
  ),
);

Widget _catalogViewport({
  required CatalogArtistDetail detail,
  ValueChanged<CatalogCollection>? onCollectionTap,
  ValueChanged<CatalogArtist>? onArtistTap,
  ValueChanged<CatalogVideo>? onVideoTap,
  ValueChanged<CatalogCollection>? onCollectionPlay,
  ValueChanged<CatalogCollection>? onCollectionToggleSaved,
  ValueChanged<CatalogCollection>? onCollectionShare,
  Set<String> savedCollectionIds = const {},
  String? quickPlayingCollectionId,
  ValueChanged<CatalogArtist>? onArtistToggleFollow,
  Set<String> followedArtistIds = const {},
  bool tvMode = false,
  double? catalogWidth,
}) => SingleChildScrollView(
  child: Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: catalogWidth,
      child: ArtistProfileCatalog(
        detail: detail,
        onCollectionTap: onCollectionTap ?? (_) {},
        onArtistTap: onArtistTap ?? (_) {},
        onVideoTap: onVideoTap ?? (_) {},
        onCollectionPlay: onCollectionPlay,
        onCollectionToggleSaved: onCollectionToggleSaved,
        onCollectionShare: onCollectionShare,
        savedCollectionIds: savedCollectionIds,
        quickPlayingCollectionId: quickPlayingCollectionId,
        onArtistToggleFollow: onArtistToggleFollow,
        followedArtistIds: followedArtistIds,
        tvMode: tvMode,
      ),
    ),
  ),
);

const _artist = CatalogArtist(
  id: 'artist-main',
  name: 'Sơn Tùng M-TP',
  aliasName: 'Son-Tung-M-TP',
  avatar: '',
  totalFollow: 543210,
);

final _collections = List<CatalogCollection>.generate(9, (index) {
  final number = index + 1;
  return CatalogCollection(
    id: 'collection-$number',
    title: 'Tuyển Tập Chính Thức $number',
    artist: 'Sơn Tùng M-TP',
    thumbnail: '',
    kind: index.isEven
        ? CatalogCollectionKind.album
        : CatalogCollectionKind.playlist,
    externalUrl:
        'https://zingmp3.vn/album/tuyen-tap-$number/collection-$number.html',
  );
});

final _relatedArtists = List<CatalogArtist>.generate(5, (index) {
  final number = index + 1;
  return CatalogArtist(
    id: 'related-$number',
    name: 'Nghệ sĩ liên quan $number',
    aliasName: 'Nghe-Si-Lien-Quan-$number',
    avatar: '',
    totalFollow: number * 1000,
  );
});

final _videos = List<CatalogVideo>.generate(8, (index) {
  final number = index + 1;
  return CatalogVideo(
    id: 'video-$number',
    title: 'MV Chính Thức $number',
    artist: 'Sơn Tùng M-TP',
    thumbnail: '',
    duration: Duration(minutes: 3, seconds: number),
    externalUrl:
        'https://zingmp3.vn/video-clip/mv-chinh-thuc-$number/video-$number.html',
  );
});

final _detail = CatalogArtistDetail(
  artist: _artist,
  cover: '',
  biography: 'Nghệ sĩ Việt Nam với nhiều sản phẩm âm nhạc nổi bật.',
  realName: 'Nguyễn Thanh Tùng',
  national: 'Việt Nam',
  birthday: '05/07/1994',
  totalFollow: 543210,
  awardCount: 12,
  songs: const [],
  collectionSections: [
    CatalogArtistCollectionSection(
      id: 'singles',
      title: 'Single & EP',
      collections: _collections,
    ),
  ],
  relatedArtists: _relatedArtists,
  catalogPlaybackEnabled: true,
);

final _videoDetail = CatalogArtistDetail(
  artist: _artist,
  cover: '',
  biography: '',
  realName: 'Nguyễn Thanh Tùng',
  national: 'Việt Nam',
  birthday: '05/07/1994',
  totalFollow: 543210,
  awardCount: 12,
  songs: const [],
  videos: _videos,
  collectionSections: const [],
  relatedArtists: const [],
  catalogPlaybackEnabled: true,
);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ScrollableState _scrollableState(WidgetTester tester, Finder list) =>
    tester.state<ScrollableState>(
      find.descendant(of: list, matching: find.byType(Scrollable)),
    );

IconButton _iconButton(WidgetTester tester, Finder navigationButton) =>
    tester.widget<IconButton>(
      find.descendant(of: navigationButton, matching: find.byType(IconButton)),
    );
