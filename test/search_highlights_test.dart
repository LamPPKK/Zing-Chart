import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/search_discovery_summary.dart';

void main() {
  testWidgets('Zing highlights adapt as one two and three equal cards', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in const [
      Size(320, 844),
      Size(360, 844),
      Size(768, 1024),
      Size(1024, 900),
      Size(1440, 900),
      Size(1920, 1080),
    ]) {
      tester.view.physicalSize = size;
      final tvMode = size.width == 1920;
      await tester.pumpWidget(_HighlightsApp(tvMode: tvMode));
      await tester.pumpAndSettle();

      final artist = find.byKey(
        const ValueKey('catalog-artist-highlight-artist'),
      );
      final firstSong = find.byKey(
        const ValueKey('catalog-highlight-song-highlight-song-one'),
      );
      final secondSong = find.byKey(
        const ValueKey('catalog-highlight-song-highlight-song-two'),
      );
      expect(artist, findsOneWidget);
      expect(firstSong, findsOneWidget);
      expect(secondSong, findsOneWidget);

      final artistRect = tester.getRect(artist);
      final firstSongRect = tester.getRect(firstSong);
      final secondSongRect = tester.getRect(secondSong);
      final expectedHeight = tvMode ? 132.0 : 104.0;
      expect(artistRect.height, closeTo(expectedHeight, 0.1));
      expect(firstSongRect.height, closeTo(expectedHeight, 0.1));
      expect(secondSongRect.height, closeTo(expectedHeight, 0.1));

      if (size.width < 640) {
        expect(firstSongRect.top, greaterThan(artistRect.bottom));
        expect(secondSongRect.top, greaterThan(firstSongRect.bottom));
      } else if (size.width < 800) {
        expect(firstSongRect.top, closeTo(artistRect.top, 0.1));
        expect(secondSongRect.top, greaterThan(artistRect.bottom));
      } else {
        expect(firstSongRect.top, closeTo(artistRect.top, 0.1));
        expect(secondSongRect.top, closeTo(artistRect.top, 0.1));
      }

      expect(find.text('2.6M quan tâm'), findsOneWidget);
      expect(
        find.descendant(of: firstSong, matching: find.text('CÓ LỜI')),
        findsNothing,
      );
      expect(
        find.descendant(of: firstSong, matching: find.text('Album nổi bật')),
        findsNothing,
      );
      expect(
        find.descendant(of: firstSong, matching: find.text('04:22')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('desktop hover and TV Enter activate exact highlight cards', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    var opened = '';

    await tester.pumpWidget(_HighlightsApp(onOpen: (value) => opened = value));
    await tester.pumpAndSettle();
    final firstSong = find.byKey(
      const ValueKey('catalog-highlight-song-highlight-song-one'),
    );
    final surface = find.descendant(
      of: firstSong,
      matching: find.byType(AnimatedContainer),
    );
    expect(surface, findsOneWidget);
    expect(
      (tester.widget<AnimatedContainer>(surface).decoration as BoxDecoration)
          .border!
          .top
          .width,
      1,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(firstSong));
    await tester.pump(const Duration(milliseconds: 220));
    expect(
      (tester.widget<AnimatedContainer>(surface).decoration as BoxDecoration)
          .border!
          .top
          .width,
      2,
    );
    await tester.tap(firstSong);
    await tester.pump();
    expect(opened, 'song:highlight-song-one');

    tester.view.physicalSize = const Size(1920, 1080);
    opened = '';
    await tester.pumpWidget(
      _HighlightsApp(tvMode: true, onOpen: (value) => opened = value),
    );
    await tester.pumpAndSettle();
    final artist = find.byKey(
      const ValueKey('catalog-artist-highlight-artist'),
    );
    for (var index = 0; index < 4; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      if (_primaryFocusIsInside(artist)) break;
    }
    expect(_primaryFocusIsInside(artist), isTrue);
    final focusedSurface = find.descendant(
      of: artist,
      matching: find.byType(AnimatedContainer),
    );
    expect(
      (tester.widget<AnimatedContainer>(focusedSurface).decoration
              as BoxDecoration)
          .border!
          .top
          .width,
      3,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(opened, 'artist:highlight-artist');
    expect(tester.takeException(), isNull);
  });
}

class _HighlightsApp extends StatelessWidget {
  const _HighlightsApp({this.tvMode = false, this.onOpen});

  final bool tvMode;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildZingDarkTheme(tvMode: tvMode),
    home: Scaffold(
      backgroundColor: ZingColors.ink,
      body: SingleChildScrollView(
        child: SearchDiscoverySummary(
          query: 'sơn tùng',
          isLoading: false,
          result: _result,
          errorMessage: null,
          section: CatalogSearchSection.all,
          onSuggestion: (_) {},
          onArtistTap: (artist) => onOpen?.call('artist:${artist.id}'),
          onSongTap: (song) => onOpen?.call('song:${song.song.id}'),
          onCollectionTap: (_) {},
          onVideoTap: (_) {},
          onRetry: () {},
          tvMode: tvMode,
        ),
      ),
    ),
  );
}

const _artist = CatalogArtist(
  id: 'highlight-artist',
  name: 'Sơn Tùng M-TP',
  aliasName: 'Son-Tung-M-TP',
  avatar: '',
  totalFollow: 2600000,
);

const _album = CatalogCollection(
  id: 'highlight-album',
  title: 'Album nổi bật',
  artist: 'Sơn Tùng M-TP',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: '',
);

const _result = CatalogSearchResult(
  query: 'sơn tùng',
  catalogPlaybackEnabled: true,
  artists: [_artist],
  songs: [
    CatalogSong(
      song: Song(
        id: 'highlight-song-one',
        name: 'highlight-song-one',
        title: 'Nơi Này Có Anh',
        thumbnail: '',
        artistsNames: 'Sơn Tùng M-TP',
        code: 'highlight-song-code-one',
      ),
      duration: Duration(minutes: 4, seconds: 22),
      externalUrl: '',
      playable: true,
      hasLyrics: true,
      artists: [_artist],
      album: _album,
    ),
    CatalogSong(
      song: Song(
        id: 'highlight-song-two',
        name: 'highlight-song-two',
        title: 'Lạc Trôi',
        thumbnail: '',
        artistsNames: 'Sơn Tùng M-TP',
        code: 'highlight-song-code-two',
      ),
      duration: Duration(minutes: 4, seconds: 7),
      externalUrl: '',
      playable: true,
      artists: [_artist],
      album: _album,
    ),
  ],
);

bool _primaryFocusIsInside(Finder targetFinder) {
  final target = targetFinder.evaluate().single;
  var current = FocusManager.instance.primaryFocus?.context as Element?;
  while (current != null) {
    if (identical(current, target)) return true;
    Element? parent;
    current.visitAncestorElements((element) {
      parent = element;
      return false;
    });
    current = parent;
  }
  return false;
}
