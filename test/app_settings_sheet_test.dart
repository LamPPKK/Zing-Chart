import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/song_radio.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/music_player_screen.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/app_settings_sheet.dart';
import 'package:zmp3chart/widgets/streaming_quality_controls.dart';
import 'package:zmp3chart/zing_chart_screen.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const song = Song(
    id: 'fullscreen-song',
    name: 'bai-toan-man-hinh',
    title: 'Bài Toàn Màn Hình',
    thumbnail: '',
    artistsNames: 'Nghệ Sĩ',
    code: 'fullscreen-code',
  );

  testWidgets('settings panel is adaptive without overflow', (tester) async {
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
      final controller = await _controller();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildZingDarkTheme(tvMode: size.width >= 1800),
          home: Scaffold(
            body: AppSettingsPanel(
              controller: controller,
              tvMode: size.width >= 1800,
              showFullscreenPlayerPreference:
                  size.width >= 1100 && size.width < 1800,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('app-settings-panel')), findsOneWidget);
      expect(find.text('Tùy chỉnh #zingChart'), findsOneWidget);
      if (size.width == 1440) {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-fullscreen-player')),
          240,
          scrollable: find.byType(Scrollable).last,
        );
        expect(
          find.byKey(const ValueKey('settings-fullscreen-player')),
          findsOneWidget,
        );
      }
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('quality-option-auto')),
        320,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byKey(const ValueKey('quality-option-128')), findsOneWidget);
      expect(find.byKey(const ValueKey('quality-option-320')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Dữ liệu thuộc về bạn'),
        400,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Dữ liệu thuộc về bạn'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'viewport $size');

      if (size.width >= 1800) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, isNotNull);
      }

      controller.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('streaming quality selector supports TV focus and Enter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    final controller = await _controller();
    controller.setStreamingQualityPreference(
      StreamingQualityPreference.standard,
    );
    addTearDown(() {
      controller.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildZingDarkTheme(tvMode: true),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 720,
              child: StreamingQualitySelector(controller: controller),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(
      controller.streamingQualityPreference,
      StreamingQualityPreference.automatic,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Now Playing recovers a failed 320 source with one-tap Auto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    final audio = FakePlaybackAudioPlayer();
    final requested = <StreamingQualityPreference>[];
    final controller = PlaybackService(
      playbackAudioPlayer: audio,
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      qualitySourceResolver: (code, quality) async {
        requested.add(quality);
        if (quality == StreamingQualityPreference.high) {
          throw StateError('Nguồn 320 kbps không khả dụng');
        }
        return 'https://audio.example.com/${quality.apiValue}/$code.mp3';
      },
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    controller.setStreamingQualityPreference(StreamingQualityPreference.high);
    await controller.playSong(song, queue: const [song]);
    addTearDown(() {
      controller.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: buildZingDarkTheme(tvMode: false),
          home: const MusicPlayerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('playback-error-retry')), findsOneWidget);
    final useAuto = find.byKey(const ValueKey('playback-error-use-auto'));
    expect(useAuto, findsOneWidget);
    expect(find.textContaining('không khả dụng'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(useAuto);
    await tester.tap(useAuto);
    await tester.pumpAndSettle();

    expect(requested, [
      StreamingQualityPreference.high,
      StreamingQualityPreference.automatic,
    ]);
    expect(
      controller.streamingQualityPreference,
      StreamingQualityPreference.automatic,
    );
    expect(controller.currentSong, song);
    expect(controller.errorMessage, isNull);
    expect(controller.isPlaying, isTrue);
    expect(audio.playedSources, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV can focus and activate the playback Auto recovery action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      qualitySourceResolver: (code, quality) async {
        if (quality == StreamingQualityPreference.high) {
          throw StateError('Nguồn 320 kbps không khả dụng');
        }
        return 'https://audio.example.com/${quality.apiValue}/$code.mp3';
      },
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    controller.setStreamingQualityPreference(StreamingQualityPreference.high);
    await controller.playSong(song, queue: const [song]);
    addTearDown(() {
      controller.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: buildZingDarkTheme(tvMode: true),
          home: const MusicPlayerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final useAuto = find.byKey(const ValueKey('playback-error-use-auto'));
    expect(useAuto, findsOneWidget);
    for (var step = 0; step < 30 && !_focusIsWithin(useAuto); step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(_focusIsWithin(useAuto), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      controller.streamingQualityPreference,
      StreamingQualityPreference.automatic,
    );
    expect(controller.isPlaying, isTrue);
    expect(controller.errorMessage, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings controls update real playback preferences', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    final controller = await _controller();
    addTearDown(() {
      controller.cancelSleepTimer();
      controller.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(body: AppSettingsPanel(controller: controller)),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('settings-theme-dark')));
    await tester.pump();
    expect(controller.themePreference, AppThemePreference.dark);

    await tester.tap(find.byKey(const ValueKey('settings-shuffle')));
    await tester.pump();
    expect(controller.shuffleEnabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('settings-repeat-one')));
    await tester.pump();
    expect(controller.repeatMode, PlayerRepeatMode.one);

    expect(controller.autoplayRecommendationsEnabled, isTrue);
    await tester.tap(find.byKey(const ValueKey('settings-autoplay')));
    await tester.pump();
    expect(controller.autoplayRecommendationsEnabled, isFalse);

    final carModeSwitch = find.byKey(const ValueKey('settings-car-mode'));
    await tester.ensureVisible(carModeSwitch);
    await tester.pumpAndSettle();
    await tester.tap(carModeSwitch);
    await tester.pump();
    expect(controller.carModeEnabled, isTrue);

    final sleepButton = find.byKey(const ValueKey('settings-sleep-15'));
    await tester.ensureVisible(sleepButton);
    await tester.pumpAndSettle();
    await tester.tap(sleepButton);
    await tester.pump();
    expect(controller.hasSleepTimer, isTrue);
    expect(controller.sleepTimerRemaining, isNotNull);

    final cancelButton = find.byKey(const ValueKey('settings-sleep-cancel'));
    await tester.ensureVisible(cancelButton);
    await tester.pumpAndSettle();
    await tester.tap(cancelButton);
    await tester.pump();
    expect(controller.hasSleepTimer, isFalse);

    final quality320 = find.byKey(const ValueKey('quality-option-320'));
    await tester.scrollUntilVisible(
      quality320,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(quality320);
    await tester.pump();
    expect(
      controller.streamingQualityPreference,
      StreamingQualityPreference.high,
    );
  });

  testWidgets('desktop header opens and closes the adaptive settings dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    final controller = await _controller();
    addTearDown(() {
      controller.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadSongs: () async => const [song],
            loadDiscoveryHome: () async => const DiscoveryHome.empty(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      MediaQuery.sizeOf(tester.element(find.byType(ZingChartScreen))).width,
      1440,
    );
    expect(find.byTooltip('Cài đặt'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-app-settings')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byKey(const ValueKey('app-settings-panel')), findsOneWidget);
    expect(
      tester
          .widget<AppSettingsPanel>(find.byType(AppSettingsPanel))
          .showFullscreenPlayerPreference,
      isTrue,
    );
    final fullscreenSwitch = find.byKey(
      const ValueKey('settings-fullscreen-player'),
    );
    await tester.scrollUntilVisible(
      fullscreenSwitch,
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(fullscreenSwitch);
    await tester.pump();
    expect(controller.alwaysOpenFullscreenPlayer, isTrue);
    await tester.tap(find.byKey(const ValueKey('settings-close')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.text(song.displayTitle));
    await tester.pumpAndSettle();
    expect(find.byType(MusicPlayerScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-streaming-quality')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('streaming-quality-picker')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('quality-option-128')));
    await tester.pumpAndSettle();
    expect(
      controller.streamingQualityPreference,
      StreamingQualityPreference.standard,
    );
  });
}

Future<PlaybackService> _controller() async {
  final controller = PlaybackService(
    playbackAudioPlayer: FakePlaybackAudioPlayer(),
    sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
    songRadioLoader: (code) async => SongRadio.empty(code),
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  return controller;
}

bool _focusIsWithin(Finder finder) {
  final root = finder.evaluate().single;
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  if (identical(context, root)) return true;
  var inside = false;
  context.visitAncestorElements((ancestor) {
    inside = identical(ancestor, root);
    return !inside;
  });
  return inside;
}
