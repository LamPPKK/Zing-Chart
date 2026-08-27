import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_artist_detail.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/official_zing_link.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/artist_profile_catalog.dart';

void main() {
  testWidgets(
    'deduplicates in upstream order and classifies Single EP and Album strictly',
    (tester) async {
      _setViewport(tester, const Size(1440, 900));
      await tester.pumpWidget(
        _catalogApp(detail: _detail, view: ArtistProfileCatalogView.singles),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('artist-singles-grid')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('artist-collection-single-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('artist-collection-single-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('artist-collection-album-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('artist-collection-ambiguous-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('artist-collection-playlist-leak')),
        findsNothing,
      );
      expect(find.text('First single'), findsOneWidget);
      expect(find.text('Duplicate single'), findsNothing);
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('artist-collection-single-1')),
            )
            .dx,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('artist-collection-single-2')),
              )
              .dx,
        ),
      );

      await tester.pumpWidget(
        _catalogApp(detail: _detail, view: ArtistProfileCatalogView.albums),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('artist-albums-grid')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('artist-collection-album-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('artist-collection-album-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('artist-collection-single-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('artist-collection-ambiguous-1')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final testCase in const <(Size, bool, int)>[
    (Size(360, 844), false, 2),
    (Size(768, 1024), false, 3),
    (Size(1440, 900), false, 4),
    (Size(1920, 1080), true, 5),
  ]) {
    testWidgets(
      '${testCase.$1.width.toInt()}px discography uses ${testCase.$3} focus-friendly columns',
      (tester) async {
        _setViewport(tester, testCase.$1);
        await tester.pumpWidget(
          _catalogApp(
            detail: _detail,
            view: ArtistProfileCatalogView.albums,
            tvMode: testCase.$2,
          ),
        );
        await tester.pumpAndSettle();

        final grid = tester.widget<GridView>(
          find.descendant(
            of: find.byKey(const ValueKey('artist-albums-grid')),
            matching: find.byType(GridView),
          ),
        );
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, testCase.$3);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'deduplicated MV grid keeps keyboard and exact callback behavior',
    (tester) async {
      _setViewport(tester, const Size(1440, 900));
      CatalogVideo? opened;
      await tester.pumpWidget(
        _catalogApp(
          detail: _detail,
          view: ArtistProfileCatalogView.videos,
          onVideoTap: (video) => opened = video,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('artist-videos-grid')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('artist-video-video-1')),
        findsOneWidget,
      );
      expect(find.text('Duplicate MV'), findsNothing);
      final target = find.byKey(const ValueKey('artist-video-video-2'));
      final detector = tester
          .widgetList<FocusableActionDetector>(
            find.descendant(
              of: target,
              matching: find.byType(FocusableActionDetector),
            ),
          )
          .firstWhere((widget) => widget.focusNode != null);

      detector.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(detector.focusNode!.hasFocus, isTrue);
      expect(opened?.id, 'video-2');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dedicated collection grid reuses touch Play without opening', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final opened = <String>[];
    final played = <String>[];
    await tester.pumpWidget(
      _catalogApp(
        detail: _detail,
        view: ArtistProfileCatalogView.albums,
        platform: TargetPlatform.android,
        onCollectionTap: (collection) => opened.add(collection.id),
        onCollectionPlay: (collection) => played.add(collection.id),
      ),
    );
    await tester.pumpAndSettle();

    final play = find.byKey(const ValueKey('artist-collection-play-album-1'));
    expect(play, findsOneWidget);
    expect(tester.getSize(play).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(play).height, greaterThanOrEqualTo(44));
    await tester.tap(play);
    await tester.pump();

    expect(played, ['album-1']);
    expect(opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile rails retain all Single Album and MV callbacks', (
    tester,
  ) async {
    _setViewport(tester, const Size(1440, 900));
    var singles = 0;
    var albums = 0;
    var videos = 0;
    await tester.pumpWidget(
      _catalogApp(
        detail: _detail,
        onShowAllSingles: () => singles++,
        onShowAllAlbums: () => albums++,
        onShowAllVideos: () => videos++,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('artist-section-show-all-singlesShelf')),
    );
    await tester.tap(
      find.byKey(const ValueKey('artist-section-show-all-albumShelf')),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('artist-videos-show-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('artist-videos-show-all')));
    await tester.pump();

    expect((singles, albums, videos), (1, 1, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'section tabs derive availability and expose selected semantics',
    (tester) async {
      _setViewport(tester, const Size(768, 1024));
      OfficialArtistSection? selected;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _tabsApp(
          detail: _detail,
          selected: OfficialArtistSection.albums,
          onSelected: (value) => selected = value,
        ),
      );
      await tester.pumpAndSettle();

      for (final section in OfficialArtistSection.values) {
        expect(
          find.byKey(ValueKey('artist-profile-section-tab-${section.name}')),
          findsOneWidget,
        );
      }
      final albums = find.byKey(
        const ValueKey('artist-profile-section-tab-albums'),
      );
      final profile = find.byKey(
        const ValueKey('artist-profile-section-tab-profile'),
      );
      expect(
        tester
            .getSemantics(albums)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(profile)
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
      await tester.tap(
        find.byKey(const ValueKey('artist-profile-section-tab-videos')),
      );
      await tester.pump();
      expect(selected, OfficialArtistSection.videos);
      semantics.dispose();
    },
  );

  testWidgets('phone deep link reveals the selected trailing section tab', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 844));
    var selected = OfficialArtistSection.albums;

    Future<void> pumpTabs() => tester.pumpWidget(
      _tabsApp(detail: _detail, selected: selected, onSelected: (_) {}),
    );

    await pumpTabs();
    await tester.pumpAndSettle();

    Rect visibleRect(OfficialArtistSection section) => tester.getRect(
      find.byKey(ValueKey('artist-profile-section-tab-${section.name}')),
    );

    expect(
      visibleRect(OfficialArtistSection.albums).left,
      greaterThanOrEqualTo(0),
    );
    expect(
      visibleRect(OfficialArtistSection.albums).right,
      lessThanOrEqualTo(360),
    );

    selected = OfficialArtistSection.videos;
    await pumpTabs();
    await tester.pumpAndSettle();

    expect(
      visibleRect(OfficialArtistSection.videos).left,
      greaterThanOrEqualTo(0),
    );
    expect(
      visibleRect(OfficialArtistSection.videos).right,
      lessThanOrEqualTo(360),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('explicit empty route remains visible and explains the state', (
    tester,
  ) async {
    _setViewport(tester, const Size(390, 844));
    final empty = _emptyDetail;
    await tester.pumpWidget(
      Column(
        children: [
          Expanded(
            child: _tabsApp(
              detail: empty,
              selected: OfficialArtistSection.albums,
              onSelected: (_) {},
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('artist-profile-section-tab-profile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('artist-profile-section-tab-albums')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('artist-profile-section-tab-singles')),
      findsNothing,
    );

    await tester.pumpWidget(
      _catalogApp(detail: empty, view: ArtistProfileCatalogView.albums),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nghệ sĩ chưa có album công khai'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV section tabs have 56px targets and activate from keyboard', (
    tester,
  ) async {
    _setViewport(tester, const Size(1920, 1080));
    OfficialArtistSection? selected;
    await tester.pumpWidget(
      _tabsApp(
        detail: _detail,
        selected: OfficialArtistSection.profile,
        onSelected: (value) => selected = value,
        tvMode: true,
      ),
    );
    await tester.pumpAndSettle();

    final tab = find.byKey(const ValueKey('artist-profile-section-tab-albums'));
    expect(tester.getSize(tab).height, greaterThanOrEqualTo(56));
    final button = tester.widget<TextButton>(
      find.descendant(of: tab, matching: find.byType(TextButton)),
    );
    button.focusNode!.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(button.focusNode!.hasFocus, isTrue);
    expect(selected, OfficialArtistSection.albums);
    expect(tester.takeException(), isNull);
  });
}

Widget _catalogApp({
  required CatalogArtistDetail detail,
  ArtistProfileCatalogView view = ArtistProfileCatalogView.profile,
  bool tvMode = false,
  TargetPlatform platform = TargetPlatform.macOS,
  ValueChanged<CatalogCollection>? onCollectionTap,
  ValueChanged<CatalogCollection>? onCollectionPlay,
  ValueChanged<CatalogVideo>? onVideoTap,
  VoidCallback? onShowAllSingles,
  VoidCallback? onShowAllAlbums,
  VoidCallback? onShowAllVideos,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildZingDarkTheme(tvMode: tvMode).copyWith(platform: platform),
  home: Scaffold(
    body: SingleChildScrollView(
      child: ArtistProfileCatalog(
        detail: detail,
        view: view,
        tvMode: tvMode,
        onCollectionTap: onCollectionTap ?? (_) {},
        onCollectionPlay: onCollectionPlay,
        onArtistTap: (_) {},
        onVideoTap: onVideoTap ?? (_) {},
        onShowAllSingles: onShowAllSingles,
        onShowAllAlbums: onShowAllAlbums,
        onShowAllVideos: onShowAllVideos,
      ),
    ),
  ),
);

Widget _tabsApp({
  required CatalogArtistDetail detail,
  required OfficialArtistSection selected,
  required ValueChanged<OfficialArtistSection> onSelected,
  bool tvMode = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: buildZingDarkTheme(tvMode: tvMode),
  home: Scaffold(
    body: ArtistProfileSectionTabs(
      detail: detail,
      selected: selected,
      onSelected: onSelected,
      tvMode: tvMode,
    ),
  ),
);

const _artist = CatalogArtist(
  id: 'artist',
  name: 'Nghệ sĩ',
  aliasName: 'Nghe-Si',
  avatar: '',
);

CatalogCollection _collection(
  String id,
  String title, {
  CatalogCollectionKind kind = CatalogCollectionKind.album,
}) => CatalogCollection(
  id: id,
  title: title,
  artist: 'Nghệ sĩ',
  thumbnail: '',
  kind: kind,
  externalUrl: 'https://zingmp3.vn/link/album/$id',
);

CatalogVideo _video(String id, String title) => CatalogVideo(
  id: id,
  title: title,
  artist: 'Nghệ sĩ',
  thumbnail: '',
  duration: const Duration(minutes: 3),
  externalUrl: 'https://zingmp3.vn/video-clip/video/$id.html',
);

final _singleOne = _collection('single-1', 'First single');
final _singleTwo = _collection('single-2', 'Second single');
final _albums = List<CatalogCollection>.generate(
  6,
  (index) => _collection('album-${index + 1}', 'Album ${index + 1}'),
);

final _detail = CatalogArtistDetail(
  artist: _artist,
  cover: '',
  biography: '',
  realName: '',
  national: '',
  birthday: '',
  totalFollow: 0,
  awardCount: 0,
  songs: const [
    CatalogSong(
      song: Song(
        id: 'song-1',
        name: 'Bài hát',
        title: 'Bài hát',
        thumbnail: '',
        artistsNames: 'Nghệ sĩ',
        code: 'song-1',
      ),
      duration: Duration(minutes: 3),
      externalUrl: 'https://zingmp3.vn/bai-hat/song/song-1.html',
      playable: true,
    ),
  ],
  videos: [
    _video('video-1', 'First MV'),
    _video('video-1', 'Duplicate MV'),
    _video('video-2', 'Second MV'),
  ],
  collectionSections: [
    CatalogArtistCollectionSection(
      id: 'singlesShelf',
      title: 'Single & EP',
      collections: [
        _singleOne,
        _collection('single-1', 'Duplicate single'),
        _singleTwo,
        _collection(
          'playlist-leak',
          'Not an album object',
          kind: CatalogCollectionKind.playlist,
        ),
      ],
    ),
    CatalogArtistCollectionSection(
      id: 'albumShelf',
      title: 'Album nổi bật',
      collections: _albums,
    ),
    CatalogArtistCollectionSection(
      id: 'album-single-mixed',
      title: 'Album & Single',
      collections: [_collection('ambiguous-1', 'Ambiguous')],
    ),
    CatalogArtistCollectionSection(
      id: 'featured',
      title: 'Tuyển tập',
      collections: [_collection('unclassified-1', 'Unclassified')],
    ),
  ],
  relatedArtists: const [],
  catalogPlaybackEnabled: true,
);

const _emptyDetail = CatalogArtistDetail(
  artist: _artist,
  cover: '',
  biography: '',
  realName: '',
  national: '',
  birthday: '',
  totalFollow: 0,
  awardCount: 0,
  songs: [],
  videos: [],
  collectionSections: [],
  relatedArtists: [],
  catalogPlaybackEnabled: false,
);

void _setViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
