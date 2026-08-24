import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/data/listening_analytics_repository.dart';
import 'package:zmp3chart/models/chart_snapshot.dart';
import 'package:zmp3chart/models/catalog_artist_detail.dart';
import 'package:zmp3chart/models/catalog_hub.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/live_radio.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/listening_analytics.dart';
import 'package:zmp3chart/models/new_release_chart.dart';
import 'package:zmp3chart/models/release_catalog.dart';
import 'package:zmp3chart/models/search_suggestions.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/song_detail.dart';
import 'package:zmp3chart/models/song_lyrics.dart';
import 'package:zmp3chart/models/song_radio.dart';
import 'package:zmp3chart/models/weekly_chart.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_screen.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/zing_chart_screen.dart';
import 'package:zmp3chart/widgets/discovery_home_hub.dart';
import 'package:zmp3chart/widgets/collection_detail_hero.dart';
import 'package:zmp3chart/widgets/lyric_share_composer.dart';
import 'package:zmp3chart/widgets/realtime_chart.dart';
import 'package:zmp3chart/widgets/search_discovery_summary.dart';
import 'package:zmp3chart/widgets/song_detail_panel.dart';
import 'package:zmp3chart/widgets/song_lyrics_panel.dart';
import 'package:zmp3chart/widgets/streaming_quality_controls.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  late GoldenFileComparator previousGoldenComparator;

  setUpAll(() {
    previousGoldenComparator = goldenFileComparator;
    final localComparator = previousGoldenComparator as LocalFileComparator;
    goldenFileComparator = _ChartGoldenComparator(
      localComparator.basedir.resolve('zing_chart_golden_test.dart'),
    );
  });

  tearDownAll(() => goldenFileComparator = previousGoldenComparator);

  test(
    'golden tolerance accepts runner raster drift but rejects layout drift',
    () {
      expect(_ChartGoldenComparator.acceptsDiff(0.049), isTrue);
      expect(_ChartGoldenComparator.acceptsDiff(0.051), isFalse);
    },
  );

  testWidgets('desktop client mirrors the #zingchart visual hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final snapshot = ChartSnapshot(
      songs: _songs,
      songMetadata: {
        for (var index = 0; index < _songs.length; index++)
          _songs[index].id: ChartSongMetadata(
            albumTitle: index < 4
                ? '${_songs[index].displayTitle} (Single)'
                : '',
            duration: Duration(seconds: 198 + index * 11),
            rankChange: index == 0
                ? 3
                : index == 1
                ? -1
                : 0,
          ),
      },
      series: {
        for (var songIndex = 0; songIndex < _songs.length; songIndex++)
          _songs[songIndex].id: [
            for (var hour = 0; hour < 8; hour++)
              ChartPoint(
                time: DateTime(2026, 8, 20, hour * 3),
                hour: (hour * 3).toString().padLeft(2, '0'),
                counter:
                    28 + songIndex * 12 + ((hour * 17 + songIndex * 11) % 45),
              ),
          ],
      },
      maxScore: 100,
      updatedAt: DateTime(2026, 8, 20, 21),
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => snapshot,
            loadChartSuggestion: () async => _chartSuggestion,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('realtime-chart')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('artist-link-chart-suggestion-artist-vu')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('song-album-link-suggested')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/zing_chart_desktop_1440.png'),
    );
  });

  testWidgets('mobile client keeps the five-destination Zing hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            chartRefreshInterval: null,
            loadChart: () async => ChartSnapshot(
              songs: _songs,
              songMetadata: const {
                'one': ChartSongMetadata(
                  albumTitle: 'Kẻ Say Tình 2 (Single)',
                  duration: Duration(minutes: 4, seconds: 2),
                  rankChange: 3,
                ),
                'two': ChartSongMetadata(
                  albumTitle: 'Thiên Đường Với Người Thương (Single)',
                  duration: Duration(minutes: 3, seconds: 48),
                  rankChange: -1,
                ),
                'three': ChartSongMetadata(
                  albumTitle: 'Giá Như Anh Là Em (Single)',
                  duration: Duration(minutes: 3, seconds: 35),
                ),
              },
              updatedAt: DateTime(2026, 8, 24, 2),
            ),
            loadChartSuggestion: () async => _chartSuggestion,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navigation = tester.widget<NavigationBar>(
      find.byKey(const ValueKey('mobile-primary-navigation')),
    );
    expect(navigation.selectedIndex, 2);
    expect(navigation.destinations, hasLength(5));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/mobile_primary_navigation_360.png'),
    );
  });

  testWidgets('mobile mini player stays compact above Zing navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = PlaybackService(
      playbackAudioPlayer: audio,
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    await controller.playSong(_songOne, queue: _songs);
    audio
      ..emitDuration(const Duration(minutes: 4, seconds: 2))
      ..emitPosition(const Duration(minutes: 1, seconds: 18));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            chartRefreshInterval: null,
            loadChart: () async => ChartSnapshot(
              songs: _songs,
              updatedAt: DateTime(2026, 8, 24, 2),
            ),
            loadChartSuggestion: () async => _chartSuggestion,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-mini-player')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-mini-next')), findsOneWidget);
    expect(find.byTooltip('Dừng'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/mobile_mini_player_360.png'),
    );
  });

  testWidgets('desktop playback keeps the Zing-style dock in the catalog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    await controller.playSong(_songs.first, queue: _songs);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => ChartSnapshot(songs: _songs),
            initialDesktopQueueVisible: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('desktop-playback-dock')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-close-player-panel')),
      findsOneWidget,
    );
    expect(find.text('TRÌNH PHÁT'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/desktop_playback_dock_1440.png'),
    );
  });

  testWidgets(
    'desktop catalog keeps synchronized lyrics in the player drawer',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        analyticsRepository: MemoryListeningAnalyticsRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      await controller.playSong(_songOne, queue: _songs);
      audio
        ..emitDuration(const Duration(minutes: 3))
        ..emitPosition(const Duration(seconds: 38));
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildZingDarkTheme(tvMode: false),
            home: ZingChartScreen(
              loadChart: () async => ChartSnapshot(songs: _songs),
              lyricsLoader: (_) async => _lyrics,
              initialDesktopQueueVisible: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('desktop-queue-tab-lyrics')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('desktop-embedded-lyrics')),
        findsOneWidget,
      );
      expect(find.text('Và hát cho đêm nay sáng lên'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('desktop-playback-dock')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/desktop_lyrics_drawer_1440.png'),
      );
    },
  );

  testWidgets('desktop library mirrors the Zing collection workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 8, 21, 12);
    const artist = CatalogArtist(
      id: 'golden-library-artist',
      name: 'Mây Lang Thang',
      aliasName: 'May-Lang-Thang',
      avatar: '',
    );
    const album = CatalogCollection(
      id: 'golden-library-album',
      title: 'Mùa Nhớ',
      artist: 'Mây Lang Thang',
      thumbnail: '',
      kind: CatalogCollectionKind.album,
      externalUrl: '',
    );
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(
        PlayerSnapshot(
          likedSongs: _songs.take(4).toList(growable: false),
          followedArtists: const [artist],
          savedCollections: const [album],
          playlists: [
            LocalPlaylist(
              id: 'golden-library-playlist',
              name: 'Chill cuối ngày',
              createdAt: now.subtract(const Duration(days: 14)),
              updatedAt: now,
              songs: _songs.take(4).toList(growable: false),
            ),
          ],
        ),
      ),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(initialTab: 4, loadSongs: () async => _songs),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library-section-tabs')), findsOneWidget);
    expect(find.text('TỔNG QUAN'), findsOneWidget);
    expect(find.text('Mix của bạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/library_workspace_desktop_1440.png'),
    );
  });

  testWidgets('interactive 24-hour chart exposes the active Zing point', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const chartHours = [0, 1, 3, 6, 9, 12, 18, 21];
    final snapshot = ChartSnapshot(
      songs: _songs.take(3).toList(growable: false),
      series: {
        for (var songIndex = 0; songIndex < 3; songIndex++)
          _songs[songIndex].id: [
            for (
              var pointIndex = 0;
              pointIndex < chartHours.length;
              pointIndex++
            )
              ChartPoint(
                time: DateTime(2026, 8, 21, chartHours[pointIndex]),
                hour: chartHours[pointIndex].toString().padLeft(2, '0'),
                counter:
                    28 +
                    songIndex * 14 +
                    ((pointIndex * 17 + songIndex * 9) % 48),
              ),
          ],
      },
      minScore: 20,
      maxScore: 100,
      updatedAt: DateTime(2026, 8, 21, 21),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          body: Center(
            child: RealtimeChart(snapshot: snapshot, onPlay: (_, _) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final plot = find.byKey(const ValueKey('realtime-chart-plot'));
    final rect = tester.getRect(plot);
    await tester.tapAt(Offset(rect.left + rect.width * 0.58, rect.center.dy));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('realtime-chart-tooltip')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/realtime_chart_desktop_1440.png'),
    );
  });

  testWidgets('desktop chart exposes the official top 100 CTA', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final chartSongs = List<Song>.generate(
      100,
      (index) => Song(
        id: 'golden-chart-${index + 1}',
        name: 'golden-chart-${index + 1}',
        title: 'Bài Hát Trong Top ${index + 1}',
        thumbnail: '',
        artistsNames: 'Nghệ Sĩ ${index + 1}',
        code: 'golden-chart-code-${index + 1}',
      ),
      growable: false,
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(loadSongs: () async => chartSongs),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('chart-show-top-100')),
      320,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.text('Xem top 100'), findsOneWidget);
    expect(find.byKey(const ValueKey('golden-chart-11')), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/zing_chart_top_100_cta_1440.png'),
    );
  });

  testWidgets('desktop Discovery embeds a compact realtime #zingchart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 430);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const chartHours = [0, 3, 6, 9, 12, 15, 18, 21];
    final chartSongs = _songs.take(3).toList(growable: false);
    final snapshot = ChartSnapshot(
      songs: chartSongs,
      series: {
        for (var songIndex = 0; songIndex < chartSongs.length; songIndex++)
          chartSongs[songIndex].id: [
            for (var index = 0; index < chartHours.length; index++)
              ChartPoint(
                time: DateTime(2026, 8, 24, chartHours[index]),
                hour: chartHours[index].toString().padLeft(2, '0'),
                counter:
                    26 + songIndex * 17 + ((index * 13 + songIndex * 7) % 44),
              ),
          ],
      },
      songMetadata: {
        chartSongs[0].id: const ChartSongMetadata(rankChange: 3),
        chartSongs[1].id: const ChartSongMetadata(rankChange: -1),
        chartSongs[2].id: const ChartSongMetadata(rankChange: 0),
      },
      minScore: 20,
      maxScore: 100,
      updatedAt: DateTime(2026, 8, 24, 21),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DiscoveryZingChartPreview(
                snapshot: snapshot,
                onPlay: (_, _) {},
                onOpenAll: () {},
                tvMode: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discovery-zingchart-preview')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/discovery_realtime_chart_desktop_1440.png'),
    );
  });

  testWidgets('desktop BXH Nhạc Mới mirrors the ranked release hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _songs),
            loadNewReleases: () async => _newReleaseChart,
            initialTab: 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('BXH Nhạc Mới'), findsWidgets);
    expect(
      find.byKey(const ValueKey('artist-link-chart-artist-phuong-my-chi')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('song-album-link-two')), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/new_release_desktop_1440.png'),
    );
  });

  testWidgets('desktop Discovery presents all three weekly chart regions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 245);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DiscoveryWeeklyChartRegionRail(
                onOpenRegion: (_) {},
                tvMode: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discovery-weekly-chart-regions')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/discovery_weekly_regions_desktop_1440.png'),
    );
  });

  testWidgets('desktop Discovery Home mirrors Zing collection rails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(
        PlayerSnapshot(
          history: [
            ListeningRecord(
              id: 'golden-recent-one',
              song: _songOne,
              playedAt: DateTime.utc(2026, 8, 21, 8),
            ),
            ListeningRecord(
              id: 'golden-recent-two',
              song: _songTwo,
              playedAt: DateTime.utc(2026, 8, 21, 7),
            ),
            ListeningRecord(
              id: 'golden-recent-three',
              song: _songThree,
              playedAt: DateTime.utc(2026, 8, 21, 6),
            ),
          ],
        ),
      ),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _songs),
            loadDiscoveryHome: () async => _discoveryHome,
            loadDiscoveryCategories: () async => _discoveryCategories,
            loadDiscoveryRecommendations: () async => _discoveryRecommendations,
            loadReleaseCatalog: () async => _releaseCatalog,
            loadNewReleases: () async => _newReleaseChart,
            initialTab: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('discovery-home')), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/discovery_home_desktop_1440.png'),
    );
  });

  testWidgets('desktop Discovery loading preserves the final content rhythm', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: SingleChildScrollView(
              child: DiscoveryHomeHub(
                home: const DiscoveryHome.empty(),
                loading: true,
                errorMessage: null,
                onRetry: () {},
                categories: const [],
                categoriesLoading: false,
                categoriesErrorMessage: null,
                selectedCategoryId: '-1',
                onCategorySelected: (_) {},
                onRetryCategories: () {},
                onCollectionTap: (_) {},
                onVideoTap: (_) {},
                onOpenHubHome: () {},
                onOpenTop100: () {},
                onOpenReleases: () {},
                onOpenWeeklyChart: () {},
                recommendations: const [],
                canRefreshRecommendations: false,
                onRecommendationTap: (_) {},
                onRefreshRecommendations: () {},
                releaseSongs: const [],
                releaseLoading: false,
                releaseErrorMessage: null,
                releaseRegion: DiscoveryReleaseRegion.all,
                onReleaseRegionChanged: (_) {},
                onReleaseTap: (_) {},
                onRetryReleases: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('discovery-loading-state')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/discovery_loading_desktop_1440.png'),
    );
  });

  testWidgets('desktop Discovery recommendations use a Zing-style matrix', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final songs = List<Song>.generate(
      9,
      (index) => Song(
        id: 'golden-recommendation-$index',
        name: 'golden-recommendation-$index',
        title: 'Gợi Ý Dành Cho Bạn ${index + 1}',
        thumbnail: '',
        artistsNames: 'Nghệ sĩ ${index + 1}',
        code: 'golden-recommendation-code-$index',
      ),
      growable: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(42),
              child: DiscoveryRecommendationShelf(
                songs: songs,
                official: true,
                canRefresh: true,
                onSongTap: (_) {},
                onRefresh: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/discovery_recommendations_desktop_1440.png'),
    );
  });

  testWidgets('desktop Discovery collections expose Zing-style actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scrollController = ScrollController(initialScrollOffset: 104);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: DiscoveryHomeHub(
                home: DiscoveryHome(
                  updatedAt: null,
                  banners: const [],
                  sections: _discoveryHome.sections,
                ),
                loading: false,
                errorMessage: null,
                onRetry: () {},
                categories: const [],
                categoriesLoading: false,
                categoriesErrorMessage: null,
                selectedCategoryId: '-1',
                onCategorySelected: (_) {},
                onRetryCategories: () {},
                onCollectionTap: (_) {},
                onCollectionPlay: (_) {},
                onCollectionToggleSaved: (_) {},
                onCollectionShare: (_) {},
                savedCollectionIds: const {'top-100-vpop'},
                onVideoTap: (_) {},
                onOpenHubHome: () {},
                onOpenTop100: () {},
                onOpenReleases: () {},
                onOpenWeeklyChart: () {},
                recommendations: const [],
                canRefreshRecommendations: false,
                onRecommendationTap: (_) {},
                onRefreshRecommendations: () {},
                releaseSongs: const [],
                releaseLoading: false,
                releaseErrorMessage: null,
                releaseRegion: DiscoveryReleaseRegion.all,
                onReleaseRegionChanged: (_) {},
                onReleaseTap: (_) {},
                onRetryReleases: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discovery-collection-play-top-100-vpop')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('discovery-collection-more-top-100-vpop')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey('discovery-collection-save-top-100-vpop'),
        ),
        matching: find.byIcon(Icons.favorite_rounded),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/discovery_collection_actions_1440.png'),
    );
  });

  testWidgets('desktop Discovery collection rows page like Zing carousels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scrollController = ScrollController(initialScrollOffset: 104);
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: DiscoveryHomeHub(
                home: _collectionCarouselHome,
                loading: false,
                errorMessage: null,
                onRetry: () {},
                categories: const [],
                categoriesLoading: false,
                categoriesErrorMessage: null,
                selectedCategoryId: '-1',
                onCategorySelected: (_) {},
                onRetryCategories: () {},
                onCollectionTap: (_) {},
                onCollectionPlay: (_) {},
                onCollectionToggleSaved: (_) {},
                onCollectionShare: (_) {},
                onVideoTap: (_) {},
                onOpenHubHome: () {},
                onOpenTop100: () {},
                onOpenReleases: () {},
                onOpenWeeklyChart: () {},
                recommendations: const [],
                canRefreshRecommendations: false,
                onRecommendationTap: (_) {},
                onRefreshRecommendations: () {},
                releaseSongs: const [],
                releaseLoading: false,
                releaseErrorMessage: null,
                releaseRegion: DiscoveryReleaseRegion.all,
                onReleaseRegionChanged: (_) {},
                onReleaseTap: (_) {},
                onRetryReleases: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discovery-section-next-golden-carousel')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/discovery_collection_carousel_1440.png'),
    );
  });

  testWidgets('desktop Discovery presents official MV handoff cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: DiscoveryVideoShelf(
                videos: _fullSearchResult.videos,
                onVideoTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('MV Nổi Bật'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/discovery_mv_desktop_1440.png'),
    );
  });

  testWidgets('desktop Discovery recent history stays local-first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: DiscoveryRecentlyPlayedShelf(
                songs: _songs,
                onSongTap: (_) {},
                onOpenLibrary: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/discovery_recent_desktop_1440.png'),
    );
  });

  testWidgets('desktop Discovery highlights the top-three new release chart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(36),
              child: DiscoveryNewReleaseChartSpotlight(
                entries: _newReleaseChart.entries,
                loading: false,
                errorMessage: null,
                onEntryTap: (_) {},
                onOpenAll: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('discovery-new-release-chart')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/discovery_new_release_chart_desktop_1440.png'),
    );
  });

  testWidgets('desktop inline New Releases mirrors the Zing Home grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final releases = List<ReleaseSong>.generate(
      12,
      (index) => ReleaseSong(
        catalogSong: CatalogSong(
          song: Song(
            id: 'golden-home-release-$index',
            name: 'golden-home-release-$index',
            title: const [
              'Giữa Thiên Hà',
              'Motivation',
              'Giá Như Anh Ở Đây',
              'Lips Together',
              'Rực Rỡ',
              'Mưa Hạ',
            ][index % 6],
            thumbnail: '',
            artistsNames: const [
              'Yeolan, CoolKid',
              'Carly Rae Jepsen',
              'Lê Bảo Bình',
              'Tiffany Young, MIYEON',
              'Quốc Thiên, Tăng Phúc',
              'LAMOON',
            ][index % 6],
            code: 'golden-home-release-code-$index',
          ),
          duration: Duration(seconds: 190 + index),
          externalUrl: '',
          playable: index != 7,
        ),
        releasedAt: null,
        region: index < 6 ? ReleaseRegion.vietnam : ReleaseRegion.usuk,
      ),
      growable: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(42),
              child: DiscoveryNewReleaseShelf(
                songs: releases,
                loading: false,
                errorMessage: null,
                region: DiscoveryReleaseRegion.all,
                onRegionChanged: (_) {},
                onSongTap: (_) {},
                onOpenAll: () {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('discovery-new-releases-grid')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/discovery_new_releases_desktop_1440.png'),
    );
  });

  testWidgets('desktop search autocomplete mirrors Zing suggestions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _songs),
            loadDiscoveryHome: () async => _discoveryHome,
            searchSuggestions: (query) async => _suggestions(query),
            searchCatalog: (query) async => CatalogSearchResult.empty(query),
            initialTab: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chart-search-field')),
      'một',
    );
    await tester.pump(const Duration(milliseconds: 140));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('search-suggestion-dropdown')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(Overlay).first,
      matchesGoldenFile('goldens/search_suggestions_desktop_1440.png'),
    );
  });

  testWidgets('desktop catalog search loading preserves result hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(36),
              child: SearchDiscoverySummary(
                query: 'Sơn Tùng',
                isLoading: true,
                result: null,
                errorMessage: null,
                section: CatalogSearchSection.all,
                onSuggestion: (_) {},
                onArtistTap: (_) {},
                onSongTap: (_) {},
                onCollectionTap: (_) {},
                onVideoTap: (_) {},
                onRetry: () {},
                tvMode: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey('catalog-search-loading')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/search_loading_desktop_1440.png'),
    );
  });

  testWidgets('desktop catalog search tail follows the official Zing order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: SingleChildScrollView(
              child: SearchDiscoverySecondarySections(
                result: _searchHierarchyResult,
                onArtistTap: (_) {},
                onCollectionTap: (_) {},
                onVideoTap: (_) {},
                onSectionSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('catalog-search-secondary-sections')),
      findsOneWidget,
    );
    expect(find.text('PLAYLIST/ALBUM'), findsWidgets);
    expect(find.text('MV'), findsOneWidget);
    expect(find.text('NGHỆ SĨ/OA'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/search_all_tail_desktop_1440.png'),
    );
  });

  testWidgets('desktop all search mirrors Zing three-card highlights', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final result = CatalogSearchResult(
      query: 'sơn tùng',
      songs: _searchSongsPageResult.songs.take(2).toList(growable: false),
      artists: _searchHierarchyResult.artists.take(1).toList(growable: false),
      collections: _searchHierarchyResult.collections
          .take(4)
          .toList(growable: false),
      catalogPlaybackEnabled: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: SingleChildScrollView(
              child: SearchDiscoverySummary(
                query: 'sơn tùng',
                isLoading: false,
                result: result,
                errorMessage: null,
                section: CatalogSearchSection.all,
                onSuggestion: (_) {},
                onArtistTap: (_) {},
                onSongTap: (_) {},
                onCollectionTap: (_) {},
                onVideoTap: (_) {},
                onRetry: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final artist = find.byKey(
      const ValueKey('catalog-artist-golden-search-artist-0'),
    );
    final firstSong = find.byKey(
      const ValueKey('catalog-highlight-song-golden-song-search-0'),
    );
    final secondSong = find.byKey(
      const ValueKey('catalog-highlight-song-golden-song-search-1'),
    );
    expect(artist, findsOneWidget);
    expect(firstSong, findsOneWidget);
    expect(secondSong, findsOneWidget);
    expect(tester.getRect(artist).height, 104);
    expect(tester.getRect(firstSong).top, tester.getRect(artist).top);
    expect(tester.getRect(secondSong).top, tester.getRect(artist).top);
    expect(find.text('2.6M quan tâm'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/search_all_highlights_desktop_1440.png'),
    );
  });

  testWidgets('desktop artist search mirrors Zing circular profiles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final artists = [
      const CatalogArtist(
        id: 'golden-artist-son-tung',
        name: 'Sơn Tùng M-TP',
        aliasName: 'Son-Tung-M-TP',
        avatar: '',
        totalFollow: 2600000,
      ),
      const CatalogArtist(
        id: 'golden-artist-kid',
        name: 'Sơn Tùng Kid',
        aliasName: 'Son-Tung-Kid',
        avatar: '',
        totalFollow: 800,
      ),
      const CatalogArtist(
        id: 'golden-artist-acoustic',
        name: 'Sơn Tùng Acoustic',
        aliasName: 'Son-Tung-Acoustic',
        avatar: '',
        totalFollow: 44000,
      ),
      const CatalogArtist(
        id: 'golden-artist-le-son-tung',
        name: 'Lê Sơn Tùng',
        aliasName: 'Le-Son-Tung',
        avatar: '',
        totalFollow: 573,
      ),
      const CatalogArtist(
        id: 'golden-artist-live',
        name: 'Sơn Tùng Live',
        aliasName: 'Son-Tung-Live',
        avatar: '',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF21142F), ZingColors.ink],
              ),
            ),
            child: SearchDiscoverySecondarySections(
              result: CatalogSearchResult(
                query: 'sơn tùng',
                songs: const [],
                catalogPlaybackEnabled: true,
                artists: artists,
              ),
              onArtistTap: (_) {},
              onCollectionTap: (_) {},
              onVideoTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NGHỆ SĨ/OA'), findsOneWidget);
    expect(find.text('2.6M quan tâm'), findsOneWidget);
    expect(find.text('800 quan tâm'), findsOneWidget);
    expect(find.text('44K quan tâm'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/search_artists_desktop_1440.png'),
    );
  });

  testWidgets('desktop Playlist Album search mirrors Zing artwork cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            initialTab: 1,
            loadChart: () async => const ChartSnapshot(songs: _songs),
            loadDiscoveryHome: () async => DiscoveryHome.empty(),
            searchCatalog: (_) async => _searchHierarchyResult,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chart-search-field')),
      'sơn tùng',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('search-section-collections')));
    await tester.pumpAndSettle();

    expect(find.text('PLAYLIST/ALBUM'), findsWidgets);
    expect(
      find.byKey(
        const ValueKey('catalog-collection-golden-search-collection-0'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/search_collections_desktop_1440.png'),
    );
  });

  testWidgets('desktop song search mirrors Zing metadata rows', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            initialTab: 1,
            loadChart: () async => const ChartSnapshot(songs: _songs),
            loadDiscoveryHome: () async => DiscoveryHome.empty(),
            searchCatalog: (_) async => _searchSongsPageResult,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chart-search-field')),
      'sơn tùng',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('search-section-songs')));
    await tester.pumpAndSettle();

    final firstRow = find.byKey(
      const ValueKey('song-row-golden-song-search-0'),
    );
    expect(firstRow, findsOneWidget);
    expect(
      find.descendant(
        of: firstRow,
        matching: find.byIcon(Icons.music_note_rounded),
      ),
      findsNothing,
    );
    expect(find.text('04:22'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('song-album-link-golden-song-search-0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/search_songs_desktop_1440.png'),
    );
  });

  testWidgets('desktop MV search mirrors the official Zing result surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _songs),
            loadDiscoveryHome: () async => _discoveryHome,
            searchSuggestions: (query) async =>
                SearchSuggestionSnapshot.empty(query),
            searchCatalog: (_) async => _fullSearchResult,
            initialTab: 1,
            initialSearchQuery: 'chúng ta không thuộc về nhau',
            initialSearchSection: CatalogSearchSection.videos,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('catalog-video-search-video-1')),
      findsOneWidget,
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/search_mv_desktop_1440.png'),
    );
  });

  testWidgets('desktop Phòng Nhạc mirrors Zing LIVE room cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      liveRadioSourceResolver: (_) async =>
          'https://proxy.example.com/v1/live-streams/token',
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _songs),
            loadLiveRadio: () async => _liveRadio,
            initialTab: 5,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('live-radio-vpop')), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/live_radio_desktop_1440.png'),
    );
  });

  testWidgets('desktop Hub Home mirrors Zing topic and genre rails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _songs),
            loadHubHome: () async => _hubHome,
            initialCatalogLanding: CatalogLanding.hubs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('hub-home')), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/hub_home_desktop_1440.png'),
    );
  });

  testWidgets('desktop Mới Phát Hành mirrors Zing song release tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _songs),
            loadReleaseCatalog: () async => _releaseCatalog,
            initialCatalogLanding: CatalogLanding.releases,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('release-catalog')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('artist-link-release-catalog-artist')),
      findsWidgets,
    );
    expect(find.byKey(const ValueKey('song-album-link-two')), findsOneWidget);
    expect(find.text('3:38'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/release_catalog_desktop_1440.png'),
    );
  });

  testWidgets('desktop BXH Tuần mirrors Zing regional chart hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _songs),
            loadWeeklyChart: (region, {week, year}) async => _weeklyChart,
            initialCatalogLanding: CatalogLanding.weekly,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('weekly-chart')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('artist-link-chart-artist-phuong-my-chi')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('song-album-link-two')), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/weekly_chart_desktop_1440.png'),
    );
  });

  testWidgets('desktop artist profile mirrors Zing OA hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _artistSongs),
            loadArtistDetail: (_) async => _artistDetail,
            initialArtist: _artist,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('artist-desktop-overview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('artist-latest-release-single-one')),
      findsOneWidget,
    );
    expect(find.text('Mới Phát Hành'), findsOneWidget);
    expect(find.text('Bài Hát Nổi Bật'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('artist-link-artist-son-tung')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('song-album-link-artist-one')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('artist-one')),
        matching: find.text('4:05'),
      ),
      findsOneWidget,
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/artist_profile_desktop_1440.png'),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -620));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('artist-video-artist-video-one')),
      findsOneWidget,
    );
  });

  testWidgets('desktop collection detail links its official artist profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final collection = _artistDetail.collectionSections.first.collections.first;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: Center(
            child: SizedBox(
              width: 1180,
              child: CollectionDetailHero(
                collection: collection,
                detail: CatalogCollectionDetail(
                  collection: collection,
                  artists: const [_artist],
                  description:
                      'Tuyển tập chính thức được lưu vào thư viện trên thiết bị.',
                  year: '2026',
                  likeCount: 2200000,
                  genres: const ['V-Pop'],
                  songs: _artistDetail.songs,
                  catalogPlaybackEnabled: true,
                ),
                loading: false,
                onPlay: () {},
                onArtistTap: (_) {},
                onToggleSave: () {},
                isSaved: true,
                onShare: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('collection-artist-artist-son-tung')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/collection_detail_desktop_1440.png'),
    );
  });

  testWidgets('desktop collection tracks expose official row metadata', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final collection = _artistDetail.collectionSections.first.collections.first;
    final detail = CatalogCollectionDetail(
      collection: collection,
      artists: const [_artist],
      description: 'Tuyển tập chính thức với metadata từng bài từ Zing MP3.',
      year: '2026',
      releasedAt: DateTime.utc(2026, 8, 3),
      distributor: 'VIVI ENM',
      likeCount: 2200000,
      genres: const ['V-Pop'],
      songs: [
        for (var index = 0; index < _artistDetail.songs.length; index++)
          CatalogSong(
            song: _artistDetail.songs[index].song,
            duration: _artistDetail.songs[index].duration,
            externalUrl: _artistDetail.songs[index].externalUrl,
            playable: index != 1 && _artistDetail.songs[index].playable,
            artists: const [_artist],
            album: collection,
          ),
      ],
      sections: [
        CatalogCollectionSection(
          id: 'appears-in',
          title: 'Sơn Tùng M-TP Xuất Hiện Trong',
          collections: [collection],
        ),
      ],
      catalogPlaybackEnabled: true,
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _songs),
            loadCollection: (_) async => detail,
            loadArtistDetail: (_) async => _artistDetail,
            initialOfficialUrl:
                'https://zingmp3.vn/album/chung-ta-cua-tuong-lai/single-one.html',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('artist-link-artist-son-tung')),
      findsNWidgets(3),
    );
    expect(find.text('4:05'), findsOneWidget);
    expect(find.text('Chúng Ta Của Tương Lai'), findsWidgets);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/collection_tracks_desktop_1440.png'),
    );
  });

  testWidgets('mobile collection detail keeps the compact official hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final collection = _artistDetail.collectionSections.first.collections.first;
    final detail = CatalogCollectionDetail(
      collection: collection,
      artists: const [_artist],
      description:
          'Tuyển tập chính thức với metadata từng bài từ Zing MP3 và phần giới thiệu dài.',
      year: '2026',
      releasedAt: DateTime.utc(2026, 8, 3),
      distributor: 'VIVI ENM',
      likeCount: 2200000,
      genres: const ['V-Pop'],
      songs: [
        for (var index = 0; index < _artistDetail.songs.length; index++)
          CatalogSong(
            song: _artistDetail.songs[index].song,
            duration: _artistDetail.songs[index].duration,
            externalUrl: _artistDetail.songs[index].externalUrl,
            playable: index != 1 && _artistDetail.songs[index].playable,
            artists: const [_artist],
            album: collection,
          ),
      ],
      catalogPlaybackEnabled: true,
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(
            tvMode: false,
          ).copyWith(platform: TargetPlatform.android),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _songs),
            loadCollection: (_) async => detail,
            loadArtistDetail: (_) async => _artistDetail,
            initialOfficialUrl:
                'https://zingmp3.vn/album/chung-ta-cua-tuong-lai/single-one.html',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('collection-more-button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('collection-share-button')), findsNothing);
    expect(find.byKey(const ValueKey('artist-one')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('goldens/collection_detail_mobile_360.png'),
    );
  });

  testWidgets('desktop artist follow state stays local-first', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(
        const PlayerSnapshot(followedArtists: [_artist]),
      ),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _artistSongs),
            loadArtistDetail: (_) async => _artistDetail,
            initialArtist: _artist,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ĐANG QUAN TÂM'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/artist_follow_desktop_1440.png'),
    );
  });

  testWidgets('desktop lyrics mirrors the focused Zing karaoke hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = PlaybackService(
      playbackAudioPlayer: audio,
      sourceResolver: (_) async => 'https://audio.example.test/song.mp3',
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    await controller.playSong(_songOne);
    audio
      ..emitDuration(const Duration(minutes: 3))
      ..emitPosition(const Duration(seconds: 38));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          body: SongLyricsPanel(
            controller: controller,
            lyricsLoader: (_) async => _lyrics,
            initialKaraoke: true,
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('song-karaoke-stage')), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/lyrics_desktop_1440.png'),
    );
  });

  testWidgets('mobile Now Playing mirrors the Zing playback hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = PlaybackService(
      playbackAudioPlayer: audio,
      sourceResolver: (_) async => 'https://audio.example.test/song.mp3',
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    controller.setStreamingQualityPreference(StreamingQualityPreference.high);
    await controller.playSong(_songOne, queue: _songs);
    controller
      ..toggleLike(_songOne)
      ..toggleMood(_songOne, MoodTag.chill);
    audio
      ..emitDuration(const Duration(minutes: 3, seconds: 42))
      ..emitPosition(const Duration(minutes: 1, seconds: 18));
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: const MusicPlayerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('320 KBPS'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('now-playing-action-dock')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/now_playing_mobile_360.png'),
    );
  });

  testWidgets(
    'desktop Car Mode keeps playback glanceable and distraction-free',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audio = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (_) async => 'https://audio.example.test/song.mp3',
        libraryRepository: MemoryLibraryRepository(),
        analyticsRepository: MemoryListeningAnalyticsRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      await controller.playSong(_songOne, queue: _songs);
      controller.setCarModeEnabled(true);
      audio
        ..emitDuration(const Duration(minutes: 3, seconds: 42))
        ..emitPosition(const Duration(minutes: 1, seconds: 18));
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildZingDarkTheme(tvMode: false),
            home: const MusicPlayerScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('car-mode-player')), findsOneWidget);
      expect(find.text('CHẾ ĐỘ LÁI XE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/car_mode_desktop_1440.png'),
      );
    },
  );

  testWidgets('desktop Lyric Card mirrors the Zing sharing hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: Center(
            child: SizedBox(
              width: 1040,
              height: 780,
              child: LyricShareComposer(
                song: _songOne,
                lyrics: _lyrics,
                initialLineIndex: 0,
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lyric-share-line-1')));
    await tester.tap(find.byKey(const ValueKey('lyric-share-line-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lyric-share-composer')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/lyric_share_desktop_1440.png'),
    );
  });

  testWidgets('desktop song detail mirrors the official single hierarchy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (_) async => 'https://audio.example.test/song.mp3',
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    await controller.playSong(_songOne);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: 1080,
                height: 760,
                child: SongDetailPanel(
                  controller: controller,
                  detailLoader: (_) async => _songDetail,
                  onOpenArtist: (_) {},
                  onOpenAlbum: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('song-detail-scroll')), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/song_detail_desktop_1440.png'),
    );
  });

  testWidgets('desktop Song Radio mirrors the Zing autoplay queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.test/$code.mp3',
      songRadioLoader: (code) async => SongRadio(
        seedId: code,
        recommendations: const [
          CatalogSong(
            song: _songTwo,
            duration: Duration(minutes: 3, seconds: 38),
            externalUrl: '',
            playable: true,
          ),
          CatalogSong(
            song: _songThree,
            duration: Duration(minutes: 4, seconds: 14),
            externalUrl: '',
            playable: true,
          ),
        ],
      ),
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    await controller.playSong(_songOne, queue: const [_songOne]);
    await controller.startSongRadio();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _songs),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-queue')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('RADIO'), findsNWidgets(2));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/song_radio_desktop_1440.png'),
    );
  });

  testWidgets('desktop Smart Shuffle marks local catalog suggestions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.test/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      analyticsRepository: MemoryListeningAnalyticsRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    controller.updateCatalog(_smartShuffleCatalog);
    await controller.playSong(
      _smartShuffleQueue.first,
      queue: _smartShuffleQueue,
    );
    controller.setSmartShuffleEnabled(true);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            loadChart: () async => const ChartSnapshot(songs: _songs),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-queue')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('SMART'), findsNWidgets(2));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/smart_shuffle_desktop_1440.png'),
    );
  });

  testWidgets('desktop streaming quality exposes real relay choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.test/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    controller.setStreamingQualityPreference(StreamingQualityPreference.high);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: Scaffold(
          backgroundColor: ZingColors.ink,
          body: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 690,
                child: StreamingQualityPickerPanel(
                  controller: controller,
                  showCloseButton: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('320 kbps'), findsOneWidget);
    expect(find.text('Relay có chữ ký'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/stream_quality_desktop_1280.png'),
    );
  });
}

