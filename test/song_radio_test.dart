import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/song_radio.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/music_player_screen.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/desktop_now_playing_panel.dart';
import 'package:zmp3chart/widgets/song_radio_controls.dart';

import 'support/fake_playback_audio_player.dart';

const _seed = Song(
  id: 'seed',
  name: 'noi-nay-co-anh',
  title: 'Nơi Này Có Anh',
  thumbnail: 'https://image.example.com/seed.jpg',
  artistsNames: 'Sơn Tùng M-TP',
  code: 'SEED123',
);

const _recommendations = [
  Song(
    id: 'radio-one',
    name: 'radio-one',
    title: 'Lạc Trôi',
    thumbnail: 'https://image.example.com/radio-one.jpg',
    artistsNames: 'Sơn Tùng M-TP',
    code: 'RADIO1',
  ),
  Song(
    id: 'radio-two',
    name: 'radio-two',
    title: 'Chúng Ta Của Tương Lai',
    thumbnail: 'https://image.example.com/radio-two.jpg',
    artistsNames: 'Sơn Tùng M-TP',
    code: 'RADIO2',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts Song Radio and exposes autoplay in the mobile queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, const MusicPlayerScreen()));
    await tester.pump();
    final radioButton = find.byKey(const ValueKey('start-song-radio'));
    await tester.ensureVisible(radioButton);
    await tester.pump();
    await tester.tap(radioButton);
    await tester.pumpAndSettle();

    expect(controller.queue.map((song) => song.id), [
      'seed',
      'radio-one',
      'radio-two',
    ]);
    expect(find.textContaining('Đã tạo Song Radio'), findsOneWidget);

    final queueButton = find.byKey(const ValueKey('open-playback-queue'));
    await tester.ensureVisible(queueButton);
    await tester.tap(queueButton);
    await tester.pumpAndSettle();
    expect(find.byType(SongRadioControlCard), findsOneWidget);
    expect(find.text('RADIO'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('song-radio-autoplay-toggle')));
    await tester.pump();
    expect(controller.autoplayRecommendationsEnabled, isFalse);
  });

  for (final scenario in const [
    (name: 'desktop', size: Size(1440, 900), tvMode: false),
    (name: 'TV', size: Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      '${scenario.name} Now Playing renders radio queue without overflow',
      (tester) async {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = await _controller();
        addTearDown(controller.dispose);
        await controller.startSongRadio();

        await tester.pumpWidget(
          _app(
            controller,
            Scaffold(
              body: Row(
                children: [
                  const Expanded(child: SizedBox()),
                  DesktopNowPlayingPanel(tvMode: scenario.tvMode),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SongRadioControlCard), findsOneWidget);
        expect(
          find.byKey(const ValueKey('desktop-start-song-radio')),
          findsOneWidget,
        );
        expect(find.text('RADIO'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<MusicPlayerController> _controller() async {
  final controller = MusicPlayerController(
    playbackAudioPlayer: FakePlaybackAudioPlayer(),
    sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
    songRadioLoader: (code) async => SongRadio(
      seedId: code,
      recommendations: _recommendations
          .map(
            (song) => CatalogSong(
              song: song,
              duration: const Duration(minutes: 4),
              externalUrl: 'https://zingmp3.vn/bai-hat/${song.id}',
              playable: true,
            ),
          )
          .toList(growable: false),
    ),
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  await controller.playSong(_seed, queue: const [_seed]);
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
