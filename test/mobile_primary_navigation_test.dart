import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/analytics_dashboard_screen.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/new_release_chart.dart';
import 'package:zmp3chart/models/release_catalog.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/zing_chart_screen.dart';
import 'package:zmp3chart/widgets/desktop_catalog_sidebar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in const [Size(320, 760), Size(360, 844)]) {
    testWidgets(
      'mobile primary navigation keeps five Zing-style destinations at '
      '${size.width.toInt()}px',
      (tester) async {
        await _setViewport(tester, size);
        final controller = MusicPlayerController(
          libraryRepository: MemoryLibraryRepository(),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_app(controller));
        await tester.pumpAndSettle();

        final navigation = tester.widget<NavigationBar>(
          find.byKey(const ValueKey('mobile-primary-navigation')),
        );
        expect(navigation.selectedIndex, 2);
        expect(
          navigation.destinations
              .whereType<NavigationDestination>()
              .map((destination) => destination.label)
              .toList(growable: false),
          const ['Thư viện', 'Khám phá', '#zingchart', 'Radio', 'Cá nhân'],
        );
        expect(find.text('BXH mới'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'new-release chart maps to Discovery without losing its dedicated route',
    (tester) async {
      await _setViewport(tester, const Size(360, 844));
      final controller = MusicPlayerController(
        libraryRepository: MemoryLibraryRepository(),
      );
      addTearDown(controller.dispose);
      var discoveryCalls = 0;

      await tester.pumpWidget(
        _app(
          controller,
          initialTab: 2,
          loadDiscoveryHome: () async {
            discoveryCalls++;
            return const DiscoveryHome.empty();
          },
        ),
      );
      await tester.pumpAndSettle();

      var navigation = tester.widget<NavigationBar>(
        find.byKey(const ValueKey('mobile-primary-navigation')),
      );
      expect(navigation.selectedIndex, 1);
      expect(discoveryCalls, 0);

      await tester.tap(find.byKey(const ValueKey('mobile-nav-discovery')));
      await tester.pumpAndSettle();

      navigation = tester.widget<NavigationBar>(
        find.byKey(const ValueKey('mobile-primary-navigation')),
      );
      expect(navigation.selectedIndex, 1);
      expect(discoveryCalls, 1);
      expect(find.text('Khám phá'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tablet sidebar retains every catalog destination', (
    tester,
  ) async {
    await _setViewport(tester, const Size(768, 1024));
    final controller = MusicPlayerController(
      libraryRepository: MemoryLibraryRepository(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    final sidebar = tester.widget<DesktopCatalogSidebar>(
      find.byType(DesktopCatalogSidebar),
    );
    expect(sidebar.compact, isTrue);
    expect(find.byTooltip('BXH Nhạc Mới'), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-nav-hubs')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-nav-top100')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in const [720.0, 1024.0, 1133.0, 1134.0, 1280.0, 1440.0]) {
    testWidgets('catalog sidebar matches Zing density at ${width.toInt()}px', (
      tester,
    ) async {
      await _setViewport(tester, Size(width, 900));
      final controller = MusicPlayerController(
        libraryRepository: MemoryLibraryRepository(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      final sidebarFinder = find.byType(DesktopCatalogSidebar);
      final sidebar = tester.widget<DesktopCatalogSidebar>(sidebarFinder);
      final compact = width < DesktopCatalogSidebar.expandedBreakpoint;
      expect(sidebar.compact, compact);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('desktop-catalog-sidebar')))
            .width,
        compact
            ? DesktopCatalogSidebar.compactWidth
            : DesktopCatalogSidebar.width,
      );
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      for (final destination in DesktopCatalogDestination.values) {
        expect(
          find.byKey(ValueKey('desktop-nav-${destination.name}')),
          findsOneWidget,
        );
      }
      if (compact) {
        expect(find.byTooltip('Chủ Đề & Thể Loại'), findsOneWidget);
        expect(find.byTooltip('Top 100'), findsOneWidget);
      } else {
        expect(find.text('Chủ Đề & Thể Loại'), findsOneWidget);
        expect(find.text('Top 100'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile Personal tab exposes the private local profile', (
    tester,
  ) async {
    await _setViewport(tester, const Size(360, 844));
    final controller = MusicPlayerController(
      libraryRepository: MemoryLibraryRepository(),
    );
    addTearDown(controller.dispose);
    controller.toggleLike(_songs.first);
    controller.createPlaylist('Mix trên máy');

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile-nav-for-you')));
    await tester.pumpAndSettle();

    final navigation = tester.widget<NavigationBar>(
      find.byKey(const ValueKey('mobile-primary-navigation')),
    );
    expect(navigation.selectedIndex, 4);
    expect(find.text('Cá nhân'), findsWidgets);
    expect(
      find.byKey(const ValueKey('mobile-personal-summary')),
      findsOneWidget,
    );
    expect(find.text('Không cần đăng nhập'), findsOneWidget);
    expect(find.text('Mix và lịch sử chỉ lưu cục bộ'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('personal-liked-stat')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('personal-playlist-stat')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('mobile-personal-summary')));
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsDashboardScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  MusicPlayerController controller, {
  int initialTab = 0,
  Future<DiscoveryHome> Function()? loadDiscoveryHome,
}) => MusicPlayerScope(
  controller: controller,
  child: MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: ZingChartScreen(
      initialTab: initialTab,
      chartRefreshInterval: null,
      loadSongs: () async => _songs,
      loadDiscoveryHome:
          loadDiscoveryHome ?? () async => const DiscoveryHome.empty(),
      loadDiscoveryCategories: () async => const DiscoveryCategories.empty(),
      loadDiscoveryRecommendations: () async =>
          const DiscoveryRecommendations.empty(),
      loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
      loadNewReleases: () async => const NewReleaseChart.empty(),
    ),
  ),
);

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _songs = <Song>[
  Song(
    id: 'mobile-nav-song',
    name: 'mobile-nav-song',
    title: 'Một Bài Hát',
    thumbnail: '',
    artistsNames: 'Nghệ Sĩ',
    code: 'mobile-nav-code',
  ),
];
