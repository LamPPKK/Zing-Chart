import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/music_player_screen.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/desktop_playback_queue_panel.dart';
import 'package:zmp3chart/widgets/smart_shuffle_controls.dart';

import 'support/fake_playback_audio_player.dart';

const _baseQueue = [
  Song(
    id: 'base-one',
    name: 'base-one',
    title: 'Một Đời',
    thumbnail: '',
    artistsNames: '14 Casper & Bon Nghiêm',
    code: 'base-code-one',
  ),
  Song(
    id: 'base-two',
    name: 'base-two',
    title: 'Nàng Thơ',
    thumbnail: '',
    artistsNames: 'Hoàng Dũng',
    code: 'base-code-two',
  ),
  Song(
    id: 'base-three',
    name: 'base-three',
    title: 'Lạc Trôi',
    thumbnail: '',
    artistsNames: 'Sơn Tùng M-TP',
    code: 'base-code-three',
  ),
  Song(
    id: 'base-four',
    name: 'base-four',
    title: 'Từng Là',
    thumbnail: '',
    artistsNames: 'Vũ Cát Tường',
    code: 'base-code-four',
  ),
];

final _catalog = [
  ..._baseQueue,
  for (var index = 0; index < 8; index++)
    Song(
      id: 'smart-$index',
      name: 'smart-$index',
      title: 'Gợi ý thông minh ${index + 1}',
      thumbnail: '',
      artistsNames: 'Nghệ sĩ mới ${index + 1}',
      code: 'smart-code-$index',
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('enables Smart Shuffle and labels the mobile queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const MusicPlayerScreen()));
    await tester.pumpAndSettle();
    final smartAction = find.byKey(const ValueKey('toggle-smart-shuffle'));
    await tester.ensureVisible(smartAction);
    await tester.tap(smartAction);
    await tester.pumpAndSettle();

    expect(controller.smartShuffleEnabled, isTrue);
    expect(controller.smartShuffleSongCount, 2);
    expect(controller.queue, hasLength(6));

    final queueButton = find.byKey(const ValueKey('open-playback-queue'));
    await tester.ensureVisible(queueButton);
    await tester.tap(queueButton);
    await tester.pumpAndSettle();
    expect(find.byType(SmartShuffleControlCard), findsOneWidget);
    final smartSongs = controller.queue
        .where(controller.isSmartShuffleSong)
        .toList(growable: false);
    expect(smartSongs, hasLength(2));
    for (final song in smartSongs) {
      final queueRow = find.byKey(ValueKey('queue-${song.id}'));
      await tester.scrollUntilVisible(
        queueRow,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.descendant(of: queueRow, matching: find.text('SMART')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('smart-shuffle-toggle')));
    await tester.pumpAndSettle();
    expect(controller.smartShuffleEnabled, isFalse);
    expect(
      controller.queue.map((song) => song.id),
      _baseQueue.map((s) => s.id),
    );
  });

  for (final scenario in const [
    (name: 'phone', size: Size(360, 844), tv: false),
    (name: 'tablet', size: Size(768, 1024), tv: false),
    (name: 'desktop', size: Size(1440, 900), tv: false),
    (name: 'TV', size: Size(1920, 1080), tv: true),
  ]) {
    testWidgets('Smart Shuffle control is adaptive on ${scenario.name}', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await _controller();
      addTearDown(controller.dispose);
      controller.setSmartShuffleEnabled(true);

      await tester.pumpWidget(
        _app(
          controller,
          Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SmartShuffleControlCard(
                  controller: controller,
                  tvMode: scenario.tv,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(find.text('Smart Shuffle'), findsOneWidget);
      expect(find.text('SMART'), findsNothing);
      expect(
        find.byKey(const ValueKey('smart-shuffle-refresh')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop queue shows exact Smart Shuffle markers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.setSmartShuffleEnabled(true);

    await tester.pumpWidget(
      _app(
        controller,
        const Scaffold(
          body: SizedBox(
            width: 430,
            child: DesktopPlaybackQueuePanel(onClose: _noop),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SmartShuffleControlCard), findsOneWidget);
    final smartSongs = controller.queue
        .where(controller.isSmartShuffleSong)
        .toList(growable: false);
    expect(smartSongs, hasLength(2));
    for (final song in smartSongs) {
      final queueRow = find.byKey(ValueKey('desktop-queue-${song.id}'));
      await tester.scrollUntilVisible(
        queueRow,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.descendant(of: queueRow, matching: find.text('SMART')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV remote toggles Smart Shuffle with focus and Enter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _app(
        controller,
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 620,
              child: SmartShuffleControlCard(
                controller: controller,
                tvMode: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(controller.smartShuffleEnabled, isTrue);
    expect(controller.smartShuffleSongCount, 2);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

Future<MusicPlayerController> _controller() async {
  final controller = MusicPlayerController(
    playbackAudioPlayer: FakePlaybackAudioPlayer(),
    sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  controller.updateCatalog(_catalog);
  await controller.playSong(_baseQueue.first, queue: _baseQueue);
  return controller;
}

Widget _app(MusicPlayerController controller, Widget home) => MusicPlayerScope(
  controller: controller,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildZingDarkTheme(tvMode: false),
    home: home,
  ),
);