SearchSuggestionSnapshot _suggestions(String query) => SearchSuggestionSnapshot(
  query: query,
  keywords: const [
    'một bài hát',
    'một bước yêu vạn dặm đau',
    'một vòng việt nam',
    'một đời người một rừng cây',
  ],
  songs: const [
    SearchSuggestionSong(
      id: 'suggestion-one',
      title: 'Một Bước Yêu, Vạn Dặm Đau',
      artist: 'Mr. Siro',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 59),
      externalUrl: 'https://zingmp3.vn/bai-hat/one.html',
    ),
    SearchSuggestionSong(
      id: 'suggestion-two',
      title: 'Một Vòng Việt Nam',
      artist: 'Tùng Dương',
      thumbnail: '',
      duration: Duration(minutes: 3, seconds: 52),
      externalUrl: 'https://zingmp3.vn/bai-hat/two.html',
    ),
    SearchSuggestionSong(
      id: 'suggestion-three',
      title: 'Một Đời Người Một Rừng Cây',
      artist: 'Trọng Tấn',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 21),
      externalUrl: 'https://zingmp3.vn/bai-hat/three.html',
    ),
  ],
);

final _searchHierarchyResult = CatalogSearchResult(
  query: 'sơn tùng',
  catalogPlaybackEnabled: true,
  songs: const [],
  collections: List.generate(
    5,
    (index) => CatalogCollection(
      id: 'golden-search-collection-$index',
      title: switch (index) {
        0 => 'Những Bài Hát Hay Nhất Của Sơn Tùng M-TP',
        1 => 'Remix Việt Ngày Nay',
        2 => 'V-Pop: Hits Quốc Dân',
        3 => 'Nơi Này Có Anh (Single)',
        _ => 'Em Của Ngày Hôm Qua (EP)',
      },
      artist: index == 1
          ? 'Sơn Tùng M-TP, RayO, Ngô Lan Hương'
          : 'Sơn Tùng M-TP',
      thumbnail: '',
      kind: index >= 3
          ? CatalogCollectionKind.album
          : CatalogCollectionKind.playlist,
      externalUrl: 'https://zingmp3.vn/album/golden-$index',
    ),
  ),
  videos: List.generate(
    4,
    (index) => CatalogVideo(
      id: 'golden-search-video-$index',
      title: switch (index) {
        0 => 'Em Của Ngày Hôm Qua',
        1 => 'Nơi Này Có Anh',
        2 => 'Lạc Trôi',
        _ => 'Chạy Ngay Đi',
      },
      artist: 'Sơn Tùng M-TP',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 18 + index * 7),
      externalUrl: 'https://zingmp3.vn/video-clip/golden-$index',
    ),
  ),
  artists: List.generate(
    3,
    (index) => CatalogArtist(
      id: 'golden-search-artist-$index',
      name: switch (index) {
        0 => 'Sơn Tùng M-TP',
        1 => 'Sơn Tùng Kid',
        _ => 'Sơn Tùng Acoustic',
      },
      aliasName: 'golden-search-artist-$index',
      avatar: '',
      totalFollow: switch (index) {
        0 => 2600000,
        1 => 800,
        _ => 44000,
      },
    ),
  ),
);

