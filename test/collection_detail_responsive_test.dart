import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/zing_chart_screen.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final configuration in const [
    (size: Size(1180, 900), workspace: false, showQueue: false),
    (size: Size(1320, 900), workspace: true, showQueue: false),
    (size: Size(1320, 900), workspace: false, showQueue: true),
    (size: Size(1440, 900), workspace: true, showQueue: false),
  ]) {
    testWidgets('collection detail uses the expected workspace at '
        '${configuration.size.width.toInt()}px'
        '${configuration.showQueue ? ' with queue open' : ''}', (tester) async {
      await _pumpCollection(
        tester,
        size: configuration.size,
        detail: _playlistDetail,
        showDesktopQueue: configuration.showQueue,
      );

      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collection-desktop-overview')),
        configuration.workspace ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('collection-desktop-table-header')),
        configuration.workspace ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'album workspace plays all in order, numbers tracks, and hides Album column',
    (tester) async {
      final harness = await _pumpCollection(
        tester,
        size: const Size(1440, 900),
        detail: _albumDetail,
      );
      harness.controller.setShuffleEnabled(true);
      await tester.pump();

      final tableHeader = find.byKey(
        const ValueKey('collection-desktop-table-header'),
      );
      expect(tableHeader, findsOneWidget);
      expect(
        find.descendant(of: tableHeader, matching: find.text('ALBUM')),
        findsNothing,
      );
      expect(find.text('PHÁT TẤT CẢ'), findsOneWidget);
      for (var index = 0; index < _albumSongs.length; index++) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey(_albumSongs[index].song.id)),
            matching: find.text('${index + 1}'),
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('collection-play-button')));
      await tester.pumpAndSettle();

      expect(harness.controller.shuffleEnabled, isFalse);
      expect(
        harness.controller.queue.map((song) => song.id),
        _albumSongs.map((item) => item.song.id),
      );
      expect(harness.controller.currentSong?.id, _albumSongs.first.song.id);
      expect(harness.audioPlayer.playedSources, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'playlist keeps a playable queue and Escape closes its player panel first',
    (tester) async {
      final harness = await _pumpCollection(
        tester,
        size: const Size(1440, 900),
        detail: _playlistDetail,
        showDesktopQueue: true,
      );

      expect(
        find.byKey(const ValueKey('desktop-playback-queue-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('desktop-playback-queue-panel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsOneWidget,
      );
      final tableHeader = find.byKey(
        const ValueKey('collection-desktop-table-header'),
      );
      expect(tableHeader, findsOneWidget);
      expect(
        find.descendant(of: tableHeader, matching: find.text('ALBUM')),
        findsOneWidget,
      );
      expect(find.text('PHÁT NGẪU NHIÊN'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(ValueKey(_lockedPlaylistSong.song.id)));
      await tester.pump(const Duration(milliseconds: 250));

      expect(harness.controller.currentSong, isNull);
      expect(harness.controller.queue, isEmpty);
      expect(harness.audioPlayer.playedSources, isEmpty);

      await tester.tap(find.byKey(const ValueKey('collection-play-button')));
      await tester.pumpAndSettle();

      expect(harness.controller.shuffleEnabled, isTrue);
      expect(harness.controller.queue.map((song) => song.id), const [
        'playlist-song-1',
        'playlist-song-3',
      ]);
      expect(harness.controller.currentSong?.id, 'playlist-song-1');
      expect(
        harness.controller.queue.any(
          (song) => song.id == _lockedPlaylistSong.song.id,
        ),
        isFalse,
      );
      expect(harness.audioPlayer.playedSources, hasLength(1));
      expect(tester.takeException(), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('collection-detail-hero')),
        findsNothing,
      );
    },
  );
}

Future<_CollectionHarness> _pumpCollection(
  WidgetTester tester, {
  required Size size,
  required CatalogCollectionDetail detail,
  bool showDesktopQueue = false,
}) async {
  tester.view.physicalSize = size;
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

  await tester.pumpWidget(
    MusicPlayerScope(
      controller: controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildZingDarkTheme(tvMode: false),
        home: ZingChartScreen(
          loadSongs: () async =>
              detail.songs.map((item) => item.song).toList(growable: false),
          loadCollection: (id) async {
            expect(id, detail.collection.id);
            return detail;
          },
          chartRefreshInterval: null,
          initialOfficialUrl: detail.collection.externalUrl,
          initialDesktopQueueVisible: showDesktopQueue,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _CollectionHarness(controller, audioPlayer);
}

class _CollectionHarness {
  const _CollectionHarness(this.controller, this.audioPlayer);

  final PlaybackService controller;
  final FakePlaybackAudioPlayer audioPlayer;
}

const _artist = CatalogArtist(
  id: 'responsive-artist',
  name: 'Nghệ Sĩ Responsive',
  aliasName: 'Nghe-Si-Responsive',
  avatar: '',
);

const _album = CatalogCollection(
  id: 'responsive-album',
  title: 'Album Theo Thứ Tự',
  artist: 'Nghệ Sĩ Responsive',
  artists: [_artist],
  thumbnail: '',
  kind: CatalogCollectionKind.album,
  externalUrl:
      'https://zingmp3.vn/album/album-theo-thu-tu/responsive-album.html',
);

const _playlist = CatalogCollection(
  id: 'responsive-playlist',
  title: 'Playlist Ngẫu Nhiên',
  artist: 'Nghệ Sĩ Responsive',
  artists: [_artist],
  thumbnail: '',
  kind: CatalogCollectionKind.playlist,
  externalUrl:
      'https://zingmp3.vn/album/playlist-ngau-nhien/responsive-playlist.html',
);

const _albumSongs = [
  CatalogSong(
    song: Song(
      id: 'album-song-1',
      name: 'album-song-1',
      title: 'Khúc Dạo Đầu',
      thumbnail: '',
      artistsNames: 'Nghệ Sĩ Responsive',
      code: 'album-code-1',
    ),
    duration: Duration(minutes: 3, seconds: 12),
    externalUrl: '',
    playable: true,
    artists: [_artist],
    album: _album,
  ),
  CatalogSong(
    song: Song(
      id: 'album-song-2',
      name: 'album-song-2',
      title: 'Đi Qua Mùa Hạ',
      thumbnail: '',
      artistsNames: 'Nghệ Sĩ Responsive',
      code: 'album-code-2',
    ),
    duration: Duration(minutes: 4, seconds: 8),
    externalUrl: '',
    playable: true,
    artists: [_artist],
    album: _album,
  ),
  CatalogSong(
    song: Song(
      id: 'album-song-3',
      name: 'album-song-3',
      title: 'Lời Kết',
      thumbnail: '',
      artistsNames: 'Nghệ Sĩ Responsive',
      code: 'album-code-3',
    ),
    duration: Duration(minutes: 2, seconds: 59),
    externalUrl: '',
    playable: true,
    artists: [_artist],
    album: _album,
  ),
];

const _playlistSongs = [
  CatalogSong(
    song: Song(
      id: 'playlist-song-1',
      name: 'playlist-song-1',
      title: 'Mở Đầu Playlist',
      thumbnail: '',
      artistsNames: 'Nghệ Sĩ Responsive',
      code: 'playlist-code-1',
    ),
    duration: Duration(minutes: 3, seconds: 41),
    externalUrl: '',
    playable: true,
    artists: [_artist],
    album: _playlist,
  ),
  _lockedPlaylistSong,
  CatalogSong(
    song: Song(
      id: 'playlist-song-3',
      name: 'playlist-song-3',
      title: 'Kết Playlist',
      thumbnail: '',
      artistsNames: 'Nghệ Sĩ Responsive',
      code: 'playlist-code-3',
    ),
    duration: Duration(minutes: 3, seconds: 5),
    externalUrl: '',
    playable: true,
    artists: [_artist],
    album: _playlist,
  ),
];

const _lockedPlaylistSong = CatalogSong(
  song: Song(
    id: 'playlist-song-locked',
    name: 'playlist-song-locked',
    title: 'Bài Hát Bị Khóa',
    thumbnail: '',
    artistsNames: 'Nghệ Sĩ Responsive',
    code: 'playlist-code-locked',
  ),
  duration: Duration(minutes: 4),
  externalUrl: '',
  playable: false,
  artists: [_artist],
  album: _playlist,
);

const _albumDetail = CatalogCollectionDetail(
  collection: _album,
  artists: [_artist],
  description: 'Album chính thức được phát theo đúng thứ tự bài hát.',
  year: '2026',
  distributor: 'Zing MP3',
  genres: ['V-Pop'],
  songs: _albumSongs,
  catalogPlaybackEnabled: true,
);

const _playlistDetail = CatalogCollectionDetail(
  collection: _playlist,
  artists: [_artist],
  description: 'Playlist tuyển chọn để kiểm tra trải nghiệm responsive.',
  year: '2026',
  distributor: 'Zing MP3',
  genres: ['V-Pop'],
  songs: _playlistSongs,
  catalogPlaybackEnabled: true,
);
