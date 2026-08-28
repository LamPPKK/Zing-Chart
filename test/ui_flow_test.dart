import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/catalog_artist_detail.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/discovery_home.dart';
import 'package:zmp3chart/models/new_release_chart.dart';
import 'package:zmp3chart/models/release_catalog.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/song_detail.dart';
import 'package:zmp3chart/models/song_lyrics.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_screen.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/library_backup_file_service.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/widgets/desktop_now_playing_panel.dart';
import 'package:zmp3chart/zing_chart_screen.dart';
import 'package:zmp3chart/zing_mp3_api.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('shows chart load failure and retries successfully', (
    tester,
  ) async {
    var attempts = 0;
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpChart(
      tester,
      controller,
      loader: () async {
        attempts++;
        if (attempts == 1) throw Exception('proxy offline');
        return songs;
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa tải được bảng xếp hạng'), findsOneWidget);
    expect(find.textContaining('proxy offline'), findsOneWidget);

    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Một Bài Hát'), findsOneWidget);
    expect(find.text('Nàng Thơ'), findsOneWidget);
  });

  testWidgets('shows loading and empty states', (tester) async {
    final result = Completer<List<Song>>();
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpChart(tester, controller, loader: () => result.future);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    result.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy bài hát phù hợp'), findsOneWidget);
  });

  testWidgets('selects a song and controls playback from Now Playing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = await _createController(audio);
    addTearDown(controller.dispose);

    await _pumpChart(tester, controller, loader: () async => songs);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Một Bài Hát'));
    await tester.pumpAndSettle();

    expect(controller.currentSong, songs.first);
    expect(controller.isPlaying, isTrue);
    expect(
      find.byKey(const ValueKey('now-playing-artwork-atmosphere')),
      findsOneWidget,
    );
    expect(find.text('ĐANG PHÁT TỪ'), findsOneWidget);
    expect(find.text('Ca Sĩ A'), findsWidgets);
    expect(
      find.byKey(const ValueKey('player-progress-slider')),
      findsOneWidget,
    );
    expect(find.byTooltip('Dừng phát'), findsOneWidget);

    final playButton = find.byKey(const ValueKey('primary-play-pause-button'));
    await tester.ensureVisible(playButton);
    await tester.pumpAndSettle();
    await tester.tap(playButton);
    await tester.pump();
    expect(audio.pauseCalls, 1);
    expect(find.bySemanticsLabel('Phát'), findsOneWidget);

    await tester.tap(find.byTooltip('Yêu thích'));
    await tester.pump();
    expect(controller.isLiked(songs.first), isTrue);
    expect(find.byTooltip('Bỏ yêu thích'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sleep-timer-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sau khi phát xong bài này'));
    await tester.pumpAndSettle();
    expect(controller.sleepAfterCurrentSong, isTrue);
    expect(find.text('Tắt sau bài này'), findsOneWidget);

    final queueButton = find.text('Hàng đợi · 2 bài');
    await tester.ensureVisible(queueButton);
    await tester.pumpAndSettle();
    await tester.tap(queueButton);
    await tester.pumpAndSettle();
    expect(find.text('Danh sách phát · 2 bài'), findsOneWidget);
    expect(find.text('Đang phát'), findsOneWidget);

    await tester.tap(find.byTooltip('Xóa khỏi hàng đợi'));
    await tester.pump();
    expect(controller.queue, [songs.first]);

    Navigator.of(tester.element(find.text('Danh sách phát · 1 bài'))).pop();
    await tester.pumpAndSettle();
    final stopButton = find.byTooltip('Dừng phát');
    await tester.ensureVisible(stopButton);
    await tester.pumpAndSettle();
    await tester.tap(stopButton);
    await tester.pump();
    expect(controller.state, PlayerState.stopped);
    expect(controller.position, Duration.zero);
  });

  testWidgets('desktop keyboard shortcuts control search, playback and panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = await _createController(audio);
    addTearDown(controller.dispose);

    await _pumpChart(tester, controller, loader: () async => songs);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-playback-dock')), findsNothing);
    expect(
      find.byKey(const ValueKey('desktop-close-player-panel')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('desktop-open-player-panel')));
    await tester.pumpAndSettle();
    expect(find.text('Hàng đợi đang trống'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-close-player-panel')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('desktop-close-player-panel')));
    await tester.pumpAndSettle();
    expect(find.text('Hàng đợi đang trống'), findsNothing);
    await tester.tap(find.text('Một Bài Hát').first);
    await tester.pumpAndSettle();
    expect(controller.currentSong, songs.first);
    expect(find.byKey(const ValueKey('desktop-playback-dock')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-close-player-panel')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-queue')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('desktop-close-player-panel')),
      findsOneWidget,
    );
    expect(find.text('TRÌNH PHÁT'), findsOneWidget);
    expect(find.text('Hàng đợi'), findsOneWidget);
    expect(find.text('Gần đây'), findsOneWidget);
    expect(find.text('Lời bài hát'), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-playback-dock')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('desktop-close-player-panel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-playback-dock')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-queue')));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(audio.pauseCalls, 1);

    await _sendModifiedKey(
      tester,
      modifier: LogicalKeyboardKey.controlLeft,
      key: LogicalKeyboardKey.arrowRight,
    );
    await tester.pumpAndSettle();
    expect(controller.currentSong, songs[1]);

    await _sendModifiedKey(
      tester,
      modifier: LogicalKeyboardKey.controlLeft,
      key: LogicalKeyboardKey.keyF,
    );
    await tester.pump();
    final searchField = tester.widget<TextField>(
      find.byKey(const ValueKey('chart-search-field')),
    );
    expect(searchField.focusNode?.hasFocus, isTrue);
    expect(find.text('Khám phá'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byTooltip('Dừng phát'), findsNothing);
    expect(find.byKey(const ValueKey('desktop-playback-dock')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-open-player-panel')),
      findsOneWidget,
    );
  });

  testWidgets('desktop can opt into opening the full Now Playing screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);
    controller.setAlwaysOpenFullscreenPlayer(true);

    await _pumpChart(tester, controller, loader: () async => songs);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Một Bài Hát').first);
    await tester.pumpAndSettle();

    expect(controller.currentSong, songs.first);
    expect(find.byType(MusicPlayerScreen), findsOneWidget);
    expect(find.text('ĐANG PHÁT TỪ'), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-playback-dock')), findsNothing);
  });

  testWidgets('mobile keeps full Now Playing below the 720px breakpoint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(719, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpChart(tester, controller, loader: () async => songs);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Một Bài Hát').first);
    await tester.pumpAndSettle();

    expect(controller.currentSong, songs.first);
    expect(find.byType(MusicPlayerScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-playback-dock')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop dock opens direct lyrics and the official MV', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);
    String? requestedSongId;
    var detailCalls = 0;
    Uri? launchedUri;
    var lyricsCalls = 0;
    const officialMvUrl =
        'https://zingmp3.vn/video-clip/mot-bai-hat/MVONE.html';

    await _pumpChart(
      tester,
      controller,
      loader: () async => songs,
      loadSongDetail: (songId) async {
        detailCalls++;
        requestedSongId = songId;
        return _songDetailFor(
          songs[0],
          mv: const CatalogVideo(
            id: 'MVONE',
            title: 'Một Bài Hát',
            artist: 'Ca Sĩ A',
            thumbnail: '',
            duration: Duration(minutes: 3),
            externalUrl: officialMvUrl,
          ),
        );
      },
      lyricsLoader: (code) async {
        lyricsCalls++;
        return SongLyrics(
          songId: code,
          synced: true,
          lines: const [
            LyricLine(
              start: Duration.zero,
              end: Duration(seconds: 20),
              text: 'Lời bài hát mở thẳng từ dock',
            ),
          ],
        );
      },
      launchExternalCatalog: (uri) async {
        launchedUri = uri;
        return true;
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Một Bài Hát').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('desktop-dock-song-more')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('desktop-dock-song-action-detail')),
    );
    await tester.pumpAndSettle();
    expect(find.text('THÔNG TIN BÀI HÁT'), findsOneWidget);
    expect(requestedSongId, songs.first.id);
    await tester.tap(find.byKey(const ValueKey('song-detail-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-lyrics')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('desktop-playback-queue-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('desktop-embedded-lyrics')),
      findsOneWidget,
    );
    expect(find.text('Lời bài hát mở thẳng từ dock'), findsOneWidget);
    expect(lyricsCalls, 1);

    await tester.tap(find.byKey(const ValueKey('desktop-queue-tab-playing')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('desktop-playing-queue-tab')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-lyrics')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('desktop-embedded-lyrics')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('desktop-close-player-panel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-mv')));
    await tester.pumpAndSettle();

    expect(requestedSongId, songs.first.id);
    expect(detailCalls, 2);
    expect(launchedUri, Uri.parse(officialMvUrl));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop MV shortcut ignores stale details and fails closed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);
    final firstDetail = Completer<SongDetail>();
    final requestedIds = <String>[];
    Uri? launchedUri;

    await _pumpChart(
      tester,
      controller,
      loader: () async => songs,
      loadSongDetail: (songId) {
        requestedIds.add(songId);
        if (songId == songs.first.id) return firstDetail.future;
        return Future.value(_songDetailFor(songs[1]));
      },
      launchExternalCatalog: (uri) async {
        launchedUri = uri;
        return true;
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Một Bài Hát').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-mv')));
    await tester.pump();
    expect(find.byTooltip('Đang tải MV chính thức'), findsOneWidget);

    await controller.playSong(songs[1], queue: songs);
    await tester.pump();
    firstDetail.complete(
      _songDetailFor(
        songs.first,
        mv: const CatalogVideo(
          id: 'STALEMV',
          title: 'MV cũ',
          artist: 'Ca Sĩ A',
          thumbnail: '',
          duration: Duration(minutes: 3),
          externalUrl: 'https://zingmp3.vn/video-clip/mv-cu/STALEMV.html',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(launchedUri, isNull);

    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-mv')));
    await tester.pumpAndSettle();
    expect(requestedIds, [songs.first.id, songs[1].id]);
    expect(
      find.text(
        '${songs[1].displayTitle} chưa có MV chính thức trên Zing MP3.',
      ),
      findsOneWidget,
    );
    expect(launchedUri, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('song detail opens the official artist inside the catalog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);
    const artist = CatalogArtist(
      id: 'artist-one',
      name: 'Ca Sĩ A',
      aliasName: 'Ca-Si-A',
      avatar: '',
      externalUrl: 'https://zingmp3.vn/nghe-si/Ca-Si-A',
    );
    const album = CatalogCollection(
      id: 'album-one',
      title: 'Một Bài Hát (Single)',
      artist: 'Ca Sĩ A',
      thumbnail: '',
      kind: CatalogCollectionKind.album,
      externalUrl: 'https://zingmp3.vn/album/mot-bai-hat-single/album-one.html',
    );
    const artistDetail = CatalogArtistDetail(
      artist: artist,
      cover: '',
      biography: 'Hồ sơ nghệ sĩ mở trực tiếp từ metadata bài hát.',
      realName: 'Ca Sĩ A',
      national: 'Việt Nam',
      birthday: '',
      totalFollow: 1200,
      awardCount: 0,
      songs: [],
      collectionSections: [],
      relatedArtists: [],
      catalogPlaybackEnabled: true,
    );
    String? requestedAlias;
    String? requestedCollectionId;

    await _pumpChart(
      tester,
      controller,
      loader: () async => songs,
      loadSongDetail: (_) async =>
          _songDetailFor(songs.first, artists: const [artist], album: album),
      loadArtistDetail: (alias) async {
        requestedAlias = alias;
        return artistDetail;
      },
      loadCollection: (id) async {
        requestedCollectionId = id;
        return const CatalogCollectionDetail(
          collection: album,
          description: 'Single chính thức mở từ thông tin bài hát.',
          year: '2026',
          genres: ['V-Pop'],
          songs: [],
          catalogPlaybackEnabled: true,
        );
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Một Bài Hát').first);
    await tester.pumpAndSettle();
    final originalQueue = controller.queue;

    await tester.tap(find.byKey(const ValueKey('desktop-dock-song-more')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('desktop-dock-song-action-detail')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('song-detail-artist-artist-one')),
    );
    await tester.pumpAndSettle();

    expect(requestedAlias, artist.aliasName);
    expect(find.byKey(const ValueKey('song-detail-scroll')), findsNothing);
    expect(find.byKey(const ValueKey('artist-profile-hero')), findsOneWidget);
    expect(
      find.text('Hồ sơ nghệ sĩ mở trực tiếp từ metadata bài hát.'),
      findsOneWidget,
    );
    expect(controller.currentSong, songs.first);
    expect(controller.queue, originalQueue);

    await tester.tap(find.byKey(const ValueKey('desktop-dock-song-more')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('desktop-dock-song-action-detail')),
    );
    await tester.pumpAndSettle();
    final albumAction = find.byKey(const ValueKey('song-detail-open-album'));
    await tester.ensureVisible(albumAction);
    await tester.pumpAndSettle();
    await tester.tap(albumAction);
    await tester.pumpAndSettle();

    expect(requestedCollectionId, album.id);
    expect(find.byKey(const ValueKey('song-detail-scroll')), findsNothing);
    expect(
      find.byKey(const ValueKey('collection-detail-hero')),
      findsOneWidget,
    );
    expect(
      find.text('Single chính thức mở từ thông tin bài hát.'),
      findsOneWidget,
    );
    expect(controller.currentSong, songs.first);
    expect(controller.queue, originalQueue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet playback dock spans the shell and queue fits at 720px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpChart(tester, controller, loader: () async => songs);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Một Bài Hát').first);
    await tester.pumpAndSettle();

    expect(controller.currentSong, songs.first);
    expect(find.byType(MusicPlayerScreen), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-mini-player')), findsNothing);
    final dock = find.byKey(const ValueKey('desktop-playback-dock'));
    expect(dock, findsOneWidget);
    final dockRect = tester.getRect(dock);
    expect(dockRect.left, 0);
    expect(dockRect.right, 720);
    expect(
      tester.getRect(find.byType(NavigationRail)).bottom,
      lessThanOrEqualTo(dockRect.top),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('desktop-dock-open-queue')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('desktop-playback-queue-panel')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('desktop-playback-dock')), findsOneWidget);
    expect(find.text('TRÌNH PHÁT'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('desktop-playback-queue-panel')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('desktop-playback-dock')), findsOneWidget);
  });

  testWidgets('desktop catalog Back and Forward restore the exact collection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);
    var collectionLoads = 0;
    const collection = CatalogCollection(
      id: 'history-album',
      title: 'Album Trong Lịch Sử',
      artist: 'Nghệ sĩ điều hướng',
      thumbnail: '',
      kind: CatalogCollectionKind.album,
      externalUrl: 'https://zingmp3.vn/album/history-album/HISTORY1.html',
    );
    const home = DiscoveryHome(
      updatedAt: null,
      banners: [],
      sections: [
        DiscoverySection(
          id: 'history-section',
          title: 'Dành cho bạn',
          collections: [
            DiscoveryCollection(
              collection: collection,
              description: 'Mở và quay lại không mất vị trí điều hướng',
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
            loadDiscoveryHome: () async => home,
            loadDiscoveryCategories: () async =>
                const DiscoveryCategories.empty(),
            loadDiscoveryRecommendations: () async =>
                const DiscoveryRecommendations.empty(),
            loadReleaseCatalog: () async => const ReleaseCatalog.empty(),
            loadNewReleases: () async => const NewReleaseChart.empty(),
            loadCollection: (id) async {
              collectionLoads++;
              return const CatalogCollectionDetail(
                collection: collection,
                description: 'Chi tiết album được khôi phục từ lịch sử.',
                year: '2026',
                genres: ['V-Pop'],
                songs: [],
                catalogPlaybackEnabled: false,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Khám phá').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Album Trong Lịch Sử').first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('collection-detail-hero')),
      findsOneWidget,
    );
    expect(collectionLoads, 1);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('catalog-history-back')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('catalog-history-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('collection-detail-hero')), findsNothing);
    expect(find.text('Album Trong Lịch Sử'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('catalog-history-forward')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('catalog-history-forward')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collection-detail-hero')),
      findsOneWidget,
    );
    expect(collectionLoads, 1);

    await _sendModifiedKey(
      tester,
      modifier: LogicalKeyboardKey.altLeft,
      key: LogicalKeyboardKey.arrowLeft,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('collection-detail-hero')), findsNothing);

    await _sendModifiedKey(
      tester,
      modifier: LogicalKeyboardKey.altLeft,
      key: LogicalKeyboardKey.arrowRight,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('collection-detail-hero')),
      findsOneWidget,
    );
    expect(collectionLoads, 1);
  });

  testWidgets('desktop history restores Discovery Home and search results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpChart(
      tester,
      controller,
      loader: () async => songs,
      searchCatalog: (query) async => CatalogSearchResult(
        query: query,
        songs: const [
          CatalogSong(
            song: Song(
              id: 'history-search-result',
              name: 'history-search-result',
              title: 'Kết Quả Điều Hướng',
              thumbnail: '',
              artistsNames: 'Nghệ sĩ lịch sử',
              code: 'history-search-code',
            ),
            duration: Duration(minutes: 3),
            externalUrl: '',
            playable: true,
          ),
        ],
        artists: const [],
        catalogPlaybackEnabled: true,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khám phá').first);
    await tester.pumpAndSettle();

    final field = find.byKey(const ValueKey('chart-search-field'));
    await tester.enterText(field, 'Nàng Thơ');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Kết Quả Điều Hướng'), findsWidgets);
    expect(tester.widget<TextField>(field).controller?.text, 'Nàng Thơ');

    await tester.tap(find.byKey(const ValueKey('catalog-history-back')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller?.text, isEmpty);
    expect(find.text('Kết Quả Điều Hướng'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('catalog-history-forward')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller?.text, 'Nàng Thơ');
    expect(find.text('Kết Quả Điều Hướng'), findsWidgets);
  });

  testWidgets('keeps the newest catalog result after competing searches', (
    tester,
  ) async {
    final first = Completer<CatalogSearchResult>();
    final second = Completer<CatalogSearchResult>();
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpChart(
      tester,
      controller,
      loader: () async => songs,
      searchCatalog: (query) => query == 'first' ? first.future : second.future,
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const ValueKey('chart-search-field'));

    await tester.enterText(field, 'first');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(field, 'second');
    await tester.pump(const Duration(milliseconds: 350));

    second.complete(
      const CatalogSearchResult(
        query: 'second',
        catalogPlaybackEnabled: true,
        songs: [
          CatalogSong(
            song: Song(
              id: 'newest',
              name: 'newest',
              title: 'Kết quả mới nhất',
              thumbnail: '',
              artistsNames: 'Nghệ sĩ mới',
              code: 'newest-code',
            ),
            duration: Duration(minutes: 3),
            externalUrl: '',
            playable: true,
          ),
        ],
        artists: [],
      ),
    );
    await tester.pump();
    first.complete(
      const CatalogSearchResult(
        query: 'first',
        catalogPlaybackEnabled: true,
        songs: [
          CatalogSong(
            song: Song(
              id: 'stale',
              name: 'stale',
              title: 'Kết quả cũ',
              thumbnail: '',
              artistsNames: 'Nghệ sĩ cũ',
              code: 'stale-code',
            ),
            duration: Duration(minutes: 3),
            externalUrl: '',
            playable: true,
          ),
        ],
        artists: [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kết quả mới nhất'), findsWidgets);
    expect(find.text('Kết quả cũ'), findsNothing);
  });

  testWidgets('creates a local playlist and exports a JSON backup', (
    tester,
  ) async {
    final backupFiles = _FakeBackupFileService();
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpChart(
      tester,
      controller,
      loader: () async => songs,
      backupFileService: backupFiles,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await tester.pumpAndSettle();

    final createButton = find.byKey(const ValueKey('create-playlist-button'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -360));
    await tester.pumpAndSettle();
    expect(createButton, findsOneWidget);
    await tester.tap(createButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('playlist-name-field')),
      'Buổi sáng',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(controller.playlists.single.name, 'Buổi sáng');

    await tester.tap(find.byKey(const ValueKey('catalog-history-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-tab-overview')));
    await tester.pumpAndSettle();
    final exportButton = find.byKey(const ValueKey('export-backup-button'));
    await tester.ensureVisible(exportButton);
    await tester.pumpAndSettle();
    expect(exportButton, findsOneWidget);
    await tester.tap(exportButton);
    await tester.pumpAndSettle();
    expect(backupFiles.exportedJson, contains('zingchart-library'));
    expect(find.text('Đã xuất backup thư viện'), findsOneWidget);
  });

  testWidgets('keeps backup restore usable after malformed nested JSON', (
    tester,
  ) async {
    final backupFiles = _FakeBackupFileService(
      importedJson:
          '{"schema":"zingchart-library","version":1,'
          '"library":{"likedSongs":[{"id":1}]}}',
    );
    final controller = await _createController();
    addTearDown(controller.dispose);

    await _pumpChart(
      tester,
      controller,
      loader: () async => songs,
      backupFileService: backupFiles,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.library_music_outlined));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('import-backup-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-import-backup-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('File backup #zingChart có dữ liệu không hợp lệ.'),
      findsOneWidget,
    );
    final restoreButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('confirm-import-backup-button')),
    );
    expect(restoreButton.onPressed, isNotNull);
  });

  testWidgets(
    'desktop catalog toolbar stays pinned and opens the local profile',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await _createController();
      addTearDown(controller.dispose);
      final longChart = List<Song>.generate(
        36,
        (index) => Song(
          id: 'toolbar-song-$index',
          name: 'toolbar-song-$index',
          title: 'Bài hát toolbar ${index + 1}',
          thumbnail: '',
          artistsNames: 'Nghệ sĩ ${(index % 5) + 1}',
          code: 'toolbar-code-$index',
        ),
      );
      controller.toggleLike(longChart.first);
      controller.createPlaylist('Tuyển tập local');

      await _pumpChart(tester, controller, loader: () async => longChart);
      await tester.pumpAndSettle();

      final toolbar = find.byKey(const ValueKey('pinned-catalog-toolbar'));
      expect(toolbar, findsOneWidget);
      expect(
        find.descendant(
          of: toolbar,
          matching: find.byKey(const ValueKey('chart-search-field')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('open-app-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('open-local-profile')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('desktop-open-local-profile')),
        findsOneWidget,
      );
      expect(find.text('1 bài thích · 1 playlist'), findsOneWidget);
      final initialTop = tester.getTopLeft(toolbar).dy;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(toolbar).dy, closeTo(initialTop, 0.1));
      expect(
        find.descendant(
          of: toolbar,
          matching: find.byKey(const ValueKey('chart-search-field')),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('open-local-profile')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('for-you-daily-mix')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('desktop-nav-chart')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('desktop-open-local-profile')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('for-you-daily-mix')), findsOneWidget);
      expect(toolbar, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalog toolbar adapts across tablet, mobile and TV', (
    tester,
  ) async {
    final controller = await _createController();
    addTearDown(controller.dispose);

    Future<void> pumpAt(Size size, {bool tvMode = false}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await _pumpChart(
        tester,
        controller,
        loader: () async => songs,
        tvMode: tvMode,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAt(const Size(768, 1024));
    expect(
      find.byKey(const ValueKey('pinned-catalog-toolbar')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('open-local-profile')), findsNothing);

    await pumpAt(const Size(360, 844));
    expect(find.byKey(const ValueKey('pinned-catalog-toolbar')), findsNothing);
    expect(find.byKey(const ValueKey('chart-search-field')), findsOneWidget);

    await pumpAt(const Size(1920, 1080), tvMode: true);
    expect(find.byKey(const ValueKey('pinned-catalog-toolbar')), findsNothing);
    expect(find.byKey(const ValueKey('chart-search-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV layout supports D-pad focus and remote media keys', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final audio = FakePlaybackAudioPlayer();
    final controller = await _createController(audio);
    addTearDown(controller.dispose);

    await _pumpChart(
      tester,
      controller,
      loader: () async => songs,
      tvMode: true,
    );
    await tester.pumpAndSettle();

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.text('Chọn một bài để bắt đầu'), findsOneWidget);
    expect(find.byKey(const ValueKey('one')), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(controller.currentSong, songs.first);
    expect(find.text('ĐANG PHÁT TỪ'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DesktopNowPlayingPanel),
        matching: find.text('#zingChart'),
      ),
      findsOneWidget,
    );

    audio.emitDuration(const Duration(minutes: 3));
    audio.emitPosition(const Duration(seconds: 30));
    await tester.pump();
    final seeksBeforeDpad = audio.seekTargets.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(audio.seekTargets, hasLength(seeksBeforeDpad));

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaPlayPause);
    await tester.pump();
    expect(audio.pauseCalls, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaFastForward);
    await tester.pump();
    expect(audio.seekTargets.last, const Duration(seconds: 40));

    await tester.sendKeyEvent(LogicalKeyboardKey.mediaTrackNext);
    await tester.pumpAndSettle();
    expect(controller.currentSong, songs[1]);

    await tester.tap(find.text('Khám phá').first);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chart-search-field')))
          .focusNode
          ?.hasFocus,
      isFalse,
    );
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('chart-search-field')))
          .focusNode
          ?.hasFocus,
      isFalse,
    );
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      0,
    );

    await tester.tap(find.text('Thư viện').first);
    await tester.pump();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      5,
    );
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      0,
    );
  });
}

Future<PlaybackService> _createController([
  FakePlaybackAudioPlayer? audio,
]) async {
  final controller = PlaybackService(
    playbackAudioPlayer: audio ?? FakePlaybackAudioPlayer(),
    sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
    libraryRepository: MemoryLibraryRepository(),
    systemMediaBridge: NoopSystemMediaBridge(),
  );
  await controller.initialize();
  return controller;
}

SongDetail _songDetailFor(
  Song song, {
  CatalogVideo? mv,
  List<CatalogArtist> artists = const [],
  CatalogCollection? album,
}) => SongDetail(
  catalogSong: CatalogSong(
    song: song,
    duration: const Duration(minutes: 3),
    externalUrl: 'https://zingmp3.vn/bai-hat/${song.name}/${song.id}.html',
    playable: true,
    hasLyrics: true,
  ),
  artists: artists,
  album: album,
  releasedAt: null,
  distributor: '',
  genres: const [],
  composers: const [],
  listenCount: 0,
  likeCount: 0,
  commentCount: 0,
  mv: mv,
  catalogPlaybackEnabled: true,
);

Future<void> _pumpChart(
  WidgetTester tester,
  PlaybackService controller, {
  required Future<List<Song>> Function() loader,
  bool tvMode = false,
  LibraryBackupFileService? backupFileService,
  CatalogSearchLoader? searchCatalog,
  CatalogSongDetailLoader? loadSongDetail,
  CatalogArtistDetailLoader? loadArtistDetail,
  CatalogCollectionLoader? loadCollection,
  Future<SongLyrics> Function(String code)? lyricsLoader,
  ExternalCatalogLauncher? launchExternalCatalog,
}) => tester.pumpWidget(
  MusicPlayerScope(
    controller: controller,
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: ZingChartScreen(
        loadSongs: loader,
        tvMode: tvMode,
        backupFileService: backupFileService,
        searchCatalog: searchCatalog ?? ZingMP3API.searchCatalog,
        loadSongDetail: loadSongDetail ?? ZingMP3API.getSongDetail,
        loadArtistDetail: loadArtistDetail ?? ZingMP3API.getArtistDetail,
        loadCollection: loadCollection ?? ZingMP3API.getCollection,
        lyricsLoader: lyricsLoader ?? ZingMP3API.getSongLyrics,
        launchExternalCatalog:
            launchExternalCatalog ?? launchExternalCatalogPage,
        loadDiscoveryHome: () async => const DiscoveryHome.empty(),
      ),
    ),
  ),
);

class _FakeBackupFileService implements LibraryBackupFileService {
  _FakeBackupFileService({this.importedJson});

  String? exportedJson;
  final String? importedJson;

  @override
  Future<bool> exportJson(String json, {required String fileName}) async {
    exportedJson = json;
    return true;
  }

  @override
  Future<String?> importJson() async => importedJson;
}

Future<void> _sendModifiedKey(
  WidgetTester tester, {
  required LogicalKeyboardKey modifier,
  required LogicalKeyboardKey key,
}) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
}
