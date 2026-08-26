import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/song_lyrics.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/music_player_screen.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/desktop_now_playing_panel.dart';
import 'package:zmp3chart/widgets/desktop_playback_queue_panel.dart';
import 'package:zmp3chart/widgets/mini_player.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile mini player keeps its compact playback surface', (
    tester,
  ) async {
    final fixture = await _fixture();
    addTearDown(fixture.controller.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in const [Size(320, 720), Size(360, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        _app(
          fixture.controller,
          const Scaffold(body: SizedBox(), bottomNavigationBar: MiniPlayer()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('desktop-playback-dock')), findsNothing);
      expect(find.byKey(const ValueKey('mobile-mini-player')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mobile-mini-progress')),
        findsOneWidget,
      );
      expect(find.text(_song.displayTitle), findsOneWidget);
      expect(find.byTooltip('Tạm dừng'), findsOneWidget);
      expect(find.byTooltip('Bài tiếp theo'), findsOneWidget);
      expect(find.byTooltip('Dừng'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'viewport $size');
    }
  });

  testWidgets('mobile mini player pauses, skips next and opens Now Playing', (
    tester,
  ) async {
    final fixture = await _fixture(queue: const [_song, _songTwo]);
    addTearDown(fixture.controller.dispose);
    await _setViewport(tester, const Size(360, 844));

    await tester.pumpWidget(
      _app(
        fixture.controller,
        const Scaffold(body: SizedBox(), bottomNavigationBar: MiniPlayer()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('mobile-mini-play-pause')));
    await tester.pump();
    expect(fixture.audio.pauseCalls, 1);

    await tester.tap(find.byKey(const ValueKey('mobile-mini-next')));
    await tester.pumpAndSettle();
    expect(fixture.controller.currentSong, _songTwo);
    expect(find.text(_songTwo.displayTitle), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-mini-open-player')));
    await tester.pumpAndSettle();
    expect(find.byType(MusicPlayerScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop dock controls playback seek volume and queue', (
    tester,
  ) async {
    final fixture = await _fixture();
    addTearDown(fixture.controller.dispose);
    await _setViewport(tester, const Size(1440, 900));
    var mvCalls = 0;
    var lyricsCalls = 0;
    final songActions = <DesktopDockSongAction>[];

    await tester.pumpWidget(
      _app(
        fixture.controller,
        Scaffold(
          body: const SizedBox(),
          bottomNavigationBar: MiniPlayer(
            desktop: true,
            onOpenMv: () => mvCalls++,
            onOpenLyrics: () => lyricsCalls++,
            onSongAction: songActions.add,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('desktop-playback-dock')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-dock-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-dock-volume')), findsOneWidget);
    expect(find.bySemanticsLabel('Âm lượng 100 phần trăm'), findsOneWidget);
    expect(find.text('0:30'), findsOneWidget);
    expect(find.text('3:00'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-mv')));
    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-lyrics')));
    expect(mvCalls, 1);
    expect(lyricsCalls, 1);

    await tester.tap(find.byKey(const ValueKey('desktop-dock-song-more')));
    await tester.pumpAndSettle();
    expect(find.text('Thông tin bài hát'), findsOneWidget);
    expect(find.text('Bắt đầu Song Radio'), findsOneWidget);
    expect(find.text('Thêm vào playlist'), findsOneWidget);
    expect(find.text('Chia sẻ liên kết'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('desktop-dock-song-action-detail')),
    );
    await tester.pumpAndSettle();
    expect(songActions, [DesktopDockSongAction.detail]);

    await tester.tap(find.byKey(const ValueKey('desktop-dock-expand-player')));
    await tester.pumpAndSettle();
    expect(find.byType(MusicPlayerScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(MusicPlayerScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('desktop-dock-play-pause')));
    await tester.pump();
    expect(fixture.audio.pauseCalls, 1);

    await tester.tap(find.byKey(const ValueKey('desktop-dock-mute')));
    await tester.pump();
    expect(fixture.controller.isMuted, isTrue);
    expect(fixture.audio.volumeValues.last, 0);

    await tester.tap(find.byKey(const ValueKey('desktop-dock-mute')));
    await tester.pump();
    expect(fixture.controller.isMuted, isFalse);
    expect(fixture.audio.volumeValues.last, 1);

    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-queue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MusicPlayerScreen), findsOneWidget);
  });

  testWidgets(
    'desktop dock and player panel stay adaptive at wide breakpoints',
    (tester) async {
      for (final size in const [Size(1100, 760), Size(1440, 900)]) {
        await _setViewport(tester, size, registerTearDown: false);
        final fixture = await _fixture();

        await tester.pumpWidget(
          _app(
            fixture.controller,
            Scaffold(
              body: Row(
                children: [
                  const Expanded(child: SizedBox()),
                  SizedBox(
                    width: size.width >= 1400 ? 380 : 340,
                    child: const DesktopNowPlayingPanel(),
                  ),
                ],
              ),
              bottomNavigationBar: const MiniPlayer(desktop: true),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const ValueKey('desktop-player-volume')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('desktop-dock-volume')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('desktop-dock-open-mv')),
          size.width >= 1400 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('desktop-dock-open-lyrics')),
          size.width >= 1400 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('desktop-dock-song-more')),
          size.width >= 1400 ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull, reason: 'viewport $size');

        fixture.controller.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'mobile queue clears safely while the current song keeps playing',
    (tester) async {
      final audio = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.playSong(
        _songTwo,
        queue: const [_song, _songTwo, _songThree],
      );
      final playCalls = audio.playedSources.length;
      final stopCalls = audio.stopCalls;
      await _setViewport(tester, const Size(360, 844));

      await tester.pumpWidget(_app(controller, const MusicPlayerScreen()));
      await tester.pumpAndSettle();
      final openQueue = find.byKey(const ValueKey('open-playback-queue'));
      await tester.ensureVisible(openQueue);
      await tester.pumpAndSettle();
      await tester.tap(openQueue);
      await tester.pumpAndSettle();

      expect(find.text('Đang phát từ #zingChart'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mobile-clear-playback-queue')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('mobile-clear-playback-queue')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('clear-playback-queue-dialog')),
        findsOneWidget,
      );
      expect(find.textContaining('xóa 2 bài'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('confirm-clear-playback-queue')),
      );
      await tester.pumpAndSettle();

      expect(controller.queue, const [_songTwo]);
      expect(controller.currentSong, _songTwo);
      expect(audio.playedSources, hasLength(playCalls));
      expect(audio.stopCalls, stopCalls);
      expect(
        find.byKey(const ValueKey('mobile-clear-playback-queue')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TV queue makes cancel the safe default before clearing', (
    tester,
  ) async {
    final audio = FakePlaybackAudioPlayer();
    final controller = PlaybackService(
      playbackAudioPlayer: audio,
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.playSong(
      _song,
      queue: const [_song, _songTwo, _songThree],
    );
    await _setViewport(tester, const Size(1920, 1080));

    await tester.pumpWidget(
      _app(
        controller,
        const Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: DesktopNowPlayingPanel(tvMode: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final clearButton = find.byKey(const ValueKey('tv-clear-playback-queue'));
    await tester.ensureVisible(clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    final cancel = find.byKey(const ValueKey('cancel-clear-playback-queue'));
    expect(tester.widget<TextButton>(cancel).autofocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.queue, const [_song, _songTwo, _songThree]);

    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-clear-playback-queue')),
    );
    await tester.pumpAndSettle();
    expect(controller.queue, const [_song]);
    expect(controller.currentSong, _song);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop queue drawer keeps the dock visible and exposes local history',
    (tester) async {
      final audio = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.playSong(
        _song,
        queue: const [_song, _songTwo, _songThree],
      );
      audio.emitDuration(const Duration(minutes: 3));
      var lyricsCalls = 0;
      Future<SongLyrics> loadLyrics(String code) async {
        lyricsCalls++;
        return SongLyrics(
          songId: code,
          synced: true,
          lines: const [
            LyricLine(
              start: Duration.zero,
              end: Duration(seconds: 10),
              text: 'Dòng đầu đang hát',
            ),
            LyricLine(
              start: Duration(seconds: 10),
              end: Duration(seconds: 30),
              text: 'Dòng tiếp theo để tua',
            ),
          ],
        );
      }

      for (final size in const [Size(1100, 760), Size(1440, 900)]) {
        await _setViewport(tester, size, registerTearDown: false);
        await tester.pumpWidget(
          _app(
            controller,
            Scaffold(
              body: Row(
                children: [
                  const Expanded(child: SizedBox()),
                  DesktopPlaybackQueuePanel(
                    onClose: () {},
                    lyricsLoader: loadLyrics,
                  ),
                ],
              ),
              bottomNavigationBar: const MiniPlayer(desktop: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('desktop-playback-queue-panel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('desktop-playback-dock')),
          findsOneWidget,
        );
        expect(find.text('TRÌNH PHÁT'), findsOneWidget);
        expect(find.text('Hàng đợi'), findsOneWidget);
        expect(find.text('Gần đây'), findsOneWidget);
        expect(find.text('Lời bài hát'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('desktop-queue-tab-lyrics')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('desktop-embedded-lyrics')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull, reason: 'viewport $size');

        await tester.tap(
          find.byKey(const ValueKey('desktop-queue-tab-playing')),
        );
        await tester.pumpAndSettle();
      }

      final list = tester.widget<ReorderableListView>(
        find.byKey(const ValueKey('desktop-playing-queue-list')),
      );
      list.onReorderItem!(1, 0);
      await tester.pump();
      expect(controller.upNextSongs, const [_songThree, _songTwo]);

      await tester.tap(find.byKey(const ValueKey('desktop-queue-song-three')));
      await tester.pumpAndSettle();
      expect(controller.currentSong, _songThree);
      audio.emitDuration(const Duration(minutes: 3));

      await tester.tap(find.byKey(const ValueKey('desktop-queue-tab-recent')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-recent-queue-list')),
        findsOneWidget,
      );
      expect(find.text('Lịch sử trên thiết bị'), findsOneWidget);
      expect(
        find.text('Không gửi danh sách này lên proxy hoặc dịch vụ đồng bộ.'),
        findsOneWidget,
      );
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('desktop-recent-song-three')))
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('desktop-recent-dock-song')),
              )
              .dy,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('desktop-queue-tab-lyrics')));
      await tester.pumpAndSettle();
      expect(lyricsCalls, 3);
      expect(
        find.byKey(const ValueKey('desktop-embedded-lyrics')),
        findsOneWidget,
      );
      expect(find.text('LỜI ĐỒNG BỘ'), findsOneWidget);
      expect(find.text('Dòng đầu đang hát'), findsOneWidget);
      expect(find.text('Dòng tiếp theo để tua'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('desktop-expand-lyrics')),
        findsOneWidget,
      );

      final seekLine = find.text('Dòng tiếp theo để tua');
      await tester.ensureVisible(seekLine);
      await tester.pumpAndSettle();
      final seekAction = tester
          .widget<InkWell>(
            find.ancestor(of: seekLine, matching: find.byType(InkWell)).first,
          )
          .onTap;
      expect(seekAction, isNotNull);
      seekAction!();
      await tester.pumpAndSettle();
      expect(audio.seekTargets.last, const Duration(seconds: 10));

      await tester.tap(find.byKey(const ValueKey('desktop-queue-tab-playing')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-clear-playback-queue')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('desktop-clear-playback-queue')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('confirm-clear-playback-queue')),
      );
      await tester.pumpAndSettle();
      expect(controller.queue, [controller.currentSong!]);
      expect(
        find.byKey(const ValueKey('desktop-clear-playback-queue')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}

Future<_PlaybackFixture> _fixture({List<Song> queue = const [_song]}) async {
  final audio = FakePlaybackAudioPlayer();
  final controller = PlaybackService(
    playbackAudioPlayer: audio,
    sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  await controller.playSong(_song, queue: queue);
  audio.emitDuration(const Duration(minutes: 3));
  audio.emitPosition(const Duration(seconds: 30));
  return _PlaybackFixture(controller, audio);
}

Future<void> _setViewport(
  WidgetTester tester,
  Size size, {
  bool registerTearDown = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  if (registerTearDown) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
}

Widget _app(PlaybackService controller, Widget home) => MusicPlayerScope(
  controller: controller,
  child: MaterialApp(theme: buildZingDarkTheme(tvMode: false), home: home),
);

const _song = Song(
  id: 'dock-song',
  name: 'dock-song',
  title: 'Bài Hát Trong Dock',
  thumbnail: '',
  artistsNames: 'Nghệ Sĩ Dock',
  code: 'dock-code',
);

const _songTwo = Song(
  id: 'song-two',
  name: 'song-two',
  title: 'Bài Hát Thứ Hai',
  thumbnail: '',
  artistsNames: 'Nghệ Sĩ Hai',
  code: 'song-two-code',
);

const _songThree = Song(
  id: 'song-three',
  name: 'song-three',
  title: 'Bài Hát Thứ Ba',
  thumbnail: '',
  artistsNames: 'Nghệ Sĩ Ba',
  code: 'song-three-code',
);

class _PlaybackFixture {
  const _PlaybackFixture(this.controller, this.audio);

  final PlaybackService controller;
  final FakePlaybackAudioPlayer audio;
}
