import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/music_player_screen.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/desktop_now_playing_panel.dart';
import 'package:zmp3chart/widgets/desktop_playback_queue_panel.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile queue renders and reorders the real shuffle future', (
    tester,
  ) async {
    await _setViewport(tester, const Size(390, 844));
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.setShuffleEnabled(true);
    final before = controller.upNextSongs;

    await tester.pumpWidget(_app(controller, const MusicPlayerScreen()));
    await tester.pumpAndSettle();
    final openQueue = find.byKey(const ValueKey('open-playback-queue'));
    await tester.ensureVisible(openQueue);
    await tester.tap(openQueue);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('queue-current-song-one')),
      findsOneWidget,
    );
    final listFinder = find.byKey(const ValueKey('mobile-up-next-list'));
    final list = tester.widget<ReorderableListView>(listFinder);
    expect(list.itemCount, before.length);
    for (final song in before) {
      expect(find.byKey(ValueKey('queue-${song.id}')), findsOneWidget);
    }

    list.onReorderItem!(0, before.length - 1);
    await tester.pump();
    expect(
      controller.upNextSongs.map((song) => song.id),
      [...before.skip(1), before.first].map((song) => song.id),
    );
    expect(controller.nextSong, before[1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop drawer separates current from the true Up Next order', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1440, 900));
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.setShuffleEnabled(true);
    final expected = controller.upNextSongs;

    await tester.pumpWidget(
      _app(
        controller,
        const Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 430,
              child: DesktopPlaybackQueuePanel(onClose: _noop),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('desktop-current-song-one')),
      findsOneWidget,
    );
    final list = tester.widget<ReorderableListView>(
      find.byKey(const ValueKey('desktop-playing-queue-list')),
    );
    expect(list.itemCount, expected.length);
    for (final song in expected) {
      expect(find.byKey(ValueKey('desktop-queue-${song.id}')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV exposes focusable Up and Down controls for the real future', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1920, 1080));
    final controller = await _controller();
    addTearDown(controller.dispose);
    final before = controller.upNextSongs;

    await tester.pumpWidget(
      _app(
        controller,
        const Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: DesktopNowPlayingPanel(tvMode: true),
          ),
        ),
        tvMode: true,
      ),
    );
    await tester.pumpAndSettle();

    final moveDown = find.byKey(
      ValueKey('tv-up-next-move-down-${before.first.id}'),
    );
    expect(moveDown, findsOneWidget);
    expect(tester.widget<IconButton>(moveDown).onPressed, isNotNull);
    await tester.ensureVisible(moveDown);
    await tester.tap(moveDown);
    await tester.pump();

    expect(
      controller.upNextSongs.map((song) => song.id),
      [before[1], before.first, ...before.skip(2)].map((song) => song.id),
    );
    expect(controller.nextSong, before[1]);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}

Future<MusicPlayerController> _controller() async {
  final controller = PlaybackService(
    playbackAudioPlayer: FakePlaybackAudioPlayer(),
    sourceResolver: (code) async => 'https://audio.example.test/$code.mp3',
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  await controller.playSong(_songs.first, queue: _songs);
  return controller;
}

Widget _app(
  MusicPlayerController controller,
  Widget home, {
  bool tvMode = false,
}) => MusicPlayerScope(
  controller: controller,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildZingDarkTheme(tvMode: tvMode),
    home: home,
  ),
);

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _songs = [
  Song(
    id: 'song-one',
    name: 'song-one',
    title: 'Bài đang phát',
    thumbnail: '',
    artistsNames: 'Nghệ sĩ Một',
    code: 'code-one',
  ),
  Song(
    id: 'song-two',
    name: 'song-two',
    title: 'Bài tiếp theo có tiêu đề dài để kiểm tra TV',
    thumbnail: '',
    artistsNames: 'Nghệ sĩ Hai',
    code: 'code-two',
  ),
  Song(
    id: 'song-three',
    name: 'song-three',
    title: 'Bài thứ ba',
    thumbnail: '',
    artistsNames: 'Nghệ sĩ Ba',
    code: 'code-three',
  ),
  Song(
    id: 'song-four',
    name: 'song-four',
    title: 'Bài thứ tư',
    thumbnail: '',
    artistsNames: 'Nghệ sĩ Bốn',
    code: 'code-four',
  ),
];
