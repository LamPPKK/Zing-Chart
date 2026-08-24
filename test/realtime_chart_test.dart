import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/chart_snapshot.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/realtime_chart.dart';

void main() {
  for (final size in const [
    Size(360, 844),
    Size(768, 1024),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets('interactive realtime chart renders without overflow at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await _pumpChart(tester, size);

      expect(find.byKey(const ValueKey('realtime-chart')), findsOneWidget);
      expect(find.byKey(const ValueKey('realtime-chart-plot')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows a Zing-style tooltip and plays its selected song', (
    tester,
  ) async {
    Song? playedSong;
    List<Song>? playedQueue;
    await _pumpChart(
      tester,
      const Size(1440, 900),
      onPlay: (song, queue) {
        playedSong = song;
        playedQueue = queue;
      },
    );

    final plot = find.byKey(const ValueKey('realtime-chart-plot'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(plot));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('realtime-chart-tooltip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('realtime-chart-tooltip-time')),
      findsOneWidget,
    );
    final tooltipTitle = tester
        .widget<Text>(
          find.byKey(const ValueKey('realtime-chart-tooltip-title')),
        )
        .data;

    final playButton = find.byKey(
      const ValueKey('realtime-chart-tooltip-play'),
    );
    final playCenter = tester.getCenter(playButton);
    await gesture.moveTo(playCenter);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('realtime-chart-tooltip')),
      findsOneWidget,
    );
    await gesture.down(playCenter);
    await gesture.up();
    await tester.pump();

    expect(playedSong, isNotNull);
    expect(playedSong?.displayTitle, tooltipTitle);
    expect(playedQueue, _songs);
    await gesture.removePointer();
  });

  testWidgets('aligns tooltip percentages by hour when a series omits points', (
    tester,
  ) async {
    final unevenSnapshot = ChartSnapshot(
      songs: _songs,
      series: {
        _songs[0].id: [
          ChartPoint(time: DateTime(2026, 8, 21, 8), hour: '08', counter: 100),
          ChartPoint(time: DateTime(2026, 8, 21, 9), hour: '09', counter: 100),
        ],
        _songs[1].id: [
          ChartPoint(time: DateTime(2026, 8, 21, 8), hour: '08', counter: 100),
          ChartPoint(time: DateTime(2026, 8, 21, 20), hour: '20', counter: 900),
        ],
        _songs[2].id: [
          ChartPoint(time: DateTime(2026, 8, 21, 8), hour: '08', counter: 100),
          ChartPoint(time: DateTime(2026, 8, 21, 9), hour: '09', counter: 100),
        ],
      },
      maxScore: 1000,
    );
    await _pumpChart(tester, const Size(1440, 900), snapshot: unevenSnapshot);
    final rect = tester.getRect(
      find.byKey(const ValueKey('realtime-chart-plot')),
    );
    await tester.tapAt(Offset(rect.left + rect.width / 12, rect.bottom - 45));
    await tester.pump();

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('realtime-chart-tooltip-time')),
          )
          .data,
      '09:00 · 50%',
    );
  });

  testWidgets('touch drag pins the tooltip and changes its time', (
    tester,
  ) async {
    await _pumpChart(tester, const Size(360, 844));
    final plot = find.byKey(const ValueKey('realtime-chart-plot'));
    final rect = tester.getRect(plot);
    final gesture = await tester.startGesture(
      Offset(rect.left + 18, rect.center.dy),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveTo(Offset(rect.left + 54, rect.center.dy));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('realtime-chart-tooltip')),
      findsOneWidget,
    );
    final firstTime = tester
        .widget<Text>(find.byKey(const ValueKey('realtime-chart-tooltip-time')))
        .data;

    await gesture.moveTo(Offset(rect.right - 18, rect.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    final lastTime = tester
        .widget<Text>(find.byKey(const ValueKey('realtime-chart-tooltip-time')))
        .data;

    expect(lastTime, isNot(firstTime));
    expect(
      find.byKey(const ValueKey('realtime-chart-tooltip')),
      findsOneWidget,
    );
  });

  testWidgets('realtime refresh status stays usable at 360px', (tester) async {
    await _pumpChart(tester, const Size(360, 844), refreshing: true);

    expect(find.byKey(const ValueKey('chart-refreshing')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Đang cập nhật bảng xếp hạng'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    var retried = false;
    await _pumpChart(
      tester,
      const Size(360, 844),
      refreshFailed: true,
      onRetry: () => retried = true,
    );
    await tester.tap(find.byKey(const ValueKey('chart-refresh-retry')));
    await tester.pump();

    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV remote changes time and song then plays from the chart', (
    tester,
  ) async {
    Song? playedSong;
    await _pumpChart(
      tester,
      const Size(1920, 1080),
      onPlay: (song, _) => playedSong = song,
    );

    for (var index = 0; index < 12; index++) {
      if (FocusManager.instance.primaryFocus?.debugLabel ==
          'realtime-chart-focus') {
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'realtime-chart-focus',
    );
    expect(
      find.byKey(const ValueKey('realtime-chart-tooltip')),
      findsOneWidget,
    );

    final initialTime = tester
        .widget<Text>(find.byKey(const ValueKey('realtime-chart-tooltip-time')))
        .data;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    final previousTime = tester
        .widget<Text>(find.byKey(const ValueKey('realtime-chart-tooltip-time')))
        .data;
    expect(previousTime, isNot(initialTime));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(find.text(_songs[1].displayTitle), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(playedSong, _songs[1]);
  });
}

Future<void> _pumpChart(
  WidgetTester tester,
  Size size, {
  void Function(Song song, List<Song> queue)? onPlay,
  ChartSnapshot? snapshot,
  bool refreshing = false,
  bool refreshFailed = false,
  VoidCallback? onRetry,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildZingDarkTheme(tvMode: size.width >= 1800),
      home: Scaffold(
        body: SingleChildScrollView(
          child: RealtimeChart(
            snapshot: snapshot ?? _snapshot,
            onPlay: onPlay ?? (_, _) {},
            refreshing: refreshing,
            refreshFailed: refreshFailed,
            onRetry: onRetry,
          ),
        ),
      ),
    ),
  );
  if (refreshing) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

const _songs = [
  Song(
    id: 'chart-one',
    name: 'chart-one',
    title: 'Một Đời',
    thumbnail: '',
    artistsNames: '14 Casper & Bon Nghiêm',
    code: 'chart-code-one',
  ),
  Song(
    id: 'chart-two',
    name: 'chart-two',
    title: 'Nàng Thơ',
    thumbnail: '',
    artistsNames: 'Hoàng Dũng',
    code: 'chart-code-two',
  ),
  Song(
    id: 'chart-three',
    name: 'chart-three',
    title: 'Từng Là',
    thumbnail: '',
    artistsNames: 'Vũ Cát Tường',
    code: 'chart-code-three',
  ),
];

final _snapshot = ChartSnapshot(
  songs: _songs,
  series: {
    for (var songIndex = 0; songIndex < _songs.length; songIndex++)
      _songs[songIndex].id: [
        for (var hour = 0; hour < 8; hour++)
          ChartPoint(
            time: DateTime(2026, 8, 21, hour * 3),
            hour: (hour * 3).toString().padLeft(2, '0'),
            counter: 28 + songIndex * 14 + ((hour * 17 + songIndex * 9) % 48),
          ),
      ],
  },
  minScore: 20,
  maxScore: 100,
  updatedAt: DateTime(2026, 8, 21, 21),
);