const _goldenSearchArtist = CatalogArtist(
  id: 'golden-song-search-artist',
  name: 'Sơn Tùng M-TP',
  aliasName: 'Son-Tung-M-TP',
  avatar: '',
  totalFollow: 2600000,
);

final _searchSongsPageResult = CatalogSearchResult(
  query: 'sơn tùng',
  catalogPlaybackEnabled: true,
  songs: List.generate(
    8,
    (index) => CatalogSong(
      song: Song(
        id: 'golden-song-search-$index',
        name: 'golden-song-search-$index',
        title: switch (index) {
          0 => 'Nơi Này Có Anh',
          1 => 'Âm Thầm Bên Em',
          2 => 'Khuôn Mặt Đáng Thương',
          3 => 'Hãy Trao Cho Anh',
          4 => 'Em Của Ngày Hôm Qua',
          5 => 'Chắc Ai Đó Sẽ Về',
          6 => 'Nắng Ấm Xa Dần',
          _ => 'Cơn Mưa Ngang Qua',
        },
        thumbnail: '',
        artistsNames: index == 3
            ? 'Sơn Tùng M-TP, Snoop Dogg'
            : 'Sơn Tùng M-TP',
        code: 'golden-song-search-code-$index',
      ),
      duration: Duration(seconds: 262 + index * 9),
      externalUrl: 'https://zingmp3.vn/bai-hat/golden-song-search-$index.html',
      playable: true,
      artists: const [_goldenSearchArtist],
      album: CatalogCollection(
        id: 'golden-song-search-album-$index',
        title: switch (index) {
          4 || 6 => 'Em Của Ngày Hôm Qua (EP)',
          5 => 'Chàng Trai Năm Ấy OST (EP)',
          _ => 'Single chính thức · Sơn Tùng M-TP',
        },
        artist: 'Sơn Tùng M-TP',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: 'https://zingmp3.vn/album/golden-song-search-$index.html',
      ),
    ),
  ),
  artists: const [_goldenSearchArtist],
);

