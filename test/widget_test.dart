import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/catalog_artist_detail.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/catalog_hub.dart';
import 'package:zmp3chart/models/chart_snapshot.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/live_radio.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/new_release_chart.dart';
import 'package:zmp3chart/models/playback_origin.dart';
import 'package:zmp3chart/models/release_catalog.dart';
import 'package:zmp3chart/models/search_suggestions.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/song_detail.dart';
import 'package:zmp3chart/models/weekly_chart.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/official_content_share_service.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/artist_desktop_overview.dart';
import 'package:zmp3chart/widgets/collection_detail_hero.dart';
import 'package:zmp3chart/widgets/desktop_catalog_sidebar.dart';
import 'package:zmp3chart/widgets/discovery_home_hub.dart';
import 'package:zmp3chart/widgets/release_catalog_view.dart';
import 'package:zmp3chart/widgets/search_discovery_summary.dart';
import 'package:zmp3chart/zing_chart_screen.dart';
import 'package:zmp3chart/zing_mp3_api.dart';

import 'support/fake_playback_audio_player.dart';

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

  testWidgets('shares a chart song from its context menu by public song ID', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final shareService = _RecordingOfficialContentShareService();
    String? requestedSongId;

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            loadSongs: () async => songs,
            loadSongDetail: (songId) async {
              requestedSongId = songId;
              return SongDetail(
                catalogSong: CatalogSong(
                  song: songs.first,
                  duration: const Duration(minutes: 3),
                  externalUrl:
                      'https://zingmp3.vn/bai-hat/mot-bai-hat/one.html',
                  playable: true,
                ),
                artists: const [],
                album: null,
                releasedAt: null,
                distributor: '',
                genres: const [],
                composers: const [],
                listenCount: 0,
                likeCount: 0,
                commentCount: 0,
                mv: null,
                catalogPlaybackEnabled: true,
              );
            },
            officialContentShareService: shareService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('song-action-menu-${songs.first.id}')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('song-action-menu-item-play-${songs.first.id}')),
      findsOneWidget,
    );
    await tester.tap(find.text('Chia sẻ liên kết').last);
    await tester.pumpAndSettle();

    expect(requestedSongId, songs.first.id);
    expect(shareService.contents, hasLength(1));
    expect(shareService.contents.single.kind, OfficialContentKind.song);
    expect(shareService.contents.single.title, songs.first.displayTitle);
    // Let Flutter report the full render tree while diagnosing this state.
  });

  group('Chart filtering', () {
    test('matches title and artist without case sensitivity', () {
      expect(filterSongs(songs, 'nàng'), [songs[1]]);
      expect(filterSongs(songs, 'CA SĨ A'), [songs[0]]);
      expect(filterSongs(songs, 'không có'), isEmpty);
    });
  });

  test('formats release age labels without mutating catalog timestamps', () {
    final now = DateTime(2026, 8, 21, 18);
    expect(releaseAgeLabel(DateTime(2026, 8, 21), now: now), 'Hôm nay');
    expect(releaseAgeLabel(DateTime(2026, 8, 20), now: now), 'Hôm qua');
    expect(releaseAgeLabel(DateTime(2026, 8, 15), now: now), '6 ngày trước');
    expect(releaseAgeLabel(DateTime(2026, 8, 7), now: now), '2 tuần trước');
    expect(releaseAgeLabel(DateTime(2026, 7, 1), now: now), '01/07/2026');
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

  testWidgets('renders chart songs and saves an official search result', (
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
          home: ZingChartScreen(
            loadSongs: () async => songs,
            searchCatalog: (query) async {
              expect(query, 'Hoàng Dũng');
              return CatalogSearchResult(
                query: query,
                catalogPlaybackEnabled: true,
                songs: [
                  CatalogSong(
                    song: songs[1],
                    duration: Duration(minutes: 3, seconds: 42),
                    externalUrl: 'https://zingmp3.vn/bai-hat/nang-tho/two.html',
                    playable: true,
                  ),
                ],
                artists: const [],
              );
            },
          ),
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
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('Một Bài Hát'), findsNothing);
    expect(find.text('Nàng Thơ'), findsWidgets);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Thư viện'), findsWidgets);
    expect(
      find.text('1 BÀI THÍCH · 0 NGHỆ SĨ · 0 ĐÃ LƯU · 0 PLAYLIST'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('library-tab-songs')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('library-liked-songs-hero')),
      findsOneWidget,
    );
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

  testWidgets('debounces catalog search and renders artist plus playable songs', (
    tester,
  ) async {
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (_) async => 'https://example.com/search-song.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    var calls = 0;
    final searchSongs = List.generate(
      8,
      (index) => Song(
        id: index == 0 ? 'search-one' : 'search-${index + 1}',
        name: index == 0 ? 'noi-nay-co-anh' : 'search-${index + 1}',
        title: index == 0 ? 'Nơi Này Có Anh' : 'Bài Tìm Kiếm ${index + 1}',
        thumbnail: '',
        artistsNames: 'Sơn Tùng M-TP',
        code: index == 0 ? 'search-source-one' : 'search-source-${index + 1}',
      ),
    );
    final searchSong = searchSongs.first;
    const searchArtist = CatalogArtist(
      id: 'artist-one',
      name: 'Sơn Tùng M-TP',
      aliasName: 'Son-Tung-M-TP',
      avatar: '',
    );
    const searchCollection = CatalogCollection(
      id: 'search-collection',
      title: 'Những Bài Hát Hay Nhất',
      artist: 'Sơn Tùng M-TP',
      thumbnail: '',
      kind: CatalogCollectionKind.playlist,
      externalUrl:
          'https://zingmp3.vn/album/nhung-bai-hat-hay-nhat/search-collection.html',
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            loadSongs: () async => songs,
            searchCatalog: (query) async {
              calls++;
              expect(query, 'Sơn Tùng');
              return CatalogSearchResult(
                query: 'Sơn Tùng',
                catalogPlaybackEnabled: true,
                songs: searchSongs
                    .map(
                      (song) => CatalogSong(
                        song: song,
                        duration: const Duration(minutes: 4),
                        externalUrl: 'https://zingmp3.vn/link/song/${song.id}',
                        playable: true,
                        artists: const [searchArtist],
                        album: searchCollection,
                      ),
                    )
                    .toList(growable: false),
                artists: const [searchArtist],
                collections: const [searchCollection],
                videos: const [
                  CatalogVideo(
                    id: 'search-video',
                    title: 'Nơi Này Có Anh (MV)',
                    artist: 'Sơn Tùng M-TP',
                    thumbnail: '',
                    duration: Duration(minutes: 4),
                    externalUrl:
                        'https://zingmp3.vn/video-clip/noi-nay/search-video.html',
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chart-search-field')),
      'Sơn Tùng',
    );
    await tester.pump(const Duration(milliseconds: 349));
    expect(calls, 0);
    expect(
      find.byKey(const ValueKey('catalog-search-loading')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(calls, 1);
    expect(find.text('NỔI BẬT'), findsOneWidget);
    expect(find.text('Sơn Tùng M-TP'), findsWidgets);
    expect(find.text('Nơi Này Có Anh'), findsWidgets);
    final catalogScroll = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('search-song-section-header')),
      280,
      scrollable: catalogScroll,
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey('search-song-section-header')),
          )
          .label,
      startsWith('Bài hát, hiển thị 6 trong 8'),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('catalog-search-secondary-sections')),
      320,
      scrollable: catalogScroll,
    );
    expect(
      find.byKey(const ValueKey('catalog-search-secondary-sections')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('search-song-see-all')),
      -320,
      scrollable: catalogScroll,
    );
    expect(find.byKey(const ValueKey('search-song-see-all')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('search-song-see-all')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('catalog-search-secondary-sections')),
      findsNothing,
    );
    expect(find.text('8 bài hát'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('search-8')),
      240,
      scrollable: catalogScroll,
    );
    expect(find.byKey(const ValueKey('search-8')), findsOneWidget);

    final resultTile = find.byKey(const ValueKey('search-one'));
    await tester.scrollUntilVisible(
      resultTile,
      -240,
      scrollable: catalogScroll,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: resultTile, matching: find.byType(InkWell)).first,
    );
    await tester.pumpAndSettle();
    expect(controller.currentSong, searchSong);
  });

  testWidgets(
    'renders Zing-style search suggestions and applies a keyword on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      addTearDown(controller.dispose);
      var suggestionCalls = 0;
      final submittedQueries = <String>[];

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => songs,
              initialTab: 1,
              searchSuggestions: (query) async {
                suggestionCalls++;
                expect(query, 'một');
                return _searchSuggestions(query);
              },
              searchCatalog: (query) async {
                submittedQueries.add(query);
                return CatalogSearchResult.empty(query);
              },
              loadDiscoveryHome: () async => const DiscoveryHome.empty(),
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

      expect(suggestionCalls, 1);
      expect(
        find.byKey(const ValueKey('search-suggestion-dropdown')),
        findsOneWidget,
      );
      expect(find.text('một bài hát'), findsOneWidget);
      expect(find.text('Tìm kiếm “một”'), findsOneWidget);
      expect(find.text('GỢI Ý KẾT QUẢ'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('search-suggestion-dropdown')),
          matching: find.text('Một Bài Hát'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('search-keyword-0')));
      await tester.pumpAndSettle();

      expect(submittedQueries, ['một bài hát']);
      expect(
        find.byKey(const ValueKey('search-suggestion-dropdown')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'opens a playable autocomplete song detail before explicit playback',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
        sourceResolver: (_) async => 'https://audio.example.com/suggestion.mp3',
      );
      await controller.initialize();
      addTearDown(controller.dispose);
      String? requestedSongId;

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => songs,
              initialTab: 1,
              searchSuggestions: (query) async => _searchSuggestions(query),
              searchCatalog: (query) async => CatalogSearchResult.empty(query),
              loadSongDetail: (songId) async {
                requestedSongId = songId;
                return _suggestionSongDetail(
                  id: songId,
                  title: 'Một Bài Hát',
                  playable: true,
                );
              },
              loadDiscoveryHome: () async => const DiscoveryHome.empty(),
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

      await tester.tap(
        find.byKey(const ValueKey('search-suggestion-song-suggestion-one')),
      );
      await tester.pumpAndSettle();

      expect(requestedSongId, 'suggestion-one');
      expect(find.byKey(const ValueKey('song-detail-scroll')), findsOneWidget);
      expect(find.text('PHÁT ĐƯỢC'), findsOneWidget);
      expect(find.byKey(const ValueKey('song-detail-play')), findsOneWidget);
      expect(controller.currentSong, isNull);

      await tester.tap(find.byKey(const ValueKey('song-detail-play')));
      await tester.pumpAndSettle();
      expect(controller.currentSong?.id, 'suggestion-one');
      expect(controller.playbackOrigin.kind, PlaybackOriginKind.search);
      expect(controller.playbackOrigin.label, 'Gợi ý tìm kiếm · Zing MP3');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keeps a restricted autocomplete song informative but not playable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => songs,
              initialTab: 1,
              searchSuggestions: (query) async => _searchSuggestions(query),
              searchCatalog: (query) async => CatalogSearchResult.empty(query),
              loadSongDetail: (songId) async => _suggestionSongDetail(
                id: songId,
                title: 'Một Bài Hát',
                playable: false,
              ),
              loadDiscoveryHome: () async => const DiscoveryHome.empty(),
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
      await tester.tap(
        find.byKey(const ValueKey('search-suggestion-song-suggestion-one')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('song-detail-scroll')), findsOneWidget);
      expect(find.text('BỊ GIỚI HẠN'), findsOneWidget);
      expect(find.byKey(const ValueKey('song-detail-play')), findsNothing);
      expect(controller.currentSong, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ignores stale autocomplete detail and reports the latest failure',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      addTearDown(controller.dispose);
      final first = Completer<SongDetail>();
      final second = Completer<SongDetail>();
      final requests = <String>[];
      const suggestions = SearchSuggestionSnapshot(
        query: 'gợi ý',
        keywords: [],
        songs: [
          SearchSuggestionSong(
            id: 'first-suggestion',
            title: 'Bài Thứ Nhất',
            artist: 'Ca Sĩ A',
            thumbnail: '',
            duration: Duration(minutes: 3),
            externalUrl:
                'https://zingmp3.vn/bai-hat/bai-thu-nhat/first-suggestion.html',
          ),
          SearchSuggestionSong(
            id: 'second-suggestion',
            title: 'Bài Thứ Hai',
            artist: 'Ca Sĩ B',
            thumbnail: '',
            duration: Duration(minutes: 4),
            externalUrl:
                'https://zingmp3.vn/bai-hat/bai-thu-hai/second-suggestion.html',
          ),
        ],
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => songs,
              initialTab: 1,
              searchSuggestions: (_) async => suggestions,
              searchCatalog: (query) async => CatalogSearchResult.empty(query),
              loadSongDetail: (songId) {
                requests.add(songId);
                return songId == 'first-suggestion'
                    ? first.future
                    : second.future;
              },
              loadDiscoveryHome: () async => const DiscoveryHome.empty(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('chart-search-field')),
        'gợi ý',
      );
      await tester.pump(const Duration(milliseconds: 140));
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('search-suggestion-song-first-suggestion')),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await tester.tap(
        find.byKey(const ValueKey('search-suggestion-song-second-suggestion')),
      );
      await tester.pump();
      expect(requests, ['first-suggestion', 'second-suggestion']);

      first.complete(
        _suggestionSongDetail(
          id: 'first-suggestion',
          title: 'Bài Thứ Nhất',
          playable: true,
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('song-detail-scroll')), findsNothing);

      second.completeError(Exception('upstream unavailable'));
      await tester.pump();
      expect(
        find.textContaining('Chưa mở được thông tin Bài Thứ Hai'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('song-detail-scroll')), findsNothing);
      expect(controller.currentSong, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('renders official lyric metadata and opens an MV externally', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final opened = <Uri>[];

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            loadSongs: () async => songs,
            initialTab: 1,
            searchCatalog: (_) async => const CatalogSearchResult(
              query: 'chúng ta',
              catalogPlaybackEnabled: true,
              songs: [
                CatalogSong(
                  song: Song(
                    id: 'lyric-song',
                    name: 'lyric-song',
                    title: 'Chúng Ta Không Thuộc Về Nhau',
                    thumbnail: '',
                    artistsNames: 'Sơn Tùng M-TP',
                    code: 'lyric-song',
                  ),
                  duration: Duration(minutes: 3, seconds: 53),
                  externalUrl:
                      'https://zingmp3.vn/bai-hat/chung-ta/lyric-song.html',
                  playable: true,
                  hasLyrics: true,
                ),
              ],
              artists: [],
              videos: [
                CatalogVideo(
                  id: 'video-one',
                  title: 'Chúng Ta Không Thuộc Về Nhau (MV)',
                  artist: 'Sơn Tùng M-TP',
                  thumbnail: '',
                  duration: Duration(minutes: 4, seconds: 2),
                  externalUrl:
                      'https://zingmp3.vn/video-clip/chung-ta/video-one.html',
                ),
              ],
            ),
            launchExternalCatalog: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chart-search-field')),
      'chúng ta',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('CÓ LỜI'), findsOneWidget);
    expect(find.text('MV'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    final videoTab = find.byKey(const ValueKey('search-section-videos'));
    await tester.ensureVisible(videoTab);
    await tester.pumpAndSettle();
    await tester.tap(videoTab);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('catalog-video-video-one')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('lyric-song')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('catalog-video-video-one')));
    await tester.pumpAndSettle();

    expect(opened, [
      Uri.parse('https://zingmp3.vn/video-clip/chung-ta/video-one.html'),
    ]);
    expect(
      find.byKey(const ValueKey('catalog-video-handoff-dialog')),
      findsNothing,
    );
  });

  testWidgets('uses the QR handoff for MV on TV without launching a browser', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    var launchCalls = 0;

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            loadSongs: () async => songs,
            initialTab: 1,
            tvMode: true,
            searchCatalog: (_) async => const CatalogSearchResult(
              query: 'mv',
              catalogPlaybackEnabled: true,
              songs: [],
              artists: [],
              videos: [
                CatalogVideo(
                  id: 'tv-video',
                  title: 'MV phòng khách',
                  artist: 'Nghệ sĩ TV',
                  thumbnail: '',
                  duration: Duration(minutes: 4),
                  externalUrl:
                      'https://zingmp3.vn/video-clip/phong-khach/tv-video.html',
                ),
              ],
            ),
            launchExternalCatalog: (_) async {
              launchCalls++;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chart-search-field')),
      'mv',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    final videoTab = find.byKey(const ValueKey('search-section-videos'));
    await tester.ensureVisible(videoTab);
    await tester.pumpAndSettle();
    await tester.tap(videoTab);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catalog-video-tv-video')));
    await tester.pumpAndSettle();

    expect(launchCalls, 0);
    expect(
      find.byKey(const ValueKey('catalog-video-handoff-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('catalog-video-qr')), findsOneWidget);
    expect(
      find.text(
        'Quét mã để mở MV trên Zing MP3. #zingChart chỉ bàn giao liên kết chính thức, không tải hoặc lưu video.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(1440, 900), const Size(1920, 1080)]) {
    testWidgets(
      'search suggestions support keyboard selection without overflow at '
      '${size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: MemoryLibraryRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        addTearDown(controller.dispose);
        final submittedQueries = <String>[];

        await tester.pumpWidget(
          MusicPlayerScope(
            controller: controller,
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: ZingChartScreen(
                loadSongs: () async => songs,
                initialTab: 1,
                tvMode: size.width >= 1900,
                searchSuggestions: (query) async => _searchSuggestions(query),
                searchCatalog: (query) async {
                  submittedQueries.add(query);
                  return CatalogSearchResult.empty(query);
                },
                loadDiscoveryHome: () async => const DiscoveryHome.empty(),
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

        if (size.width == 1440) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          expect(
            find.byKey(const ValueKey('search-suggestion-dropdown')),
            findsNothing,
          );
          await tester.tap(find.byKey(const ValueKey('chart-search-field')));
          await tester.pump();
          expect(
            find.byKey(const ValueKey('search-suggestion-dropdown')),
            findsOneWidget,
          );
        }

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(submittedQueries, ['một bài hát']);
        expect(
          find.byKey(const ValueKey('search-suggestion-dropdown')),
          findsNothing,
        );
      },
    );
  }

  testWidgets(
    'TV keyboard opens an autocomplete song detail without autoplay',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      addTearDown(controller.dispose);
      String? requestedSongId;

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => songs,
              initialTab: 1,
              tvMode: true,
              searchSuggestions: (query) async => _searchSuggestions(query),
              searchCatalog: (query) async => CatalogSearchResult.empty(query),
              loadSongDetail: (songId) async {
                requestedSongId = songId;
                return _suggestionSongDetail(
                  id: songId,
                  title: 'Một Bài Hát',
                  playable: true,
                );
              },
              loadDiscoveryHome: () async => const DiscoveryHome.empty(),
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

      for (var index = 0; index < 5; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(requestedSongId, 'suggestion-one');
      expect(find.byKey(const ValueKey('song-detail-scroll')), findsOneWidget);
      expect(find.byKey(const ValueKey('song-detail-play')), findsOneWidget);
      expect(controller.currentSong, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ignores stale search suggestion responses', (tester) async {
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final first = Completer<SearchSuggestionSnapshot>();
    final second = Completer<SearchSuggestionSnapshot>();

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            loadSongs: () async => songs,
            initialTab: 1,
            searchSuggestions: (query) =>
                query == 'first' ? first.future : second.future,
            searchCatalog: (query) async => CatalogSearchResult.empty(query),
            loadDiscoveryHome: () async => const DiscoveryHome.empty(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('chart-search-field'));

    await tester.enterText(field, 'first');
    await tester.pump(const Duration(milliseconds: 140));
    await tester.enterText(field, 'second');
    await tester.pump(const Duration(milliseconds: 140));
    second.complete(_searchSuggestions('second', keyword: 'second result'));
    await tester.pump();
    first.complete(_searchSuggestions('first', keyword: 'stale result'));
    await tester.pump();

    expect(find.text('second result'), findsOneWidget);
    expect(find.text('stale result'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters artist results and opens the in-shell artist profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    var artistDetailCalls = 0;
    final launchedVideos = <Uri>[];
    final shareService = _RecordingOfficialContentShareService();
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    addTearDown(controller.dispose);
    const artist = CatalogArtist(
      id: 'artist-profile',
      name: 'Sơn Tùng M-TP',
      aliasName: 'Son-Tung-M-TP',
      avatar: '',
    );
    const artistSong = Song(
      id: 'artist-song',
      name: 'artist-song',
      title: 'Nơi Này Có Anh',
      thumbnail: '',
      artistsNames: 'Sơn Tùng M-TP',
      code: 'artist-song-code',
    );
    const result = CatalogSearchResult(
      query: 'Sơn Tùng M-TP',
      catalogPlaybackEnabled: true,
      songs: [
        CatalogSong(
          song: artistSong,
          duration: Duration(minutes: 4),
          externalUrl: '',
          playable: true,
        ),
      ],
      artists: [artist],
    );
    const artistCollection = CatalogCollection(
      id: 'artist-single',
      title: 'Chúng Ta Của Tương Lai',
      artist: 'Sơn Tùng M-TP',
      thumbnail: '',
      kind: CatalogCollectionKind.album,
      externalUrl: 'https://zingmp3.vn/link/album/artist-single',
    );
    const artistVideo = CatalogVideo(
      id: 'artist-mv',
      title: 'Chúng Ta Của Tương Lai',
      artist: 'Sơn Tùng M-TP',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 37),
      externalUrl:
          'https://zingmp3.vn/video-clip/chung-ta-cua-tuong-lai/artist-mv.html',
    );
    const artistDetail = CatalogArtistDetail(
      artist: artist,
      cover: '',
      biography: 'Nghệ sĩ V-Pop với nhiều ca khúc nổi bật.',
      realName: 'Nguyễn Thanh Tùng',
      national: 'Việt Nam',
      birthday: '05/07/1994',
      totalFollow: 2655838,
      awardCount: 1,
      songs: [
        CatalogSong(
          song: artistSong,
          duration: Duration(minutes: 4),
          externalUrl: '',
          playable: true,
          artists: [artist],
          album: artistCollection,
        ),
      ],
      videos: [artistVideo],
      collectionSections: [
        CatalogArtistCollectionSection(
          id: 'aSingle-1',
          title: 'Single & EP',
          collections: [artistCollection],
        ),
      ],
      relatedArtists: [
        CatalogArtist(
          id: 'related-artist',
          name: 'MONO',
          aliasName: 'MONO-Nguyen-Viet-Hoang',
          avatar: '',
        ),
      ],
      catalogPlaybackEnabled: true,
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            loadSongs: () async => songs,
            initialTab: 1,
            searchCatalog: (_) async {
              calls++;
              return result;
            },
            loadArtistDetail: (_) async {
              artistDetailCalls++;
              return artistDetail;
            },
            loadCollection: (_) async => const CatalogCollectionDetail(
              collection: artistCollection,
              description: 'Single chính thức',
              year: '2024',
              genres: ['V-Pop'],
              songs: [
                CatalogSong(
                  song: artistSong,
                  duration: Duration(minutes: 4),
                  externalUrl: '',
                  playable: true,
                ),
              ],
              catalogPlaybackEnabled: true,
            ),
            launchExternalCatalog: (uri) async {
              launchedVideos.add(uri);
              return true;
            },
            officialContentShareService: shareService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chart-search-field')),
      'Sơn Tùng',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    final artistSection = find.byKey(const ValueKey('search-section-artists'));
    await tester.ensureVisible(artistSection);
    await tester.pump();
    await tester.tap(artistSection);
    await tester.pump();
    expect(find.text('NGHỆ SĨ/OA'), findsWidgets);
    expect(find.byKey(const ValueKey('artist-song')), findsNothing);

    final artistCard = find.byKey(
      const ValueKey('catalog-artist-artist-profile'),
    );
    await tester.ensureVisible(artistCard);
    await tester.tap(artistCard);
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(artistDetailCalls, 1);
    expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
    expect(find.text('BÀI HÁT NỔI BẬT'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('artist-link-artist-profile')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('artist-link-artist-profile')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('artist-link-artist-profile')));
    await tester.pumpAndSettle();
    expect(artistDetailCalls, 1);
    expect(find.byKey(const ValueKey('artist-play-button')), findsOneWidget);
    expect(find.text('QUAN TÂM'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('artist-follow-button')));
    await tester.pump();
    expect(controller.isArtistFollowed(artist), isTrue);
    expect(find.text('ĐANG QUAN TÂM'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('artist-share-button')));
    await tester.pumpAndSettle();
    expect(shareService.contents.single.kind, OfficialContentKind.artist);
    expect(
      shareService.contents.single.externalUrl,
      'https://zingmp3.vn/nghe-si/Son-Tung-M-TP',
    );
    expect(find.textContaining('2.7 TR NGƯỜI QUAN TÂM'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('artist-profile-catalog')),
      360,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(const ValueKey('artist-collection-artist-single')),
      findsOneWidget,
    );
    final artistVideoCard = find.byKey(
      const ValueKey('artist-video-artist-mv'),
    );
    await tester.ensureVisible(artistVideoCard);
    await tester.pump();
    await tester.tap(artistVideoCard);
    await tester.pumpAndSettle();
    expect(launchedVideos, [Uri.parse(artistVideo.externalUrl)]);
    expect(controller.currentSong, isNull);
    expect(
      find.byKey(const ValueKey('related-artist-related-artist')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('artist-biography')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final artistCollectionCard = find.byKey(
      const ValueKey('artist-collection-artist-single'),
    );
    await tester.ensureVisible(artistCollectionCard);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('artist-collection-save-artist-single')),
    );
    await tester.pump();
    expect(controller.isCollectionSaved(artistCollection), isTrue);
    expect(find.byKey(const ValueKey('collection-detail-hero')), findsNothing);
    expect(artistCollectionCard, findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('artist-collection-more-artist-single')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('artist-collection-menu-share-artist-single')),
    );
    await tester.pumpAndSettle();
    expect(shareService.contents, hasLength(2));
    expect(shareService.contents.last.kind, OfficialContentKind.collection);
    expect(
      shareService.contents.last.externalUrl,
      artistCollection.externalUrl,
    );
    expect(find.byKey(const ValueKey('collection-detail-hero')), findsNothing);
    expect(artistCollectionCard, findsOneWidget);
    final artistCollectionRect = tester.getRect(artistCollectionCard);
    await tester.tapAt(
      Offset(artistCollectionRect.center.dx, artistCollectionRect.bottom - 18),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collection-detail-hero')),
      findsOneWidget,
    );
    final collectionMore = find.byKey(const ValueKey('collection-more-button'));
    await tester.ensureVisible(collectionMore);
    await tester.pump();
    await tester.tap(collectionMore);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('collection-hero-menu-share-artist-single')),
    );
    await tester.pumpAndSettle();
    expect(shareService.contents, hasLength(3));
    expect(shareService.contents.last.kind, OfficialContentKind.collection);
    expect(
      shareService.contents.last.externalUrl,
      artistCollection.externalUrl,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('artist-profile-hero')), findsNothing);
    expect(
      find.byKey(const ValueKey('search-section-artists')),
      findsOneWidget,
    );

    await tester.tap(find.text('Thư viện').last);
    await tester.pumpAndSettle();
    final followedArtist = find.byKey(
      const ValueKey('followed-artist-artist-profile'),
    );
    await tester.ensureVisible(followedArtist);
    await tester.pumpAndSettle();
    expect(followedArtist, findsOneWidget);
    await tester.tap(followedArtist);
    await tester.pumpAndSettle();
    expect(artistDetailCalls, 2);
    expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
    expect(find.text('ĐANG QUAN TÂM'), findsOneWidget);
  });

  for (final configuration in [
    (size: const Size(768, 1024), tvMode: false),
    (size: const Size(1180, 900), tvMode: false),
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'artist profile is adaptive at ${configuration.size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = configuration.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          libraryRepository: MemoryLibraryRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        addTearDown(controller.dispose);
        final launchedVideos = <Uri>[];

        await tester.pumpWidget(
          MusicPlayerScope(
            controller: controller,
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: ZingChartScreen(
                loadSongs: () async => _responsiveArtistSongs,
                loadArtistDetail: (_) async => _responsiveArtistDetail,
                loadCollection: (_) async => const CatalogCollectionDetail(
                  collection: _responsiveArtistAlbum,
                  description: 'Album chính thức của nghệ sĩ',
                  year: '2024',
                  genres: ['V-Pop'],
                  artists: [_responsiveArtist],
                  songs: [
                    CatalogSong(
                      song: _responsiveArtistSong,
                      duration: Duration(minutes: 4),
                      externalUrl: '',
                      playable: true,
                      artists: [_responsiveArtist],
                      album: _responsiveArtistAlbum,
                    ),
                  ],
                  catalogPlaybackEnabled: true,
                ),
                initialArtist: _responsiveArtist,
                tvMode: configuration.tvMode,
                launchExternalCatalog: (uri) async {
                  launchedVideos.add(uri);
                  return true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('artist-profile-hero')),
          findsOneWidget,
        );
        if (configuration.size.width >= 1180 && !configuration.tvMode) {
          final hero = find.byKey(const ValueKey('artist-profile-hero'));
          final heroRect = tester.getRect(hero);
          expect(
            find.byKey(const ValueKey('artist-desktop-overview')),
            findsOneWidget,
          );
          expect(
            find.byKey(
              const ValueKey('artist-latest-release-responsive-album'),
            ),
            findsOneWidget,
          );
          expect(find.text('Mới Phát Hành'), findsOneWidget);
          expect(find.text('Bài Hát Nổi Bật'), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(
                const ValueKey('artist-latest-release-responsive-album'),
              ),
              matching: find.text('Single & EP'),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('artist-desktop-title-row')),
            findsOneWidget,
          );
          if (configuration.size.width == 1440) {
            expect(heroRect.left, closeTo(238, 1));
            expect(heroRect.right, closeTo(1440, 1));
          }
          final playButton = find.byKey(const ValueKey('artist-play-button'));
          expect(tester.getSize(playButton), const Size.square(56));
          expect(
            find.descendant(of: hero, matching: find.text('PHÁT NHẠC')),
            findsNothing,
          );
          expect(find.textContaining('2.7 TR người quan tâm'), findsOneWidget);
          if (configuration.size.width == 1440) {
            final overview = find.byKey(
              const ValueKey('artist-desktop-overview'),
            );
            for (final duration in ['4:00', '3:30', '4:08']) {
              expect(
                find.descendant(of: overview, matching: find.text(duration)),
                findsOneWidget,
              );
            }
            expect(
              find.text(_responsiveArtistLockedSong.displayTitle),
              findsOneWidget,
            );
            await tester.tap(
              find.byKey(
                const ValueKey(
                  'song-action-menu-responsive-artist-featured-locked',
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.byKey(
                const ValueKey(
                  'song-action-menu-item-detail-responsive-artist-featured-locked',
                ),
              ),
              findsOneWidget,
            );
            expect(
              find.byKey(
                const ValueKey(
                  'song-action-menu-item-play-responsive-artist-featured-locked',
                ),
              ),
              findsNothing,
            );
            expect(
              find.byKey(
                const ValueKey(
                  'song-action-menu-item-queue-responsive-artist-featured-locked',
                ),
              ),
              findsNothing,
            );
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('responsive-artist-featured-locked')),
            );
            await tester.pumpAndSettle();
            expect(controller.currentSong, isNull);
            expect(controller.queue, isEmpty);

            await tester.tap(
              find.byKey(const ValueKey('responsive-artist-song')),
            );
            await tester.pumpAndSettle();
            expect(controller.currentSong?.id, _responsiveArtistSong.id);
            expect(controller.queue.map((song) => song.id), [
              _responsiveArtistSong.id,
              _responsiveArtistSongTwo.id,
            ]);
            expect(
              find.byKey(const ValueKey('artist-desktop-songs-show-all')),
              findsOneWidget,
            );
            expect(
              find.text(_responsiveArtistSongFour.displayTitle),
              findsNothing,
            );
            await tester.tap(
              find.byKey(const ValueKey('artist-desktop-songs-show-all')),
            );
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('artist-desktop-overview')),
              findsNothing,
            );
            expect(find.text('TẤT CẢ BÀI HÁT'), findsOneWidget);
            expect(
              find.text(_responsiveArtistSongFour.displayTitle),
              findsOneWidget,
            );
            await tester.tap(
              find.byKey(const ValueKey('catalog-history-back')).first,
            );
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('artist-desktop-overview')),
              findsOneWidget,
            );
          }
        } else {
          expect(
            find.byKey(const ValueKey('artist-desktop-overview')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('artist-desktop-title-row')),
            findsNothing,
          );
          expect(find.text('PHÁT NHẠC'), findsOneWidget);
        }
        expect(
          find.byKey(const ValueKey('artist-follow-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('artist-link-responsive-artist')),
          findsWidgets,
        );
        if (configuration.size.width >= 1180) {
          final albumLink = find.byKey(
            const ValueKey('song-album-link-responsive-artist-song'),
          );
          if (!configuration.tvMode) {
            expect(albumLink, findsNothing);
          } else {
            expect(albumLink, findsOneWidget);
            expect(find.textContaining('4:00'), findsOneWidget);
          }
          if (!configuration.tvMode) {
            if (configuration.size.width >= 1180) {
              await tester.tap(
                find.byKey(
                  const ValueKey('artist-latest-release-responsive-album'),
                ),
              );
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('collection-detail-hero')),
                findsOneWidget,
              );
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pumpAndSettle();
              expect(
                find.byKey(const ValueKey('artist-desktop-overview')),
                findsOneWidget,
              );
            }
          }
        }
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('artist-profile-catalog')),
          520,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          find.byKey(const ValueKey('artist-collection-responsive-album')),
          findsOneWidget,
        );
        final videoCard = find.byKey(
          const ValueKey('artist-video-responsive-mv'),
        );
        expect(videoCard, findsOneWidget);
        await tester.drag(
          find.byType(CustomScrollView),
          Offset(0, configuration.tvMode ? -620 : -460),
        );
        await tester.pumpAndSettle();
        if (configuration.tvMode) {
          var focused = _primaryFocusIsInside(videoCard);
          for (var index = 0; index < 60 && !focused; index++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            focused = _primaryFocusIsInside(videoCard);
          }
          expect(focused, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        } else {
          await tester.tap(videoCard);
        }
        await tester.pumpAndSettle();
        if (configuration.tvMode) {
          expect(launchedVideos, isEmpty);
          expect(
            find.byKey(const ValueKey('catalog-video-handoff-dialog')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('catalog-video-qr')),
            findsOneWidget,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        } else {
          expect(launchedVideos, [
            Uri.parse(_responsiveArtistDetail.videos.single.externalUrl),
          ]);
        }
        expect(
          find.byKey(const ValueKey('related-artist-responsive-related')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'artist latest release keeps its focus treatment after pointer exit',
    (tester) async {
      tester.view.physicalSize = const Size(1180, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: ArtistDesktopOverview(
              latestRelease: _responsiveArtistAlbum,
              releaseLabel: 'Single & EP',
              featuredSongs: const [],
              totalSongCount: 0,
              songBuilder: (_, _) => const SizedBox.shrink(),
              onReleaseTap: () {},
              onShowAllSongs: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(
        const ValueKey('artist-latest-release-responsive-album'),
      );
      var focused = _primaryFocusIsInside(card);
      for (var step = 0; step < 6 && !focused; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        focused = _primaryFocusIsInside(card);
      }
      expect(focused, isTrue);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(tester.getCenter(card));
      await tester.pumpAndSettle();
      await mouse.moveTo(const Offset(1, 1));
      await tester.pumpAndSettle();
      addTearDown(mouse.removePointer);

      expect(_primaryFocusIsInside(card), isTrue);
      final surface = tester.widget<AnimatedContainer>(
        find.byKey(
          const ValueKey('artist-latest-release-surface-responsive-album'),
        ),
      );
      final decoration = surface.decoration! as BoxDecoration;
      expect((decoration.border! as Border).top.color, ZingColors.lime);
    },
  );

  testWidgets('Escape closes the desktop player before leaving an artist', (
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
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            loadSongs: () async => _responsiveArtistSongs,
            loadArtistDetail: (_) async => _responsiveArtistDetail,
            chartRefreshInterval: null,
            initialArtist: _responsiveArtist,
            initialDesktopQueueVisible: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('desktop-close-player-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('artist-desktop-overview')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('desktop-close-player-panel')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('artist-desktop-overview')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('artist-desktop-overview')), findsNothing);
  });

  testWidgets(
    'opens playlist detail and preserves a playable collection queue',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var detailCalls = 0;
      var artistDetailCalls = 0;
      final audioPlayer = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audioPlayer,
        sourceResolver: (_) async => 'https://audio.example.com/collection.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      addTearDown(controller.dispose);
      const collection = CatalogCollection(
        id: 'playlist-profile',
        title: 'Gợi ý cũ',
        artist: 'Nghệ sĩ cũ',
        thumbnail: '',
        kind: CatalogCollectionKind.playlist,
        externalUrl: '',
      );
      const authoritativeCollection = CatalogCollection(
        id: 'playlist-profile',
        title: 'Album chính thức',
        artist: 'Sơn Tùng M-TP',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: '',
      );
      const collectionArtist = CatalogArtist(
        id: 'son-tung-mtp',
        name: 'Sơn Tùng M-TP',
        aliasName: 'Son-Tung-M-TP',
        avatar: '',
        totalFollow: 2600000,
      );
      const collectionSong = Song(
        id: 'collection-song',
        name: 'collection-song',
        title: 'Âm Thầm Bên Em',
        thumbnail: '',
        artistsNames: 'Sơn Tùng M-TP',
        code: 'collection-song-code',
      );
      const catalogSong = CatalogSong(
        song: collectionSong,
        duration: Duration(minutes: 4, seconds: 51),
        externalUrl: '',
        playable: true,
        artists: [collectionArtist],
        album: authoritativeCollection,
      );
      const restrictedSong = Song(
        id: 'restricted-collection-song',
        name: 'restricted-collection-song',
        title: 'Bài hát giới hạn',
        thumbnail: '',
        artistsNames: 'Sơn Tùng M-TP',
        code: 'restricted-code',
      );
      const secondPlayableSong = Song(
        id: 'second-collection-song',
        name: 'second-collection-song',
        title: 'Chúng Ta Không Thuộc Về Nhau',
        thumbnail: '',
        artistsNames: 'Sơn Tùng M-TP',
        code: 'second-playable-code',
      );
      const collectionSongs = [
        catalogSong,
        CatalogSong(
          song: restrictedSong,
          duration: Duration(minutes: 4),
          externalUrl: '',
          playable: false,
        ),
        CatalogSong(
          song: secondPlayableSong,
          duration: Duration(minutes: 3, seconds: 53),
          externalUrl: '',
          playable: true,
        ),
      ];
      const result = CatalogSearchResult(
        query: 'Sơn Tùng',
        catalogPlaybackEnabled: true,
        songs: [catalogSong],
        artists: [],
        collections: [collection],
      );
      final detail = CatalogCollectionDetail(
        collection: authoritativeCollection,
        artists: [collectionArtist],
        description: 'Sơn Tùng M-TP và bộ sưu tập siêu Hit',
        year: '2017',
        releasedAt: DateTime.utc(2017, 4, 1),
        distributor: 'VIVI ENM',
        likeCount: 2200000,
        genres: ['V-Pop'],
        songs: collectionSongs,
        sections: [
          CatalogCollectionSection(
            id: 'appears-in',
            title: 'Sơn Tùng M-TP Xuất Hiện Trong',
            collections: [collection],
          ),
        ],
        catalogPlaybackEnabled: true,
      );
      const artistDetail = CatalogArtistDetail(
        artist: collectionArtist,
        cover: '',
        biography: 'Nghệ sĩ V-Pop Việt Nam.',
        realName: 'Nguyễn Thanh Tùng',
        national: 'Việt Nam',
        birthday: '05/07/1994',
        totalFollow: 2655838,
        awardCount: 1,
        songs: [catalogSong],
        collectionSections: [],
        relatedArtists: [],
        catalogPlaybackEnabled: true,
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => songs,
              initialTab: 1,
              searchCatalog: (_) async => result,
              loadCollection: (_) async {
                detailCalls++;
                return detail;
              },
              loadArtistDetail: (_) async {
                artistDetailCalls++;
                return artistDetail;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('chart-search-field')),
        'Sơn Tùng',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      final collectionSection = find.byKey(
        const ValueKey('search-section-collections'),
      );
      await tester.ensureVisible(collectionSection);
      await tester.tap(collectionSection);
      await tester.pump();
      expect(find.text('PLAYLIST/ALBUM'), findsWidgets);
      expect(find.byKey(const ValueKey('collection-song')), findsNothing);

      final collectionCard = find.byKey(
        const ValueKey('catalog-collection-playlist-profile'),
      );
      await tester.ensureVisible(collectionCard);
      await tester.tap(collectionCard);
      await tester.pumpAndSettle();

      expect(detailCalls, 1);
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      expect(find.text('DANH SÁCH BÀI HÁT'), findsOneWidget);
      expect(find.byKey(const ValueKey('collection-song')), findsOneWidget);
      expect(find.text('3 bài hát'), findsWidgets);
      expect(find.text('Album chính thức'), findsWidgets);
      expect(find.text('ALBUM'), findsOneWidget);
      expect(find.textContaining('2.2M NGƯỜI YÊU THÍCH'), findsOneWidget);
      expect(find.text('Gợi ý cũ'), findsNothing);
      expect(
        find.byKey(const ValueKey('artist-link-son-tung-mtp')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collection-play-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collection-save-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collection-more-button')),
        findsOneWidget,
      );
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      final desktopHero = find.byKey(const ValueKey('collection-detail-hero'));
      final desktopOverview = find.byKey(
        const ValueKey('collection-desktop-overview'),
      );
      expect(desktopOverview, findsOneWidget);
      expect(
        find.byKey(const ValueKey('collection-desktop-table-header')),
        findsOneWidget,
      );
      expect(find.text('BÀI HÁT · 3'), findsOneWidget);
      expect(find.textContaining('Cập nhật: 01/04/2017'), findsOneWidget);
      expect(
        tester.getRect(desktopHero).right,
        lessThanOrEqualTo(tester.getRect(desktopOverview).left),
      );
      expect(find.text('4:51'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('collection-detail-catalog')),
        findsOneWidget,
      );
      expect(find.text('VIVI ENM'), findsOneWidget);
      expect(find.text('Sơn Tùng M-TP Xuất Hiện Trong'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();

      final artistLink = find.byKey(const ValueKey('artist-link-son-tung-mtp'));
      await tester.ensureVisible(artistLink);
      await tester.pumpAndSettle();
      await tester.tap(artistLink);
      await tester.pumpAndSettle();
      expect(artistDetailCalls, 1);
      expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsNothing,
      );
      expect(controller.currentSong, isNull);
      expect(controller.queue, isEmpty);

      await tester.tap(find.byKey(const ValueKey('artist-back-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      expect(find.text('Album chính thức'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('collection-save-button')));
      await tester.pump();
      expect(controller.isCollectionSaved(authoritativeCollection), isTrue);
      expect(find.byTooltip('Bỏ lưu'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('collection-play-button')));
      await tester.pumpAndSettle();
      expect(controller.currentSong, collectionSong);
      expect(controller.queue, [collectionSong, secondPlayableSong]);
      expect(controller.playbackOrigin.label, 'Album chính thức');
      expect(audioPlayer.playedSources, hasLength(1));
      expect(find.text('Âm Thầm Bên Em'), findsWidgets);
      expect(find.text('ĐANG PHÁT TỪ'), findsOneWidget);
      expect(find.text('Album chính thức'), findsWidgets);

      await tester.tap(find.byTooltip('Quay lại bảng xếp hạng'));
      await tester.pumpAndSettle();
      expect(controller.currentSong, collectionSong);
      expect(controller.queue, [collectionSong, secondPlayableSong]);

      await tester.tap(find.byKey(const ValueKey('collection-back-button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('search-section-collections')),
        findsOneWidget,
      );

      await tester.tap(find.text('Thư viện').last);
      await tester.pumpAndSettle();
      final savedCollection = find.byKey(
        const ValueKey('saved-collection-playlist-profile'),
      );
      await tester.ensureVisible(savedCollection);
      await tester.pumpAndSettle();
      expect(savedCollection, findsOneWidget);
      await tester.tap(savedCollection);
      await tester.pumpAndSettle();
      expect(detailCalls, 2);
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      expect(find.byTooltip('Bỏ lưu'), findsOneWidget);
    },
  );

  testWidgets(
    'loads BXH Nhạc Mới and plays only permitted songs in rank order',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var chartLoadCalls = 0;
      var loadCalls = 0;
      final audioPlayer = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audioPlayer,
        sourceResolver: (_) async =>
            'https://audio.example.com/new-release.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      addTearDown(controller.dispose);
      const first = Song(
        id: 'new-release-one',
        name: 'new-release-one',
        title: 'Thiên Đường Với Người Thương',
        thumbnail: '',
        artistsNames: 'Phương Mỹ Chi, DTAP',
        code: 'new-release-code-one',
      );
      const locked = Song(
        id: 'new-release-locked',
        name: 'new-release-locked',
        title: 'Bài hát giới hạn',
        thumbnail: '',
        artistsNames: 'Nghệ sĩ giới hạn',
        code: 'new-release-locked-code',
      );
      const third = Song(
        id: 'new-release-three',
        name: 'new-release-three',
        title: 'Gái Tây Gốc Việt',
        thumbnail: '',
        artistsNames: 'Nicole Nguyễn',
        code: 'new-release-code-three',
      );
      const chart = NewReleaseChart(
        title: 'BXH Nhạc Mới',
        updatedAt: null,
        catalogPlaybackEnabled: true,
        entries: [
          NewReleaseEntry(
            catalogSong: CatalogSong(
              song: first,
              duration: Duration(minutes: 3, seconds: 38),
              externalUrl: '',
              playable: true,
            ),
            albumTitle: 'Thiên Đường Với Người Thương (Single)',
            rank: 1,
            rankChange: 0,
            releasedAt: null,
          ),
          NewReleaseEntry(
            catalogSong: CatalogSong(
              song: locked,
              duration: Duration(minutes: 4),
              externalUrl: '',
              playable: false,
            ),
            albumTitle: 'Album giới hạn',
            rank: 2,
            rankChange: -1,
            releasedAt: null,
          ),
          NewReleaseEntry(
            catalogSong: CatalogSong(
              song: third,
              duration: Duration(minutes: 3, seconds: 56),
              externalUrl: '',
              playable: true,
            ),
            albumTitle: 'Gái Tây Gốc Việt (Single)',
            rank: 3,
            rankChange: 2,
            releasedAt: null,
          ),
        ],
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async {
                chartLoadCalls++;
                return songs;
              },
              loadNewReleases: () async {
                loadCalls++;
                return chart;
              },
              loadDiscoveryHome: () async => const DiscoveryHome.empty(),
              loadDiscoveryCategories: () async =>
                  const DiscoveryCategories.empty(),
              loadDiscoveryRecommendations: () async =>
                  const DiscoveryRecommendations.empty(),
              loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mobile-nav-discovery')));
      await tester.pumpAndSettle();
      expect(loadCalls, 1);
      final discoveryScroll = find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      final openNewReleaseChart = find.byKey(
        const ValueKey('open-new-release-chart'),
      );
      await tester.scrollUntilVisible(
        openNewReleaseChart,
        240,
        scrollable: discoveryScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(openNewReleaseChart);
      await tester.pumpAndSettle();

      expect(loadCalls, 1);
      expect(find.text('BXH Nhạc Mới'), findsWidgets);
      expect(find.text('3 bài hát'), findsOneWidget);
      expect(find.byKey(const ValueKey('new-release-one')), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsWidgets);
      expect(tester.takeException(), isNull);

      tester.state<ScrollableState>(discoveryScroll).position.jumpTo(0);
      await tester.pump();
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 320),
      );
      await tester.pumpAndSettle();
      expect(loadCalls, 2);
      expect(chartLoadCalls, 1);

      await tester.tap(find.byKey(const ValueKey('new-release-one')));
      await tester.pumpAndSettle();
      expect(controller.currentSong, first);
      expect(controller.queue, [first, third]);
      expect(audioPlayer.playedSources, hasLength(1));
    },
  );

  testWidgets('renders and activates official collection track metadata on TV', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audioPlayer = FakePlaybackAudioPlayer();
    final controller = PlaybackService(
      playbackAudioPlayer: audioPlayer,
      sourceResolver: (_) async => 'https://audio.example.com/tv-track.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    addTearDown(controller.dispose);
    const artist = CatalogArtist(
      id: 'tv-collection-artist',
      name: 'Nghệ sĩ TV',
      aliasName: 'Nghe-Si-TV',
      avatar: '',
    );
    const album = CatalogCollection(
      id: 'tv-collection-album',
      title: 'Album TV chính thức',
      artist: 'Nghệ sĩ TV',
      thumbnail: '',
      kind: CatalogCollectionKind.album,
      externalUrl: '',
    );
    const song = Song(
      id: 'tv-collection-song',
      name: 'tv-collection-song',
      title: 'Bài hát trên TV',
      thumbnail: '',
      artistsNames: 'Nghệ sĩ TV',
      code: 'tv-collection-source',
    );
    const detail = CatalogCollectionDetail(
      collection: album,
      artists: [artist],
      description: 'Metadata collection cho màn hình TV.',
      year: '2026',
      genres: ['V-Pop'],
      songs: [
        CatalogSong(
          song: song,
          duration: Duration(minutes: 4, seconds: 51),
          externalUrl: '',
          playable: true,
          artists: [artist],
          album: album,
        ),
      ],
      catalogPlaybackEnabled: true,
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            tvMode: true,
            loadChart: () async => const ChartSnapshot(songs: [song]),
            loadCollection: (_) async => detail,
            loadArtistDetail: (_) async => const CatalogArtistDetail(
              artist: artist,
              cover: '',
              biography: '',
              realName: '',
              national: '',
              birthday: '',
              totalFollow: 0,
              awardCount: 0,
              songs: [],
              collectionSections: [],
              relatedArtists: [],
              catalogPlaybackEnabled: true,
            ),
            initialOfficialUrl:
                'https://zingmp3.vn/album/album-tv-chinh-thuc/tv-collection-album.html',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const ValueKey('tv-collection-song'));
    expect(row, findsOneWidget);
    expect(
      find.byKey(const ValueKey('artist-link-tv-collection-artist')),
      findsOneWidget,
    );
    expect(find.text('Album TV chính thức'), findsWidgets);
    expect(find.textContaining('4:51'), findsOneWidget);
    expect(tester.takeException(), isNull);

    var focusInsideRow = false;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
      element,
    ) {
      if (element.widget.key == const ValueKey('tv-collection-song')) {
        focusInsideRow = true;
      }
      return !focusInsideRow;
    });
    expect(focusInsideRow, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.currentSong, song);
    expect(audioPlayer.playedSources, hasLength(1));
  });

  testWidgets(
    'opens BXH Tuần, changes region and period, then queues playable songs',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <(WeeklyChartRegion, int?, int?)>[];
      final audioPlayer = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audioPlayer,
        sourceResolver: (_) async => 'https://audio.example.com/weekly.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      addTearDown(controller.dispose);
      const first = Song(
        id: 'weekly-first',
        name: 'weekly-first',
        title: 'Cứ Để Anh Ta Rời Đi',
        thumbnail: '',
        artistsNames: 'Nghệ Sĩ Việt',
        code: 'weekly-first-code',
      );
      const locked = Song(
        id: 'weekly-locked',
        name: 'weekly-locked',
        title: 'Bài Hát Giới Hạn',
        thumbnail: '',
        artistsNames: 'Nghệ Sĩ Giới Hạn',
        code: 'weekly-locked-code',
      );
      const third = Song(
        id: 'weekly-third',
        name: 'weekly-third',
        title: 'Chờ Anh Nhé',
        thumbnail: '',
        artistsNames: 'Nghệ Sĩ Trẻ',
        code: 'weekly-third-code',
      );
      WeeklyChart chartFor(WeeklyChartRegion region, {int? week, int? year}) =>
          WeeklyChart(
            region: region,
            title: 'Bảng Xếp Hạng Tuần',
            week: week ?? 33,
            year: year ?? 2026,
            latestWeek: 33,
            startDate: week == 32 ? '03/08' : '10/08',
            endDate: week == 32 ? '09/08' : '16/08',
            updatedAt: null,
            catalogPlaybackEnabled: true,
            entries: const [
              WeeklyChartEntry(
                catalogSong: CatalogSong(
                  song: first,
                  duration: Duration(minutes: 3, seconds: 45),
                  externalUrl: '',
                  playable: true,
                ),
                albumTitle: 'Album Hạng Nhất',
                rank: 1,
                rankChange: 2,
                score: 2526,
              ),
              WeeklyChartEntry(
                catalogSong: CatalogSong(
                  song: locked,
                  duration: Duration(minutes: 4),
                  externalUrl: '',
                  playable: false,
                ),
                albumTitle: 'Album Giới Hạn',
                rank: 2,
                rankChange: -1,
                score: 2100,
              ),
              WeeklyChartEntry(
                catalogSong: CatalogSong(
                  song: third,
                  duration: Duration(minutes: 3, seconds: 30),
                  externalUrl: '',
                  playable: true,
                ),
                albumTitle: 'Album Mới',
                rank: 3,
                rankChange: 0,
                score: 1800,
              ),
            ],
          );
      const weeklyEntryCollection = CatalogCollection(
        id: 'weekly-entry-collection',
        title: 'Bảng Xếp Hạng Tuần',
        artist: 'Nhiều nghệ sĩ',
        thumbnail: '',
        kind: CatalogCollectionKind.playlist,
        externalUrl: '',
      );
      const discovery = DiscoveryHome(
        updatedAt: null,
        banners: [],
        sections: [
          DiscoverySection(
            id: 'weekly-entry',
            title: 'Khám phá bảng xếp hạng',
            collections: [
              DiscoveryCollection(
                collection: weeklyEntryCollection,
                description: 'Xếp hạng theo từng tuần.',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => songs,
              initialTab: 1,
              loadDiscoveryHome: () async => discovery,
              loadWeeklyChart: (region, {week, year}) async {
                requests.add((region, week, year));
                return chartFor(region, week: week, year: year);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final usukRegion = find.byKey(
        const ValueKey('discovery-weekly-region-usuk'),
      );
      await tester.ensureVisible(usukRegion);
      await tester.pumpAndSettle();
      await tester.tap(usukRegion);
      await tester.pumpAndSettle();
      expect(requests, [(WeeklyChartRegion.usuk, null, null)]);
      expect(find.byKey(const ValueKey('weekly-chart')), findsOneWidget);
      expect(find.text('Tuần 33 (10/08 - 16/08)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      expect(find.byKey(const ValueKey('weekly-region-korea')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('weekly-region-vietnam')));
      await tester.pumpAndSettle();
      expect(requests.last, (WeeklyChartRegion.vietnam, null, null));

      await tester.tap(find.byKey(const ValueKey('weekly-period-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('weekly-period-2026-32')));
      await tester.pumpAndSettle();
      expect(requests.last, (WeeklyChartRegion.vietnam, 32, 2026));
      expect(find.text('Tuần 32 (03/08 - 09/08)'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 360));
      await tester.pumpAndSettle();
      expect(requests.last, (WeeklyChartRegion.vietnam, 32, 2026));

      await tester.tap(find.byKey(const ValueKey('weekly-chart-play-all')));
      await tester.pumpAndSettle();
      expect(controller.currentSong, first);
      expect(controller.queue, [first, third]);
      expect(audioPlayer.playedSources, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loads Discovery Home, refreshes it, and opens a curated collection',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var chartLoadCalls = 0;
      var discoveryLoadCalls = 0;
      var collectionLoadCalls = 0;
      var releaseLoadCalls = 0;
      var newReleaseLoadCalls = 0;
      Uri? launchedVideo;
      final shareService = _RecordingOfficialContentShareService();
      final audioPlayer = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audioPlayer,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      addTearDown(controller.dispose);
      const topCollection = CatalogCollection(
        id: 'discovery-top-100',
        title: 'Top 100 Nhạc Trẻ',
        artist: 'Nhiều nghệ sĩ',
        thumbnail: '',
        kind: CatalogCollectionKind.playlist,
        externalUrl:
            'https://zingmp3.vn/playlist/top-100/discovery-top-100.html',
      );
      const discovery = DiscoveryHome(
        updatedAt: null,
        banners: [
          DiscoveryBanner(
            id: 'discovery-banner-one',
            image: '',
            collection: topCollection,
          ),
          DiscoveryBanner(
            id: 'discovery-banner-two',
            image: '',
            collection: topCollection,
          ),
          DiscoveryBanner(
            id: 'discovery-banner-three',
            image: '',
            collection: topCollection,
          ),
        ],
        videos: [
          CatalogVideo(
            id: 'discovery-mv-one',
            title: 'MV Nổi Bật',
            artist: 'Nghệ sĩ Việt',
            thumbnail: '',
            duration: Duration(minutes: 4, seconds: 5),
            externalUrl:
                'https://zingmp3.vn/video-clip/mv-noi-bat/discovery-mv-one.html',
          ),
        ],
        sections: [
          DiscoverySection(
            id: 'top-100',
            title: 'Top 100',
            collections: [
              DiscoveryCollection(
                collection: topCollection,
                description: 'Các ca khúc được nghe nhiều nhất.',
              ),
            ],
          ),
          DiscoverySection(
            id: 'chill',
            title: 'Chill',
            collections: [
              DiscoveryCollection(
                collection: CatalogCollection(
                  id: 'discovery-chill',
                  title: 'Ngắm Nhìn Những Suy Tư',
                  artist: 'Nhiều nghệ sĩ',
                  thumbnail: '',
                  kind: CatalogCollectionKind.playlist,
                  externalUrl: '',
                ),
                description: 'Giai điệu nhẹ nhàng cho một ngày dài.',
              ),
            ],
          ),
          DiscoverySection(
            id: 'album-hot',
            title: 'Album Hot',
            collections: [
              DiscoveryCollection(
                collection: CatalogCollection(
                  id: 'discovery-album',
                  title: 'Album Mới (EP)',
                  artist: 'Nghệ sĩ Việt',
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
      const detailSong = CatalogSong(
        song: Song(
          id: 'discovery-detail-song',
          name: 'discovery-detail-song',
          title: 'Bài Hát Trong Top 100',
          thumbnail: '',
          artistsNames: 'Ca Sĩ Việt',
          code: 'discovery-detail-code',
        ),
        duration: Duration(minutes: 4),
        externalUrl: '',
        playable: true,
      );
      const lockedDetailSong = CatalogSong(
        song: Song(
          id: 'discovery-detail-locked',
          name: 'discovery-detail-locked',
          title: 'Bài Hát Bị Giới Hạn',
          thumbnail: '',
          artistsNames: 'Ca Sĩ Việt',
          code: 'discovery-detail-locked-code',
        ),
        duration: Duration(minutes: 3),
        externalUrl: '',
        playable: false,
      );
      const secondDetailSong = CatalogSong(
        song: Song(
          id: 'discovery-detail-second',
          name: 'discovery-detail-second',
          title: 'Bài Hát Tiếp Theo',
          thumbnail: '',
          artistsNames: 'Ca Sĩ Việt',
          code: 'discovery-detail-second-code',
        ),
        duration: Duration(minutes: 3, seconds: 30),
        externalUrl: '',
        playable: true,
      );
      final releaseCatalog = ReleaseCatalog(
        updatedAt: DateTime(2026, 8, 21),
        songs: [
          ReleaseSong(
            catalogSong: CatalogSong(
              song: songs.first,
              duration: const Duration(minutes: 3),
              externalUrl: '',
              playable: true,
            ),
            releasedAt: DateTime(2026, 8, 21),
            region: ReleaseRegion.vietnam,
          ),
        ],
        albums: const [],
        catalogPlaybackEnabled: true,
      );
      final newReleaseChart = NewReleaseChart(
        title: 'BXH Nhạc Mới',
        updatedAt: null,
        catalogPlaybackEnabled: true,
        entries: [
          NewReleaseEntry(
            catalogSong: CatalogSong(
              song: songs.first,
              duration: Duration(minutes: 3),
              externalUrl: '',
              playable: true,
            ),
            albumTitle: 'Single mới',
            rank: 1,
            rankChange: 1,
            releasedAt: null,
          ),
        ],
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async {
                chartLoadCalls++;
                return songs;
              },
              loadDiscoveryHome: () async {
                discoveryLoadCalls++;
                return discovery;
              },
              loadReleaseCatalog: () async {
                releaseLoadCalls++;
                return releaseCatalog;
              },
              loadNewReleases: () async {
                newReleaseLoadCalls++;
                return newReleaseChart;
              },
              loadDiscoveryCategories: () async => _testDiscoveryCategories,
              launchExternalCatalog: (uri) async {
                launchedVideo = uri;
                return true;
              },
              officialContentShareService: shareService,
              loadCollection: (_) async {
                collectionLoadCalls++;
                return const CatalogCollectionDetail(
                  collection: topCollection,
                  description: 'Top 100 cập nhật liên tục.',
                  year: '2026',
                  genres: ['V-Pop'],
                  songs: [detailSong, lockedDetailSong, secondDetailSong],
                  catalogPlaybackEnabled: true,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(discoveryLoadCalls, 0);
      expect(releaseLoadCalls, 0);
      expect(newReleaseLoadCalls, 0);
      await tester.tap(find.byKey(const ValueKey('chart-search-field')));
      await tester.pumpAndSettle();
      expect(discoveryLoadCalls, 1);
      expect(releaseLoadCalls, 1);
      expect(newReleaseLoadCalls, 1);
      await tester.enterText(
        find.byKey(const ValueKey('chart-search-field')),
        'Top',
      );
      await tester.enterText(
        find.byKey(const ValueKey('chart-search-field')),
        '',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discovery-home')), findsOneWidget);
      expect(find.text('Top 100'), findsWidgets);
      expect(find.text('Chill'), findsOneWidget);
      expect(find.text('Album Hot'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('discovery-video-shelf')),
        findsOneWidget,
      );
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -240),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('discovery-video-discovery-mv-one')),
      );
      await tester.pump();
      expect(
        launchedVideo,
        Uri.parse(
          'https://zingmp3.vn/video-clip/mv-noi-bat/discovery-mv-one.html',
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('discovery-banner-rail')),
      );
      await tester.pump();
      final mobileBannerRail = tester.getRect(
        find.byKey(const ValueKey('discovery-banner-rail')),
      );
      final mobileFirstBanner = tester.getRect(
        find.byKey(const ValueKey('discovery-banner-discovery-banner-one')),
      );
      final mobileSecondBanner = tester.getRect(
        find.byKey(const ValueKey('discovery-banner-discovery-banner-two')),
      );
      expect(mobileFirstBanner.right, lessThan(mobileBannerRail.right));
      expect(mobileSecondBanner.left, lessThan(mobileBannerRail.right));
      expect(mobileSecondBanner.right, greaterThan(mobileBannerRail.right));
      expect(find.byKey(const ValueKey('discovery-banner-next')), findsNothing);
      expect(
        find.byKey(const ValueKey('discovery-new-releases')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discovery-new-release-chart')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!
          .jumpTo(0);
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 320));
      await tester.pumpAndSettle();
      expect(discoveryLoadCalls, 2);
      expect(releaseLoadCalls, 2);
      expect(newReleaseLoadCalls, 2);
      expect(chartLoadCalls, 1);

      final quickPlayButton = find.byKey(
        const ValueKey('discovery-collection-play-discovery-top-100'),
      );
      final contentScroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView).first)
          .controller!;
      final quickPlayOffset =
          contentScroll.offset + tester.getCenter(quickPlayButton).dy - 500;
      contentScroll.jumpTo(
        quickPlayOffset.clamp(
          contentScroll.position.minScrollExtent,
          contentScroll.position.maxScrollExtent,
        ),
      );
      await tester.pump();
      final collectionSaveButton = find.byKey(
        const ValueKey('discovery-collection-save-discovery-top-100'),
      );
      await tester.tap(collectionSaveButton);
      await tester.pump();
      expect(controller.isCollectionSaved(topCollection), isTrue);
      expect(
        find.descendant(
          of: collectionSaveButton,
          matching: find.byIcon(Icons.favorite_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('discovery-collection-more-discovery-top-100'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('discovery-collection-menu-share-discovery-top-100'),
        ),
      );
      await tester.pumpAndSettle();
      expect(shareService.contents, hasLength(1));
      expect(shareService.contents.single.kind, OfficialContentKind.collection);
      expect(
        shareService.contents.single.externalUrl,
        topCollection.externalUrl,
      );

      await tester.ensureVisible(quickPlayButton);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(quickPlayButton).onPressed, isNotNull);
      await tester.tap(quickPlayButton);
      await tester.pumpAndSettle();
      expect(controller.currentSong, detailSong.song);
      expect(controller.queue.map((song) => song.id), [
        'discovery-detail-song',
        'discovery-detail-second',
      ]);
      expect(controller.playbackOrigin.kind, PlaybackOriginKind.collection);
      expect(controller.playbackOrigin.label, 'Top 100 Nhạc Trẻ');
      expect(audioPlayer.playedSources, hasLength(1));
      expect(collectionLoadCalls, 1);
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsNothing,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('discovery-collection-discovery-top-100')),
      );
      await tester.pumpAndSettle();
      final discoveryCollectionCard = find.byKey(
        const ValueKey('discovery-collection-discovery-top-100'),
      );
      final discoveryCollectionRect = tester.getRect(discoveryCollectionCard);
      await tester.tapAt(
        Offset(
          discoveryCollectionRect.center.dx,
          discoveryCollectionRect.bottom - 18,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('discovery-detail-song')),
          matching: find.text('Bài Hát Trong Top 100'),
        ),
        findsOneWidget,
      );
      expect(collectionLoadCalls, 2);

      final detailScrollable = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      );
      tester.state<ScrollableState>(detailScrollable).position.jumpTo(0);
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 320));
      await tester.pumpAndSettle();
      expect(collectionLoadCalls, 3);
      expect(discoveryLoadCalls, 2);
      expect(newReleaseLoadCalls, 2);
      expect(chartLoadCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('only the latest collection Quick Play request can start', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audioPlayer = FakePlaybackAudioPlayer();
    final controller = PlaybackService(
      playbackAudioPlayer: audioPlayer,
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    const firstCollection = CatalogCollection(
      id: 'quick-play-first',
      title: 'Playlist chậm',
      artist: 'Nhiều nghệ sĩ',
      thumbnail: '',
      kind: CatalogCollectionKind.playlist,
      externalUrl: '',
    );
    const latestCollection = CatalogCollection(
      id: 'quick-play-latest',
      title: 'Playlist mới nhất',
      artist: 'Nhiều nghệ sĩ',
      thumbnail: '',
      kind: CatalogCollectionKind.playlist,
      externalUrl: '',
    );
    const firstSong = Song(
      id: 'quick-play-first-song',
      name: 'quick-play-first-song',
      title: 'Bài từ yêu cầu cũ',
      thumbnail: '',
      artistsNames: 'Ca sĩ A',
      code: 'quick-play-first-code',
    );
    const latestSong = Song(
      id: 'quick-play-latest-song',
      name: 'quick-play-latest-song',
      title: 'Bài từ yêu cầu mới',
      thumbnail: '',
      artistsNames: 'Ca sĩ B',
      code: 'quick-play-latest-code',
    );
    const home = DiscoveryHome(
      updatedAt: null,
      banners: [],
      sections: [
        DiscoverySection(
          id: 'quick-play-race',
          title: 'Dành cho bạn',
          collections: [
            DiscoveryCollection(collection: firstCollection, description: ''),
            DiscoveryCollection(collection: latestCollection, description: ''),
          ],
        ),
      ],
    );
    final firstRequest = Completer<CatalogCollectionDetail>();
    final latestRequest = Completer<CatalogCollectionDetail>();

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            initialTab: 1,
            loadSongs: () async => songs,
            loadDiscoveryHome: () async => home,
            loadDiscoveryCategories: () async =>
                const DiscoveryCategories.empty(),
            loadDiscoveryRecommendations: () async =>
                const DiscoveryRecommendations.empty(),
            loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
            loadNewReleases: () async => const NewReleaseChart.empty(),
            loadCollection: (id) => id == firstCollection.id
                ? firstRequest.future
                : latestRequest.future,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstButton = find.byKey(
      const ValueKey('discovery-collection-play-quick-play-first'),
    );
    final latestButton = find.byKey(
      const ValueKey('discovery-collection-play-quick-play-latest'),
    );
    final contentScroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView).first)
        .controller!;
    final targetOffset =
        contentScroll.offset + tester.getCenter(firstButton).dy - 420;
    contentScroll.jumpTo(
      targetOffset.clamp(
        contentScroll.position.minScrollExtent,
        contentScroll.position.maxScrollExtent,
      ),
    );
    await tester.pump();
    await tester.tap(firstButton);
    await tester.pump();
    await tester.tap(latestButton);
    await tester.pump();

    latestRequest.complete(
      const CatalogCollectionDetail(
        collection: latestCollection,
        description: '',
        year: '2026',
        genres: [],
        songs: [
          CatalogSong(
            song: latestSong,
            duration: Duration(minutes: 3),
            externalUrl: '',
            playable: true,
          ),
        ],
        catalogPlaybackEnabled: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.currentSong, latestSong);
    expect(controller.queue, [latestSong]);
    expect(controller.playbackOrigin.label, latestCollection.title);
    expect(audioPlayer.playedSources, hasLength(1));

    firstRequest.complete(
      const CatalogCollectionDetail(
        collection: firstCollection,
        description: '',
        year: '2026',
        genres: [],
        songs: [
          CatalogSong(
            song: firstSong,
            duration: Duration(minutes: 3),
            externalUrl: '',
            playable: true,
          ),
        ],
        catalogPlaybackEnabled: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.currentSong, latestSong);
    expect(controller.queue, [latestSong]);
    expect(audioPlayer.playedSources, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('plays the private recent-history queue from Discovery Home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 8, 21, 7);
    final audioPlayer = FakePlaybackAudioPlayer();
    final controller = PlaybackService(
      playbackAudioPlayer: audioPlayer,
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(
        PlayerSnapshot(
          history: [
            ListeningRecord(id: 'latest', song: songs[1], playedAt: now),
            ListeningRecord(
              id: 'duplicate',
              song: songs[1],
              playedAt: now.subtract(const Duration(minutes: 1)),
            ),
            ListeningRecord(
              id: 'older',
              song: songs[0],
              playedAt: now.subtract(const Duration(minutes: 2)),
            ),
          ],
        ),
      ),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            loadSongs: () async => songs,
            loadDiscoveryHome: () async => const DiscoveryHome(
              updatedAt: null,
              banners: [],
              sections: [
                DiscoverySection(
                  id: 'recent-test',
                  title: 'Chill',
                  collections: [
                    DiscoveryCollection(
                      collection: CatalogCollection(
                        id: 'recent-collection',
                        title: 'Nhạc Chill',
                        artist: 'Nhiều nghệ sĩ',
                        thumbnail: '',
                        kind: CatalogCollectionKind.playlist,
                        externalUrl: '',
                      ),
                      description: '',
                    ),
                  ],
                ),
              ],
            ),
            initialTab: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('discovery-recent-song-one')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('discovery-recent-song-two')),
      findsOneWidget,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -720));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('discovery-recent-menu-one')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('discovery-recent-menu-item-play-one')),
      findsOneWidget,
    );
    await tester.tap(find.text('Yêu thích').last);
    await tester.pumpAndSettle();
    expect(controller.isLiked(songs[0]), isTrue);
    await tester.tap(find.byKey(const ValueKey('discovery-recent-song-one')));
    await tester.pumpAndSettle();

    expect(controller.currentSong, songs[0]);
    expect(controller.queue, [songs[1], songs[0]]);
    expect(audioPlayer.playedSources, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'loads the Discovery top-three chart and queues only playable ranks',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var releaseChartCalls = 0;
      final audioPlayer = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audioPlayer,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      addTearDown(controller.dispose);
      const first = Song(
        id: 'discovery-chart-one',
        name: 'discovery-chart-one',
        title: 'Thiên Đường Với Người Thương',
        thumbnail: '',
        artistsNames: 'Phương Mỹ Chi, DTAP',
        code: 'discovery-chart-code-one',
      );
      const locked = Song(
        id: 'discovery-chart-locked',
        name: 'discovery-chart-locked',
        title: 'Bài Hát Giới Hạn',
        thumbnail: '',
        artistsNames: 'Nghệ sĩ giới hạn',
        code: 'discovery-chart-code-locked',
      );
      const third = Song(
        id: 'discovery-chart-three',
        name: 'discovery-chart-three',
        title: 'Vạn Niên',
        thumbnail: '',
        artistsNames: 'Chung Thanh Duy',
        code: 'discovery-chart-code-three',
      );
      const releaseChart = NewReleaseChart(
        title: 'BXH Nhạc Mới',
        updatedAt: null,
        catalogPlaybackEnabled: true,
        entries: [
          NewReleaseEntry(
            catalogSong: CatalogSong(
              song: first,
              duration: Duration(minutes: 3, seconds: 38),
              externalUrl: '',
              playable: true,
            ),
            albumTitle: 'Single hạng nhất',
            rank: 1,
            rankChange: 2,
            releasedAt: null,
          ),
          NewReleaseEntry(
            catalogSong: CatalogSong(
              song: locked,
              duration: Duration(minutes: 4),
              externalUrl: '',
              playable: false,
            ),
            albumTitle: 'Single giới hạn',
            rank: 2,
            rankChange: -1,
            releasedAt: null,
          ),
          NewReleaseEntry(
            catalogSong: CatalogSong(
              song: third,
              duration: Duration(minutes: 3, seconds: 51),
              externalUrl: '',
              playable: true,
            ),
            albumTitle: 'Single hạng ba',
            rank: 3,
            rankChange: 0,
            releasedAt: null,
          ),
        ],
      );
      const discovery = DiscoveryHome(
        updatedAt: null,
        banners: [],
        sections: [
          DiscoverySection(
            id: 'chart-spotlight-test',
            title: 'Chọn lọc hôm nay',
            collections: [],
          ),
        ],
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => songs,
              loadDiscoveryHome: () async => discovery,
              loadNewReleases: () async {
                releaseChartCalls++;
                return releaseChart;
              },
              initialTab: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(releaseChartCalls, 1);
      expect(
        find.byKey(const ValueKey('discovery-new-release-chart')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('discovery-new-release-chart-discovery-chart-one'),
        ),
        findsOneWidget,
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1320));
      await tester.pumpAndSettle();
      final lockedMenu = find.byKey(
        const ValueKey(
          'discovery-new-release-chart-menu-discovery-chart-locked',
        ),
      );
      await tester.ensureVisible(lockedMenu);
      await tester.pumpAndSettle();
      await tester.tap(lockedMenu);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey(
            'discovery-new-release-chart-menu-item-play-'
            'discovery-chart-locked',
          ),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Yêu thích').last);
      await tester.pumpAndSettle();
      expect(controller.isLiked(locked), isTrue);
      await tester.drag(
        find.byKey(const ValueKey('discovery-new-release-chart-list')),
        const Offset(520, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('discovery-new-release-chart-discovery-chart-one'),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.currentSong, first);
      expect(controller.queue, [first, third]);
      expect(audioPlayer.playedSources, hasLength(1));

      await tester.tap(find.byTooltip('Quay lại bảng xếp hạng'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('open-new-release-chart')),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -140));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-new-release-chart')));
      await tester.pumpAndSettle();
      expect(releaseChartCalls, 1);
      expect(find.byKey(const ValueKey('discovery-chart-one')), findsOneWidget);
      expect(find.text('3 bài hát'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switches Discovery categories without flicker and ignores stale results',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MusicPlayerController(
        libraryRepository: MemoryLibraryRepository(),
      );
      addTearDown(controller.dispose);
      var defaultHomeCalls = 0;
      var categoriesCalls = 0;
      final categoryRequests = <String>[];
      final relaxation = Completer<DiscoveryHome>();
      final work = Completer<DiscoveryHome>();

      DiscoveryHome home(String categoryId, String title) => DiscoveryHome(
        categoryId: categoryId,
        updatedAt: null,
        banners: const [],
        sections: [
          DiscoverySection(
            id: 'section-$categoryId',
            title: title,
            collections: const [
              DiscoveryCollection(
                collection: CatalogCollection(
                  id: 'category-collection',
                  title: 'Tuyển tập theo tâm trạng',
                  artist: 'Nhiều nghệ sĩ',
                  thumbnail: '',
                  kind: CatalogCollectionKind.playlist,
                  externalUrl: '',
                ),
                description: 'Nội dung được tuyển chọn theo danh mục.',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              initialTab: 1,
              loadSongs: () async => songs,
              loadDiscoveryCategories: () async {
                categoriesCalls++;
                return const DiscoveryCategories(
                  updatedAt: null,
                  items: [
                    DiscoveryCategory(id: '14', name: 'Thư giãn'),
                    DiscoveryCategory(id: '13', name: 'Làm việc'),
                    DiscoveryCategory(id: '21', name: 'Trending'),
                    DiscoveryCategory(id: '18', name: 'Ngủ ngon'),
                    DiscoveryCategory(id: '15', name: 'Tập luyện'),
                  ],
                );
              },
              loadDiscoveryHome: () async {
                defaultHomeCalls++;
                return home('-1', 'Dành riêng cho bạn');
              },
              loadDiscoveryCategoryHome: (categoryId) {
                categoryRequests.add(categoryId);
                if (categoryId == '14' && categoryRequests.length == 1) {
                  return relaxation.future;
                }
                if (categoryId == '13' && categoryRequests.length == 2) {
                  return work.future;
                }
                return Future.value(home(categoryId, 'Làm mới $categoryId'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(categoriesCalls, 1);
      expect(defaultHomeCalls, 1);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('discovery-category--1')),
          matching: find.text('Cho bạn'),
        ),
        findsOneWidget,
      );
      expect(find.text('Thư giãn'), findsOneWidget);
      expect(find.text('Làm việc'), findsOneWidget);
      expect(find.text('Dành riêng cho bạn'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('discovery-category-14')));
      await tester.pump();
      expect(find.text('Dành riêng cho bạn'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('discovery-category-switching')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('discovery-home-stale-content')),
            )
            .ignoring,
        isTrue,
      );
      await tester.drag(
        find.byKey(const ValueKey('discovery-category-list')),
        const Offset(-180, 0),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('discovery-category-13')));
      await tester.pump();

      work.complete(home('13', 'Tập trung làm việc'));
      await tester.pumpAndSettle();
      expect(find.text('Tập trung làm việc'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('discovery-category-switching')),
        findsNothing,
      );
      expect(
        tester
            .widget<IgnorePointer>(
              find.byKey(const ValueKey('discovery-home-stale-content')),
            )
            .ignoring,
        isFalse,
      );
      relaxation.complete(home('14', 'Thả lỏng cuối ngày'));
      await tester.pumpAndSettle();
      expect(find.text('Tập trung làm việc'), findsOneWidget);
      expect(find.text('Thả lỏng cuối ngày'), findsNothing);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 320));
      await tester.pumpAndSettle();
      expect(categoryRequests, ['14', '13', '13']);
      expect(defaultHomeCalls, 1);
      expect(find.text('Làm mới 13'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'embeds realtime #zingchart in Discovery and opens the full chart',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final audioPlayer = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audioPlayer,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      addTearDown(controller.dispose);
      final snapshot = ChartSnapshot(
        songs: songs,
        series: {
          for (var songIndex = 0; songIndex < songs.length; songIndex++)
            songs[songIndex].id: [
              for (var hour = 0; hour < 4; hour++)
                ChartPoint(
                  time: DateTime(2026, 8, 24, 9 + hour * 3),
                  hour: '${9 + hour * 3}',
                  counter: 35 + songIndex * 20 + hour * 8,
                ),
            ],
        },
        updatedAt: DateTime(2026, 8, 24, 18),
      );
      const discovery = DiscoveryHome(
        updatedAt: null,
        banners: [],
        sections: [
          DiscoverySection(
            id: 'embedded-chart-section',
            title: 'Top 100',
            collections: [],
          ),
        ],
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              initialTab: 1,
              loadChart: () async => snapshot,
              loadDiscoveryHome: () async => discovery,
              loadDiscoveryCategories: () async =>
                  const DiscoveryCategories.empty(),
              loadDiscoveryRecommendations: () async =>
                  const DiscoveryRecommendations.empty(),
              loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
              loadNewReleases: () async => const NewReleaseChart.empty(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final preview = find.byKey(const ValueKey('discovery-zingchart-preview'));
      await tester.ensureVisible(preview);
      expect(preview, findsOneWidget);
      final second = find.byKey(
        ValueKey('discovery-zingchart-song-${songs[1].id}'),
      );
      final pageScroll = find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(second, 260, scrollable: pageScroll);
      await tester.pumpAndSettle();
      await tester.tap(second);
      await tester.pumpAndSettle();
      expect(controller.currentSong, songs[1]);
      expect(controller.queue, songs);
      expect(audioPlayer.playedSources, hasLength(1));

      final openAll = find.byKey(
        const ValueKey('discovery-zingchart-open-all'),
      );
      await tester.scrollUntilVisible(openAll, -220, scrollable: pageScroll);
      await tester.pumpAndSettle();
      await tester.tap(openAll);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('discovery-zingchart-preview')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('realtime-chart')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keeps categories usable when the default Discovery Home fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MusicPlayerController(
      libraryRepository: MemoryLibraryRepository(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            initialTab: 1,
            loadSongs: () async => songs,
            loadDiscoveryCategories: () async => _testDiscoveryCategories,
            loadDiscoveryHome: () async => throw Exception('Home unavailable'),
            loadDiscoveryRecommendations: () async => DiscoveryRecommendations(
              updatedAt: null,
              entries: [
                CatalogSong(
                  song: songs.first,
                  duration: const Duration(minutes: 3),
                  externalUrl: '',
                  playable: true,
                ),
              ],
              catalogPlaybackEnabled: true,
            ),
            loadDiscoveryCategoryHome: (categoryId) async => DiscoveryHome(
              categoryId: categoryId,
              updatedAt: null,
              banners: const [],
              sections: const [
                DiscoverySection(
                  id: 'recovered',
                  title: 'Thư giãn sau một ngày dài',
                  collections: [
                    DiscoveryCollection(
                      collection: CatalogCollection(
                        id: 'recovered-collection',
                        title: 'Nhạc dịu nhẹ',
                        artist: 'Nhiều nghệ sĩ',
                        thumbnail: '',
                        kind: CatalogCollectionKind.playlist,
                        externalUrl: '',
                      ),
                      description: '',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('discovery-home-error')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('discovery-recommendation-one')),
      findsOneWidget,
    );
    expect(find.text('TỪ ZING MP3'), findsOneWidget);
    expect(find.text('Thư giãn'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('discovery-category-14')));
    await tester.pumpAndSettle();
    expect(find.text('Thư giãn sau một ngày dài'), findsOneWidget);
    expect(find.byKey(const ValueKey('discovery-home')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('blocks stale Discovery Home focus and activation on TV', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var weeklyOpenCalls = 0;
    const home = DiscoveryHome(
      updatedAt: null,
      banners: [],
      sections: [
        DiscoverySection(
          id: 'tv-home',
          title: 'Nội dung cũ',
          collections: [
            DiscoveryCollection(
              collection: CatalogCollection(
                id: 'tv-old-collection',
                title: 'Tuyển tập cũ',
                artist: 'Nhiều nghệ sĩ',
                thumbnail: '',
                kind: CatalogCollectionKind.playlist,
                externalUrl: '',
              ),
              description: '',
            ),
          ],
        ),
      ],
    );

    Widget app({required bool switching}) => MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiscoveryHomeHub(
            home: home,
            loading: switching,
            errorMessage: null,
            onRetry: () {},
            categories: _testDiscoveryCategories.items,
            categoriesLoading: false,
            categoriesErrorMessage: null,
            selectedCategoryId: switching ? '14' : '-1',
            onCategorySelected: (_) {},
            onRetryCategories: () {},
            onCollectionTap: (_) {},
            onVideoTap: (_) {},
            onOpenHubHome: () {},
            onOpenTop100: () {},
            onOpenReleases: () {},
            onOpenWeeklyChart: () => weeklyOpenCalls++,
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
            tvMode: true,
          ),
        ),
      ),
    );

    bool focusIsWithin(Finder ancestor) {
      final focusContext = FocusManager.instance.primaryFocus?.context;
      if (focusContext == null) return false;
      return find
          .descendant(
            of: ancestor,
            matching: find.byWidget(focusContext.widget),
          )
          .evaluate()
          .isNotEmpty;
    }

    await tester.pumpWidget(app(switching: false));
    await tester.pumpAndSettle();
    final weeklyButton = find.byKey(const ValueKey('open-weekly-chart'));
    for (var index = 0; index < 20 && !focusIsWithin(weeklyButton); index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focusIsWithin(weeklyButton), isTrue);

    await tester.pumpWidget(app(switching: true));
    await tester.pump();
    expect(
      tester
          .widget<ExcludeFocus>(
            find.byKey(const ValueKey('discovery-home-stale-focus')),
          )
          .excluding,
      isTrue,
    );
    final staleContent = find.byKey(
      const ValueKey('discovery-home-stale-content'),
    );
    expect(focusIsWithin(staleContent), isFalse);
    for (var index = 0; index < 12; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focusIsWithin(staleContent), isFalse);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(weeklyOpenCalls, 0);
    expect(
      find.byKey(const ValueKey('discovery-category-switching')),
      findsOne,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keeps inline releases usable when Discovery Home fails and filters queue',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const vietnam = Song(
        id: 'home-release-vietnam',
        name: 'home-release-vietnam',
        title: 'Bài Mới Việt Nam',
        thumbnail: '',
        artistsNames: 'Nghệ Sĩ Việt',
        code: 'home-release-vietnam-code',
      );
      const internationalOne = Song(
        id: 'home-release-international-one',
        name: 'home-release-international-one',
        title: 'International One',
        thumbnail: '',
        artistsNames: 'Global Artist',
        code: 'home-release-international-one-code',
      );
      const internationalLocked = Song(
        id: 'home-release-international-locked',
        name: 'home-release-international-locked',
        title: 'International Locked',
        thumbnail: '',
        artistsNames: 'Locked Artist',
        code: 'home-release-international-locked-code',
      );
      const internationalTwo = Song(
        id: 'home-release-international-two',
        name: 'home-release-international-two',
        title: 'International Two',
        thumbnail: '',
        artistsNames: 'Second Global Artist',
        code: 'home-release-international-two-code',
      );
      final catalog = ReleaseCatalog(
        updatedAt: DateTime(2026, 8, 21),
        catalogPlaybackEnabled: true,
        songs: [
          ReleaseSong(
            catalogSong: const CatalogSong(
              song: vietnam,
              duration: Duration(minutes: 3),
              externalUrl: '',
              playable: true,
            ),
            releasedAt: DateTime(2026, 8, 21),
            region: ReleaseRegion.vietnam,
          ),
          ReleaseSong(
            catalogSong: const CatalogSong(
              song: internationalOne,
              duration: Duration(minutes: 3),
              externalUrl: '',
              playable: true,
            ),
            releasedAt: DateTime(2026, 8, 20),
            region: ReleaseRegion.usuk,
          ),
          ReleaseSong(
            catalogSong: const CatalogSong(
              song: internationalLocked,
              duration: Duration(minutes: 3),
              externalUrl: '',
              playable: false,
            ),
            releasedAt: DateTime(2026, 8, 19),
            region: ReleaseRegion.korea,
          ),
          ReleaseSong(
            catalogSong: const CatalogSong(
              song: internationalTwo,
              duration: Duration(minutes: 3),
              externalUrl: '',
              playable: true,
            ),
            releasedAt: DateTime(2026, 8, 18),
            region: ReleaseRegion.other,
          ),
        ],
        albums: const [],
      );
      var releaseCalls = 0;
      final audioPlayer = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audioPlayer,
        sourceResolver: (_) async => 'https://audio.example.com/release.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              initialTab: 1,
              loadSongs: () async => const [vietnam],
              loadDiscoveryHome: () async =>
                  throw Exception('Discovery Home unavailable'),
              loadDiscoveryCategories: () async =>
                  const DiscoveryCategories.empty(),
              loadDiscoveryRecommendations: () async =>
                  const DiscoveryRecommendations.empty(),
              loadReleaseCatalog: () async {
                releaseCalls++;
                if (releaseCalls > 1) {
                  throw Exception('Release refresh unavailable');
                }
                return catalog;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(releaseCalls, 1);
      expect(
        find.byKey(const ValueKey('discovery-new-releases')),
        findsOneWidget,
      );
      expect(find.text('Mới Phát Hành'), findsWidgets);
      expect(
        find.byKey(const ValueKey('discovery-home-error')),
        findsOneWidget,
      );

      final discoveryScroll = find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first;
      final internationalFilter = find.byKey(
        const ValueKey('discovery-release-region-international'),
      );
      await tester.scrollUntilVisible(
        internationalFilter,
        240,
        scrollable: discoveryScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(internationalFilter);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('discovery-release-home-release-vietnam')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('discovery-release-home-release-international-one'),
        ),
        findsOneWidget,
      );
      final lockedCard = find.byKey(
        const ValueKey('discovery-release-home-release-international-locked'),
      );
      expect(
        tester
            .widget<InkWell>(
              find
                  .descendant(of: lockedCard, matching: find.byType(InkWell))
                  .first,
            )
            .onTap,
        isNull,
      );

      tester.state<ScrollableState>(discoveryScroll).position.jumpTo(0);
      await tester.pump();
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 320),
      );
      await tester.pumpAndSettle();
      expect(releaseCalls, 2);
      expect(
        find.byKey(const ValueKey('discovery-new-releases-stale')),
        findsOneWidget,
      );

      final playableCard = find.byKey(
        const ValueKey('discovery-release-home-release-international-one'),
      );
      await tester.scrollUntilVisible(
        playableCard,
        240,
        scrollable: discoveryScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(playableCard);
      await tester.pumpAndSettle();
      expect(controller.currentSong, internationalOne);
      expect(controller.queue, [internationalOne, internationalTwo]);
      expect(audioPlayer.playedSources, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uses only current-chart songs for the private Discovery fallback',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recommendationSongs = List<Song>.generate(
        12,
        (index) => Song(
          id: 'private-recommendation-$index',
          name: 'private-recommendation-$index',
          title: 'Gợi Ý Riêng ${index + 1}',
          thumbnail: '',
          artistsNames: 'Nghệ Sĩ $index',
          code: 'private-code-$index',
        ),
        growable: false,
      );
      final audioPlayer = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audioPlayer,
        sourceResolver: (_) async => 'https://audio.example.com/private.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      const lockedFavorite = Song(
        id: 'locked-favorite',
        name: 'locked-favorite',
        title: 'Bài Đã Bị Khóa',
        thumbnail: '',
        artistsNames: 'Nghệ Sĩ Bị Khóa',
        code: 'locked-code',
      );
      controller.toggleLike(lockedFavorite);
      addTearDown(controller.dispose);
      const discovery = DiscoveryHome(
        updatedAt: null,
        banners: [],
        sections: [
          DiscoverySection(
            id: 'private-home',
            title: 'Dành cho bạn',
            collections: [],
          ),
        ],
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              initialTab: 1,
              loadSongs: () async => recommendationSongs,
              loadDiscoveryHome: () async => discovery,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('discovery-recommendations')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('discovery-recommendation-private-recommendation-0'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('discovery-recommendation-locked-favorite')),
        findsNothing,
      );
      expect(
        find.textContaining('Favorites và lịch sử nghe không được dùng'),
        findsOneWidget,
      );
      final refreshRecommendations = find.byKey(
        const ValueKey('refresh-discovery-recommendations'),
      );
      await tester.ensureVisible(refreshRecommendations);
      await tester.tap(refreshRecommendations);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const ValueKey('discovery-recommendation-private-recommendation-3'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('discovery-recommendation-private-recommendation-3'),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.currentSong, recommendationSongs[3]);
      expect(controller.queue.map((song) => song.id), [
        'private-recommendation-3',
        'private-recommendation-4',
        'private-recommendation-5',
        'private-recommendation-6',
        'private-recommendation-7',
        'private-recommendation-8',
        'private-recommendation-9',
        'private-recommendation-10',
        'private-recommendation-11',
      ]);
      expect(audioPlayer.playedSources, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('falls back to the current chart when official refresh fails', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var recommendationCalls = 0;
    final localSongs = List<Song>.generate(
      7,
      (index) => Song(
        id: 'refresh-local-$index',
        name: 'refresh-local-$index',
        title: 'Chart Local ${index + 1}',
        thumbnail: '',
        artistsNames: 'Nghệ Sĩ Local $index',
        code: 'refresh-local-code-$index',
      ),
      growable: false,
    );
    const officialSong = Song(
      id: 'refresh-official',
      name: 'refresh-official',
      title: 'Gợi Ý Official',
      thumbnail: '',
      artistsNames: 'Nghệ Sĩ Official',
      code: 'refresh-official-code',
    );
    final controller = MusicPlayerController(
      libraryRepository: MemoryLibraryRepository(),
    );
    addTearDown(controller.dispose);
    const discovery = DiscoveryHome(
      updatedAt: null,
      banners: [],
      sections: [
        DiscoverySection(
          id: 'refresh-home',
          title: 'Khám phá',
          collections: [],
        ),
      ],
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            initialTab: 1,
            loadSongs: () async => localSongs,
            loadDiscoveryHome: () async => discovery,
            loadDiscoveryRecommendations: () async {
              recommendationCalls++;
              if (recommendationCalls > 1) {
                throw Exception('Song Station unavailable');
              }
              return const DiscoveryRecommendations(
                updatedAt: null,
                entries: [
                  CatalogSong(
                    song: officialSong,
                    duration: Duration(minutes: 3),
                    externalUrl: '',
                    playable: true,
                  ),
                ],
                catalogPlaybackEnabled: true,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('TỪ ZING MP3'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('discovery-recommendation-refresh-official')),
      findsOneWidget,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(recommendationCalls, 2);
    expect(find.text('TỪ ZING MP3'), findsNothing);
    expect(find.text('CHỌN TRÊN THIẾT BỊ'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('discovery-recommendation-refresh-local-0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Discovery recommendation menu updates local likes and queue', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const actionSong = Song(
      id: 'recommendation-action-song',
      name: 'recommendation-action-song',
      title: 'Gợi Ý Có Tùy Chọn',
      thumbnail: '',
      artistsNames: 'Nghệ Sĩ Action',
      code: 'recommendation-action-code',
    );
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (_) async => 'https://audio.example.com/action.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    addTearDown(controller.dispose);
    const discovery = DiscoveryHome(
      updatedAt: null,
      banners: [],
      sections: [
        DiscoverySection(
          id: 'recommendation-actions',
          title: 'Khám phá',
          collections: [],
        ),
      ],
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            initialTab: 1,
            loadSongs: () async => const [actionSong],
            loadDiscoveryHome: () async => discovery,
            loadDiscoveryRecommendations: () async =>
                const DiscoveryRecommendations(
                  updatedAt: null,
                  entries: [
                    CatalogSong(
                      song: actionSong,
                      duration: Duration(minutes: 3),
                      externalUrl: '',
                      playable: true,
                    ),
                  ],
                  catalogPlaybackEnabled: true,
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final menu = find.byKey(
      const ValueKey(
        'discovery-recommendation-menu-recommendation-action-song',
      ),
    );
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey(
          'discovery-recommendation-menu-item-play-'
          'recommendation-action-song',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Yêu thích').last);
    await tester.pumpAndSettle();
    expect(controller.isLiked(actionSong), isTrue);

    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm vào hàng đợi').last);
    await tester.pumpAndSettle();
    expect(controller.queue.map((song) => song.id), [actionSong.id]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opens an official recommendation artist without starting playback',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const artist = CatalogArtist(
        id: 'recommendation-artist',
        name: 'Nghệ Sĩ Chính Thức',
        aliasName: 'Nghe-Si-Chinh-Thuc',
        avatar: '',
      );
      const song = Song(
        id: 'recommendation-artist-song',
        name: 'recommendation-artist-song',
        title: 'Bài Hát Có Nghệ Sĩ',
        thumbnail: '',
        artistsNames: 'Nghệ Sĩ Chính Thức',
        code: 'recommendation-artist-code',
      );
      const discovery = DiscoveryHome(
        updatedAt: null,
        banners: [],
        sections: [
          DiscoverySection(
            id: 'recommendation-artist-home',
            title: 'Khám phá',
            collections: [],
          ),
        ],
      );
      const artistDetail = CatalogArtistDetail(
        artist: artist,
        cover: '',
        biography: 'Hồ sơ nghệ sĩ được mở nội bộ từ Gợi Ý Bài Hát.',
        realName: '',
        national: 'Việt Nam',
        birthday: '',
        totalFollow: 1200,
        awardCount: 0,
        songs: [],
        collectionSections: [],
        relatedArtists: [],
        catalogPlaybackEnabled: true,
      );
      final audioPlayer = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audioPlayer,
        sourceResolver: (_) async => 'https://audio.example.com/song.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      addTearDown(controller.dispose);
      final openedAliases = <String>[];

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              initialTab: 1,
              loadSongs: () async => const [song],
              loadDiscoveryHome: () async => discovery,
              loadDiscoveryRecommendations: () async =>
                  const DiscoveryRecommendations(
                    updatedAt: null,
                    entries: [
                      CatalogSong(
                        song: song,
                        duration: Duration(minutes: 3),
                        externalUrl: '',
                        playable: true,
                        artists: [artist],
                      ),
                    ],
                    catalogPlaybackEnabled: true,
                  ),
              loadArtistDetail: (alias) async {
                openedAliases.add(alias);
                return artistDetail;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final artistLink = find.byKey(
        const ValueKey('discovery-recommendation-artist-recommendation-artist'),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
      await tester.pumpAndSettle();
      await tester.ensureVisible(artistLink);
      await tester.tap(artistLink);
      await tester.pumpAndSettle();

      expect(openedAliases, ['Nghe-Si-Chinh-Thuc']);
      expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
      expect(find.text('Nghệ Sĩ Chính Thức'), findsWidgets);
      expect(controller.currentSong, isNull);
      expect(audioPlayer.playedSources, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opens a Discovery collection artist without opening the collection',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const artist = CatalogArtist(
        id: 'collection-artist',
        name: 'Nghệ Sĩ Album',
        aliasName: 'Nghe-Si-Album',
        avatar: '',
        externalUrl: 'https://zingmp3.vn/nghe-si/Nghe-Si-Album',
      );
      const collection = CatalogCollection(
        id: 'collection-with-artist',
        title: 'Album Có Liên Kết Nghệ Sĩ',
        artist: 'Nghệ Sĩ Album',
        artists: [artist],
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl:
            'https://zingmp3.vn/album/album-co-nghe-si/collection-with-artist.html',
      );
      const discovery = DiscoveryHome(
        updatedAt: null,
        banners: [],
        sections: [
          DiscoverySection(
            id: 'collection-artist-section',
            title: 'Album nổi bật',
            collections: [
              DiscoveryCollection(
                collection: collection,
                description: 'Album chính thức từ Zing MP3.',
              ),
            ],
          ),
        ],
      );
      const artistDetail = CatalogArtistDetail(
        artist: artist,
        cover: '',
        biography: 'Hồ sơ nghệ sĩ được mở từ liên kết trong card album.',
        realName: '',
        national: 'Việt Nam',
        birthday: '',
        totalFollow: 2400,
        awardCount: 0,
        songs: [],
        collectionSections: [],
        relatedArtists: [],
        catalogPlaybackEnabled: true,
      );
      final audioPlayer = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audioPlayer,
        sourceResolver: (_) async => 'https://audio.example.com/song.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      addTearDown(controller.dispose);
      final openedAliases = <String>[];
      var collectionLoads = 0;

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              initialTab: 1,
              loadSongs: () async => songs,
              loadDiscoveryHome: () async => discovery,
              loadDiscoveryRecommendations: () async =>
                  DiscoveryRecommendations.empty(),
              loadCollection: (_) async {
                collectionLoads += 1;
                throw StateError('Collection card must not open.');
              },
              loadArtistDetail: (alias) async {
                openedAliases.add(alias);
                return artistDetail;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final artistLink = find.byKey(
        const ValueKey(
          'discovery-collection-artist-collection-with-artist-collection-artist',
        ),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
      await tester.pumpAndSettle();
      await tester.ensureVisible(artistLink);
      await tester.pumpAndSettle();
      await tester.tap(artistLink);
      await tester.pumpAndSettle();

      expect(openedAliases, ['Nghe-Si-Album']);
      expect(collectionLoads, 0);
      expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
      expect(find.text('Nghệ Sĩ Album'), findsWidgets);
      expect(controller.currentSong, isNull);
      expect(audioPlayer.playedSources, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'prefers official Discovery recommendations and plays their queue',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final localSongs = List<Song>.generate(
        12,
        (index) => Song(
          id: 'local-recommendation-$index',
          name: 'local-recommendation-$index',
          title: 'Gợi Ý Local ${index + 1}',
          thumbnail: '',
          artistsNames: 'Nghệ Sĩ Local $index',
          code: 'local-code-$index',
        ),
        growable: false,
      );
      final officialSongs = List<Song>.generate(
        12,
        (index) => Song(
          id: 'official-recommendation-$index',
          name: 'official-recommendation-$index',
          title: 'Gợi Ý Zing ${index + 1}',
          thumbnail: '',
          artistsNames: 'Nghệ Sĩ Zing $index',
          code: 'official-code-$index',
        ),
        growable: false,
      );
      final audioPlayer = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audioPlayer,
        sourceResolver: (_) async => 'https://audio.example.com/official.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      addTearDown(controller.dispose);
      const discovery = DiscoveryHome(
        updatedAt: null,
        banners: [],
        sections: [
          DiscoverySection(
            id: 'official-home',
            title: 'Dành cho bạn',
            collections: [],
          ),
        ],
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              initialTab: 1,
              loadSongs: () async => localSongs,
              loadDiscoveryHome: () async => discovery,
              loadDiscoveryRecommendations: () async =>
                  DiscoveryRecommendations(
                    updatedAt: null,
                    entries: officialSongs
                        .map(
                          (song) => CatalogSong(
                            song: song,
                            duration: const Duration(minutes: 3),
                            externalUrl: '',
                            playable: true,
                          ),
                        )
                        .toList(growable: false),
                    catalogPlaybackEnabled: true,
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TỪ ZING MP3'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('discovery-recommendation-official-recommendation-0'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('discovery-recommendation-local-recommendation-0'),
        ),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('refresh-discovery-recommendations')),
      );
      await tester.tap(
        find.byKey(const ValueKey('refresh-discovery-recommendations')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('discovery-recommendation-official-recommendation-3'),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.currentSong, officialSongs[3]);
      expect(controller.queue.map((song) => song.id), [
        'official-recommendation-3',
        'official-recommendation-4',
        'official-recommendation-5',
        'official-recommendation-6',
        'official-recommendation-7',
        'official-recommendation-8',
        'official-recommendation-9',
        'official-recommendation-10',
        'official-recommendation-11',
      ]);
      expect(audioPlayer.playedSources, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opens Mới Phát Hành, filters playable songs and browses albums at 360px',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var releaseLoadCalls = 0;
      var collectionLoadCalls = 0;
      final audioPlayer = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audioPlayer,
        sourceResolver: (_) async => 'https://audio.example.com/release.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      addTearDown(controller.dispose);
      const vietnamSong = Song(
        id: 'release-vietnam',
        name: 'release-vietnam',
        title: 'Ngày Mới Rực Rỡ',
        thumbnail: '',
        artistsNames: 'Nghệ Sĩ Việt',
        code: 'release-vietnam-code',
      );
      const lockedSong = Song(
        id: 'release-vietnam-locked',
        name: 'release-vietnam-locked',
        title: 'Bản Giới Hạn',
        thumbnail: '',
        artistsNames: 'Nghệ Sĩ Việt',
        code: 'release-vietnam-locked-code',
      );
      const koreaSong = Song(
        id: 'release-korea',
        name: 'release-korea',
        title: 'Seoul Tonight',
        thumbnail: '',
        artistsNames: 'K Artist',
        code: 'release-korea-code',
      );
      const vietnamAlbum = CatalogCollection(
        id: 'release-album-vietnam',
        title: 'Album Việt Mới',
        artist: 'Nghệ Sĩ Việt',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: '',
      );
      const koreaAlbum = CatalogCollection(
        id: 'release-album-korea',
        title: 'K Album New',
        artist: 'K Artist',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: '',
      );
      final catalog = ReleaseCatalog(
        updatedAt: DateTime(2026, 8, 21),
        catalogPlaybackEnabled: true,
        songs: [
          ReleaseSong(
            catalogSong: const CatalogSong(
              song: vietnamSong,
              duration: Duration(minutes: 3, seconds: 25),
              externalUrl: '',
              playable: true,
            ),
            releasedAt: DateTime(2026, 8, 21),
            region: ReleaseRegion.vietnam,
          ),
          ReleaseSong(
            catalogSong: const CatalogSong(
              song: lockedSong,
              duration: Duration(minutes: 4),
              externalUrl: '',
              playable: false,
            ),
            releasedAt: DateTime(2026, 8, 20),
            region: ReleaseRegion.vietnam,
          ),
          ReleaseSong(
            catalogSong: const CatalogSong(
              song: koreaSong,
              duration: Duration(minutes: 3),
              externalUrl: '',
              playable: true,
            ),
            releasedAt: DateTime(2026, 8, 19),
            region: ReleaseRegion.korea,
          ),
        ],
        albums: [
          ReleaseAlbum(
            collection: vietnamAlbum,
            releasedAt: DateTime(2026, 8, 21),
            region: ReleaseRegion.vietnam,
          ),
          ReleaseAlbum(
            collection: koreaAlbum,
            releasedAt: DateTime(2026, 8, 20),
            region: ReleaseRegion.korea,
          ),
        ],
      );
      const discovery = DiscoveryHome(
        updatedAt: null,
        banners: [],
        sections: [
          DiscoverySection(
            id: 'release-entry',
            title: 'Nội dung mới',
            collections: [
              DiscoveryCollection(
                collection: vietnamAlbum,
                description: 'Album vừa phát hành.',
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => songs,
              loadDiscoveryHome: () async => discovery,
              loadReleaseCatalog: () async {
                releaseLoadCalls++;
                return catalog;
              },
              loadCollection: (_) async {
                collectionLoadCalls++;
                return const CatalogCollectionDetail(
                  collection: vietnamAlbum,
                  description: 'Album mới chính thức.',
                  year: '2026',
                  genres: ['V-Pop'],
                  songs: [
                    CatalogSong(
                      song: vietnamSong,
                      duration: Duration(minutes: 3, seconds: 25),
                      externalUrl: '',
                      playable: true,
                    ),
                  ],
                  catalogPlaybackEnabled: true,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chart-search-field')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('open-new-releases')),
      );
      await tester.tap(find.byKey(const ValueKey('open-new-releases')));
      await tester.pumpAndSettle();

      expect(releaseLoadCalls, 1);
      expect(find.byKey(const ValueKey('release-catalog')), findsOneWidget);
      expect(find.text('Ngày Mới Rực Rỡ'), findsOneWidget);
      expect(find.text('Bản Giới Hạn'), findsOneWidget);
      expect(find.text('3 BÀI HÁT'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(
        find.byKey(const ValueKey('release-region-korea')),
      );
      await tester.tap(find.byKey(const ValueKey('release-region-korea')));
      await tester.pumpAndSettle();
      expect(find.text('1 BÀI HÁT'), findsOneWidget);
      expect(find.text('Seoul Tonight'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('release-region-vietnam')),
      );
      await tester.tap(find.byKey(const ValueKey('release-region-vietnam')));
      await tester.pumpAndSettle();
      expect(find.text('Seoul Tonight'), findsNothing);
      expect(find.text('2 BÀI HÁT'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('release-play-all')));
      await tester.pumpAndSettle();
      expect(controller.currentSong, vietnamSong);
      expect(controller.queue, [vietnamSong]);
      expect(audioPlayer.playedSources, hasLength(1));

      await tester.tap(find.byTooltip('Quay lại bảng xếp hạng'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 420));
      await tester.pumpAndSettle();
      expect(releaseLoadCalls, 2);

      await tester.ensureVisible(
        find.byKey(const ValueKey('release-tab-albums')),
      );
      await tester.tap(find.byKey(const ValueKey('release-tab-albums')));
      await tester.pumpAndSettle();
      expect(find.text('Album Việt Mới'), findsOneWidget);
      expect(find.text('K Album New'), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('release-album-release-album-vietnam')),
      );
      await tester.tap(
        find.byKey(const ValueKey('release-album-title-release-album-vietnam')),
      );
      await tester.pumpAndSettle();
      expect(collectionLoadCalls, 1);
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('collection-detail-hero')),
          matching: find.text('Album mới chính thức.'),
        ),
        findsNothing,
        reason: 'The compact phone hero keeps the first track in view.',
      );
      expect(find.byKey(const ValueKey('release-vietnam')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('release-catalog')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discovery-home')), findsOneWidget);
    },
  );

  for (final viewport in [
    (size: const Size(360, 844), tvMode: false),
    (size: const Size(768, 1024), tvMode: false),
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'Mới Phát Hành is responsive at ${viewport.size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = MusicPlayerController(
          libraryRepository: MemoryLibraryRepository(),
        );
        addTearDown(controller.dispose);
        const responsiveSong = Song(
          id: 'responsive-release-song',
          name: 'responsive-release-song',
          title: 'Một Ngày Rất Mới',
          thumbnail: '',
          artistsNames: 'Nghệ Sĩ Đa Nền Tảng',
          code: 'responsive-release-code',
        );
        const responsiveArtist = CatalogArtist(
          id: 'responsive-release-artist',
          name: 'Nghệ Sĩ Đa Nền Tảng',
          aliasName: 'Nghe-Si-Da-Nen-Tang',
          avatar: '',
        );
        const responsiveAlbum = CatalogCollection(
          id: 'responsive-release-album',
          title: 'Album Mới Trên Mọi Thiết Bị',
          artist: 'Nghệ Sĩ Đa Nền Tảng',
          thumbnail: '',
          kind: CatalogCollectionKind.album,
          externalUrl: '',
        );
        final releaseCatalog = ReleaseCatalog(
          updatedAt: DateTime(2026, 8, 21),
          catalogPlaybackEnabled: true,
          songs: [
            ReleaseSong(
              catalogSong: const CatalogSong(
                song: responsiveSong,
                duration: Duration(minutes: 3, seconds: 40),
                externalUrl: '',
                playable: true,
                artists: [responsiveArtist],
                album: responsiveAlbum,
              ),
              releasedAt: DateTime(2026, 8, 21),
              region: ReleaseRegion.vietnam,
            ),
          ],
          albums: [
            ReleaseAlbum(
              collection: responsiveAlbum,
              releasedAt: DateTime(2026, 8, 21),
              region: ReleaseRegion.vietnam,
            ),
          ],
        );

        await tester.pumpWidget(
          MusicPlayerScope(
            controller: controller,
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: ZingChartScreen(
                loadSongs: () async => songs,
                loadReleaseCatalog: () async => releaseCatalog,
                initialCatalogLanding: CatalogLanding.releases,
                tvMode: viewport.tvMode,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('release-catalog')), findsOneWidget);
        expect(find.text('Một Ngày Rất Mới'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('artist-link-responsive-release-artist')),
          findsOneWidget,
        );
        if (viewport.size.width >= 1180) {
          expect(
            find.byKey(
              const ValueKey('song-album-link-responsive-release-song'),
            ),
            findsOneWidget,
          );
          expect(find.textContaining('3:40'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, isNotNull);
        await tester.tap(find.byKey(const ValueKey('release-tab-albums')));
        await tester.pumpAndSettle();
        expect(find.text('Album Mới Trên Mọi Thiết Bị'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final viewport in [
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets('BXH Tuần is responsive at ${viewport.size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MusicPlayerController(
        libraryRepository: MemoryLibraryRepository(),
      );
      addTearDown(controller.dispose);
      const weeklySong = Song(
        id: 'responsive-weekly-song',
        name: 'responsive-weekly-song',
        title: 'Ca Khúc Của Tuần',
        thumbnail: '',
        artistsNames: 'Nghệ Sĩ Đa Nền Tảng',
        code: 'responsive-weekly-code',
      );
      const weeklyArtist = CatalogArtist(
        id: 'responsive-weekly-artist',
        name: 'Nghệ Sĩ Đa Nền Tảng',
        aliasName: 'Nghe-Si-Da-Nen-Tang',
        avatar: '',
      );
      const weeklyAlbum = CatalogCollection(
        id: 'responsive-weekly-album',
        title: 'Album Trên Mọi Màn Hình',
        artist: 'Nghệ Sĩ Đa Nền Tảng',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: '',
      );
      const chart = WeeklyChart(
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
              song: weeklySong,
              duration: Duration(minutes: 3, seconds: 42),
              externalUrl: '',
              playable: true,
              artists: [weeklyArtist],
              album: weeklyAlbum,
            ),
            albumTitle: 'Album Trên Mọi Màn Hình',
            rank: 1,
            rankChange: 4,
            score: 2500,
          ),
        ],
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => songs,
              loadWeeklyChart: (region, {week, year}) async => chart,
              initialCatalogLanding: CatalogLanding.weekly,
              tvMode: viewport.tvMode,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('weekly-chart')), findsOneWidget);
      expect(find.text('Ca Khúc Của Tuần'), findsOneWidget);
      expect(find.text('Album Trên Mọi Màn Hình'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('artist-link-responsive-weekly-artist')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('song-album-link-responsive-weekly-song')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'desktop pins Discovery categories below the toolbar while scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MusicPlayerController(
        libraryRepository: MemoryLibraryRepository(),
      );
      addTearDown(controller.dispose);
      final categoryRequests = <String>[];

      DiscoveryHome homeFor(String categoryId) => DiscoveryHome(
        categoryId: categoryId,
        updatedAt: null,
        banners: const [],
        sections: List.generate(
          8,
          (sectionIndex) => DiscoverySection(
            id: 'sticky-section-$sectionIndex',
            title: 'Tuyển chọn ${sectionIndex + 1}',
            collections: List.generate(
              4,
              (collectionIndex) => DiscoveryCollection(
                collection: CatalogCollection(
                  id: 'sticky-$categoryId-$sectionIndex-$collectionIndex',
                  title: 'Playlist $sectionIndex.$collectionIndex',
                  artist: 'Nhiều nghệ sĩ',
                  thumbnail: '',
                  kind: CatalogCollectionKind.playlist,
                  externalUrl: '',
                ),
                description: 'Nội dung dài để kiểm tra sticky category rail.',
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              initialTab: 1,
              loadSongs: () async => songs,
              loadDiscoveryCategories: () async => _testDiscoveryCategories,
              loadDiscoveryHome: () async => homeFor('-1'),
              loadDiscoveryCategoryHome: (categoryId) async {
                categoryRequests.add(categoryId);
                return homeFor(categoryId);
              },
              loadDiscoveryRecommendations: () async =>
                  const DiscoveryRecommendations.empty(),
              loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
              loadNewReleases: () async => const NewReleaseChart.empty(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toolbar = find.byKey(const ValueKey('pinned-catalog-toolbar'));
      final pinnedCategories = find.byKey(
        const ValueKey('pinned-discovery-categories'),
      );
      expect(toolbar, findsOneWidget);
      expect(pinnedCategories, findsOneWidget);
      expect(
        find.byKey(const ValueKey('discovery-category-rail')),
        findsOneWidget,
      );
      final initialToolbarTop = tester.getTopLeft(toolbar).dy;
      final initialCategoriesTop = tester.getTopLeft(pinnedCategories).dy;
      expect(
        initialCategoriesTop,
        closeTo(tester.getBottomLeft(toolbar).dy, 0.1),
      );

      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView).first,
      );
      scrollView.controller!.jumpTo(
        scrollView.controller!.position.maxScrollExtent,
      );
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(toolbar).dy, closeTo(initialToolbarTop, 0.1));
      expect(
        tester.getTopLeft(pinnedCategories).dy,
        closeTo(initialCategoriesTop, 0.1),
      );

      await tester.tap(find.byKey(const ValueKey('discovery-category-14')));
      await tester.pumpAndSettle();
      expect(categoryRequests, ['14']);
      expect(pinnedCategories, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in [
    (size: const Size(360, 844), tvMode: false),
    (size: const Size(768, 1024), tvMode: false),
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'Discovery Home is responsive at ${viewport.size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = MusicPlayerController(
          libraryRepository: MemoryLibraryRepository(),
        );
        addTearDown(controller.dispose);
        const collection = CatalogCollection(
          id: 'responsive-discovery',
          title: 'Top 100 Trên Mọi Màn Hình',
          artist: 'Nhiều nghệ sĩ',
          thumbnail: '',
          kind: CatalogCollectionKind.playlist,
          externalUrl: '',
        );
        const homeReleaseSong = Song(
          id: 'responsive-home-release',
          name: 'responsive-home-release',
          title: 'Mới Trên Trang Khám Phá',
          thumbnail: '',
          artistsNames: 'Nghệ Sĩ Responsive',
          code: 'responsive-home-release-code',
        );
        final releaseCatalog = ReleaseCatalog(
          updatedAt: DateTime(2026, 8, 21),
          catalogPlaybackEnabled: true,
          songs: [
            ReleaseSong(
              catalogSong: const CatalogSong(
                song: homeReleaseSong,
                duration: Duration(minutes: 3),
                externalUrl: '',
                playable: true,
              ),
              releasedAt: DateTime(2026, 8, 21),
              region: ReleaseRegion.vietnam,
            ),
          ],
          albums: const [],
        );
        const home = DiscoveryHome(
          updatedAt: null,
          banners: [
            DiscoveryBanner(
              id: 'responsive-banner-one',
              image: '',
              collection: collection,
            ),
            DiscoveryBanner(
              id: 'responsive-banner-two',
              image: '',
              collection: CatalogCollection(
                id: 'responsive-discovery-two',
                title: 'Remix Responsive',
                artist: 'Nhiều nghệ sĩ',
                thumbnail: '',
                kind: CatalogCollectionKind.playlist,
                externalUrl: '',
              ),
            ),
            DiscoveryBanner(
              id: 'responsive-banner-three',
              image: '',
              collection: CatalogCollection(
                id: 'responsive-discovery-three',
                title: 'Ballad Responsive',
                artist: 'Nhiều nghệ sĩ',
                thumbnail: '',
                kind: CatalogCollectionKind.playlist,
                externalUrl: '',
              ),
            ),
          ],
          sections: [
            DiscoverySection(
              id: 'responsive-top',
              title: 'Top 100',
              collections: [
                DiscoveryCollection(
                  collection: collection,
                  description: 'Tuyển tập nổi bật nhất hôm nay.',
                ),
              ],
            ),
          ],
        );

        await tester.pumpWidget(
          MusicPlayerScope(
            controller: controller,
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: ZingChartScreen(
                initialTab: 1,
                tvMode: viewport.tvMode,
                loadSongs: () async => songs,
                loadDiscoveryHome: () async => home,
                loadDiscoveryCategories: () async => _testDiscoveryCategories,
                loadReleaseCatalog: () async => releaseCatalog,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('discovery-home')), findsOneWidget);
        final compactHeader = viewport.size.width >= 720 && !viewport.tvMode;
        expect(
          find.byKey(const ValueKey('pinned-discovery-categories')),
          compactHeader ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('discovery-category-rail')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('compact-discovery-header')),
          compactHeader ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('catalog-page-header')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('discovery-recommendations')),
          findsOneWidget,
        );
        expect(
          find
                  .byKey(const ValueKey('discovery-recommendations-grid'))
                  .evaluate()
                  .length +
              find
                  .byKey(
                    const ValueKey('discovery-recommendations-mobile-rail'),
                  )
                  .evaluate()
                  .length,
          1,
        );
        expect(find.text('Top 100 Trên Mọi Màn Hình'), findsWidgets);
        final wideDesktopSidebar =
            viewport.size.width >= 1320 && !viewport.tvMode;
        expect(
          find.byKey(const ValueKey('open-top-100')),
          wideDesktopSidebar ? findsNothing : findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey('discovery-section-open-all-responsive-top'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('discovery-banner-rail')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('discovery-new-releases')),
          findsOneWidget,
        );
        expect(
          find
                  .byKey(const ValueKey('discovery-new-releases-grid'))
                  .evaluate()
                  .length +
              find
                  .byKey(const ValueKey('discovery-new-releases-mobile-rail'))
                  .evaluate()
                  .length,
          1,
        );
        expect(find.text('Mới Trên Trang Khám Phá'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, isNotNull);
      },
    );
  }

  for (final viewport in [
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'BXH Nhạc Mới is responsive at ${viewport.size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = MusicPlayerController(
          libraryRepository: MemoryLibraryRepository(),
        );
        addTearDown(controller.dispose);
        const releaseSong = Song(
          id: 'responsive-new-release',
          name: 'responsive-new-release',
          title: 'Bài hát mới trên mọi màn hình',
          thumbnail: '',
          artistsNames: 'Nghệ sĩ Việt Nam',
          code: 'responsive-new-release-code',
        );
        const releaseArtist = CatalogArtist(
          id: 'responsive-new-release-artist',
          name: 'Nghệ sĩ Việt Nam',
          aliasName: 'Nghe-Si-Viet-Nam',
          avatar: '',
        );
        const releaseAlbum = CatalogCollection(
          id: 'responsive-new-release-album',
          title: 'Album mới phát hành',
          artist: 'Nghệ sĩ Việt Nam',
          thumbnail: '',
          kind: CatalogCollectionKind.album,
          externalUrl: '',
        );
        const releaseChart = NewReleaseChart(
          title: 'BXH Nhạc Mới',
          updatedAt: null,
          catalogPlaybackEnabled: true,
          entries: [
            NewReleaseEntry(
              catalogSong: CatalogSong(
                song: releaseSong,
                duration: Duration(minutes: 4, seconds: 12),
                externalUrl: '',
                playable: true,
                artists: [releaseArtist],
                album: releaseAlbum,
              ),
              albumTitle: 'Album mới phát hành',
              rank: 1,
              rankChange: 4,
              releasedAt: null,
            ),
          ],
        );

        await tester.pumpWidget(
          MusicPlayerScope(
            controller: controller,
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: ZingChartScreen(
                loadSongs: () async => songs,
                loadNewReleases: () async => releaseChart,
                initialTab: 2,
                tvMode: viewport.tvMode,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('BXH Nhạc Mới'), findsWidgets);
        expect(find.text('Bài hát mới trên mọi màn hình'), findsOneWidget);
        expect(
          find.byKey(
            const ValueKey('artist-link-responsive-new-release-artist'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('song-album-link-responsive-new-release')),
          findsOneWidget,
        );
        if (!viewport.tvMode) {
          expect(find.text('Album mới phát hành'), findsOneWidget);
          expect(find.text('4:12'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final viewport in [
    (size: const Size(360, 844), tvMode: false),
    (size: const Size(768, 1024), tvMode: false),
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets('collection hero is adaptive and focusable at '
        '${viewport.size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = viewport.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var played = false;
      CatalogArtist? openedArtist;
      const collection = CatalogCollection(
        id: 'adaptive-album',
        title: 'Album thích ứng trên màn hình lớn',
        artist: 'Nghệ sĩ Việt Nam',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: '',
      );
      const detail = CatalogCollectionDetail(
        collection: collection,
        artists: [
          CatalogArtist(
            id: 'adaptive-artist',
            name: 'Nghệ sĩ Việt Nam',
            aliasName: 'Nghe-Si-Viet-Nam',
            avatar: '',
          ),
        ],
        description: 'Metadata đầy đủ từ trang chi tiết chính thức.',
        year: '2026',
        genres: ['V-Pop'],
        songs: [
          CatalogSong(
            song: Song(
              id: 'adaptive-song',
              name: 'adaptive-song',
              title: 'Bài hát thích ứng',
              thumbnail: '',
              artistsNames: 'Nghệ sĩ Việt Nam',
              code: 'adaptive-code',
            ),
            duration: Duration(minutes: 4),
            externalUrl: '',
            playable: true,
          ),
        ],
        catalogPlaybackEnabled: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CollectionDetailHero(
                collection: collection,
                detail: detail,
                loading: false,
                tvMode: viewport.tvMode,
                onPlay: () => played = true,
                onArtistTap: (artist) => openedArtist = artist,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Album thích ứng trên màn hình lớn'), findsOneWidget);
      expect(find.text('ALBUM'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('collection-artwork-atmosphere')),
        findsOneWidget,
      );
      final artistLink = find.byKey(
        const ValueKey('collection-artist-adaptive-artist'),
      );
      expect(artistLink, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      if (viewport.tvMode) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(openedArtist?.id, 'adaptive-artist');
      }
      await tester.tap(find.byKey(const ValueKey('collection-play-button')));
      expect(played, isTrue);
      if (!viewport.tvMode) await tester.tap(artistLink);
      expect(openedArtist?.id, 'adaptive-artist');
    });
  }

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

    expect(find.byType(DesktopCatalogSidebar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Chọn một bài để bắt đầu'), findsNothing);
    expect(find.byKey(const ValueKey('desktop-playback-dock')), findsNothing);
    controller.dispose();
  });

  testWidgets('desktop sidebar opens Hub and Top 100 directly', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var hubCalls = 0;
    var top100Calls = 0;
    var collectionLoads = 0;
    final audioPlayer = FakePlaybackAudioPlayer();
    final controller = PlaybackService(
      playbackAudioPlayer: audioPlayer,
      sourceResolver: (_) async => 'https://audio.example.com/top-100.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    addTearDown(controller.dispose);
    const collection = CatalogCollection(
      id: 'desktop-sidebar-playlist',
      title: 'Nhạc Việt Thịnh Hành',
      artist: 'Nhiều nghệ sĩ',
      thumbnail: '',
      kind: CatalogCollectionKind.playlist,
      externalUrl: '',
    );
    const discoveryCollection = DiscoveryCollection(
      collection: collection,
      description: 'Tuyển tập nổi bật trên Zing MP3.',
    );
    const top100Song = Song(
      id: 'desktop-top-100-song',
      name: 'desktop-top-100-song',
      title: 'Bài Hát Top 100',
      thumbnail: '',
      artistsNames: 'Nghệ Sĩ Top 100',
      code: 'desktop-top-100-code',
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            loadSongs: () async => songs,
            loadDiscoveryHome: () async => const DiscoveryHome.empty(),
            loadDiscoveryCategories: () async =>
                const DiscoveryCategories.empty(),
            loadDiscoveryRecommendations: () async =>
                const DiscoveryRecommendations.empty(),
            loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
            loadCollection: (_) async {
              collectionLoads++;
              return const CatalogCollectionDetail(
                collection: collection,
                description: 'Tuyển tập nổi bật trên Zing MP3.',
                year: '2026',
                genres: ['V-Pop'],
                songs: [
                  CatalogSong(
                    song: top100Song,
                    duration: Duration(minutes: 3),
                    externalUrl: '',
                    playable: true,
                  ),
                ],
                catalogPlaybackEnabled: true,
              );
            },
            loadHubHome: () async {
              hubCalls++;
              return const CatalogHubHome(
                updatedAt: null,
                featured: [
                  CatalogHub(
                    id: 'desktop-hub',
                    title: 'Chill',
                    description: 'Nhạc nhẹ nhàng',
                    image: '',
                    externalUrl: '',
                  ),
                ],
                nations: [],
                topics: [],
                genres: [],
              );
            },
            loadTop100: () async {
              top100Calls++;
              return const Top100Catalog(
                updatedAt: null,
                sections: [
                  DiscoverySection(
                    id: 'desktop-top-100',
                    title: 'Top 100 Việt Nam',
                    collections: [discoveryCollection],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('desktop-nav-hubs')));
    await tester.pumpAndSettle();
    expect(hubCalls, 1);
    expect(find.byKey(const ValueKey('hub-home')), findsOneWidget);
    expect(find.text('Chill'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('desktop-nav-top100')));
    await tester.pumpAndSettle();
    expect(top100Calls, 1);
    expect(find.byKey(const ValueKey('top-100-catalog')), findsOneWidget);
    expect(find.text('Top 100 Việt Nam'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('hub-collection-play-desktop-sidebar-playlist'),
      ),
    );
    await tester.pumpAndSettle();
    expect(collectionLoads, 1);
    expect(controller.currentSong?.id, top100Song.id);
    expect(audioPlayer.playedSources, hasLength(1));
    expect(
      (audioPlayer.playedSources.single as UrlSource).url,
      'https://audio.example.com/top-100.mp3',
    );
    expect(find.byKey(const ValueKey('collection-detail-hero')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('desktop-create-playlist')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('playlist-name-field')),
      'Playlist desktop',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(controller.playlists.single.name, 'Playlist desktop');
    expect(
      tester
          .widget<DesktopCatalogSidebar>(find.byType(DesktopCatalogSidebar))
          .selected,
      DesktopCatalogDestination.library,
    );
    expect(find.text('Playlist desktop'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders real top-three chart series returned by the proxy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MusicPlayerController(
      libraryRepository: MemoryLibraryRepository(),
    );
    addTearDown(controller.dispose);
    final snapshot = ChartSnapshot(
      songs: songs,
      songMetadata: {
        songs[0].id: const ChartSongMetadata(
          albumTitle: 'Một Bài Hát (Single)',
          duration: Duration(minutes: 3, seconds: 38),
          rankChange: 3,
        ),
        songs[1].id: const ChartSongMetadata(
          albumTitle: 'Nàng Thơ (Single)',
          duration: Duration(minutes: 4, seconds: 14),
          rankChange: -1,
        ),
      },
      series: {
        for (final song in songs)
          song.id: [
            ChartPoint(
              time: DateTime(2026, 8, 21, 8),
              hour: '08',
              counter: 100,
            ),
            ChartPoint(
              time: DateTime(2026, 8, 21, 9),
              hour: '09',
              counter: 140,
            ),
          ],
      },
      maxScore: 140,
      updatedAt: DateTime(2026, 8, 21, 9),
    );

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(loadChart: () async => snapshot),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('realtime-chart')), findsOneWidget);
    expect(find.text('NHỊP BXH 24 GIỜ'), findsOneWidget);
    expect(find.text('Một Bài Hát'), findsWidgets);
    expect(find.text('Nàng Thơ'), findsWidgets);
    expect(find.text('Một Bài Hát (Single)'), findsOneWidget);
    expect(find.text('3:38'), findsOneWidget);
    final firstRank = tester.widget<Semantics>(
      find.byKey(const ValueKey('rank-change-one')),
    );
    final secondRank = tester.widget<Semantics>(
      find.byKey(const ValueKey('rank-change-two')),
    );
    expect(firstRank.properties.label, 'Hạng 1, tăng 3 bậc');
    expect(secondRank.properties.label, 'Hạng 2, giảm 1 bậc');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refreshes the realtime chart in place and pauses while the app is inactive',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MusicPlayerController(
        libraryRepository: MemoryLibraryRepository(),
      );
      addTearDown(controller.dispose);
      const refreshedSong = Song(
        id: 'one',
        name: 'mot-bai-hat',
        title: 'Một Bài Hát · Realtime',
        thumbnail: '',
        artistsNames: 'Ca Sĩ A',
        code: 'code-one',
      );
      const recoveredSong = Song(
        id: 'one',
        name: 'mot-bai-hat',
        title: 'Một Bài Hát · Đã Kết Nối',
        thumbnail: '',
        artistsNames: 'Ca Sĩ A',
        code: 'code-one',
      );
      ChartSnapshot snapshotFor(Song firstSong, double counter) =>
          ChartSnapshot(
            songs: [firstSong, songs[1]],
            series: {
              firstSong.id: [
                ChartPoint(
                  time: DateTime(2026, 8, 21, 8),
                  hour: '08',
                  counter: counter,
                ),
                ChartPoint(
                  time: DateTime(2026, 8, 21, 9),
                  hour: '09',
                  counter: counter + 20,
                ),
              ],
              songs[1].id: [
                ChartPoint(
                  time: DateTime(2026, 8, 21, 8),
                  hour: '08',
                  counter: counter - 10,
                ),
                ChartPoint(
                  time: DateTime(2026, 8, 21, 9),
                  hour: '09',
                  counter: counter + 10,
                ),
              ],
            },
            updatedAt: DateTime(2026, 8, 21, 9),
          );

      final firstSnapshot = snapshotFor(songs[0], 100);
      final refreshedSnapshot = snapshotFor(refreshedSong, 120);
      final recoveredSnapshot = snapshotFor(recoveredSong, 140);
      final pendingRefresh = Completer<ChartSnapshot>();
      var chartCalls = 0;

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              chartRefreshInterval: const Duration(seconds: 1),
              loadChart: () {
                chartCalls++;
                return switch (chartCalls) {
                  1 => Future.value(firstSnapshot),
                  2 => pendingRefresh.future,
                  3 => Future<ChartSnapshot>.error(
                    StateError('realtime temporarily unavailable'),
                  ),
                  _ => Future.value(recoveredSnapshot),
                };
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(chartCalls, 1);
      expect(find.text('Một Bài Hát'), findsWidgets);

      await tester.pump(const Duration(seconds: 1));
      expect(chartCalls, 2);
      expect(find.byKey(const ValueKey('chart-refreshing')), findsOneWidget);
      expect(find.text('Một Bài Hát'), findsWidgets);

      pendingRefresh.complete(refreshedSnapshot);
      await tester.pumpAndSettle();
      expect(find.text('Một Bài Hát · Realtime'), findsWidgets);
      expect(find.byKey(const ValueKey('chart-refreshing')), findsNothing);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(chartCalls, 3);
      expect(find.text('Một Bài Hát · Realtime'), findsWidgets);
      expect(find.byKey(const ValueKey('chart-refresh-retry')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('chart-refresh-retry')));
      await tester.pumpAndSettle();
      expect(chartCalls, 4);
      expect(find.text('Một Bài Hát · Đã Kết Nối'), findsWidgets);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 2));
      expect(chartCalls, 4);

      final callsWhileInactive = chartCalls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 1002));
      await tester.pump();
      expect(chartCalls, greaterThan(callsWhileInactive));
      expect(find.text('Một Bài Hát · Đã Kết Nối'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opens official chart artist and album metadata without starting playback',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      addTearDown(controller.dispose);
      const chartArtist = CatalogArtist(
        id: 'chart-artist',
        name: 'Ca Sĩ A',
        aliasName: 'Ca-Si-A',
        avatar: '',
        externalUrl: 'https://zingmp3.vn/nghe-si/Ca-Si-A',
      );
      const featuredArtist = CatalogArtist(
        id: 'featured-artist',
        name: 'Nghệ Sĩ Khách Mời',
        aliasName: 'Nghe-Si-Khach-Moi',
        avatar: '',
        externalUrl: 'https://zingmp3.vn/nghe-si/Nghe-Si-Khach-Moi',
      );
      const chartAlbum = CatalogCollection(
        id: 'chart-album',
        title: 'Một Bài Hát (Single)',
        artist: 'Sơn Tùng M-TP',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: 'https://zingmp3.vn/album/mot-bai-hat/chart-album.html',
      );
      const snapshot = ChartSnapshot(
        songs: songs,
        songMetadata: {
          'one': ChartSongMetadata(
            albumTitle: 'Một Bài Hát (Single)',
            duration: Duration(minutes: 4),
            artists: [chartArtist, featuredArtist],
            album: chartAlbum,
          ),
        },
      );
      final albumDetail = CatalogCollectionDetail(
        collection: chartAlbum,
        description: 'Single chính thức từ Zing MP3.',
        year: '2026',
        genres: ['V-Pop'],
        songs: [
          CatalogSong(
            song: songs[0],
            duration: Duration(minutes: 4),
            externalUrl: 'https://zingmp3.vn/bai-hat/mot-bai-hat/one.html',
            playable: true,
          ),
        ],
        catalogPlaybackEnabled: true,
      );
      final artistDetail = CatalogArtistDetail(
        artist: chartArtist,
        cover: '',
        biography: 'Hồ sơ nghệ sĩ chính thức từ Zing MP3.',
        realName: 'Ca Sĩ A',
        national: 'Việt Nam',
        birthday: '',
        totalFollow: 1000,
        awardCount: 0,
        songs: [
          CatalogSong(
            song: songs[0],
            duration: const Duration(minutes: 4),
            externalUrl: 'https://zingmp3.vn/bai-hat/mot-bai-hat/one.html',
            playable: true,
          ),
        ],
        collectionSections: const [],
        relatedArtists: const [],
        catalogPlaybackEnabled: true,
      );
      final featuredArtistDetail = CatalogArtistDetail(
        artist: featuredArtist,
        cover: '',
        biography: 'Hồ sơ nghệ sĩ khách mời từ Zing MP3.',
        realName: 'Nghệ Sĩ Khách Mời',
        national: 'Việt Nam',
        birthday: '',
        totalFollow: 500,
        awardCount: 0,
        songs: const [],
        collectionSections: const [],
        relatedArtists: const [],
        catalogPlaybackEnabled: true,
      );
      String? requestedArtist;
      String? requestedAlbum;
      String? requestedSongId;

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              chartRefreshInterval: null,
              loadChart: () async => snapshot,
              loadArtistDetail: (alias) async {
                requestedArtist = alias;
                return alias == featuredArtist.aliasName
                    ? featuredArtistDetail
                    : artistDetail;
              },
              loadSongDetail: (songId) async {
                requestedSongId = songId;
                return SongDetail(
                  catalogSong: albumDetail.songs.first,
                  artists: const [chartArtist, featuredArtist],
                  album: chartAlbum,
                  releasedAt: DateTime(2026),
                  distributor: 'Zing MP3',
                  genres: const ['V-Pop'],
                  composers: const [],
                  listenCount: 1000,
                  likeCount: 100,
                  commentCount: 10,
                  mv: null,
                  catalogPlaybackEnabled: true,
                );
              },
              loadCollection: (id) async {
                requestedAlbum = id;
                return albumDetail;
              },
              loadDiscoveryHome: () async => const DiscoveryHome.empty(),
              loadDiscoveryCategories: () async => _testDiscoveryCategories,
              loadDiscoveryRecommendations: () async =>
                  const DiscoveryRecommendations.empty(),
              loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
              loadNewReleases: () async => const NewReleaseChart.empty(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Thông tin Một Bài Hát'));
      await tester.pumpAndSettle();
      expect(requestedSongId, 'one');
      expect(find.byKey(const ValueKey('song-detail-close')), findsOneWidget);
      expect(controller.currentSong, isNull);
      await tester.tap(find.byKey(const ValueKey('song-detail-close')));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Mở nghệ sĩ Ca Sĩ A'));
      await tester.pumpAndSettle();
      expect(requestedArtist, 'Ca-Si-A');
      expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
      expect(controller.currentSong, isNull);

      await tester.tap(find.text('#zingchart'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Mở nghệ sĩ Nghệ Sĩ Khách Mời'));
      await tester.pumpAndSettle();
      expect(requestedArtist, 'Nghe-Si-Khach-Moi');
      expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
      expect(controller.currentSong, isNull);

      await tester.tap(find.text('#zingchart'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Mở album Một Bài Hát (Single)'));
      await tester.pumpAndSettle();
      expect(requestedAlbum, 'chart-album');
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      expect(controller.currentSong, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opens chart Song Detail from the mobile overflow menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    String? requestedSongId;

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            chartRefreshInterval: null,
            loadSongs: () async => songs,
            loadSongDetail: (songId) async {
              requestedSongId = songId;
              return SongDetail(
                catalogSong: CatalogSong(
                  song: songs.first,
                  duration: const Duration(minutes: 4),
                  externalUrl:
                      'https://zingmp3.vn/bai-hat/mot-bai-hat/one.html',
                  playable: true,
                ),
                artists: const [],
                album: null,
                releasedAt: DateTime(2026),
                distributor: 'Zing MP3',
                genres: const ['V-Pop'],
                composers: const [],
                listenCount: 1000,
                likeCount: 100,
                commentCount: 10,
                mv: null,
                catalogPlaybackEnabled: true,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tùy chọn bài hát').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông tin bài hát'));
    await tester.pumpAndSettle();

    expect(requestedSongId, 'one');
    expect(find.byKey(const ValueKey('song-detail-close')), findsOneWidget);
    expect(controller.currentSong, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV remote focuses and opens an individual chart artist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    const featuredArtist = CatalogArtist(
      id: 'tv-featured',
      name: 'Nghệ Sĩ Khách Mời Trên TV',
      aliasName: 'Nghe-Si-Khach-Moi-TV',
      avatar: '',
      externalUrl: 'https://zingmp3.vn/nghe-si/Nghe-Si-Khach-Moi-TV',
    );
    const snapshot = ChartSnapshot(
      songs: songs,
      songMetadata: {
        'one': ChartSongMetadata(
          albumTitle: 'Một Bài Hát (Single)',
          duration: Duration(minutes: 4),
          artists: [_responsiveArtist, featuredArtist],
        ),
      },
    );
    const featuredDetail = CatalogArtistDetail(
      artist: featuredArtist,
      cover: '',
      biography: 'Hồ sơ nghệ sĩ khách mời trên TV.',
      realName: 'Nghệ Sĩ Khách Mời Trên TV',
      national: 'Việt Nam',
      birthday: '',
      totalFollow: 100,
      awardCount: 0,
      songs: [],
      collectionSections: [],
      relatedArtists: [],
      catalogPlaybackEnabled: true,
    );
    String? requestedArtist;

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            tvMode: true,
            chartRefreshInterval: null,
            loadChart: () async => snapshot,
            loadArtistDetail: (alias) async {
              requestedArtist = alias;
              return alias == featuredArtist.aliasName
                  ? featuredDetail
                  : _responsiveArtistDetail;
            },
            loadDiscoveryHome: () async => const DiscoveryHome.empty(),
            loadDiscoveryCategories: () async => _testDiscoveryCategories,
            loadDiscoveryRecommendations: () async =>
                const DiscoveryRecommendations.empty(),
            loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
            loadNewReleases: () async => const NewReleaseChart.empty(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final artistLink = find.byKey(const ValueKey('artist-link-tv-featured'));
    expect(artistLink, findsOneWidget);
    var focused = _primaryFocusIsInside(artistLink);
    for (var step = 0; step < 28 && !focused; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      focused = _primaryFocusIsInside(artistLink);
    }
    expect(focused, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(requestedArtist, 'Nghe-Si-Khach-Moi-TV');
    expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
    expect(controller.currentSong, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart metadata links remain adaptive across all breakpoints', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    const chartAlbum = CatalogCollection(
      id: 'adaptive-chart-album',
      title: 'Một Bài Hát (Single)',
      artist: 'Sơn Tùng M-TP',
      thumbnail: '',
      kind: CatalogCollectionKind.album,
      externalUrl:
          'https://zingmp3.vn/album/mot-bai-hat/adaptive-chart-album.html',
    );
    const snapshot = ChartSnapshot(
      songs: songs,
      songMetadata: {
        'one': ChartSongMetadata(
          albumTitle: 'Một Bài Hát (Single)',
          duration: Duration(minutes: 4),
          artists: [_responsiveArtist],
          album: chartAlbum,
        ),
      },
    );

    for (final viewport in const [
      (Size(360, 844), false),
      (Size(768, 1024), false),
      (Size(1440, 900), false),
      (Size(1920, 1080), true),
    ]) {
      tester.view.physicalSize = viewport.$1;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              key: ValueKey('chart-${viewport.$1.width}'),
              tvMode: viewport.$2,
              chartRefreshInterval: null,
              loadChart: () async => snapshot,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('song-artist-link-one')),
        findsOneWidget,
      );
      final showsDetailAction = viewport.$2 || viewport.$1.width >= 1180;
      expect(
        find.byKey(const ValueKey('song-detail-action-one')),
        showsDetailAction ? findsOneWidget : findsNothing,
      );
      final showsAlbumLink = viewport.$2 || viewport.$1.width >= 1180;
      expect(
        find.byKey(const ValueKey('song-album-link-one')),
        showsAlbumLink ? findsOneWidget : findsNothing,
      );
      if (viewport.$1.width == 1440) {
        final cover = find.byKey(const ValueKey('song-cover-action-one'));
        final opacity = find.descendant(
          of: cover,
          matching: find.byType(AnimatedOpacity),
        );
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer();
        await mouse.moveTo(tester.getCenter(cover));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
        await mouse.removePointer();
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'loads an official chart suggestion independently and plays its queue',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fakeAudio = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: fakeAudio,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      addTearDown(controller.dispose);
      const suggestedSong = Song(
        id: 'suggested',
        name: 'buoc-qua-nhau',
        title: 'Bước Qua Nhau',
        thumbnail: '',
        artistsNames: 'Vũ.',
        code: 'suggested-code',
      );
      const suggestedArtist = CatalogArtist(
        id: 'suggested-artist',
        name: 'Vũ.',
        aliasName: 'Vu',
        avatar: '',
      );
      const suggestedAlbum = CatalogCollection(
        id: 'suggested-album',
        title: 'Bước Qua Nhau (Single)',
        artist: 'Vũ.',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: '',
      );
      final firstSuggestion = Completer<DiscoveryRecommendations>();
      var chartCalls = 0;
      var suggestionCalls = 0;
      String? requestedCollectionId;

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadChart: () async {
                chartCalls++;
                return ChartSnapshot(songs: songs);
              },
              loadChartSuggestion: () {
                suggestionCalls++;
                if (suggestionCalls == 1) return firstSuggestion.future;
                throw StateError('recommendation temporarily unavailable');
              },
              loadCollection: (id) async {
                requestedCollectionId = id;
                return const CatalogCollectionDetail(
                  collection: suggestedAlbum,
                  artists: [suggestedArtist],
                  description: 'Single chính thức từ dòng Gợi ý.',
                  year: '2026',
                  genres: ['V-Pop'],
                  songs: [
                    CatalogSong(
                      song: suggestedSong,
                      duration: Duration(minutes: 4, seconds: 2),
                      externalUrl: '',
                      playable: true,
                      artists: [suggestedArtist],
                      album: suggestedAlbum,
                    ),
                  ],
                  catalogPlaybackEnabled: true,
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(chartCalls, 1);
      expect(suggestionCalls, 1);
      expect(find.text('Một Bài Hát'), findsWidgets);
      expect(
        find.byKey(const ValueKey('chart-suggestion-loading')),
        findsOneWidget,
      );

      firstSuggestion.complete(
        DiscoveryRecommendations(
          updatedAt: null,
          entries: const [
            CatalogSong(
              song: Song(
                id: 'one',
                name: 'mot-bai-hat',
                title: 'Một Bài Hát',
                thumbnail: '',
                artistsNames: 'Ca Sĩ A',
                code: 'code-one',
              ),
              duration: Duration(minutes: 3),
              externalUrl: '',
              playable: true,
            ),
            CatalogSong(
              song: suggestedSong,
              duration: Duration(minutes: 4, seconds: 2),
              externalUrl: '',
              playable: true,
              artists: [suggestedArtist],
              album: suggestedAlbum,
            ),
          ],
          catalogPlaybackEnabled: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('chart-suggestion-suggested')),
        findsOneWidget,
      );
      expect(find.text('Gợi ý'), findsOneWidget);
      expect(find.text('Bước Qua Nhau'), findsWidgets);
      expect(
        find.byKey(const ValueKey('artist-link-suggested-artist')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('song-album-link-suggested')),
        findsOneWidget,
      );
      expect(find.text('Bước Qua Nhau (Single)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('song-album-link-suggested')));
      await tester.pumpAndSettle();
      expect(requestedCollectionId, suggestedAlbum.id);
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      await tester.tap(find.text('#zingchart'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chart-suggestion-suggested')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('chart-suggestion-suggested')),
      );
      await tester.tap(
        find.byKey(const ValueKey('chart-suggestion-suggested')),
      );
      await tester.pumpAndSettle();

      expect(controller.currentSong?.id, suggestedSong.id);
      expect(controller.queue.map((song) => song.id), [
        suggestedSong.id,
        ...songs.map((song) => song.id),
      ]);
      expect(fakeAudio.playedSources, hasLength(1));

      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();
      expect(chartCalls, 2);
      expect(suggestionCalls, 2);
      expect(find.text('Bước Qua Nhau'), findsWidgets);
      expect(
        find.byKey(const ValueKey('chart-suggestion-retry')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows the official top 10 first and expands to the full chart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chartSongs = List<Song>.generate(
      100,
      (index) => Song(
        id: 'chart-${index + 1}',
        name: 'chart-${index + 1}',
        title: 'Chart Song ${index + 1}',
        thumbnail: '',
        artistsNames: 'Chart Artist ${index + 1}',
        code: 'chart-code-${index + 1}',
      ),
      growable: false,
    );
    final fakeAudio = FakePlaybackAudioPlayer();
    final controller = PlaybackService(
      playbackAudioPlayer: fakeAudio,
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    var chartCalls = 0;

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            loadChart: () async {
              chartCalls++;
              return ChartSnapshot(songs: chartSongs);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('100 bài hát'), findsOneWidget);
    expect(find.text('Chart Song 10'), findsOneWidget);
    expect(find.text('Chart Song 11'), findsNothing);
    expect(find.byKey(const ValueKey('chart-show-top-100')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    expect(chartCalls, 2);
    expect(find.byKey(const ValueKey('chart-show-top-100')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('chart-1')));
    await tester.pumpAndSettle();
    expect(controller.currentSong?.id, 'chart-1');
    expect(
      controller.queue.map((song) => song.id),
      chartSongs.map((e) => e.id),
    );
    expect(fakeAudio.playedSources, hasLength(1));
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('chart-show-top-100')),
      260,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('chart-show-top-100')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chart-show-top-100')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chart-show-top-100')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('chart-11')),
      280,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const ValueKey('chart-11')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in const [
    Size(360, 844),
    Size(768, 1024),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets('top 10 CTA stays adaptive at ${viewport.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MusicPlayerController(
        libraryRepository: MemoryLibraryRepository(),
      );
      addTearDown(controller.dispose);
      final chartSongs = List<Song>.generate(
        100,
        (index) => Song(
          id: 'adaptive-chart-${index + 1}',
          name: 'adaptive-chart-${index + 1}',
          title: 'Adaptive Chart ${index + 1}',
          thumbnail: '',
          artistsNames: 'Adaptive Artist',
          code: 'adaptive-code-${index + 1}',
        ),
        growable: false,
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => chartSongs,
              tvMode: viewport.width == 1920,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('100 bài hát'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('chart-show-top-100')),
        260,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Xem top 100'), findsOneWidget);
      expect(find.byKey(const ValueKey('adaptive-chart-11')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final viewport in const [
    Size(360, 844),
    Size(768, 1024),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets('chart metadata and official suggestion stay adaptive at '
        '${viewport.width.toInt()}px', (tester) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MusicPlayerController(
        libraryRepository: MemoryLibraryRepository(),
      );
      addTearDown(controller.dispose);
      final snapshot = ChartSnapshot(
        songs: songs,
        songMetadata: {
          songs.first.id: const ChartSongMetadata(
            albumTitle: 'Một Bài Hát (Single)',
            duration: Duration(minutes: 3, seconds: 38),
            rankChange: 3,
          ),
        },
      );
      final tvMode = viewport.width == 1920;

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadChart: () async => snapshot,
              loadChartSuggestion: () async => const DiscoveryRecommendations(
                updatedAt: null,
                entries: [
                  CatalogSong(
                    song: Song(
                      id: 'adaptive-suggestion',
                      name: 'adaptive-suggestion',
                      title: 'Gợi Ý Trên Mọi Màn Hình',
                      thumbnail: '',
                      artistsNames: 'Zing MP3',
                      code: 'adaptive-suggestion-code',
                    ),
                    duration: Duration(minutes: 3, seconds: 21),
                    externalUrl: '',
                    playable: true,
                    artists: [
                      CatalogArtist(
                        id: 'adaptive-suggestion-artist',
                        name: 'Zing MP3',
                        aliasName: 'Zing-MP3',
                        avatar: '',
                      ),
                    ],
                    album: CatalogCollection(
                      id: 'adaptive-suggestion-album',
                      title: 'Gợi Ý Trên Mọi Màn Hình (Single)',
                      artist: 'Zing MP3',
                      thumbnail: '',
                      kind: CatalogCollectionKind.album,
                      externalUrl: '',
                    ),
                  ),
                ],
                catalogPlaybackEnabled: true,
              ),
              tvMode: tvMode,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('rank-change-one')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chart-suggestion-section')),
        findsOneWidget,
      );
      expect(find.text('Gợi Ý Trên Mọi Màn Hình'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('artist-link-adaptive-suggestion-artist')),
        findsOneWidget,
      );
      if (viewport.width == 1440) {
        expect(find.text('Một Bài Hát (Single)'), findsOneWidget);
        expect(find.text('3:38'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('song-album-link-adaptive-suggestion')),
          findsOneWidget,
        );
      } else if (tvMode) {
        expect(find.text('Một Bài Hát (Single)'), findsOneWidget);
        expect(find.textContaining('3:38'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('song-album-link-adaptive-suggestion')),
          findsOneWidget,
        );
      } else {
        expect(find.text('Một Bài Hát (Single)'), findsNothing);
        expect(
          find.byKey(const ValueKey('song-album-link-adaptive-suggestion')),
          findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final viewport in const [
    (width: 320.0, height: 760.0, tvMode: false),
    (width: 360.0, height: 900.0, tvMode: false),
    (width: 768.0, height: 1024.0, tvMode: false),
    (width: 1024.0, height: 900.0, tvMode: false),
    (width: 1440.0, height: 900.0, tvMode: false),
    (width: 1920.0, height: 1080.0, tvMode: true),
  ]) {
    testWidgets('catalog search renders without overflow at '
        '${viewport.width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(viewport.width, viewport.height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MusicPlayerController(
        libraryRepository: MemoryLibraryRepository(),
      );
      addTearDown(controller.dispose);
      const responsiveSearchArtist = CatalogArtist(
        id: 'responsive-search-artist',
        name: 'Sơn Tùng M-TP',
        aliasName: 'Son-Tung-M-TP',
        avatar: '',
      );
      const responsiveSearchAlbum = CatalogCollection(
        id: 'responsive-search-album',
        title: 'Nơi Này Có Anh (Single)',
        artist: 'Sơn Tùng M-TP',
        thumbnail: '',
        kind: CatalogCollectionKind.album,
        externalUrl: '',
      );
      const responsiveSearchSong = Song(
        id: 'responsive-search-song',
        name: 'responsive-search-song',
        title: 'Nơi Này Có Anh',
        thumbnail: '',
        artistsNames: 'Sơn Tùng M-TP',
        code: 'responsive-search-song',
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => songs,
              initialTab: 1,
              tvMode: viewport.tvMode,
              searchCatalog: (_) async => const CatalogSearchResult(
                query: 'Sơn Tùng',
                catalogPlaybackEnabled: false,
                songs: [
                  CatalogSong(
                    song: responsiveSearchSong,
                    duration: Duration(minutes: 4),
                    externalUrl: '',
                    playable: false,
                    artists: [responsiveSearchArtist],
                    album: responsiveSearchAlbum,
                  ),
                ],
                artists: [responsiveSearchArtist],
                videos: [
                  CatalogVideo(
                    id: 'responsive-video',
                    title: 'Nơi Này Có Anh (MV)',
                    artist: 'Sơn Tùng M-TP',
                    thumbnail: '',
                    duration: Duration(minutes: 4, seconds: 20),
                    externalUrl:
                        'https://zingmp3.vn/video-clip/noi-nay/responsive-video.html',
                  ),
                ],
              ),
              loadCollection: (_) async => const CatalogCollectionDetail(
                collection: responsiveSearchAlbum,
                artists: [responsiveSearchArtist],
                description: 'Single chính thức từ kết quả tìm kiếm.',
                year: '2026',
                genres: ['V-Pop'],
                songs: [
                  CatalogSong(
                    song: responsiveSearchSong,
                    duration: Duration(minutes: 4),
                    externalUrl: '',
                    playable: false,
                    artists: [responsiveSearchArtist],
                    album: responsiveSearchAlbum,
                  ),
                ],
                catalogPlaybackEnabled: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('chart-search-field')),
        'Sơn Tùng',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      if (find
          .byKey(const ValueKey('search-suggestion-dropdown'))
          .evaluate()
          .isNotEmpty) {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }

      expect(find.text('NỔI BẬT'), findsOneWidget);
      expect(find.text('Nơi Này Có Anh'), findsWidgets);
      expect(
        find.byKey(
          const ValueKey('search-artist-link-responsive-search-artist'),
        ),
        findsOneWidget,
      );
      if (viewport.width == 1440) {
        final officialRow = find.byKey(
          const ValueKey('song-row-responsive-search-song'),
        );
        final officialCover = find.byKey(
          const ValueKey('song-cover-action-responsive-search-song'),
        );
        final officialActions = find.byKey(
          const ValueKey('song-actions-responsive-search-song'),
        );
        await tester.ensureVisible(officialRow);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: officialRow,
            matching: find.byIcon(Icons.music_note_rounded),
          ),
          findsNothing,
        );
        expect(
          tester.getTopLeft(officialCover).dx -
              tester.getTopLeft(officialRow).dx,
          closeTo(10, 0.5),
        );
        expect(tester.widget<AnimatedOpacity>(officialActions).opacity, 0);
        expect(
          find.byKey(const ValueKey('song-album-link-responsive-search-song')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: officialRow, matching: find.text('04:00')),
          findsOneWidget,
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(officialRow));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<AnimatedOpacity>(officialActions).opacity, 1);

        final albumLink = find.byKey(
          const ValueKey('song-album-link-responsive-search-song'),
        );
        expect(albumLink, findsOneWidget);
        expect(find.textContaining('4:00'), findsWidgets);
        await tester.ensureVisible(albumLink);
        await tester.pumpAndSettle();
        await tester.tap(albumLink);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('collection-detail-hero')),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('NỔI BẬT'), findsOneWidget);
      }
      final videoTab = find.byKey(const ValueKey('search-section-videos'));
      await tester.ensureVisible(videoTab);
      await tester.pumpAndSettle();
      await tester.tap(videoTab);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('catalog-video-responsive-video')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final viewport in const [
    (width: 320.0, height: 760.0, columns: 2, tvMode: false),
    (width: 360.0, height: 900.0, columns: 2, tvMode: false),
    (width: 768.0, height: 1024.0, columns: 3, tvMode: false),
    (width: 1440.0, height: 900.0, columns: 5, tvMode: false),
    (width: 1920.0, height: 1080.0, columns: 5, tvMode: true),
  ]) {
    testWidgets('Playlist/Album search mirrors the official card grid at '
        '${viewport.width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(viewport.width, viewport.height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final collections = List.generate(
        7,
        (index) => CatalogCollection(
          id: 'responsive-collection-$index',
          title: index == 0
              ? 'Những Bài Hát Hay Nhất Của Sơn Tùng M-TP'
              : 'Playlist Sơn Tùng ${index + 1}',
          artist: index == 1
              ? 'Sơn Tùng M-TP, RayO, Ngô Lan Hương'
              : 'Sơn Tùng M-TP',
          thumbnail: '',
          kind: index.isEven
              ? CatalogCollectionKind.album
              : CatalogCollectionKind.playlist,
          externalUrl: 'https://zingmp3.vn/album/responsive-$index',
        ),
        growable: false,
      );
      CatalogCollection? openedCollection;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SearchDiscoverySummary(
                query: 'sơn tùng',
                isLoading: false,
                result: CatalogSearchResult(
                  query: 'sơn tùng',
                  songs: const [],
                  artists: const [],
                  collections: collections,
                  catalogPlaybackEnabled: true,
                ),
                errorMessage: null,
                section: CatalogSearchSection.collections,
                onSuggestion: (_) {},
                onArtistTap: (_) {},
                onSongTap: (_) {},
                onCollectionTap: (collection) {
                  openedCollection = collection;
                },
                onVideoTap: (_) {},
                onRetry: () {},
                tvMode: viewport.tvMode,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cards = [
        for (var index = 0; index < collections.length; index++)
          find.byKey(
            ValueKey('catalog-collection-responsive-collection-$index'),
          ),
      ];
      for (final card in cards) {
        expect(card, findsOneWidget);
      }
      final firstTop = tester.getTopLeft(cards.first).dy;
      for (var index = 1; index < viewport.columns; index++) {
        expect(tester.getTopLeft(cards[index]).dy, closeTo(firstTop, 0.5));
      }
      if (collections.length > viewport.columns) {
        expect(
          tester.getTopLeft(cards[viewport.columns]).dy,
          greaterThan(firstTop),
        );
      }

      final firstTitle = tester.widget<Text>(
        find.text('Những Bài Hát Hay Nhất Của Sơn Tùng M-TP'),
      );
      expect(firstTitle.maxLines, 1);
      final firstAction = find.byKey(
        const ValueKey('catalog-collection-action-responsive-collection-0'),
      );
      expect(tester.widget<AnimatedOpacity>(firstAction).opacity, 0);

      if (viewport.width == 1440) {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(cards.first));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<AnimatedOpacity>(firstAction).opacity, 1);
      }

      if (viewport.tvMode) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<AnimatedOpacity>(firstAction).opacity, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
      } else {
        await tester.tap(cards.first);
        await tester.pump();
      }
      expect(openedCollection, collections.first);
      expect(tester.takeException(), isNull);
    });
  }

  for (final viewport in const [
    (width: 320.0, height: 760.0, columns: 1, tvMode: false),
    (width: 360.0, height: 900.0, columns: 1, tvMode: false),
    (width: 768.0, height: 1024.0, columns: 2, tvMode: false),
    (width: 1024.0, height: 900.0, columns: 3, tvMode: false),
    (width: 1440.0, height: 900.0, columns: 4, tvMode: false),
    (width: 1920.0, height: 1080.0, columns: 4, tvMode: true),
  ]) {
    testWidgets('MV search mirrors official artwork and artist rows at '
        '${viewport.width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(viewport.width, viewport.height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const primaryArtist = CatalogArtist(
        id: 'responsive-video-artist',
        name: 'Jack',
        aliasName: 'Jack-Phuong-Tuan',
        avatar: 'https://image.example.com/jack.jpg',
        externalUrl: 'https://zingmp3.vn/nghe-si/Jack-Phuong-Tuan',
      );
      final videos = List.generate(
        8,
        (index) => CatalogVideo(
          id: 'responsive-mv-$index',
          title: index == 0 ? 'Em Gì Ơi' : 'MV Chính Thức ${index + 1}',
          artist: index == 1 ? 'Jack, K-ICM' : 'Jack',
          artists: const [primaryArtist],
          thumbnail: '',
          duration: Duration(minutes: 4, seconds: 46 + index),
          externalUrl:
              'https://zingmp3.vn/video-clip/responsive/responsive-mv-$index.html',
        ),
        growable: false,
      );
      CatalogVideo? openedVideo;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SearchDiscoverySummary(
                query: 'jack',
                isLoading: false,
                result: CatalogSearchResult(
                  query: 'jack',
                  songs: const [],
                  artists: const [],
                  videos: videos,
                  catalogPlaybackEnabled: true,
                ),
                errorMessage: null,
                section: CatalogSearchSection.videos,
                onSuggestion: (_) {},
                onArtistTap: (_) {},
                onSongTap: (_) {},
                onCollectionTap: (_) {},
                onVideoTap: (video) => openedVideo = video,
                onRetry: () {},
                tvMode: viewport.tvMode,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cards = [
        for (var index = 0; index < videos.length; index++)
          find.byKey(ValueKey('catalog-video-responsive-mv-$index')),
      ];
      for (final card in cards) {
        expect(card, findsOneWidget);
      }
      final firstTop = tester.getTopLeft(cards.first).dy;
      for (var index = 1; index < viewport.columns; index++) {
        expect(tester.getTopLeft(cards[index]).dy, closeTo(firstTop, 0.5));
      }
      if (videos.length > viewport.columns) {
        expect(
          tester.getTopLeft(cards[viewport.columns]).dy,
          greaterThan(firstTop),
        );
      }
      expect(
        find.byKey(const ValueKey('catalog-video-artist-responsive-mv-0')),
        findsOneWidget,
      );
      expect(find.text('04:46'), findsOneWidget);
      expect(tester.widget<Text>(find.text('Em Gì Ơi')).maxLines, 1);

      final firstAction = find.byKey(
        const ValueKey('catalog-video-action-responsive-mv-0'),
      );
      expect(tester.widget<AnimatedOpacity>(firstAction).opacity, 0);
      if (viewport.width == 1440) {
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(cards.first));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<AnimatedOpacity>(firstAction).opacity, 1);
      }

      if (viewport.tvMode) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.widget<AnimatedOpacity>(firstAction).opacity, 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
      } else {
        await tester.tap(cards.first);
        await tester.pump();
      }
      expect(openedVideo, videos.first);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'browses hub categories, refreshes detail, and opens Top 100 on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var hubHomeCalls = 0;
      var hubDetailCalls = 0;
      var top100Calls = 0;
      var collectionCalls = 0;
      final controller = MusicPlayerController(
        libraryRepository: MemoryLibraryRepository(),
      );
      addTearDown(controller.dispose);
      const collection = CatalogCollection(
        id: 'hub-playlist',
        title: 'Nhạc Gối Đầu Giường',
        artist: 'Nhiều nghệ sĩ',
        thumbnail: '',
        kind: CatalogCollectionKind.playlist,
        externalUrl: '',
      );
      const discoveryCollection = DiscoveryCollection(
        collection: collection,
        description: 'Nhạc dịu nhẹ trước khi ngủ.',
      );
      const sleepHub = CatalogHub(
        id: 'hub-sleep',
        title: 'Ngủ Ngon',
        description: 'Thả lỏng và nghỉ ngơi.',
        image: '',
        externalUrl: '',
        collections: [discoveryCollection],
      );
      const hubHome = CatalogHubHome(
        updatedAt: null,
        featured: [
          CatalogHub(
            id: 'hub-top',
            title: 'Top 100',
            description: '',
            image: '',
            externalUrl: '',
          ),
        ],
        nations: [],
        topics: [sleepHub],
        genres: [
          CatalogHub(
            id: 'hub-chill',
            title: 'Chill',
            description: '',
            image: '',
            externalUrl: '',
            collections: [discoveryCollection],
          ),
        ],
      );
      const hubDetail = CatalogHubDetail(
        hub: sleepHub,
        sections: [
          DiscoverySection(
            id: 'featured',
            title: 'Nổi bật',
            collections: [discoveryCollection],
          ),
        ],
      );
      const top100 = Top100Catalog(
        updatedAt: null,
        sections: [
          DiscoverySection(
            id: 'vietnam',
            title: 'Nhạc Việt Nam',
            collections: [discoveryCollection],
          ),
        ],
      );
      const detailSong = CatalogSong(
        song: Song(
          id: 'hub-song',
          name: 'hub-song',
          title: 'Giấc Ngủ Êm',
          thumbnail: '',
          artistsNames: 'Ca Sĩ Chill',
          code: 'hub-song-code',
        ),
        duration: Duration(minutes: 3),
        externalUrl: '',
        playable: true,
      );

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              initialTab: 1,
              loadSongs: () async => songs,
              loadDiscoveryHome: () async => DiscoveryHome(
                updatedAt: null,
                banners: const [],
                sections: const [
                  DiscoverySection(
                    id: 'discovery',
                    title: 'Top 100',
                    collections: [discoveryCollection],
                  ),
                ],
              ),
              loadHubHome: () async {
                hubHomeCalls++;
                return hubHome;
              },
              loadHubDetail: (_) async {
                hubDetailCalls++;
                return hubDetail;
              },
              loadTop100: () async {
                top100Calls++;
                return top100;
              },
              loadCollection: (_) async {
                collectionCalls++;
                return const CatalogCollectionDetail(
                  collection: collection,
                  description: 'Nhạc dịu nhẹ.',
                  year: '2026',
                  genres: ['Chill'],
                  songs: [detailSong],
                  catalogPlaybackEnabled: true,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-hub-home')));
      await tester.pumpAndSettle();
      expect(hubHomeCalls, 1);
      expect(find.byKey(const ValueKey('hub-home')), findsOneWidget);
      expect(find.text('Tâm trạng và hoạt động'), findsOneWidget);

      final sleepCard = find.byKey(const ValueKey('catalog-hub-hub-sleep'));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await tester.pumpAndSettle();
      await tester.tap(sleepCard);
      await tester.pumpAndSettle();
      expect(hubDetailCalls, 1);
      expect(find.byKey(const ValueKey('hub-detail')), findsOneWidget);
      expect(find.text('Thả lỏng và nghỉ ngơi.'), findsOneWidget);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 2000),
        10000,
      );
      await tester.pumpAndSettle();
      final detailCallsBeforePullToRefresh = hubDetailCalls;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 320));
      await tester.pumpAndSettle();
      expect(hubDetailCalls, detailCallsBeforePullToRefresh + 1);
      expect(hubHomeCalls, 1);

      final hubCollectionTitle = find.byKey(
        const ValueKey('hub-collection-title-hub-playlist'),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await tester.pumpAndSettle();
      await tester.ensureVisible(hubCollectionTitle);
      await tester.tap(hubCollectionTitle);
      await tester.pumpAndSettle();
      expect(collectionCalls, 1);
      expect(find.text('Giấc Ngủ Êm'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('collection-back-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('hub-detail-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('catalog-hub-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discovery-home')), findsOneWidget);

      final top100Button = find.byKey(const ValueKey('open-top-100'));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(top100Button);
      await tester.pumpAndSettle();
      expect(top100Calls, 1);
      expect(find.byKey(const ValueKey('top-100-catalog')), findsOneWidget);
      expect(find.text('Nhạc Việt Nam'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in [
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'hub catalog is responsive at ${viewport.size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = viewport.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = MusicPlayerController(
          libraryRepository: MemoryLibraryRepository(),
        );
        addTearDown(controller.dispose);
        const hub = CatalogHub(
          id: 'responsive-hub',
          title: 'Workout',
          description: '',
          image: '',
          externalUrl: '',
        );
        await tester.pumpWidget(
          MusicPlayerScope(
            controller: controller,
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: ZingChartScreen(
                initialTab: 1,
                tvMode: viewport.tvMode,
                loadSongs: () async => songs,
                loadDiscoveryHome: () async => const DiscoveryHome(
                  updatedAt: null,
                  banners: [],
                  sections: [
                    DiscoverySection(
                      id: 'entry',
                      title: 'Nổi bật',
                      collections: [],
                    ),
                  ],
                ),
                loadHubHome: () async => const CatalogHubHome(
                  updatedAt: null,
                  featured: [hub],
                  nations: [],
                  topics: [],
                  genres: [],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            ValueKey(viewport.tvMode ? 'open-hub-home' : 'desktop-nav-hubs'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('hub-home')), findsOneWidget);
        expect(find.text('Chủ đề & Thể loại'), findsWidgets);
        expect(tester.takeException(), isNull);
        if (viewport.tvMode) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(FocusManager.instance.primaryFocus, isNotNull);
        }
      },
    );
  }

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
      if (width >= 1320) {
        expect(find.byType(DesktopCatalogSidebar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      } else {
        expect(
          find.byType(width >= 720 ? NavigationRail : NavigationBar),
          findsOneWidget,
        );
      }
      controller.dispose();
    });
  }

  testWidgets(
    'opens Phòng Nhạc, refreshes rooms and plays LIVE without song tools',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var liveLoadCalls = 0;
      final audio = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (_) async => 'https://audio.example.com/song.mp3',
        liveRadioSourceResolver: (id) async =>
            'https://proxy.example.com/v1/live-streams/$id-token',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MusicPlayerScope(
          controller: controller,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: ZingChartScreen(
              loadSongs: () async => songs,
              loadLiveRadio: () async {
                liveLoadCalls++;
                return _liveRadioSnapshot;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.radio_outlined).first);
      await tester.pumpAndSettle();
      expect(liveLoadCalls, 1);
      expect(find.text('Phòng Nhạc'), findsWidgets);
      expect(find.byKey(const ValueKey('live-radio-vpop')), findsOneWidget);
      expect(find.text('12.5K người đang nghe'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 320));
      await tester.pumpAndSettle();
      expect(liveLoadCalls, 2);

      await tester.tap(find.byKey(const ValueKey('live-radio-vpop')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.currentLiveRadio?.id, 'vpop');
      expect(controller.isPlaying, isTrue);
      expect(audio.playedSources, hasLength(1));
      expect(controller.playbackOrigin.kind, PlaybackOriginKind.liveRadio);
      expect(find.text('ĐANG PHÁT TỪ'), findsOneWidget);
      expect(find.text('V-POP · LIVE'), findsOneWidget);
      expect(find.byKey(const ValueKey('open-song-lyrics')), findsNothing);
      expect(find.byKey(const ValueKey('open-playback-queue')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final viewport in const [
    (Size(768, 900), false),
    (Size(1440, 900), false),
    (Size(1920, 1080), true),
  ]) {
    testWidgets(
      'Phòng Nhạc renders without overflow at ${viewport.$1.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = viewport.$1;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          liveRadioSourceResolver: (_) async =>
              'https://proxy.example.com/v1/live-streams/token',
          libraryRepository: MemoryLibraryRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MusicPlayerScope(
            controller: controller,
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: ZingChartScreen(
                loadSongs: () async => songs,
                loadLiveRadio: () async => _liveRadioSnapshot,
                initialTab: 5,
                tvMode: viewport.$2,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('live-radio-vpop')), findsOneWidget);
        if (viewport.$2 || viewport.$1.width < 1320) {
          expect(find.byType(NavigationRail), findsOneWidget);
          expect(find.byType(DesktopCatalogSidebar), findsNothing);
        } else {
          expect(find.byType(DesktopCatalogSidebar), findsOneWidget);
          expect(find.byType(NavigationRail), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

bool _primaryFocusIsInside(Finder targetFinder) {
  final targets = targetFinder.evaluate();
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (targets.length != 1 || focusContext is! Element) return false;
  final target = targets.single;
  if (identical(focusContext, target)) return true;
  var found = false;
  focusContext.visitAncestorElements((ancestor) {
    if (identical(ancestor, target)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

SearchSuggestionSnapshot _searchSuggestions(
  String query, {
  String keyword = 'một bài hát',
}) => SearchSuggestionSnapshot(
  query: query,
  keywords: [keyword, '$query remix', '$query karaoke'],
  songs: const [
    SearchSuggestionSong(
      id: 'suggestion-one',
      title: 'Một Bài Hát',
      artist: 'Ca Sĩ A',
      thumbnail: '',
      duration: Duration(minutes: 3, seconds: 42),
      externalUrl: 'https://zingmp3.vn/bai-hat/mot-bai-hat/one.html',
    ),
  ],
);

SongDetail _suggestionSongDetail({
  required String id,
  required String title,
  required bool playable,
}) => SongDetail(
  catalogSong: CatalogSong(
    song: Song(
      id: id,
      name: title.toLowerCase().replaceAll(' ', '-'),
      title: title,
      thumbnail: '',
      artistsNames: 'Ca Sĩ Gợi Ý',
      code: 'source-$id',
    ),
    duration: const Duration(minutes: 3, seconds: 42),
    externalUrl: 'https://zingmp3.vn/bai-hat/goi-y/$id.html',
    playable: playable,
  ),
  artists: const [],
  album: null,
  releasedAt: DateTime(2026),
  distributor: 'Zing MP3',
  genres: const ['V-Pop'],
  composers: const [],
  listenCount: 1200,
  likeCount: 120,
  commentCount: 12,
  mv: null,
  catalogPlaybackEnabled: true,
);

const _liveRadioSnapshot = LiveRadioSnapshot(
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
        description: 'Chương trình tuyển chọn',
        startTime: null,
        endTime: null,
      ),
    ),
    LiveRadioRoom(
      id: 'bolero',
      title: 'Bolero',
      description: 'Tình khúc vượt thời gian',
      thumbnail: '',
      listenerCount: 8900,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
    LiveRadioRoom(
      id: 'kpop',
      title: 'K-POP',
      description: 'K-Pop không ngừng nghỉ',
      thumbnail: '',
      listenerCount: 4200,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
    LiveRadioRoom(
      id: 'acoustic',
      title: 'Acoustic',
      description: 'Giai điệu mộc',
      thumbnail: '',
      listenerCount: 3100,
      hostName: 'Zing MP3',
      hostThumbnail: '',
    ),
  ],
);

const _responsiveArtist = CatalogArtist(
  id: 'responsive-artist',
  name: 'Sơn Tùng M-TP',
  aliasName: 'Son-Tung-M-TP',
  avatar: '',
);

const _responsiveArtistSong = Song(
  id: 'responsive-artist-song',
  name: 'responsive-artist-song',
  title: 'Nơi Này Có Anh',
  thumbnail: '',
  artistsNames: 'Sơn Tùng M-TP',
  code: 'responsive-artist-song',
);

const _responsiveArtistSongTwo = Song(
  id: 'responsive-artist-song-two',
  name: 'chay-ngay-di',
  title: 'Chạy Ngay Đi',
  thumbnail: '',
  artistsNames: 'Sơn Tùng M-TP',
  code: 'responsive-code-two',
);

const _responsiveArtistSongThree = Song(
  id: 'responsive-artist-song-three',
  name: 'chung-ta-cua-hien-tai',
  title: 'Chúng Ta Của Hiện Tại',
  thumbnail: '',
  artistsNames: 'Sơn Tùng M-TP',
  code: 'responsive-code-three',
);

const _responsiveArtistSongFour = Song(
  id: 'responsive-artist-song-four',
  name: 'hay-trao-cho-anh',
  title: 'Hãy Trao Cho Anh',
  thumbnail: '',
  artistsNames: 'Sơn Tùng M-TP',
  code: 'responsive-code-four',
);

const _responsiveArtistLockedSong = Song(
  id: 'responsive-artist-featured-locked',
  name: 'ban-quyen-gioi-han',
  title: 'Bản Quyền Giới Hạn',
  thumbnail: '',
  artistsNames: 'Sơn Tùng M-TP',
  code: 'responsive-code-locked',
);

const _responsiveArtistSongs = [
  _responsiveArtistSong,
  _responsiveArtistSongTwo,
  _responsiveArtistSongThree,
  _responsiveArtistSongFour,
];

const _responsiveArtistAlbum = CatalogCollection(
  id: 'responsive-album',
  title: 'Chúng Ta Của Tương Lai',
  artist: 'Sơn Tùng M-TP',
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl: '',
);

const _responsiveArtistEditorialPlaylist = CatalogCollection(
  id: 'responsive-editorial-playlist',
  title: 'Sơn Tùng M-TP Tuyển Chọn',
  artist: 'Zing MP3',
  thumbnail: '',
  kind: CatalogCollectionKind.playlist,
  externalUrl: '',
);

const _responsiveArtistDetail = CatalogArtistDetail(
  artist: _responsiveArtist,
  cover: '',
  biography: 'Hồ sơ nghệ sĩ được chuẩn hóa từ proxy chính chủ.',
  realName: 'Nguyễn Thanh Tùng',
  national: 'Việt Nam',
  birthday: '05/07/1994',
  totalFollow: 2655838,
  awardCount: 12,
  featuredSongs: [
    CatalogSong(
      song: _responsiveArtistSong,
      duration: Duration(minutes: 4),
      externalUrl: '',
      playable: true,
      artists: [_responsiveArtist],
      album: _responsiveArtistAlbum,
    ),
    CatalogSong(
      song: _responsiveArtistLockedSong,
      duration: Duration(minutes: 3, seconds: 30),
      externalUrl: '',
      playable: false,
      artists: [_responsiveArtist],
      album: _responsiveArtistAlbum,
    ),
    CatalogSong(
      song: _responsiveArtistSongTwo,
      duration: Duration(minutes: 4, seconds: 8),
      externalUrl: '',
      playable: true,
      artists: [_responsiveArtist],
      album: _responsiveArtistAlbum,
    ),
  ],
  songs: [
    CatalogSong(
      song: _responsiveArtistSong,
      duration: Duration(minutes: 4),
      externalUrl: '',
      playable: true,
      artists: [_responsiveArtist],
      album: _responsiveArtistAlbum,
    ),
    CatalogSong(
      song: _responsiveArtistSongTwo,
      duration: Duration(minutes: 4, seconds: 8),
      externalUrl: '',
      playable: true,
      artists: [_responsiveArtist],
      album: _responsiveArtistAlbum,
    ),
    CatalogSong(
      song: _responsiveArtistSongThree,
      duration: Duration(minutes: 4, seconds: 2),
      externalUrl: '',
      playable: true,
      artists: [_responsiveArtist],
      album: _responsiveArtistAlbum,
    ),
    CatalogSong(
      song: _responsiveArtistSongFour,
      duration: Duration(minutes: 4, seconds: 5),
      externalUrl: '',
      playable: true,
      artists: [_responsiveArtist],
      album: _responsiveArtistAlbum,
    ),
  ],
  videos: [
    CatalogVideo(
      id: 'responsive-mv',
      title: 'Chúng Ta Của Tương Lai',
      artist: 'Sơn Tùng M-TP',
      thumbnail: '',
      duration: Duration(minutes: 4, seconds: 37),
      externalUrl:
          'https://zingmp3.vn/video-clip/chung-ta-cua-tuong-lai/responsive-mv.html',
    ),
  ],
  collectionSections: [
    CatalogArtistCollectionSection(
      id: 'responsive-editorial',
      title: 'Tuyển tập nên nghe',
      collections: [_responsiveArtistEditorialPlaylist],
    ),
    CatalogArtistCollectionSection(
      id: 'responsive-section',
      title: 'Single & EP',
      collections: [_responsiveArtistAlbum],
    ),
  ],
  relatedArtists: [
    CatalogArtist(
      id: 'responsive-related',
      name: 'MONO',
      aliasName: 'MONO-Nguyen-Viet-Hoang',
      avatar: '',
    ),
  ],
  catalogPlaybackEnabled: true,
);

const _testDiscoveryCategories = DiscoveryCategories(
  updatedAt: null,
  items: [
    DiscoveryCategory(id: '14', name: 'Thư giãn'),
    DiscoveryCategory(id: '13', name: 'Làm việc'),
    DiscoveryCategory(id: '21', name: 'Trending'),
    DiscoveryCategory(id: '18', name: 'Ngủ ngon'),
    DiscoveryCategory(id: '15', name: 'Tập luyện'),
  ],
);

class _RecordingOfficialContentShareService
    implements OfficialContentShareService {
  final List<OfficialContentShare> contents = [];

  @override
  Future<OfficialContentShareResult> share(
    OfficialContentShare content, {
    Rect? origin,
  }) async {
    contents.add(content);
    return OfficialContentShareResult.shared;
  }
}
