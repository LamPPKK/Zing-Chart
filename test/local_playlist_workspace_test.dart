import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/app_navigation_route.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/local_playlist_workspace.dart';
import 'package:zmp3chart/widgets/song_action_menu.dart';
import 'package:zmp3chart/zing_chart_screen.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const songs = [
    Song(
      id: 'playlist-one',
      name: 'mot-ngay',
      title: 'Một Ngày Rất Khác',
      thumbnail: '',
      artistsNames: 'Mây Lang Thang',
      code: 'playlist-code-one',
    ),
    Song(
      id: 'playlist-two',
      name: 'dem-troi',
      title: 'Đêm Trôi',
      thumbnail: '',
      artistsNames: 'Lam',
      code: 'playlist-code-two',
    ),
    Song(
      id: 'playlist-three',
      name: 'nhip-rieng',
      title: 'Nhịp Riêng',
      thumbnail: '',
      artistsNames: 'An Nhiên',
      code: 'playlist-code-three',
    ),
    Song(
      id: 'playlist-four',
      name: 'thanh-pho-mua',
      title: 'Thành Phố Mưa',
      thumbnail: '',
      artistsNames: 'Kha',
      code: 'playlist-code-four',
    ),
  ];

  LocalPlaylist playlist({List<Song> tracks = songs}) => LocalPlaylist(
    id: 'playlist-local-workspace',
    name: 'Chill cuối ngày',
    createdAt: DateTime.utc(2026, 8, 1),
    updatedAt: DateTime.utc(2026, 8, 26),
    songs: tracks,
  );

  Widget workspaceHarness({
    required Size size,
    required bool tvMode,
    LocalPlaylist? value,
    PlaylistSongMoveCallback? onMoveItem,
    ValueChanged<Song>? onRemove,
    ThemeData? theme,
  }) => MaterialApp(
    theme: theme ?? buildZingDarkTheme(tvMode: tvMode),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            LocalPlaylistWorkspace(
              playlist: value ?? playlist(),
              tvMode: tvMode,
              currentSongId: songs.first.id,
              isPlaying: true,
              onBack: () {},
              onPlayAll: () {},
              onShuffle: () {},
              onRename: () {},
              onDelete: () {},
              onSongTap: (_) {},
              onReorderItem: (_, __) {},
              onMoveItem: onMoveItem ?? (_, __) {},
              onRemove: onRemove ?? (_) {},
              actionResolver: (_) => const SongActionMenuConfiguration(
                handlers: SongActionHandlers(),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  for (final configuration in [
    (size: const Size(360, 844), tvMode: false),
    (size: const Size(768, 1024), tvMode: false),
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets('playlist workspace is adaptive at '
        '${configuration.size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = configuration.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        workspaceHarness(
          size: configuration.size,
          tvMode: configuration.tvMode,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('local-playlist-workspace-playlist-local-workspace'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('local-playlist-hero')), findsOneWidget);
      expect(find.text('Chill cuối ngày'), findsOneWidget);
      expect(find.byKey(const ValueKey('local-playlist-play')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('TV edit mode exposes deterministic Up and Down actions', (
    tester,
  ) async {
    const size = Size(1920, 1080);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final moves = <(int, int)>[];

    await tester.pumpWidget(
      workspaceHarness(
        size: size,
        tvMode: true,
        onMoveItem: (oldIndex, targetIndex) =>
            moves.add((oldIndex, targetIndex)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('local-playlist-edit')));
    await tester.pumpAndSettle();

    final moveDown = find.byKey(
      const ValueKey('local-playlist-move-down-playlist-one'),
    );
    await tester.ensureVisible(moveDown);
    await tester.pumpAndSettle();
    await tester.tap(moveDown);

    expect(moves, [(0, 1)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag reorder reports the normalized target index', (
    tester,
  ) async {
    const size = Size(768, 1024);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final moves = <(int, int)>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildZingDarkTheme(tvMode: false),
        home: MediaQuery(
          data: const MediaQueryData(size: size),
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                LocalPlaylistWorkspace(
                  playlist: playlist(),
                  tvMode: false,
                  currentSongId: null,
                  isPlaying: false,
                  onBack: () {},
                  onPlayAll: () {},
                  onShuffle: () {},
                  onRename: () {},
                  onDelete: () {},
                  onSongTap: (_) {},
                  onReorderItem: (oldIndex, targetIndex) =>
                      moves.add((oldIndex, targetIndex)),
                  onMoveItem: (_, __) {},
                  onRemove: (_) {},
                  actionResolver: (_) => const SongActionMenuConfiguration(
                    handlers: SongActionHandlers(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('local-playlist-edit')));
    await tester.pumpAndSettle();
    final handle = find.byKey(
      const ValueKey('local-playlist-handle-playlist-one'),
    );
    await tester.ensureVisible(handle);
    await tester.drag(handle, const Offset(0, 150));
    await tester.pumpAndSettle();

    expect(moves, isNotEmpty);
    expect(moves.single.$1, 0);
    expect(moves.single.$2, inInclusiveRange(1, songs.length - 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit mode exits safely when its final song disappears', (
    tester,
  ) async {
    const size = Size(360, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      workspaceHarness(
        size: size,
        tvMode: false,
        value: playlist(tracks: [songs.first]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('local-playlist-edit')));
    await tester.pumpAndSettle();
    expect(find.text('Xong'), findsOneWidget);

    await tester.pumpWidget(
      workspaceHarness(
        size: size,
        tvMode: false,
        value: playlist(tracks: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xong'), findsNothing);
    expect(find.text('Sắp xếp'), findsOneWidget);
    expect(find.byKey(const ValueKey('local-playlist-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('light theme uses its accessible primary for active labels', (
    tester,
  ) async {
    const size = Size(360, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = buildZingLightTheme(tvMode: false);

    await tester.pumpWidget(
      workspaceHarness(size: size, tvMode: false, theme: theme),
    );
    await tester.pumpAndSettle();

    final eyebrow = tester.widget<Text>(
      find.text('PLAYLIST CÁ NHÂN · LOCAL-FIRST'),
    );
    final currentTitle = tester.widget<Text>(
      find.text(songs.first.displayTitle),
    );
    expect(eyebrow.style?.color, theme.colorScheme.primary);
    expect(currentTitle.style?.color, theme.colorScheme.primary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty playlist has a clear Local-First empty state', (
    tester,
  ) async {
    const size = Size(360, 844);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      workspaceHarness(
        size: size,
        tvMode: false,
        value: playlist(tracks: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('local-playlist-empty')), findsOneWidget);
    expect(find.text('Playlist này chưa có bài hát'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen removes with Undo and creates from playlist picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final initialPlaylist = playlist();
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
      libraryRepository: MemoryLibraryRepository(
        PlayerSnapshot(playlists: [initialPlaylist]),
      ),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            chartRefreshInterval: null,
            navigationRoute: AppNavigationRoute.library(
              section: LibrarySection.playlists,
              playlistId: initialPlaylist.id,
            ),
            loadSongs: () async => songs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('local-playlist-workspace-playlist-local-workspace'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('local-playlist-edit')));
    await tester.pumpAndSettle();
    final removeButton = find.byKey(
      const ValueKey('local-playlist-remove-playlist-one'),
    );
    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pumpAndSettle();
    expect(controller.playlists.single.songs, hasLength(3));

    await tester.tap(find.text('Hoàn tác'));
    await tester.pumpAndSettle();
    expect(
      controller.playlists.single.songs.map((song) => song.id),
      songs.map((song) => song.id),
    );

    await tester.tap(find.byKey(const ValueKey('local-playlist-edit')));
    await tester.pumpAndSettle();
    final menu = find.byKey(
      const ValueKey('local-playlist-action-menu-playlist-one'),
    );
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('local-playlist-action-menu-item-playlist-playlist-one'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('playlist-picker')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('playlist-picker-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('playlist-name-field')),
      'Mới từ picker',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    final created = controller.playlists.singleWhere(
      (item) => item.name == 'Mới từ picker',
    );
    expect(created.songs, [songs.first]);
    expect(
      find.byKey(
        const ValueKey('local-playlist-workspace-playlist-local-workspace'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale playlist route never falls back to liked songs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(
        PlayerSnapshot(likedSongs: [songs.first]),
      ),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: buildZingDarkTheme(tvMode: false),
          home: ZingChartScreen(
            chartRefreshInterval: null,
            navigationRoute: const AppNavigationRoute.library(
              section: LibrarySection.playlists,
              playlistId: 'missing-playlist',
            ),
            loadSongs: () async => songs,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('local-playlist-missing')),
      findsOneWidget,
    );
    expect(find.text(songs.first.displayTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