const _fullSearchResult = CatalogSearchResult(
  query: 'chúng ta không thuộc về nhau',
  catalogPlaybackEnabled: true,
  songs: [
    CatalogSong(
      song: Song(
        id: 'search-song-1',
        name: 'search-song-1',
        title: 'Chúng Ta Không Thuộc Về Nhau',
        thumbnail: '',
        artistsNames: 'Sơn Tùng M-TP',
        code: 'search-song-1',
      ),
      duration: Duration(minutes: 3, seconds: 53),
      externalUrl: '',
      playable: true,
      hasLyrics: true,
      artists: [_artist],
      album: _artistTrackAlbum,
    ),
  ],
  artists: [],
  videos: [
    CatalogVideo(
      id: 'search-video-1',
      title: 'Chúng Ta Không Thuộc Về Nhau (Official MV)',
      artist: 'Sơn Tùng M-TP',
      artists: [_artist],
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 2),
      externalUrl: 'https://zingmp3.vn/video-clip/chung-ta/search-video-1.html',
    ),
    CatalogVideo(
      id: 'search-video-2',
      title: 'Chúng Ta Không Thuộc Về Nhau (Live)',
      artist: 'Trịnh Đình Quang',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 28),
      externalUrl: 'https://zingmp3.vn/video-clip/chung-ta/search-video-2.html',
    ),
    CatalogVideo(
      id: 'search-video-3',
      title: 'Ta Không Thuộc Về Nhau (MV Lyric)',
      artist: 'Trần Đình Tôn',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 23),
      externalUrl: 'https://zingmp3.vn/video-clip/chung-ta/search-video-3.html',
    ),
    CatalogVideo(
      id: 'search-video-4',
      title: 'Chúng Ta Không Thuộc Về Nhau (Remake)',
      artist: 'CesferKhoi',
      thumbnail: '',
      duration: Duration(minutes: 3, seconds: 56),
      externalUrl: 'https://zingmp3.vn/video-clip/chung-ta/search-video-4.html',
    ),
  ],
);

