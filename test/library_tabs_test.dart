import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/widgets/library_hub.dart';
import 'package:zmp3chart/zing_chart_screen.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const likedSong = Song(
    id: 'library-liked-song',
    name: 'nhip-rieng',
    title: 'Nhịp Riêng',
    thumbnail: '',
    artistsNames: 'Mây Lang Thang',
    code: 'library-liked-source',
  );
  const followedArtist = CatalogArtist(
    id: 'library-artist',
    name: 'Mây Lang Thang',
    aliasName: 'May-Lang-Thang',
    avatar: '',
  );
  const savedAlbum = CatalogCollection(
    id: 'library-album',
    title: 'Mùa Nhớ',
    artist: 'Mây Lang Thang',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: 'https://zingmp3.vn/album/mua-nho/library-album.html',
  );

  Future<PlaybackService> createController() async {
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      sourceResolver: (_) async => 'https://audio.example.com/library.mp3',
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    await controller.initialize();
    controller.toggleLike(likedSong);
    controller.toggleArtistFollow(followedArtist);
    controller.toggleCollectionSaved(savedAlbum);
    final playlist = controller.createPlaylist('Buổi tối');
    controller.addSongToPlaylist(playlist.id, likedSong);
    return controller;
  }

  Widget libraryHarness(
    PlaybackService controller, {
    bool tvMode = false,
    LibrarySection section = LibrarySection.overview,
    ValueChanged<List<Song>>? onPlaySongs,
  }) => MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: SingleChildScrollView(
        child: LibraryHub(
          controller: controller,
          selectedPlaylistId: null,
          onSelectPlaylist: (_) {},
          onCreatePlaylist: () {},
          onRenamePlaylist: (_) {},
          onDeletePlaylist: (_) {},
          onPlaySongs: onPlaySongs ?? (_) {},
          onExportBackup: () {},
          onImportBackup: () {},
          onOpenAnalytics: () {},
          onOpenWrapped: () {},
          onArtistTap: (_) {},
          onCollectionTap: (_) {},
          section: section,
          tvMode: tvMode,
        ),
      ),
    ),
  );

  for (final configuration in [
    (size: const Size(320, 760), tvMode: false),
    (size: const Size(360, 844), tvMode: false),
    (size: const Size(768, 1024), tvMode: false),
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'library sections are adaptive at ${configuration.size.width.toInt()}px',
      (tester) async {
        tester.view.physicalSize = configuration.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = await createController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          libraryHarness(controller, tvMode: configuration.tvMode),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('library-section-tabs')),
          findsOneWidget,
        );
        for (final section in LibrarySection.values) {
          expect(
            find.byKey(ValueKey('library-tab-${section.name}')),
            findsOneWidget,
          );
        }
        expect(find.text('Mix của bạn'), findsOneWidget);
        expect(tester.takeException(), isNull);

        for (final section in LibrarySection.values.skip(1)) {
          await tester.pumpWidget(
            libraryHarness(
              controller,
              tvMode: configuration.tvMode,
              section: section,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(ValueKey('library-section-${section.name}')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('library tabs expose local songs playlists albums and artists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await createController();
    addTearDown(controller.dispose);
    List<Song>? played;

    await tester.pumpWidget(
      libraryHarness(controller, onPlaySongs: (songs) => played = songs),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('library-tab-songs')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('library-liked-songs-hero')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('library-play-liked-songs')));
    expect(played, [likedSong]);

    await tester.tap(find.byKey(const ValueKey('library-tab-playlists')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('playlist-${controller.playlists.single.id}')),
      findsOneWidget,
    );
    expect(find.text('Buổi tối'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('library-tab-albums')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('saved-collection-library-album')),
      findsOneWidget,
    );
    expect(find.text('Mùa Nhớ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('library-tab-artists')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('followed-artist-library-artist')),
      findsOneWidget,
    );
    expect(find.text('Mây Lang Thang'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV can switch library sections with remote keys', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await createController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(libraryHarness(controller, tvMode: true));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('library-liked-songs-hero')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ZingChartScreen only shows the song list in its library tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await createController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MusicPlayerScope(
        controller: controller,
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ZingChartScreen(
            initialTab: 4,
            loadSongs: () async => const [likedSong],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('library-liked-song')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('library-tab-songs')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-liked-song')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('library-play-liked-songs')));
    await tester.pumpAndSettle();
    expect(controller.currentSong, likedSong);

    await tester.tap(find.byKey(const ValueKey('library-tab-albums')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-liked-song')), findsNothing);
    expect(
      find.byKey(const ValueKey('saved-collection-library-album')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
