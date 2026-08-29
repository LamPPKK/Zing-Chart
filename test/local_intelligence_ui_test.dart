import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/analytics_dashboard_screen.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/data/listening_analytics_repository.dart';
import 'package:zmp3chart/models/app_navigation_route.dart';
import 'package:zmp3chart/models/live_radio.dart';
import 'package:zmp3chart/models/listening_analytics.dart';
import 'package:zmp3chart/models/playback_origin.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/services/wrapped_export_service.dart';
import 'package:zmp3chart/services/wrapped_image_renderer.dart';
import 'package:zmp3chart/wrapped_screen.dart';
import 'package:zmp3chart/zing_chart_screen.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  const songs = [
    Song(
      id: 'one',
      name: 'mot-bai-hat',
      title: 'Một Bài Hát',
      thumbnail: '',
      artistsNames: 'Ca Sĩ A',
      code: 'code-one',
    ),
    Song(
      id: 'two',
      name: 'nang-tho',
      title: 'Nàng Thơ',
      thumbnail: '',
      artistsNames: 'Hoàng Dũng',
      code: 'code-two',
    ),
  ];

  for (final size in const [
    Size(360, 900),
    Size(768, 1024),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets(
      'Dành cho bạn renders without overflow at ${size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = await _controller();
        addTearDown(controller.dispose);

        await _pumpChart(tester, controller, songs, tvMode: size.width == 1920);
        if (size.width < 720) {
          await tester.tap(find.byKey(const ValueKey('mobile-nav-for-you')));
        } else {
          await tester.tap(find.byIcon(Icons.auto_awesome_outlined).first);
        }
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('for-you-daily-mix')), findsOneWidget);
        if (size.width < 720) {
          expect(find.text('Cá nhân'), findsWidgets);
          expect(
            find.byKey(const ValueKey('mobile-personal-summary')),
            findsOneWidget,
          );
        } else {
          expect(find.text('Dành cho bạn'), findsWidgets);
          expect(
            find.byKey(const ValueKey('mobile-personal-summary')),
            findsNothing,
          );
        }
        expect(find.text('Ba nhịp cho một ngày'), findsOneWidget);
        expect(find.byKey(const ValueKey('open-wrapped-card')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('tags a mood from Now Playing and updates its local mix', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await _pumpChart(tester, controller, songs);

    await tester.tap(find.text('Một Bài Hát').first);
    await tester.pumpAndSettle();
    final chill = find.byKey(const ValueKey('mood-chill-one'));
    await tester.ensureVisible(chill);
    await tester.tap(chill);
    await tester.pump();

    expect(controller.moodsFor(songs.first), {MoodTag.chill});
    expect(controller.moodMix(MoodTag.chill).songs.first, songs.first);
  });

  testWidgets(
    'Daily Mix card opens a browse workspace before an explicit Play action',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await _controller();
      addTearDown(controller.dispose);
      var chartLoads = 0;
      final routes = <AppNavigationRoute>[];

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              chartRefreshInterval: null,
              navigationRoute: const AppNavigationRoute.forYou(),
              onNavigationRouteChanged: (route, {required replace}) =>
                  routes.add(route),
              loadSongs: () async {
                chartLoads++;
                return songs;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.currentSong, isNull);
      expect(find.byKey(const ValueKey('for-you-open-daily')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('for-you-open-daily')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('local-mix-workspace')), findsOneWidget);
      expect(controller.currentSong, isNull);
      expect(chartLoads, 1);
      expect(routes.last.forYouMix, ForYouMix.daily);

      await tester.tap(find.byKey(const ValueKey('catalog-history-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('for-you-daily-mix')), findsOneWidget);
      expect(routes.last.forYouMix, isNull);

      final cardQueue = controller.dailyMixCollection.songs;
      controller.setShuffleEnabled(true);
      await tester.tap(find.byKey(const ValueKey('for-you-play-daily')));
      await tester.pump();
      expect(controller.currentSong, cardQueue.first);
      expect(controller.queue, cardQueue);
      expect(controller.shuffleEnabled, isFalse);
      expect(controller.nextSong, cardQueue[1]);
      expect(controller.playbackOrigin.kind, PlaybackOriginKind.forYou);
      expect(controller.playbackOrigin.label, 'Daily Mix');
      expect(find.byKey(const ValueKey('local-mix-workspace')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('for-you-open-daily')));
      await tester.pumpAndSettle();

      final expectedQueue = controller.dailyMixCollection.songs;
      await tester.tap(find.byKey(const ValueKey('local-mix-play')));
      await tester.pump();

      expect(controller.currentSong, expectedQueue.first);
      expect(controller.queue, expectedQueue);
      expect(chartLoads, 1);
    },
  );

  testWidgets('explicit Local Mix modes replace Live Radio state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(enableLiveRadio: true);
    addTearDown(controller.dispose);
    const room = LiveRadioRoom(
      id: 'local-mix-live',
      title: 'V-POP',
      description: 'Nhạc Việt trực tiếp',
      thumbnail: '',
      listenerCount: 1200,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    );

    controller.setShuffleEnabled(true);
    await controller.playLiveRadio(room);
    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            chartRefreshInterval: null,
            navigationRoute: const AppNavigationRoute.forYou(),
            loadSongs: () async => songs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.isLiveRadio, isTrue);
    await tester.tap(find.byKey(const ValueKey('for-you-play-daily')));
    await tester.pump();
    expect(controller.isLiveRadio, isFalse);
    expect(controller.shuffleEnabled, isFalse);

    await controller.playLiveRadio(room);
    await tester.tap(find.byKey(const ValueKey('for-you-open-daily')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('local-mix-shuffle')));
    await tester.pump();

    expect(controller.isLiveRadio, isFalse);
    expect(controller.shuffleEnabled, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mood Mix route restores its exact local snapshot', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    controller.updateCatalog(songs);
    controller.toggleMood(songs.last, MoodTag.chill);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            chartRefreshInterval: null,
            navigationRoute: const AppNavigationRoute.forYou(
              mix: ForYouMix.chill,
            ),
            loadSongs: () async => songs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mix = controller.moodMix(MoodTag.chill);
    expect(find.byKey(const ValueKey('local-mix-workspace')), findsOneWidget);
    expect(find.text('Chill chậm lại'), findsOneWidget);
    for (final song in mix.songs) {
      expect(find.byKey(ValueKey('local-mix-song-${song.id}')), findsOneWidget);
    }
    expect(controller.currentSong, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system Back closes a cold local Mix deep link', (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            chartRefreshInterval: null,
            navigationRoute: const AppNavigationRoute.forYou(
              mix: ForYouMix.daily,
            ),
            loadSongs: () async => songs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('local-mix-workspace')), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('local-mix-workspace')), findsNothing);
    expect(find.byKey(const ValueKey('for-you-daily-mix')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV Escape closes a cold local Mix deep link', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            chartRefreshInterval: null,
            navigationRoute: const AppNavigationRoute.forYou(
              mix: ForYouMix.gym,
            ),
            loadSongs: () async => songs,
            tvMode: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('local-mix-workspace')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('local-mix-workspace')), findsNothing);
    expect(find.byKey(const ValueKey('for-you-daily-mix')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked local signals never enter a Mix or playable queue', (
    tester,
  ) async {
    const locked = Song(
      id: 'locked-local',
      name: 'locked-local',
      title: 'Bài Bị Giới Hạn',
      thumbnail: '',
      artistsNames: 'Nghệ sĩ khóa',
      code: 'real-but-locked-code',
      playable: false,
    );
    final controller = await _controller();
    controller.updateCatalog([...songs, locked]);
    controller.toggleLike(locked);
    controller.toggleMood(locked, MoodTag.chill);
    addTearDown(controller.dispose);

    expect(controller.dailyMixCollection.songs, isNot(contains(locked)));
    expect(controller.moodMix(MoodTag.chill).songs, isNot(contains(locked)));

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            chartRefreshInterval: null,
            navigationRoute: const AppNavigationRoute.forYou(),
            loadSongs: () async => [...songs, locked],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('for-you-open-daily')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('local-mix-song-locked-local')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('local-mix-play')));
    await tester.pump();
    expect(controller.queue, isNotEmpty);
    expect(controller.queue.every((song) => song.isPlaybackEligible), isTrue);
    expect(controller.queue, isNot(contains(locked)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tags a mood from the song context menu', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await _pumpChart(tester, controller, songs);

    await tester.tap(find.byTooltip('Tùy chọn bài hát').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gắn mood Tập trung'));
    await tester.pumpAndSettle();

    expect(controller.moodsFor(songs.first), {MoodTag.focus});
  });

  testWidgets('opens analytics dashboard with all requested periods', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await _pumpChart(tester, controller, songs);

    final forYouDestination = find.byKey(const ValueKey('desktop-nav-forYou'));
    await tester.scrollUntilVisible(
      forYouDestination,
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('desktop-catalog-sidebar')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(forYouDestination);
    await tester.pumpAndSettle();
    final openAnalytics = find.text('Xem thống kê');
    final contentScroll = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      openAnalytics,
      140,
      scrollable: contentScroll.first,
    );
    await tester.pumpAndSettle();
    await tester.tap(openAnalytics);
    await tester.pumpAndSettle();

    expect(find.byType(AnalyticsDashboardScreen), findsOneWidget);
    expect(find.text('7 ngày'), findsOneWidget);
    expect(find.text('30 ngày'), findsOneWidget);
    expect(find.text('Theo năm'), findsOneWidget);
    expect(find.text('Top 5 bài hát'), findsOneWidget);
    expect(find.text('Top 5 nghệ sĩ'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('for-you-daily-mix')), findsOneWidget);
  });

  testWidgets('analytics keeps legacy song stats visible but not playable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(lockedAnalytics: true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: const MaterialApp(home: AnalyticsDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.byKey(const ValueKey('analytics-song-one'));
    expect(tile, findsOneWidget);
    expect(tester.widget<ListTile>(tile).enabled, isFalse);
    expect(tester.widget<ListTile>(tile).onTap, isNull);
    expect(
      find.descendant(
        of: tile,
        matching: find.byIcon(Icons.lock_outline_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(tile);
    await tester.pump();
    expect(controller.currentSong, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV can open and close Wrapped with the remote Back key', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    await _pumpChart(tester, controller, songs, tvMode: true);

    await tester.tap(find.text('Dành cho bạn').first);
    await tester.pumpAndSettle();
    final wrappedButton = find.text('Mở Wrapped');
    await tester.scrollUntilVisible(
      wrappedButton,
      400,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(wrappedButton);
    await tester.pumpAndSettle();
    expect(find.byType(WrappedScreen), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('for-you-daily-mix')), findsOneWidget);
  });

  testWidgets('renders six Wrapped slides and exports a local PNG', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    final exporter = _FakeWrappedExportService();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: WrappedScreen(
            exportService: exporter,
            imageRenderer: const _FakeWrappedImageRenderer(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 / 6'), findsOneWidget);
    for (var page = 2; page <= 6; page++) {
      await tester.tap(find.byTooltip('Trang sau'));
      await tester.pumpAndSettle();
      expect(find.text('$page / 6'), findsOneWidget);
      expect(find.byKey(ValueKey('wrapped-slide-${page - 1}')), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('wrapped-export-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    expect(exporter.bytes, isNotNull);
    expect(exporter.bytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(exporter.fileName, contains('zingchart-wrapped'));
  });

  testWidgets('Canvas renderer produces a standalone PNG without artwork', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    final bytes = await tester.runAsync(
      () => const CanvasWrappedImageRenderer().render(
        controller.wrappedSummary(DateTime.now().year),
        0,
      ),
    );

    expect(bytes, isNotNull);
    expect(bytes!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(bytes.length, greaterThan(1000));
  });
}

Future<PlaybackService> _controller({
  bool lockedAnalytics = false,
  bool enableLiveRadio = false,
}) async {
  final now = DateTime.now();
  final date = _dateKey(now);
  final month = date.substring(0, 7);
  final song = lockedAnalytics
      ? Song.fromJson(const {
          'id': 'one',
          'name': 'mot-bai-hat',
          'title': 'Một Bài Hát',
          'thumbnail': '',
          'artists_names': 'Ca Sĩ A',
          'code': 'code-one',
        })
      : const Song(
          id: 'one',
          name: 'mot-bai-hat',
          title: 'Một Bài Hát',
          thumbnail: '',
          artistsNames: 'Ca Sĩ A',
          code: 'code-one',
        );
  final aggregate = SongAnalyticsAggregate(
    song: song,
    starts: 8,
    qualifiedPlays: 6,
    completions: 4,
    listened: Duration(minutes: 32),
  );
  final analytics = ListeningAnalyticsSnapshot(
    installationId: 'ui-test-device',
    dailyBuckets: [
      DailyListeningBucket(
        sourceId: 'ui-test-device',
        date: date,
        songs: {'one': aggregate},
      ),
    ],
    dailyTotals: [
      DailyListeningTotal(
        sourceId: 'ui-test-device',
        date: date,
        starts: 8,
        qualifiedPlays: 6,
        completions: 4,
        listened: const Duration(minutes: 32),
      ),
    ],
    monthlyBuckets: [
      MonthlySongAggregate(
        sourceId: 'ui-test-device',
        month: month,
        songs: {'one': aggregate},
      ),
    ],
  );
  final controller = PlaybackService(
    playbackAudioPlayer: FakePlaybackAudioPlayer(),
    sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
    liveRadioSourceResolver: enableLiveRadio
        ? (id) async => 'https://audio.example.com/live/$id.m3u8'
        : null,
    libraryRepository: MemoryLibraryRepository(),
    analyticsRepository: MemoryListeningAnalyticsRepository(analytics),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  return controller;
}

Future<void> _pumpChart(
  WidgetTester tester,
  PlaybackService controller,
  List<Song> songs, {
  bool tvMode = false,
}) async {
  await tester.pumpWidget(
    MusicPlayerScope(
      controller: controller,
      child: MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: ZingChartScreen(loadSongs: () async => songs, tvMode: tvMode),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class _FakeWrappedExportService implements WrappedExportService {
  Uint8List? bytes;
  String? fileName;

  @override
  Future<WrappedExportResult> exportPng(
    Uint8List bytes, {
    required String fileName,
    required String title,
  }) async {
    this.bytes = bytes;
    this.fileName = fileName;
    return WrappedExportResult.saved;
  }
}

class _FakeWrappedImageRenderer implements WrappedImageRenderer {
  const _FakeWrappedImageRenderer();

  @override
  Future<Uint8List> render(WrappedSummary summary, int slideIndex) async =>
      Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
}