const _songOne = Song(
  id: 'one',
  name: 'ke-say-tinh',
  title: 'Kẻ Say Tình 2',
  thumbnail: '',
  artistsNames: 'Quốc Thiên',
  code: 'one',
);
const _songTwo = Song(
  id: 'two',
  name: 'thien-duong',
  title: 'Thiên Đường Với Người Thương',
  thumbnail: '',
  artistsNames: 'Phương Mỹ Chi, DTAP',
  code: 'two',
);
const _songThree = Song(
  id: 'three',
  name: 'gia-nhu',
  title: 'Giá Như Anh Là Em',
  thumbnail: '',
  artistsNames: 'Lệ Quyên',
  code: 'three',
);
const _suggestedSong = Song(
  id: 'suggested',
  name: 'buoc-qua-nhau',
  title: 'Bước Qua Nhau',
  thumbnail: '',
  artistsNames: 'Vũ.',
  code: 'suggested',
);
const _songs = [_songOne, _songTwo, _songThree];

const _chartArtistQuocThien = CatalogArtist(
  id: 'chart-artist-quoc-thien',
  name: 'Quốc Thiên',
  aliasName: 'Quoc-Thien',
  avatar: '',
);
const _chartArtistPhuongMyChi = CatalogArtist(
  id: 'chart-artist-phuong-my-chi',
  name: 'Phương Mỹ Chi',
  aliasName: 'Phuong-My-Chi',
  avatar: '',
);
const _chartArtistLeQuyen = CatalogArtist(
  id: 'chart-artist-le-quyen',
  name: 'Lệ Quyên',
  aliasName: 'Le-Quyen',
  avatar: '',
);

