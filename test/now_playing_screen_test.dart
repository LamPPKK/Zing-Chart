import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/data/listening_analytics_repository.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/music_player_screen.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Now Playing keeps the Zing playback hierarchy responsive', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in const [
      Size(360, 844),
      Size(768, 1024),
      Size(1440, 900),
      Size(1920, 1080),
    ]) {
      tester.view.physicalSize = size;
      final audio = FakePlaybackAudioPlayer();
      final controller = await _controller(audio);

      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(find.text('ĐANG PHÁT TỪ'), findsOneWidget);
      expect(find.text('Kẻ Say Tình 2'), findsOneWidget);
      expect(find.text('Quốc Thiên'), findsOneWidget);
      expect(find.text('AUTO'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('now-playing-action-dock')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('player-progress-slider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('primary-play-pause-button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('open-song-lyrics')), findsOneWidget);
      expect(find.byKey(const ValueKey('open-playback-queue')), findsOneWidget);
      expect(find.byKey(const ValueKey('start-song-radio')), findsOneWidget);
      expect(find.byKey(const ValueKey('sleep-timer-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('open-song-detail')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('toggle-smart-shuffle')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('enter-car-mode')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport $size');

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('quality badge opens the truthful streaming selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(FakePlaybackAudioPlayer());
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-streaming-quality')));
    await tester.pumpAndSettle();

    expect(find.text('CHẤT LƯỢNG NHẠC'), findsOneWidget);
    expect(find.text('128 kbps'), findsOneWidget);
    expect(find.text('320 kbps'), findsOneWidget);
    expect(find.text('Lossless'), findsNothing);
  });
}

Future<MusicPlayerController> _controller(FakePlaybackAudioPlayer audio) async {
  final controller = PlaybackService(
    playbackAudioPlayer: audio,
    sourceResolver: (_) async => 'https://audio.example.test/song.mp3',
    libraryRepository: MemoryLibraryRepository(),
    analyticsRepository: MemoryListeningAnalyticsRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  await controller.playSong(_songs.first, queue: _songs);
  audio
    ..emitDuration(const Duration(minutes: 3, seconds: 42))
    ..emitPosition(const Duration(minutes: 1, seconds: 18));
  return controller;
}

Widget _app(MusicPlayerController controller) => MusicPlayerScope(
  controller: controller,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildZingDarkTheme(tvMode: false),
    home: const MusicPlayerScreen(),
  ),
);

const _songs = [
  Song(
    id: 'one',
    name: 'ke-say-tinh',
    title: 'Kẻ Say Tình 2',
    thumbnail: '',
    artistsNames: 'Quốc Thiên',
    code: 'one',
  ),
  Song(
    id: 'two',
    name: 'thien-duong',
    title: 'Thiên Đường Với Người Thương',
    thumbnail: '',
    artistsNames: 'Phương Mỹ Chi, DTAP',
    code: 'two',
  ),
];
