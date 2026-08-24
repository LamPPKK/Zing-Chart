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
import 'package:zmp3chart/widgets/song_lyrics_panel.dart';
import 'package:zmp3chart/widgets/desktop_now_playing_panel.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const firstSong = Song(
    id: 'song-one',
    name: 'song-one',
    title: 'Bài hát đầu tiên',
    thumbnail: '',
    artistsNames: 'Nghệ sĩ A',
    code: 'code-one',
  );
  const secondSong = Song(
    id: 'song-two',
    name: 'song-two',
    title: 'Bài hát tiếp theo',
    thumbnail: '',
    artistsNames: 'Nghệ sĩ B',
    code: 'code-two',
  );
  const firstLyrics = SongLyrics(
    songId: 'code-one',
    synced: true,
    lines: [
      LyricLine(
        start: Duration(seconds: 1),
        end: Duration(seconds: 2),
        text: 'Dòng thứ nhất',
        words: [
          LyricWord(
            start: Duration(milliseconds: 1000),
            end: Duration(milliseconds: 1300),
            text: 'Dòng',
          ),
          LyricWord(
            start: Duration(milliseconds: 1300),
            end: Duration(milliseconds: 1600),
            text: 'thứ',
          ),
          LyricWord(
            start: Duration(milliseconds: 1600),
            end: Duration(milliseconds: 2000),
            text: 'nhất',
          ),
        ],
      ),
      LyricLine(
        start: Duration(seconds: 2),
        end: Duration(seconds: 4),
        text: 'Dòng thứ hai',
        words: [
          LyricWord(
            start: Duration(milliseconds: 2000),
            end: Duration(milliseconds: 2400),
            text: 'Dòng',
          ),
          LyricWord(
            start: Duration(milliseconds: 2400),
            end: Duration(milliseconds: 2800),
            text: 'thứ',
          ),
          LyricWord(
            start: Duration(milliseconds: 2800),
            end: Duration(milliseconds: 4000),
            text: 'hai',
          ),
        ],
      ),
      LyricLine(
        start: Duration(seconds: 5),
        end: Duration(seconds: 7),
        text: 'Dòng thứ ba',
      ),
    ],
  );

  test('finds the active synchronized line with stable boundaries', () {
    expect(firstLyrics.activeLineIndex(Duration.zero), -1);
    expect(firstLyrics.activeLineIndex(const Duration(seconds: 1)), 0);
    expect(firstLyrics.activeLineIndex(const Duration(milliseconds: 2500)), 1);
    expect(firstLyrics.wordSynced, isTrue);
    expect(
      firstLyrics.lines[1].activeWordIndex(const Duration(milliseconds: 2500)),
      1,
    );
    expect(firstLyrics.lines[1].activeWordIndex(Duration.zero), -1);
    expect(
      firstLyrics.lines[1].activeWordIndex(const Duration(seconds: 4)),
      -1,
    );
    expect(firstLyrics.activeLineIndex(const Duration(milliseconds: 4500)), -1);
    expect(firstLyrics.activeLineIndex(const Duration(seconds: 7)), -1);
    expect(firstLyrics.activeLineIndex(const Duration(seconds: 9)), -1);
    expect(const SongLyrics.empty('empty').activeLineIndex(Duration.zero), -1);
  });

  testWidgets(
    'switches to immersive Karaoke and follows word timing',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = FakePlaybackAudioPlayer();
      final controller = await _controller(audio);
      addTearDown(controller.dispose);
      await controller.playSong(firstSong);
      audio.emitDuration(const Duration(minutes: 3));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SongLyricsPanel(
              controller: controller,
              lyricsLoader: (_) async => firstLyrics,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('song-karaoke-stage')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('lyrics-mode-karaoke')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('song-karaoke-stage')), findsOneWidget);
      expect(find.text('KARAOKE · CHẠY THEO TỪ'), findsOneWidget);

      audio.emitPosition(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp(r'Đang hát:\s*Dòng thứ hai')),
        findsOneWidget,
      );
      final currentLine = find.byKey(const ValueKey('karaoke-line-1'));
      final richText = tester.widget<Text>(
        find.descendant(of: currentLine, matching: find.byType(Text)).first,
      );
      final spans = (richText.textSpan! as TextSpan).children!;
      expect((spans[0] as TextSpan).text, 'Dòng');
      expect((spans[0] as TextSpan).style?.color, const Color(0xFFB8F43D));
      expect((spans[2] as TextSpan).text, 'thứ');
      expect((spans[2] as TextSpan).style?.color, const Color(0xFFFF6B4A));
      tester.semantics.tap(
        find.semantics.byLabel(RegExp(r'Đang hát:\s*Dòng thứ hai')),
      );
      await _pumpUntil(tester, () => audio.seekTargets.isNotEmpty);
      expect(audio.seekTargets.last, const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
    semanticsEnabled: true,
  );

  testWidgets('opens synced lyrics, seeks a line, and follows song changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = await _controller(audio);
    addTearDown(controller.dispose);
    await controller.playSong(firstSong, queue: const [firstSong, secondSong]);
    audio.emitDuration(const Duration(minutes: 3));

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: MusicPlayerScreen(
            lyricsLoader: (code) async => code == 'code-one'
                ? firstLyrics
                : const SongLyrics(
                    songId: 'code-two',
                    synced: false,
                    lines: [
                      LyricLine(
                        start: Duration.zero,
                        end: Duration.zero,
                        text: 'Lời của bài tiếp theo',
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final openButton = find.byKey(const ValueKey('open-song-lyrics'));
    await tester.ensureVisible(openButton);
    await tester.tap(openButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('song-lyrics-panel')), findsOneWidget);
    expect(find.text('Dòng thứ nhất'), findsOneWidget);

    audio.emitPosition(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(r'Đang hát:\s*Dòng thứ hai')),
      findsOneWidget,
    );

    final thirdLine = find.text('Dòng thứ ba');
    final thirdLineButton = find
        .ancestor(of: thirdLine, matching: find.byType(InkWell))
        .first;
    await tester.ensureVisible(thirdLineButton);
    await tester.pumpAndSettle();
    await tester.tap(thirdLineButton);
    await tester.pumpAndSettle();
    expect(audio.seekTargets.last, const Duration(seconds: 5));

    await controller.playSong(secondSong, queue: const [firstSong, secondSong]);
    await tester.pumpAndSettle();
    expect(find.text('Bài hát tiếp theo'), findsWidgets);
    expect(find.text('Lời của bài tiếp theo'), findsOneWidget);
    expect(find.text('Dòng thứ nhất'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recovers from lyric errors and renders the empty state', (
    tester,
  ) async {
    final controller = await _controller(FakePlaybackAudioPlayer());
    addTearDown(controller.dispose);
    await controller.playSong(firstSong);
    var attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SongLyricsPanel(
            controller: controller,
            lyricsLoader: (_) async {
              attempts++;
              if (attempts == 1) throw Exception('proxy tạm thời gián đoạn');
              return const SongLyrics.empty('code-one');
            },
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('song-lyrics-error')), findsOneWidget);
    expect(find.textContaining('proxy tạm thời gián đoạn'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byKey(const ValueKey('song-lyrics-empty')), findsOneWidget);
  });

  testWidgets('labels plain lyrics honestly and disables seek guidance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(FakePlaybackAudioPlayer());
    addTearDown(controller.dispose);
    await controller.playSong(firstSong);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SongLyricsPanel(
            controller: controller,
            lyricsLoader: (_) async => const SongLyrics(
              songId: 'code-one',
              synced: false,
              lines: [
                LyricLine(
                  start: Duration.zero,
                  end: Duration.zero,
                  text: 'Đây là lời tĩnh',
                ),
              ],
            ),
            initialKaraoke: true,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#zingChart · LỜI TĨNH'), findsOneWidget);
    expect(find.text('KARAOKE · LỜI TĨNH'), findsOneWidget);
    expect(find.text('Lời tĩnh không hỗ trợ chạm để tua'), findsOneWidget);
    expect(find.textContaining('CHẠY THEO DÒNG'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls valid long Karaoke lines instead of overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = await _controller(audio);
    addTearDown(controller.dispose);
    await controller.playSong(firstSong);
    audio.emitDuration(const Duration(minutes: 3));
    audio.emitPosition(const Duration(milliseconds: 2500));
    final longText = List.filled(100, 'nhạc').join(' ');
    final lyrics = SongLyrics(
      songId: 'code-one',
      synced: true,
      lines: [
        LyricLine(
          start: Duration.zero,
          end: const Duration(seconds: 2),
          text: longText,
        ),
        LyricLine(
          start: const Duration(seconds: 2),
          end: const Duration(seconds: 4),
          text: longText,
        ),
        LyricLine(
          start: const Duration(seconds: 5),
          end: const Duration(seconds: 7),
          text: longText,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SongLyricsPanel(
            controller: controller,
            lyricsLoader: (_) async => lyrics,
            initialKaraoke: true,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('song-karaoke-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps TV focus on a lyric when it becomes current', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = await _controller(audio);
    addTearDown(controller.dispose);
    await controller.playSong(firstSong);
    audio.emitDuration(const Duration(minutes: 3));
    audio.emitPosition(const Duration(milliseconds: 2500));
    final tvLyrics = SongLyrics(
      songId: 'code-one',
      synced: true,
      lines: List.generate(
        5,
        (index) => LyricLine(
          start: Duration(seconds: index * 2),
          end: Duration(seconds: index * 2 + 2),
          text: 'Dòng TV ${index + 1}',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SongLyricsPanel(
            controller: controller,
            lyricsLoader: (_) async => tvLyrics,
            tvMode: true,
            initialKaraoke: true,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final thirdLine = find.byKey(const ValueKey('karaoke-line-2'));
    final lineFocus = tester
        .widgetList<Focus>(
          find.descendant(of: thirdLine, matching: find.byType(Focus)),
        )
        .firstWhere((focus) => focus.focusNode?.debugLabel == 'Karaoke line 2');
    lineFocus.focusNode!.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(lineFocus.focusNode));

    audio.emitPosition(const Duration(milliseconds: 4500));
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(lineFocus.focusNode));
    expect(
      find.bySemanticsLabel(RegExp(r'Đang hát:\s*Dòng TV 3')),
      findsOneWidget,
    );

    audio.emitPosition(const Duration(milliseconds: 8500));
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Karaoke line 4');
    expect(
      find.bySemanticsLabel(RegExp(r'Đang hát:\s*Dòng TV 5')),
      findsOneWidget,
    );

    expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isTrue);
    await _pumpUntil(tester, () => audio.seekTargets.isNotEmpty);
    expect(audio.seekTargets.last, const Duration(seconds: 8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens lyrics from the desktop Now Playing panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _controller(FakePlaybackAudioPlayer());
    addTearDown(controller.dispose);
    await controller.playSong(firstSong);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: DesktopNowPlayingPanel(
                lyricsLoader: (_) async => firstLyrics,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('desktop-open-song-lyrics')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byKey(const ValueKey('song-lyrics-panel')), findsOneWidget);
    expect(find.text('Dòng thứ nhất'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto-scrolls to a synchronized line that was not built yet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = await _controller(audio);
    addTearDown(controller.dispose);
    await controller.playSong(firstSong);
    audio.emitDuration(const Duration(minutes: 5));
    final longLyrics = SongLyrics(
      songId: 'code-one',
      synced: true,
      lines: List.generate(
        120,
        (index) => LyricLine(
          start: Duration(seconds: index * 2),
          end: Duration(seconds: index * 2 + 2),
          text: 'Câu $index',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: SongLyricsPanel(
            controller: controller,
            lyricsLoader: (_) async => longLyrics,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Câu 90'), findsNothing);

    audio.emitPosition(const Duration(minutes: 3));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('song-lyrics-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, greaterThan(1000));
    expect(find.text('Câu 90'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Đang hát:\s*Câu 90')),
      findsOneWidget,
    );
  });

  for (final viewport in const [
    (size: Size(1440, 900), tvMode: false),
    (size: Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'lyrics remain focusable without overflow at ${viewport.size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = await _controller(FakePlaybackAudioPlayer());
        addTearDown(controller.dispose);
        await controller.playSong(firstSong);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: SongLyricsPanel(
                controller: controller,
                lyricsLoader: (_) async => firstLyrics,
                tvMode: viewport.tvMode,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(find.byKey(const ValueKey('song-lyrics-list')), findsOneWidget);
        expect(FocusManager.instance.primaryFocus, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final viewport in const [
    (size: Size(360, 844), tvMode: false),
    (size: Size(768, 1024), tvMode: false),
    (size: Size(1440, 900), tvMode: false),
    (size: Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'Karaoke remains adaptive at ${viewport.size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final audio = FakePlaybackAudioPlayer();
        final controller = await _controller(audio);
        addTearDown(controller.dispose);
        await controller.playSong(firstSong);
        audio.emitDuration(const Duration(minutes: 3));
        audio.emitPosition(const Duration(milliseconds: 2500));

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: SongLyricsPanel(
                controller: controller,
                lyricsLoader: (_) async => firstLyrics,
                tvMode: viewport.tvMode,
                initialKaraoke: true,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        expect(
          find.byKey(const ValueKey('song-karaoke-stage')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(r'Đang hát:\s*Dòng thứ hai')),
          findsOneWidget,
        );
        expect(FocusManager.instance.primaryFocus, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<PlaybackService> _controller(FakePlaybackAudioPlayer audio) async {
  final controller = PlaybackService(
    playbackAudioPlayer: audio,
    sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  return controller;
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 50 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}