const _chartAlbumKeSayTinh = CatalogCollection(
  id: 'chart-album-ke-say-tinh-2',
  title: 'Kẻ Say Tình 2 (Single)',
  artist: 'Quốc Thiên',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: '',
);
const _chartAlbumThienDuong = CatalogCollection(
  id: 'chart-album-thien-duong-voi-nguoi-thuong',
  title: 'Thiên Đường Với Người Thương (Single)',
  artist: 'Phương Mỹ Chi, DTAP',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: '',
);
const _chartAlbumGiaNhu = CatalogCollection(
  id: 'chart-album-gia-nhu-anh-la-em',
  title: 'Giá Như Anh Là Em (Single)',
  artist: 'Lệ Quyên',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: '',
);

final _smartShuffleQueue = [
  ..._songs,
  for (var index = 0; index < 3; index++)
    Song(
      id: 'queue-$index',
      name: 'queue-$index',
      title: 'Bài trong hàng đợi ${index + 4}',
      thumbnail: '',
      artistsNames: 'Nghệ sĩ hàng đợi ${index + 1}',
      code: 'queue-code-$index',
    ),
];

final _smartShuffleCatalog = [
  ..._smartShuffleQueue,
  for (var index = 0; index < 6; index++)
    Song(
      id: 'smart-golden-$index',
      name: 'smart-golden-$index',
      title: 'Gợi ý hợp gu ${index + 1}',
      thumbnail: '',
      artistsNames: 'Nghệ sĩ khám phá ${index + 1}',
      code: 'smart-golden-code-$index',
    ),
];

const _chartSuggestionArtist = CatalogArtist(
  id: 'chart-suggestion-artist-vu',
  name: 'Vũ.',
  aliasName: 'Vu',
  avatar: '',
);

const _chartSuggestionAlbum = CatalogCollection(
  id: 'chart-suggestion-album-buoc-qua-nhau',
  title: 'Bước Qua Nhau (Single)',
  artist: 'Vũ.',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: '',
);

const _chartSuggestion = DiscoveryRecommendations(
  updatedAt: null,
  entries: [
    CatalogSong(
      song: _suggestedSong,
      duration: Duration(minutes: 4, seconds: 2),
      externalUrl: '',
      playable: true,
      artists: [_chartSuggestionArtist],
      album: _chartSuggestionAlbum,
    ),
  ],
  catalogPlaybackEnabled: true,
);

final _songDetail = SongDetail(
  catalogSong: CatalogSong(
    song: _songOne,
    duration: Duration(minutes: 3, seconds: 48),
    externalUrl: 'https://zingmp3.vn/bai-hat/ke-say-tinh/one.html',
    playable: true,
    hasLyrics: true,
  ),
  artists: [
    CatalogArtist(
      id: 'artist-one',
      name: 'Quốc Thiên',
      aliasName: 'Quoc-Thien',
      avatar: '',
    ),
  ],
  album: CatalogCollection(
    id: 'album-one',
    title: 'Kẻ Say Tình 2 (Single)',
    artist: 'Quốc Thiên',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: 'https://zingmp3.vn/album/ke-say-tinh/album-one.html',
  ),
  releasedAt: DateTime(2026, 8, 12),
  distributor: 'Universal Music Vietnam',
  genres: ['Việt Nam', 'V-Pop', 'Ballad'],
  composers: [
    CatalogArtist(
      id: 'composer-one',
      name: 'Vương Anh Tú',
      aliasName: 'Vuong-Anh-Tu',
      avatar: '',
    ),
  ],
  listenCount: 12854067,
  likeCount: 683214,
  commentCount: 1238,
  mv: CatalogVideo(
    id: 'one',
    title: 'Kẻ Say Tình 2',
    artist: 'Quốc Thiên',
    thumbnail: '',
    duration: Duration(minutes: 3, seconds: 48),
    externalUrl: 'https://zingmp3.vn/video-clip/ke-say-tinh/one.html',
  ),
  catalogPlaybackEnabled: true,
);

const _lyrics = SongLyrics(
  songId: 'one',
  synced: true,
  lines: [
    LyricLine(
      start: Duration(seconds: 5),
      end: Duration(seconds: 12),
      text: 'Có những ngày thành phố chậm hơn một nhịp',
    ),
    LyricLine(
      start: Duration(seconds: 13),
      end: Duration(seconds: 21),
      text: 'Mình nghe thanh xuân đi qua ô cửa nhỏ',
    ),
    LyricLine(
      start: Duration(seconds: 22),
      end: Duration(seconds: 30),
      text: 'Giữ một giai điệu ở lại giữa bàn tay',
    ),
    LyricLine(
      start: Duration(seconds: 31),
      end: Duration(seconds: 42),
      text: 'Và hát cho đêm nay sáng lên',
      words: [
        LyricWord(
          start: Duration(seconds: 31),
          end: Duration(seconds: 33),
          text: 'Và',
        ),
        LyricWord(
          start: Duration(seconds: 33),
          end: Duration(seconds: 34),
          text: 'hát',
        ),
        LyricWord(
          start: Duration(seconds: 34),
          end: Duration(seconds: 35),
          text: 'cho',
        ),
        LyricWord(
          start: Duration(seconds: 35),
          end: Duration(seconds: 37),
          text: 'đêm',
        ),
        LyricWord(
          start: Duration(seconds: 37),
          end: Duration(seconds: 38),
          text: 'nay',
        ),
        LyricWord(
          start: Duration(seconds: 38),
          end: Duration(seconds: 40),
          text: 'sáng',
        ),
        LyricWord(
          start: Duration(seconds: 40),
          end: Duration(seconds: 42),
          text: 'lên',
        ),
      ],
    ),
    LyricLine(
      start: Duration(seconds: 43),
      end: Duration(seconds: 52),
      text: 'Từng nhịp tim vẫn đang ngân vang',
    ),
    LyricLine(
      start: Duration(seconds: 53),
      end: Duration(seconds: 62),
      text: 'Đưa mình về gần nhau hơn',
    ),
  ],
);

const _artist = CatalogArtist(
  id: 'artist-son-tung',
  name: 'Sơn Tùng M-TP',
  aliasName: 'Son-Tung-M-TP',
  avatar: '',
);

const _artistSongOne = Song(
  id: 'artist-one',
  name: 'noi-nay-co-anh',
  title: 'Nơi Này Có Anh',
  thumbnail: '',
  artistsNames: 'Sơn Tùng M-TP',
  code: 'artist-one',
);
const _artistSongTwo = Song(
  id: 'artist-two',
  name: 'chay-ngay-di',
  title: 'Chạy Ngay Đi',
  thumbnail: '',
  artistsNames: 'Sơn Tùng M-TP',
  code: 'artist-two',
);
const _artistSongThree = Song(
  id: 'artist-three',
  name: 'chung-ta-cua-hien-tai',
  title: 'Chúng Ta Của Hiện Tại',
  thumbnail: '',
  artistsNames: 'Sơn Tùng M-TP',
  code: 'artist-three',
);
const _artistSongs = [_artistSongOne, _artistSongTwo, _artistSongThree];

