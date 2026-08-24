import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/widgets/catalog_artist_rail.dart';

void main() {
  testWidgets('hides empty content and deduplicates artists by id', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        CatalogArtistRail(
          title: 'Không có nghệ sĩ',
          artists: const [],
          onArtistTap: (_) {},
        ),
      ),
    );

    expect(find.text('Không có nghệ sĩ'), findsNothing);

    await tester.pumpWidget(
      _app(
        CatalogArtistRail(
          title: 'Nghệ sĩ tham gia',
          artists: const [
            _artistOne,
            CatalogArtist(
              id: 'artist-one',
              name: 'Bản sao bị loại',
              aliasName: 'Ban-Sao',
              avatar: '',
            ),
            _artistTwo,
            CatalogArtist(id: '', name: 'Thiếu ID', aliasName: '', avatar: ''),
          ],
          onArtistTap: (_) {},
          keyPrefix: 'dedupe',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nghệ sĩ tham gia'), findsOneWidget);
    expect(find.text('2 nghệ sĩ'), findsOneWidget);
    expect(find.byKey(const ValueKey('dedupe-artist-one')), findsOneWidget);
    expect(find.byKey(const ValueKey('dedupe-artist-two')), findsOneWidget);
    expect(find.text('Bản sao bị loại'), findsNothing);
    expect(find.text('Thiếu ID'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens artists and toggles local follow state independently', (
    tester,
  ) async {
    CatalogArtist? opened;
    CatalogArtist? toggled;
    var followed = <String>{};

    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => CatalogArtistRail(
            title: 'Nghệ sĩ tham gia',
            artists: const [_artistOne, _artistTwo],
            onArtistTap: (artist) => opened = artist,
            onToggleFollow: (artist) {
              toggled = artist;
              setState(() {
                followed = followed.contains(artist.id)
                    ? ({...followed}..remove(artist.id))
                    : {...followed, artist.id};
              });
            },
            followedArtistIds: followed,
            keyPrefix: 'callback',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('12.345 người quan tâm'), findsOneWidget);
    expect(find.text('Quan tâm'), findsNWidgets(2));
    final semantics = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('callback-artist-one')))
          .label,
      'Mở nghệ sĩ Nghệ sĩ Một',
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('callback-follow-artist-one')),
          )
          .label,
      contains('Quan tâm'),
    );
    semantics.dispose();

    await tester.tap(find.byKey(const ValueKey('callback-artist-one')));
    await tester.pump();
    expect(opened?.id, 'artist-one');

    opened = null;
    await tester.tap(find.byKey(const ValueKey('callback-follow-artist-one')));
    await tester.pumpAndSettle();
    expect(toggled?.id, 'artist-one');
    expect(opened, isNull);
    expect(find.text('Đang quan tâm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360px rail remains swipeable without desktop arrows', (
    tester,
  ) async {
    _setViewport(tester, const Size(360, 844));
    await tester.pumpWidget(
      _app(
        CatalogArtistRail(
          title: 'Nghệ sĩ',
          artists: _artists(8),
          onArtistTap: (_) {},
          keyPrefix: 'mobile',
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(const ValueKey('mobile-list'));
    final scrollable = _scrollableState(tester, list);
    expect(scrollable.position.pixels, 0);
    expect(find.byKey(const ValueKey('mobile-next')), findsNothing);

    await tester.drag(list, const Offset(-260, 0));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('500px desktop rail keeps mouse paging controls', (tester) async {
    _setViewport(tester, const Size(1440, 900));
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 500,
          child: CatalogArtistRail(
            title: 'Nghệ sĩ tham gia',
            artists: _artists(8),
            onArtistTap: (_) {},
            keyPrefix: 'compact-desktop',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(const ValueKey('compact-desktop-list'));
    final next = find.byKey(const ValueKey('compact-desktop-next'));
    expect(next, findsOneWidget);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(_scrollableState(tester, list).position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('1440px rail exposes working previous and next controls', (
    tester,
  ) async {
    _setViewport(tester, const Size(1440, 900));
    await tester.pumpWidget(
      _app(
        CatalogArtistRail(
          title: 'Nghệ sĩ',
          artists: _artists(12),
          onArtistTap: (_) {},
          keyPrefix: 'desktop',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final previous = find.byKey(const ValueKey('desktop-previous'));
    final next = find.byKey(const ValueKey('desktop-next'));
    final list = find.byKey(const ValueKey('desktop-list'));
    final scrollable = _scrollableState(tester, list);
    expect(previous, findsOneWidget);
    expect(next, findsOneWidget);
    expect(_iconButton(tester, previous).onPressed, isNull);
    expect(_iconButton(tester, next).onPressed, isNotNull);

    await tester.tap(next);
    await tester.pumpAndSettle();

    final forwardOffset = scrollable.position.pixels;
    expect(forwardOffset, greaterThan(0));
    expect(_iconButton(tester, previous).onPressed, isNotNull);
    await tester.tap(previous);
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, lessThan(forwardOffset));
    expect(tester.takeException(), isNull);
  });

  testWidgets('same-size artist updates reset the rail to the first profile', (
    tester,
  ) async {
    _setViewport(tester, const Size(1440, 900));
    await tester.pumpWidget(
      _app(
        CatalogArtistRail(
          title: 'Nghệ sĩ',
          artists: _artists(12),
          onArtistTap: (_) {},
          keyPrefix: 'identity',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final next = find.byKey(const ValueKey('identity-next'));
    final list = find.byKey(const ValueKey('identity-list'));
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(_scrollableState(tester, list).position.pixels, greaterThan(0));

    final replacements = List<CatalogArtist>.generate(
      12,
      (index) => CatalogArtist(
        id: 'replacement-${index + 1}',
        name: 'Nghệ sĩ thay thế ${index + 1}',
        aliasName: 'Nghe-Si-Thay-The-${index + 1}',
        avatar: '',
      ),
      growable: false,
    );
    await tester.pumpWidget(
      _app(
        CatalogArtistRail(
          title: 'Nghệ sĩ',
          artists: replacements,
          onArtistTap: (_) {},
          keyPrefix: 'identity',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_scrollableState(tester, list).position.pixels, 0);
    expect(
      find.byKey(const ValueKey('identity-replacement-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('1920px TV focus reveals and activates an offscreen artist', (
    tester,
  ) async {
    _setViewport(tester, const Size(1920, 1080));
    CatalogArtist? opened;
    await tester.pumpWidget(
      _app(
        CatalogArtistRail(
          title: 'Nghệ sĩ',
          artists: _artists(9),
          onArtistTap: (artist) => opened = artist,
          keyPrefix: 'tv',
          tvMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('tv-artist-9'));
    final list = find.byKey(const ValueKey('tv-list'));
    expect(card, findsOneWidget);
    expect(find.byKey(const ValueKey('tv-next')), findsOneWidget);
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
    expect(opened?.id, 'artist-9');
    expect(tester.takeException(), isNull);
  });
}

const _artistOne = CatalogArtist(
  id: 'artist-one',
  name: 'Nghệ sĩ Một',
  aliasName: 'Nghe-Si-Mot',
  avatar: '',
  totalFollow: 12345,
);

const _artistTwo = CatalogArtist(
  id: 'artist-two',
  name: 'Nghệ sĩ Hai',
  aliasName: 'Nghe-Si-Hai',
  avatar: '',
  totalFollow: 987,
);

List<CatalogArtist> _artists(int count) => List.generate(
  count,
  (index) => CatalogArtist(
    id: 'artist-${index + 1}',
    name: 'Nghệ sĩ ${index + 1}',
    aliasName: 'Nghe-Si-${index + 1}',
    avatar: '',
    totalFollow: (index + 1) * 1000,
  ),
  growable: false,
);

Widget _app(Widget child, {TargetPlatform platform = TargetPlatform.macOS}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(platform: platform),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(20), child: child),
      ),
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
