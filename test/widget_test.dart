import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/zing_chart_screen.dart';
import 'package:zmp3chart/zing_mp3_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    for (final channelName in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            MethodChannel(channelName),
            (_) async => null,
          );
    }
  });

  const songs = [
    Song(
      id: 'one',
      name: 'mot-bai-hat',
      title: 'Một Bài Hát',
      thumbnail: '',
      artistsNames: 'Ca Sĩ A',
      code: 'code-one',
    ),
    Song(
      id: 'two',
      name: 'nang-tho',
      title: 'Nàng Thơ',
      thumbnail: '',
      artistsNames: 'Hoàng Dũng',
      code: 'code-two',
    ),
  ];

  group('Song model', () {
    test('parses the Zing Chart response shape', () {
      final song = Song.fromJson({
        'id': 'Z123',
        'title': 'Kẻ Say Tình',
        'thumbnail': 'https://photo.example/cover.jpg',
        'artists_names': 'Quốc Thiên',
        'code': 'source-code',
      });

      expect(song.id, 'Z123');
      expect(song.displayTitle, 'Kẻ Say Tình');
      expect(song.artistsNames, 'Quốc Thiên');
      expect(song.code, 'source-code');
    });

    test('normalizes absolute and protocol-relative media sources', () {
      expect(
        normalizeSongSource('https://a128.zmdcdn.me/song'),
        'https://a128.zmdcdn.me/song',
      );
      expect(
        normalizeSongSource('//a128.zmdcdn.me/song'),
        'https://a128.zmdcdn.me/song',
      );
      expect(
        normalizeSongSource('http://a128.zmdcdn.me/song'),
        'https://a128.zmdcdn.me/song',
      );
    });
  });

  group('Chart filtering', () {
    test('matches title and artist without case sensitivity', () {
      expect(filterSongs(songs, 'nàng'), [songs[1]]);
      expect(filterSongs(songs, 'CA SĨ A'), [songs[0]]);
      expect(filterSongs(songs, 'không có'), isEmpty);
    });
  });

  group('Spotify-inspired library and queue', () {
    test('manages liked songs, queue, shuffle and repeat modes', () {
      final controller = MusicPlayerController(
        libraryRepository: MemoryLibraryRepository(),
      );

      controller.toggleLike(songs[0]);
      expect(controller.isLiked(songs[0]), isTrue);
      expect(controller.likedSongs, [songs[0]]);

      controller.addToQueue(songs[0]);
      controller.addToQueue(songs[1]);
      controller.addToQueue(songs[1]);
      expect(controller.queue, songs);

      controller.toggleShuffle();
      expect(controller.shuffleEnabled, isTrue);

      controller.cycleRepeatMode();
      expect(controller.repeatMode, PlayerRepeatMode.all);
      controller.cycleRepeatMode();
      expect(controller.repeatMode, PlayerRepeatMode.one);
    });

    test(
      'restores the local library, queue and playback preferences',
      () async {
        final repository = MemoryLibraryRepository(
          PlayerSnapshot(
            likedSongs: [songs.first],
            queue: songs,
            currentSong: songs.first,
            currentIndex: 0,
            position: Duration(seconds: 24),
            shuffleEnabled: true,
            repeatModeIndex: 2,
          ),
        );
        final controller = MusicPlayerController(
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );

        await controller.initialize();

        expect(controller.likedSongs, [songs.first]);
        expect(controller.queue, songs);
        expect(controller.currentSong, songs.first);
        expect(controller.position, const Duration(seconds: 24));
        expect(controller.shuffleEnabled, isTrue);
        expect(controller.repeatMode, PlayerRepeatMode.one);
        controller.dispose();
      },
    );
  });

  testWidgets('renders chart songs and filters from the search bar', (
    tester,
  ) async {
    final controller = MusicPlayerController(
      sourceResolver: (_) async => 'https://example.com/song.mp3',
      libraryRepository: MemoryLibraryRepository(),
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(loadSongs: () async => songs),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Một Bài Hát'), findsOneWidget);
    expect(find.text('Nàng Thơ'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('chart-search-field')),
      'Hoàng Dũng',
    );
    await tester.pump();

    expect(find.text('Một Bài Hát'), findsNothing);
    expect(find.text('Nàng Thơ'), findsOneWidget);
    expect(find.text('1 bài hát'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Thư viện'), findsWidgets);
    expect(find.text('1 BÀI THÍCH · 0 PLAYLIST'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Nàng Thơ'),
      280,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Nàng Thơ'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('switches to desktop navigation at wide widths', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MusicPlayerController(
      libraryRepository: MemoryLibraryRepository(),
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(loadSongs: () async => songs),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Chọn một bài để bắt đầu'), findsOneWidget);
    controller.dispose();
  });

  for (final width in [360.0, 768.0, 1440.0]) {
    testWidgets('renders without overflow at ${width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MusicPlayerController(
        libraryRepository: MemoryLibraryRepository(),
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(loadSongs: () async => songs),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byType(width >= 720 ? NavigationRail : NavigationBar),
        findsOneWidget,
      );
      controller.dispose();
    });
  }
}