const _artistTrackAlbum = CatalogCollection(
  id: 'single-one',
  title: 'Chúng Ta Của Tương Lai',
  artist: 'Sơn Tùng M-TP',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: '',
);

const _artistDetail = CatalogArtistDetail(
  artist: _artist,
  cover: '',
  biography:
      'Sơn Tùng M-TP là ca sĩ, nhạc sĩ và nhà sản xuất âm nhạc Việt Nam.',
  realName: 'Nguyễn Thanh Tùng',
  national: 'Việt Nam',
  birthday: '05/07/1994',
  totalFollow: 2655838,
  awardCount: 12,
  featuredSongs: [
    CatalogSong(
      song: _artistSongOne,
      duration: Duration(minutes: 4, seconds: 5),
      externalUrl: '',
      playable: true,
      artists: [_artist],
      album: _artistTrackAlbum,
    ),
    CatalogSong(
      song: _artistSongTwo,
      duration: Duration(minutes: 4, seconds: 8),
      externalUrl: '',
      playable: true,
      artists: [_artist],
      album: _artistTrackAlbum,
    ),
    CatalogSong(
      song: _artistSongThree,
      duration: Duration(minutes: 4, seconds: 2),
      externalUrl: '',
      playable: true,
      artists: [_artist],
      album: _artistTrackAlbum,
    ),
  ],
  songs: [
    CatalogSong(
      song: _artistSongOne,
      duration: Duration(minutes: 4, seconds: 5),
      externalUrl: '',
      playable: true,
      artists: [_artist],
      album: _artistTrackAlbum,
    ),
    CatalogSong(
      song: _artistSongTwo,
      duration: Duration(minutes: 4, seconds: 8),
      externalUrl: '',
      playable: true,
      artists: [_artist],
      album: _artistTrackAlbum,
    ),
    CatalogSong(
      song: _artistSongThree,
      duration: Duration(minutes: 4, seconds: 2),
      externalUrl: '',
      playable: true,
      artists: [_artist],
      album: _artistTrackAlbum,
    ),
  ],
  videos: [
    CatalogVideo(
      id: 'artist-video-one',
      title: 'Chúng Ta Của Tương Lai',
      artist: 'Sơn Tùng M-TP',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 37),
      externalUrl:
          'https://zingmp3.vn/video-clip/chung-ta-cua-tuong-lai/artist-video-one.html',
    ),
    CatalogVideo(
      id: 'artist-video-two',
      title: 'Hãy Trao Cho Anh',
      artist: 'Sơn Tùng M-TP, Snoop Dogg',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 5),
      externalUrl:
          'https://zingmp3.vn/video-clip/hay-trao-cho-anh/artist-video-two.html',
    ),
  ],
  collectionSections: [
    CatalogArtistCollectionSection(
      id: 'single-ep',
      title: 'Single & EP',
      collections: [_artistTrackAlbum],
    ),
  ],
  relatedArtists: [
    CatalogArtist(
      id: 'related-mono',
      name: 'MONO',
      aliasName: 'MONO-Nguyen-Viet-Hoang',
      avatar: '',
    ),
  ],
  catalogPlaybackEnabled: true,
);

const _newReleaseChart = NewReleaseChart(
  title: 'BXH Nhạc Mới',
  updatedAt: null,
  catalogPlaybackEnabled: true,
  entries: [
    NewReleaseEntry(
      catalogSong: CatalogSong(
        song: _songTwo,
        duration: Duration(minutes: 3, seconds: 38),
        externalUrl: '',
        playable: true,
        artists: [_chartArtistPhuongMyChi],
        album: _chartAlbumThienDuong,
      ),
      albumTitle: 'Thiên Đường Với Người Thương (Single)',
      rank: 1,
      rankChange: 0,
      releasedAt: null,
    ),
    NewReleaseEntry(
      catalogSong: CatalogSong(
        song: _songThree,
        duration: Duration(minutes: 4, seconds: 14),
        externalUrl: '',
        playable: true,
        artists: [_chartArtistLeQuyen],
        album: _chartAlbumGiaNhu,
      ),
      albumTitle: 'Giá Như Anh Là Em (Single)',
      rank: 2,
      rankChange: 2,
      releasedAt: null,
    ),
    NewReleaseEntry(
      catalogSong: CatalogSong(
        song: _songOne,
        duration: Duration(minutes: 4, seconds: 15),
        externalUrl: '',
        playable: true,
        artists: [_chartArtistQuocThien],
        album: _chartAlbumKeSayTinh,
      ),
      albumTitle: 'Kẻ Say Tình 2 (Single)',
      rank: 3,
      rankChange: -1,
      releasedAt: null,
    ),
  ],
);

const _weeklyChart = WeeklyChart(
  region: WeeklyChartRegion.vietnam,
  title: 'Bảng Xếp Hạng Tuần',
  week: 33,
  year: 2026,
  latestWeek: 33,
  startDate: '10/08',
  endDate: '16/08',
  updatedAt: null,
  catalogPlaybackEnabled: true,
  entries: [
    WeeklyChartEntry(
      catalogSong: CatalogSong(
        song: _songTwo,
        duration: Duration(minutes: 3, seconds: 38),
        externalUrl: '',
        playable: true,
        artists: [_chartArtistPhuongMyChi],
        album: _chartAlbumThienDuong,
      ),
      albumTitle: 'Thiên Đường Với Người Thương (Single)',
      rank: 1,
      rankChange: 2,
      score: 2526,
    ),
    WeeklyChartEntry(
      catalogSong: CatalogSong(
        song: _songThree,
        duration: Duration(minutes: 4, seconds: 14),
        externalUrl: '',
        playable: true,
        artists: [_chartArtistLeQuyen],
        album: _chartAlbumGiaNhu,
      ),
      albumTitle: 'Giá Như Anh Là Em (Single)',
      rank: 2,
      rankChange: -1,
      score: 2180,
    ),
    WeeklyChartEntry(
      catalogSong: CatalogSong(
        song: _songOne,
        duration: Duration(minutes: 4, seconds: 15),
        externalUrl: '',
        playable: true,
        artists: [_chartArtistQuocThien],
        album: _chartAlbumKeSayTinh,
      ),
      albumTitle: 'Kẻ Say Tình 2 (Single)',
      rank: 3,
      rankChange: 0,
      score: 1900,
    ),
  ],
);

const _releaseCatalogArtist = CatalogArtist(
  id: 'release-catalog-artist',
  name: 'Quốc Thiên',
  aliasName: 'Quoc-Thien',
  avatar: '',
);

const _releaseCatalogTrackAlbum = CatalogCollection(
  id: 'release-catalog-track-album',
  title: 'Ngày Mới Rực Rỡ (Single)',
  artist: 'Quốc Thiên',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: '',
);

final _releaseCatalog = ReleaseCatalog(
  updatedAt: DateTime(2026, 8, 21),
  catalogPlaybackEnabled: true,
  songs: [
    ReleaseSong(
      catalogSong: const CatalogSong(
        song: _songTwo,
        duration: Duration(minutes: 3, seconds: 38),
        externalUrl: '',
        playable: true,
        artists: [_releaseCatalogArtist],
        album: _releaseCatalogTrackAlbum,
      ),
      releasedAt: DateTime(2026, 8, 21),
      region: ReleaseRegion.vietnam,
    ),
    ReleaseSong(
      catalogSong: const CatalogSong(
        song: _songThree,
        duration: Duration(minutes: 4, seconds: 14),
        externalUrl: '',
        playable: true,
        artists: [_releaseCatalogArtist],
        album: _releaseCatalogTrackAlbum,
      ),
      releasedAt: DateTime(2026, 8, 20),
      region: ReleaseRegion.vietnam,
    ),
    ReleaseSong(
      catalogSong: const CatalogSong(
        song: _songOne,
        duration: Duration(minutes: 4, seconds: 15),
        externalUrl: '',
        playable: false,
        artists: [_releaseCatalogArtist],
        album: _releaseCatalogTrackAlbum,
      ),
      releasedAt: DateTime(2026, 8, 19),
      region: ReleaseRegion.usuk,
    ),
  ],
  albums: [
    ReleaseAlbum(
      collection: const CatalogCollection(
        id: 'release-album-vpop',
        title: 'Ngày Mới Rực Rỡ',
        artist: 'Nhiều nghệ sĩ Việt',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: '',
      ),
      releasedAt: DateTime(2026, 8, 21),
      region: ReleaseRegion.vietnam,
    ),
    ReleaseAlbum(
      collection: const CatalogCollection(
        id: 'release-album-kpop',
        title: 'Seoul After Midnight',
        artist: 'K Artist',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: '',
      ),
      releasedAt: DateTime(2026, 8, 20),
      region: ReleaseRegion.korea,
    ),
  ],
);

const _topCollection = CatalogCollection(
  id: 'top-100-vpop',
  title: 'Top 100 Nhạc V-Pop Hay Nhất',
  artist: 'Dương Domic, Quang Hùng MasterD',
  thumbnail: '',
  kind: CatalogCollectionKind.playlist,
  externalUrl: '',
);

