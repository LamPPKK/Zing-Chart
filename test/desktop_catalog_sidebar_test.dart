import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/desktop_catalog_sidebar.dart';

void main() {
  testWidgets('renders Zing catalog destinations in the expected order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DesktopCatalogDestination? selected;
    var createCalls = 0;
    var queueCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerLeft,
            child: DesktopCatalogSidebar(
              selected: DesktopCatalogDestination.discovery,
              onDestinationSelected: (value) => selected = value,
              likedSongs: 12,
              playlists: 3,
              listeningMinutes: 148,
              onOpenLocalProfile: () =>
                  selected = DesktopCatalogDestination.forYou,
              onCreatePlaylist: () => createCalls++,
              onShowQueue: () => queueCalls++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const orderedKeys = [
      'desktop-nav-library',
      'desktop-nav-discovery',
      'desktop-nav-chart',
      'desktop-nav-liveRadio',
      'desktop-nav-newReleaseChart',
      'desktop-nav-hubs',
      'desktop-nav-top100',
      'desktop-nav-forYou',
    ];
    final tops = orderedKeys
        .map((key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy)
        .toList(growable: false);
    expect(tops, orderedEquals([...tops]..sort()));
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('12 bài thích · 3 playlist'), findsOneWidget);
    expect(find.text('148 phút trong 30 ngày'), findsOneWidget);
    expect(find.text('Danh sách phát'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('desktop-nav-hubs')));
    expect(selected, DesktopCatalogDestination.hubs);
    await tester.tap(find.byKey(const ValueKey('desktop-open-local-profile')));
    expect(selected, DesktopCatalogDestination.forYou);
    await tester.tap(find.byKey(const ValueKey('desktop-create-playlist')));
    await tester.tap(find.byKey(const ValueKey('desktop-open-player-panel')));
    expect(createCalls, 1);
    expect(queueCalls, 1);
  });

  testWidgets('supports keyboard focus and Enter activation', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    DesktopCatalogDestination? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerLeft,
            child: DesktopCatalogSidebar(
              selected: DesktopCatalogDestination.chart,
              onDestinationSelected: (value) => selected = value,
              likedSongs: 0,
              playlists: 0,
              listeningMinutes: 0,
              onOpenLocalProfile: () =>
                  selected = DesktopCatalogDestination.forYou,
              onCreatePlaylist: () {},
              onShowQueue: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
    expect(focusedWidget, isNotNull);
    expect(
      find.ancestor(
        of: find.byWidget(focusedWidget!),
        matching: find.byKey(const ValueKey('desktop-nav-library')),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, DesktopCatalogDestination.library);

    for (var index = 0; index < 8; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    final profileFocus = FocusManager.instance.primaryFocus?.context?.widget;
    expect(profileFocus, isNotNull);
    expect(
      find.ancestor(
        of: find.byWidget(profileFocus!),
        matching: find.byKey(const ValueKey('desktop-open-local-profile')),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, DesktopCatalogDestination.forYou);
    expect(tester.takeException(), isNull);
  });
}
