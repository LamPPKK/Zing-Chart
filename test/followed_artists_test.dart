import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/widgets/library_hub.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const artist = CatalogArtist(
    id: 'ha-nhi',
    name: 'Hà Nhi',
    aliasName: 'Ha-Nhi',
    avatar: '',
    externalUrl: 'https://zingmp3.vn/nghe-si/Ha-Nhi',
  );

  for (final configuration in [
    (size: const Size(360, 844), tvMode: false),
    (size: const Size(768, 1024), tvMode: false),
    (size: const Size(1440, 900), tvMode: false),
    (size: const Size(1920, 1080), tvMode: true),
  ]) {
    testWidgets(
      'followed artists library is adaptive at ${configuration.size.width.toInt()}px',
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
        await controller.initialize();
        controller.toggleArtistFollow(artist);
        var opened = 0;

        await tester.pumpWidget(
          MaterialApp(
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
                  onPlaySongs: (_) {},
                  onExportBackup: () {},
                  onImportBackup: () {},
                  onOpenAnalytics: () {},
                  onOpenWrapped: () {},
                  onArtistTap: (_) => opened++,
                  onCollectionTap: (_) {},
                  tvMode: configuration.tvMode,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final card = find.byKey(const ValueKey('followed-artist-ha-nhi'));
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        expect(find.text('Nghệ sĩ đã quan tâm'), findsOneWidget);
        expect(find.text('Hà Nhi'), findsOneWidget);
        expect(find.text('Đang quan tâm'), findsOneWidget);
        expect(card, findsOneWidget);
        expect(tester.takeException(), isNull);

        if (!configuration.tvMode) {
          await tester.tap(card);
        } else {
          var focused = false;
          for (var index = 0; index < 30 && !focused; index++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            focused = tester.widget<Focus>(card).focusNode?.hasFocus == true;
          }
          expect(focused, isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        }
        await tester.pump();
        expect(opened, 1);
      },
    );
  }

  testWidgets('library explains that followed artists stay local', (
    tester,
  ) async {
    final controller = PlaybackService(
      playbackAudioPlayer: FakePlaybackAudioPlayer(),
      libraryRepository: MemoryLibraryRepository(),
      systemMediaBridge: NoopSystemMediaBridge(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LibraryHub(
              controller: controller,
              selectedPlaylistId: null,
              onSelectPlaylist: (_) {},
              onCreatePlaylist: () {},
              onRenamePlaylist: (_) {},
              onDeletePlaylist: (_) {},
              onPlaySongs: (_) {},
              onExportBackup: () {},
              onImportBackup: () {},
              onOpenAnalytics: () {},
              onOpenWrapped: () {},
              onArtistTap: (_) {},
              onCollectionTap: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('followed-artists-empty')),
      findsOneWidget,
    );
    expect(find.textContaining('chỉ lưu trên thiết bị này'), findsOneWidget);
  });
}