const _discoveryHome = DiscoveryHome(
  updatedAt: null,
  quickPlay: [
    DiscoveryCollection(
      collection: _topCollection,
      description: 'BXH V-Pop được mở nhiều nhất hôm nay.',
    ),
    DiscoveryCollection(
      collection: CatalogCollection(
        id: 'home-remix-collection',
        title: 'Remix Thịnh Hành',
        artist: 'Du Uyên, Linh Hương Luz',
        thumbnail: '',
        kind: CatalogCollectionKind.playlist,
        externalUrl: '',
      ),
      description: 'Những bản remix đang gây chú ý.',
    ),
    DiscoveryCollection(
      collection: CatalogCollection(
        id: 'home-ballad-collection',
        title: 'Nhạc Ballad Nhẹ Nhàng',
        artist: 'Khả Hiệp, Thanh Hưng',
        thumbnail: '',
        kind: CatalogCollectionKind.playlist,
        externalUrl: '',
      ),
      description: 'Ballad nhẹ nhàng cho một ngày thư thái.',
    ),
  ],
  banners: [
    DiscoveryBanner(id: 'home-featured', image: '', collection: _topCollection),
  ],
  sections: [
    DiscoverySection(
      id: 'top-100',
      title: 'Top 100',
      collections: [
        DiscoveryCollection(
          collection: _topCollection,
          description: 'Những ca khúc được nghe nhiều nhất hiện tại.',
        ),
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'top-100-usuk',
            title: 'Top 100 Pop Âu Mỹ Hay Nhất',
            artist: 'Taylor Swift, Sabrina Carpenter',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Âm nhạc quốc tế nổi bật.',
        ),
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'top-100-kpop',
            title: 'Top 100 Nhạc Hàn Quốc',
            artist: 'aespa, BLACKPINK',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'K-Pop được yêu thích nhất.',
        ),
      ],
    ),
    DiscoverySection(
      id: 'chill',
      title: 'Chill',
      collections: [
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'chill-one',
            title: 'Ngắm Nhìn Những Suy Tư',
            artist: 'Nhiều nghệ sĩ',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Về với chính mình trong phiên bản mộc mạc nhất.',
        ),
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'chill-two',
            title: 'Lắng Đọng Cùng Acoustic Việt',
            artist: 'Nhiều nghệ sĩ',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Lắng đọng cảm xúc sau một ngày dài.',
        ),
      ],
    ),
    DiscoverySection(
      id: 'album-hot',
      title: 'Album Hot',
      collections: [
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'album-one',
            title: 'Về Nhà Em Nhé (Single)',
            artist: 'Thoại Nghi, Nguyễn Trung Đức, ICM',
            thumbnail: '',
            kind: CatalogCollectionKind.album,
            externalUrl: '',
          ),
          description: '',
        ),
      ],
    ),
  ],
);

final _collectionCarouselHome = DiscoveryHome(
  updatedAt: null,
  banners: const [],
  sections: [
    DiscoverySection(
      id: 'golden-carousel',
      title: 'Album Hot',
      collections: List.generate(10, (index) {
        return DiscoveryCollection(
          collection: CatalogCollection(
            id: 'golden-carousel-$index',
            title: 'Album Nổi Bật ${index + 1}',
            artist: 'Nghệ sĩ ${index + 1}',
            thumbnail: '',
            kind: CatalogCollectionKind.album,
            externalUrl: '',
          ),
          description: 'Tuyển tập chính thức từ Zing MP3.',
        );
      }),
    ),
  ],
);

const _discoveryCategories = DiscoveryCategories(
  updatedAt: null,
  items: [
    DiscoveryCategory(id: '14', name: 'Thư giãn'),
    DiscoveryCategory(id: '13', name: 'Làm việc'),
    DiscoveryCategory(id: '21', name: 'Trending'),
    DiscoveryCategory(id: '18', name: 'Ngủ ngon'),
    DiscoveryCategory(id: '15', name: 'Tập luyện'),
  ],
);

const _discoveryRecommendations = DiscoveryRecommendations(
  updatedAt: null,
  entries: [
    CatalogSong(
      song: _songOne,
      duration: Duration(minutes: 4),
      externalUrl: '',
      playable: true,
    ),
    CatalogSong(
      song: _songTwo,
      duration: Duration(minutes: 3, seconds: 48),
      externalUrl: '',
      playable: true,
    ),
    CatalogSong(
      song: _songThree,
      duration: Duration(minutes: 3, seconds: 35),
      externalUrl: '',
      playable: true,
    ),
  ],
  catalogPlaybackEnabled: true,
);

const _liveRadio = LiveRadioSnapshot(
  updatedAt: null,
  rooms: [
    LiveRadioRoom(
      id: 'vpop',
      title: 'V-POP',
      description: 'Nhạc Việt đang thịnh hành',
      thumbnail: '',
      listenerCount: 12500,
      hostName: 'Zing MP3',
      hostThumbnail: '',
      program: LiveRadioProgram(
        id: 'vpop-program',
        title: 'Nhạc Việt hôm nay',
        thumbnail: '',
        description: '',
        startTime: null,
        endTime: null,
      ),
    ),
    LiveRadioRoom(
      id: 'cham',
      title: 'Chạm',
      description: 'Những cảm xúc dịu dàng',
      thumbnail: '',
      listenerCount: 9800,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
    LiveRadioRoom(
      id: 'bolero',
      title: 'Bolero',
      description: 'Tình khúc vượt thời gian',
      thumbnail: '',
      listenerCount: 8700,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
    LiveRadioRoom(
      id: 'usuk',
      title: 'US-UK',
      description: 'Pop quốc tế nổi bật',
      thumbnail: '',
      listenerCount: 7100,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
    LiveRadioRoom(
      id: 'kpop',
      title: 'K-POP',
      description: 'K-Pop không ngừng nghỉ',
      thumbnail: '',
      listenerCount: 6400,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
    LiveRadioRoom(
      id: 'acoustic',
      title: 'Acoustic',
      description: 'Giai điệu mộc cho ngày mới',
      thumbnail: '',
      listenerCount: 4200,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
  ],
);

const _sleepCollection = CatalogCollection(
  id: 'sleep-deep',
  title: 'Ngủ Ngon Cùng Những Giai Điệu Êm Dịu',
  artist: 'Nhiều nghệ sĩ',
  thumbnail: '',
  kind: CatalogCollectionKind.playlist,
  externalUrl: '',
);

const _hubHome = CatalogHubHome(
  updatedAt: null,
  featured: [
    CatalogHub(
      id: 'top-100',
      title: 'Top 100',
      description: 'Những playlist được nghe nhiều nhất.',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'new-releases',
      title: 'BXH Nhạc Mới',
      description: 'Các ca khúc mới đang thịnh hành.',
      image: '',
      externalUrl: '',
    ),
  ],
  nations: [
    CatalogHub(
      id: 'viet-nam',
      title: 'Việt Nam',
      description: '',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'au-my',
      title: 'Âu Mỹ',
      description: '',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'han-quoc',
      title: 'Hàn Quốc',
      description: '',
      image: '',
      externalUrl: '',
    ),
  ],
  topics: [
    CatalogHub(
      id: 'ngu-ngon',
      title: 'Ngủ ngon',
      description: 'Giai điệu giúp thả lỏng.',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'workout',
      title: 'Workout',
      description: 'Năng lượng cho từng chuyển động.',
      image: '',
      externalUrl: '',
    ),
    CatalogHub(
      id: 'tap-trung',
      title: 'Tập trung',
      description: 'Không gian cho công việc.',
      image: '',
      externalUrl: '',
    ),
  ],
  genres: [
    CatalogHub(
      id: 'v-pop',
      title: 'V-Pop',
      description: 'Nhạc Việt nổi bật',
      image: '',
      externalUrl: '',
      collections: [
        DiscoveryCollection(
          collection: _sleepCollection,
          description: 'Thả lỏng với những bản nhạc nhẹ nhàng.',
        ),
        DiscoveryCollection(
          collection: CatalogCollection(
            id: 'acoustic-viet',
            title: 'Acoustic Việt Cho Ngày Dịu Dàng',
            artist: 'Nhiều nghệ sĩ',
            thumbnail: '',
            kind: CatalogCollectionKind.playlist,
            externalUrl: '',
          ),
          description: 'Những thanh âm mộc mạc và gần gũi.',
        ),
      ],
    ),
  ],
);

class _ChartGoldenComparator extends LocalFileComparator {
  _ChartGoldenComparator(super.testFile);

  // macOS-generated baselines differ by up to 4.79% on the Ubuntu runner
  // because Skia rasterizes the test font and icons differently. Keep the
  // measured allowance narrow enough that a 5%+ layout change still fails.
  static const _tolerance = 0.05;

  static bool acceptsDiff(double diffPercent) => diffPercent <= _tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || acceptsDiff(result.diffPercent)) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
