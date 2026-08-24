import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/music_player_screen.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Car Mode stays adaptive with large controls', (tester) async {
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
      controller.setCarModeEnabled(true);

      await tester.pumpWidget(_app(controller, tvMode: size.width >= 1800));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('car-mode-player')), findsOneWidget);
      expect(find.text('CHẾ ĐỘ LÁI XE'), findsOneWidget);
      expect(find.byKey(const ValueKey('car-mode-play-pause')), findsOneWidget);
      expect(find.byKey(const ValueKey('car-mode-stop')), findsOneWidget);
      expect(find.byKey(const ValueKey('exit-car-mode')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport $size');

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('Car Mode controls playback and exits to full Now Playing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = await _controller(audio);
    controller.setCarModeEnabled(true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    final playPause = find.byKey(const ValueKey('car-mode-play-pause'));
    await tester.ensureVisible(playPause);
    await tester.pumpAndSettle();
    await tester.tap(playPause);
    await tester.pump();
    expect(controller.isPlaying, isFalse);

    final next = find.byKey(const ValueKey('car-mode-next'));
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(controller.currentSong?.id, _songs.last.id);

    final stop = find.byKey(const ValueKey('car-mode-stop'));
    await tester.ensureVisible(stop);
    await tester.pumpAndSettle();
    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(controller.isPlaying, isFalse);

    final exit = find.byKey(const ValueKey('exit-car-mode'));
    await tester.ensureVisible(exit);
    await tester.pumpAndSettle();
    await tester.tap(exit);
    await tester.pumpAndSettle();
    expect(controller.carModeEnabled, isFalse);
    expect(find.byKey(const ValueKey('car-mode-player')), findsNothing);
    expect(
      find.byKey(const ValueKey('player-progress-slider')),
      findsOneWidget,
    );
  });

  testWidgets('full Now Playing can enter Car Mode directly', (tester) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(FakePlaybackAudioPlayer());
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    final enter = find.byKey(const ValueKey('enter-car-mode'));
    await tester.scrollUntilVisible(
      enter,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(enter);
    await tester.pumpAndSettle();

    expect(controller.carModeEnabled, isTrue);
    expect(find.byKey(const ValueKey('car-mode-player')), findsOneWidget);
  });
}

Widget _app(MusicPlayerController controller, {bool tvMode = false}) =>
    MusicPlayerScope(
      controller: controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: tvMode),
        home: const MusicPlayerScreen(),
      ),
    );

Future<MusicPlayerController> _controller(FakePlaybackAudioPlayer audio) async {
  final controller = PlaybackService(
    playbackAudioPlayer: audio,
    sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  await controller.playSong(_songs.first, queue: _songs);
  audio
    ..emitDuration(const Duration(minutes: 3, seconds: 48))
    ..emitPosition(const Duration(minutes: 1, seconds: 16));
  return controller;
}

const _songs = [
  Song(
    id: 'car-mode-one',
    name: 'duong-dai-phia-truoc',
    title: 'Đường Dài Phía Trước',
    thumbnail: '',
    artistsNames: 'Nghệ Sĩ Một',
    code: 'car-mode-code-one',
  ),
  Song(
    id: 'car-mode-two',
    name: 'mot-chang-duong-moi',
    title: 'Một Chặng Đường Mới',
    thumbnail: '',
    artistsNames: 'Nghệ Sĩ Hai',
    code: 'car-mode-code-two',
  ),
];
