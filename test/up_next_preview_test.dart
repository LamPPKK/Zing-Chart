import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/widgets/up_next_preview.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the navigator real next song after shuffle and Add Next', (
    tester,
  ) async {
    final controller = _controller();
    await controller.initialize();
    addTearDown(controller.dispose);
    await controller.playSong(_songs.first, queue: _songs);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('up-next-song-two')), findsOneWidget);

    controller.setShuffleEnabled(true);
    expect(controller.addToQueue(_songs.last), isTrue);
    await tester.pump();

    expect(find.text('TIẾP THEO · SHUFFLE'), findsOneWidget);
    expect(find.byKey(const ValueKey('up-next-song-three')), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Tiếp theo trong chế độ trộn bài: Bài Ba, Nghệ sĩ C. Còn 2 bài.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the accessible theme accent in light mode', (tester) async {
    final controller = _controller();
    await controller.initialize();
    addTearDown(controller.dispose);
    await controller.playSong(_songs.first, queue: _songs);
    final theme = ThemeData.from(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF7B2CBF),
        brightness: Brightness.light,
      ),
    );

    await tester.pumpWidget(_app(controller, theme: theme));
    await tester.pumpAndSettle();

    final label = tester.widget<Text>(find.text('TIẾP THEO'));
    expect(label.style?.color, theme.colorScheme.primary);
  });

  testWidgets('stays visible at a Repeat All cycle boundary', (tester) async {
    final controller = _controller();
    await controller.initialize();
    addTearDown(controller.dispose);
    await controller.playSong(_songs.last, queue: _songs);
    controller.setRepeatMode(PlayerRepeatMode.all);

    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('up-next-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('up-next-song-one')), findsOneWidget);
  });

  testWidgets('scales the Up Next preview for TV without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _controller();
    await controller.initialize();
    addTearDown(controller.dispose);
    await controller.playSong(_songs.first, queue: _songs);

    await tester.pumpWidget(_app(controller, tvMode: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('up-next-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('up-next-count')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  PlaybackService controller, {
  bool tvMode = false,
  ThemeData? theme,
}) => MaterialApp(
  theme: theme ?? ThemeData.dark(),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: tvMode ? 720 : 340,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) =>
              UpNextPreview(controller: controller, tvMode: tvMode),
        ),
      ),
    ),
  ),
);

PlaybackService _controller() => PlaybackService(
  playbackAudioPlayer: FakePlaybackAudioPlayer(),
  sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
  libraryRepository: MemoryLibraryRepository(),
  systemMediaBridge: NoopSystemMediaBridge(),
);

const _songs = [
  Song(
    id: 'one',
    name: 'one',
    title: 'Bài Một',
    thumbnail: '',
    artistsNames: 'Nghệ sĩ A',
    code: 'code-one',
  ),
  Song(
    id: 'two',
    name: 'two',
    title: 'Bài Hai',
    thumbnail: '',
    artistsNames: 'Nghệ sĩ B',
    code: 'code-two',
  ),
  Song(
    id: 'three',
    name: 'three',
    title: 'Bài Ba',
    thumbnail: '',
    artistsNames: 'Nghệ sĩ C',
    code: 'code-three',
  ),
];
