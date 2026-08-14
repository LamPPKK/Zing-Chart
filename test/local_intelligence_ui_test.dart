import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/analytics_dashboard_screen.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/data/listening_analytics_repository.dart';
import 'package:zmp3chart/models/listening_analytics.dart';
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
        await tester.tap(find.text('Dành cho bạn').first);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('for-you-daily-mix')), findsOneWidget);
        expect(find.text('Ba nhịp cho một ngày'), findsOneWidget);
        expect(find.byKey(const ValueKey('open-wrapped-card')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('tags a mood from Now Playing and updates its local mix', (
    tester,
  ) async {
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

  testWidgets('tags a mood from the song context menu', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await _pumpChart(tester, controller, songs);

    await tester.tap(find.text('Tìm kiếm').first);
    await tester.pump();
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

    await tester.tap(find.text('Dành cho bạn').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem thống kê'));
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

Future<PlaybackService> _controller() async {
  final now = DateTime.now();
  final date = _dateKey(now);
  final month = date.substring(0, 7);
  const song = Song(
    id: 'one',
    name: 'mot-bai-hat',
    title: 'Một Bài Hát',
    thumbnail: '',
    artistsNames: 'Ca Sĩ A',
    code: 'code-one',
  );
  const aggregate = SongAnalyticsAggregate(
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
        songs: const {'one': aggregate},
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
        songs: const {'one': aggregate},
      ),
    ],
  );
  final controller = PlaybackService(
    playbackAudioPlayer: FakePlaybackAudioPlayer(),
    sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
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
