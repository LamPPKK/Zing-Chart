import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const songs = [
    Song(
      id: 'one',
      name: 'mot-bai-hat',
      title: 'Một Bài Hát',
      thumbnail: 'https://images.example.com/one.jpg',
      artistsNames: 'Ca Sĩ A',
      code: 'code-one',
    ),
    Song(
      id: 'two',
      name: 'nang-tho',
      title: 'Nàng Thơ',
      thumbnail: 'https://images.example.com/two.jpg',
      artistsNames: 'Hoàng Dũng',
      code: 'code-two',
    ),
    Song(
      id: 'three',
      name: 'ba',
      title: 'Bài Ba',
      thumbnail: 'https://images.example.com/three.jpg',
      artistsNames: 'Ca Sĩ C',
      code: 'code-three',
    ),
  ];

  group('PlaybackService controls', () {
    test('plays, pauses, stops and replays the selected source', () async {
      final audio = FakePlaybackAudioPlayer();
      var resolveCalls = 0;
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) async {
          resolveCalls++;
          return 'https://audio.example.com/$code.mp3';
        },
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();

      await controller.playSong(songs.first, queue: songs);
      expect(controller.currentSong, songs.first);
      expect(controller.currentIndex, 0);
      expect(controller.isPlaying, isTrue);
      expect(
        (audio.playedSources.single as UrlSource).url,
        contains('code-one'),
      );

      await controller.togglePlayPause();
      expect(audio.pauseCalls, 1);
      expect(controller.state, PlayerState.paused);

      await controller.togglePlayPause();
      expect(audio.resumeCalls, 1);
      expect(controller.isPlaying, isTrue);

      await controller.stop();
      expect(controller.state, PlayerState.stopped);
      expect(controller.position, Duration.zero);

      await controller.togglePlayPause();
      expect(audio.playedSources, hasLength(2));
      expect(resolveCalls, 1, reason: 'A stopped loaded source is reusable.');
      expect(controller.isPlaying, isTrue);
      controller.dispose();
    });

    test('retries source resolution after an initial failure', () async {
      final audio = FakePlaybackAudioPlayer();
      var attempts = 0;
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (_) async {
          attempts++;
          if (attempts == 1) throw Exception('proxy unavailable');
          return 'https://audio.example.com/recovered.mp3';
        },
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();

      await controller.playSong(songs.first);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, contains('proxy unavailable'));
      expect(audio.playedSources, isEmpty);

      await controller.togglePlayPause();
      expect(attempts, 2);
      expect(controller.errorMessage, isNull);
      expect(controller.isPlaying, isTrue);
      controller.dispose();
    });

    test('clamps seeks and previous restarts after four seconds', () async {
      final audio = FakePlaybackAudioPlayer();
      final controller = _controller(audio);
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);
      audio.emitDuration(const Duration(seconds: 100));

      await controller.seek(const Duration(seconds: -5));
      await controller.seek(const Duration(seconds: 140));
      expect(audio.seekTargets, [Duration.zero, const Duration(seconds: 100)]);

      audio.emitPosition(const Duration(seconds: 12));
      await controller.previous();
      expect(audio.seekTargets.last, Duration.zero);
      expect(controller.currentSong, songs.first);
      controller.dispose();
    });

    test('navigates queue boundaries and repeat modes', () async {
      final audio = FakePlaybackAudioPlayer();
      final controller = _controller(audio);
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);

      await controller.next();
      expect(controller.currentSong, songs[1]);
      await controller.previous();
      expect(controller.currentSong, songs.first);

      controller.cycleRepeatMode();
      await controller.previous();
      expect(controller.currentSong, songs.last);

      await controller.next();
      expect(controller.currentSong, songs.first);
      controller.dispose();
    });

    test('repeat-one completion replays, then repeat-all advances', () async {
      final audio = FakePlaybackAudioPlayer();
      final controller = _controller(audio);
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);
      controller.cycleRepeatMode();
      controller.cycleRepeatMode();

      audio.complete();
      await _flushAsync();
      expect(controller.currentSong, songs.first);
      expect(audio.playedSources, hasLength(2));

      controller.cycleRepeatMode();
      controller.cycleRepeatMode();
      audio.complete();
      await _flushAsync();
      expect(controller.currentSong, songs[1]);
      controller.dispose();
    });

    test('ignores a stale source response after a rapid song change', () async {
      final audio = FakePlaybackAudioPlayer();
      final firstSource = Completer<String>();
      final secondSource = Completer<String>();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) =>
            code == songs.first.code ? firstSource.future : secondSource.future,
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();

      final firstPlay = controller.playSong(songs.first, queue: songs);
      await _flushAsync();
      final secondPlay = controller.playSong(songs[1], queue: songs);
      secondSource.complete('https://audio.example.com/two.mp3');
      await secondPlay;
      firstSource.complete('https://audio.example.com/one.mp3');
      await firstPlay;

      expect(controller.currentSong, songs[1]);
      expect(audio.playedSources, hasLength(1));
      expect(
        (audio.playedSources.single as UrlSource).url,
        endsWith('two.mp3'),
      );
      controller.dispose();
    });

    test('stop during loading cancels playback and Play retries it', () async {
      final audio = FakePlaybackAudioPlayer();
      final firstSource = Completer<String>();
      var attempts = 0;
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (_) {
          attempts++;
          if (attempts == 1) return firstSource.future;
          return Future.value('https://audio.example.com/retry.mp3');
        },
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();

      final pendingPlay = controller.playSong(songs.first);
      await _flushAsync();
      expect(controller.isLoading, isTrue);
      await controller.stop();
      firstSource.complete('https://audio.example.com/stale.mp3');
      await pendingPlay;

      expect(controller.state, PlayerState.stopped);
      expect(controller.isLoading, isFalse);
      expect(audio.playedSources, isEmpty);

      await controller.togglePlayPause();
      expect(attempts, 2);
      expect(controller.isPlaying, isTrue);
      expect(
        (audio.playedSources.single as UrlSource).url,
        endsWith('retry.mp3'),
      );
      controller.dispose();
    });
  });

  group('Queue, persistence and system controls', () {
    test(
      'inserts next, de-duplicates, removes and protects current song',
      () async {
        final audio = FakePlaybackAudioPlayer();
        final controller = _controller(audio);
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs.take(2).toList());

        expect(controller.addToQueue(songs[2]), isTrue);
        expect(controller.queue.map((song) => song.id), [
          'one',
          'three',
          'two',
        ]);
        expect(controller.addToQueue(songs[2]), isFalse);

        controller.removeFromQueue(songs.first);
        expect(controller.queue, hasLength(3));
        controller.removeFromQueue(songs[2]);
        expect(controller.queue.map((song) => song.id), ['one', 'two']);
        controller.dispose();
      },
    );

    test('publishes state and accepts media-system callbacks', () async {
      final audio = FakePlaybackAudioPlayer();
      final bridge = RecordingSystemMediaBridge();
      final repository = MemoryLibraryRepository();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: repository,
        systemMediaBridge: bridge,
      );
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);
      await _flushAsync();

      expect(bridge.snapshots.last.song, songs.first);
      expect(bridge.snapshots.last.status, SystemPlaybackStatus.playing);
      bridge.callbacks.setShuffle(true);
      bridge.callbacks.setRepeatMode(SystemRepeatMode.one);
      await bridge.callbacks.next();

      expect(controller.shuffleEnabled, isTrue);
      expect(controller.repeatMode, PlayerRepeatMode.one);
      expect(controller.currentSong, isNot(songs.first));
      await _flushAsync();
      expect(repository.snapshot.shuffleEnabled, isTrue);
      expect(repository.snapshot.repeatModeIndex, PlayerRepeatMode.one.index);
      controller.dispose();
    });

    test('manages playlists, recent searches and queue ordering', () async {
      final audio = FakePlaybackAudioPlayer();
      final controller = _controller(audio);
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);

      final playlist = controller.createPlaylist('Tập trung');
      expect(controller.addSongToPlaylist(playlist.id, songs.first), isTrue);
      expect(controller.addSongToPlaylist(playlist.id, songs.first), isFalse);
      expect(controller.addSongToPlaylist(playlist.id, songs[1]), isTrue);
      controller.reorderPlaylistSong(playlist.id, 0, 2);
      expect(controller.playlists.single.songs.first, songs[1]);
      controller.renamePlaylist(playlist.id, 'Deep focus');
      expect(controller.playlists.single.name, 'Deep focus');

      controller.recordSearch('  Hoàng Dũng  ');
      controller.recordSearch('hoàng dũng');
      expect(controller.recentSearches, ['hoàng dũng']);

      controller.reorderQueue(0, 3);
      expect(controller.queue.map((song) => song.id), ['two', 'three', 'one']);
      expect(controller.currentIndex, 2);
      controller.dispose();
    });

    test('serializes and coalesces local snapshot writes', () async {
      final repository = _BlockingLibraryRepository();
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: repository,
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();

      controller.toggleLike(songs.first);
      await repository.firstSaveStarted.future;
      controller.toggleLike(songs[1]);
      await _flushAsync();

      expect(repository.saveStarts, 1);
      expect(repository.maxConcurrentSaves, 1);
      repository.releaseFirstSave.complete();
      await repository.secondSaveCompleted.future.timeout(
        const Duration(seconds: 2),
      );

      expect(repository.maxConcurrentSaves, 1);
      expect(
        repository.snapshot.likedSongs.map((song) => song.id),
        containsAll(['one', 'two']),
      );
      controller.dispose();
    });

    test('tracks local listening stats and generates a daily mix', () async {
      final audio = FakePlaybackAudioPlayer();
      final controller = _controller(audio);
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);
      audio.emitPosition(const Duration(seconds: 2));
      audio.emitPosition(const Duration(seconds: 4));
      await controller.playSong(songs[1]);
      audio.emitPosition(const Duration(seconds: 3));
      await _flushAsync();

      expect(controller.history, hasLength(2));
      expect(controller.topSongStats, hasLength(2));
      expect(controller.totalListeningTime, const Duration(seconds: 7));
      expect(
        controller.dailyMix.map((song) => song.id),
        containsAll(['one', 'two']),
      );
      expect(controller.topArtistStats.first.playCount, 1);
      controller.dispose();
    });

    test('exports and imports library data with merge or overwrite', () async {
      final source = _controller(FakePlaybackAudioPlayer());
      await source.initialize();
      source.toggleLike(songs.first);
      final playlist = source.createPlaylist('Favorites 2026');
      source.addSongToPlaylist(playlist.id, songs.first);
      source.recordSearch('Một Bài Hát');
      final json = source.exportLibraryJson();

      final target = _controller(FakePlaybackAudioPlayer());
      await target.initialize();
      target.toggleLike(songs[1]);
      target.cycleThemePreference();
      final merged = await target.importLibraryJson(
        json,
        BackupImportMode.merge,
      );
      expect(merged.likedSongs, 1);
      expect(
        target.likedSongs.map((song) => song.id),
        containsAll(['one', 'two']),
      );
      expect(target.playlists.single.name, 'Favorites 2026');
      expect(target.themePreference, AppThemePreference.light);

      await target.importLibraryJson(json, BackupImportMode.overwrite);
      expect(target.likedSongs.single.id, 'one');
      expect(target.recentSearches.single, 'Một Bài Hát');
      expect(target.themePreference, AppThemePreference.system);
      source.dispose();
      target.dispose();
    });

    test('stops after the current song when sleep timer requests it', () async {
      final audio = FakePlaybackAudioPlayer();
      final controller = _controller(audio);
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);
      controller.setSleepAfterCurrentSong();

      audio.complete();
      await _flushAsync();

      expect(controller.hasSleepTimer, isFalse);
      expect(controller.state, PlayerState.stopped);
      expect(controller.currentSong, songs.first);
      controller.dispose();
    });
  });
}

PlaybackService _controller(FakePlaybackAudioPlayer audio) => PlaybackService(
  playbackAudioPlayer: audio,
  sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
  libraryRepository: MemoryLibraryRepository(),
  systemMediaBridge: NoopSystemMediaBridge(),
);

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class RecordingSystemMediaBridge implements SystemMediaBridge {
  late SystemMediaCallbacks callbacks;
  final List<SystemMediaSnapshot> snapshots = [];

  @override
  Future<void> bind(SystemMediaCallbacks callbacks) async {
    this.callbacks = callbacks;
  }

  @override
  Future<void> publish(SystemMediaSnapshot snapshot) async {
    snapshots.add(snapshot);
  }

  @override
  Future<void> dispose() async {}
}

class _BlockingLibraryRepository implements LibraryRepository {
  PlayerSnapshot snapshot = const PlayerSnapshot();
  final firstSaveStarted = Completer<void>();
  final releaseFirstSave = Completer<void>();
  final secondSaveCompleted = Completer<void>();
  int saveStarts = 0;
  int _concurrentSaves = 0;
  int maxConcurrentSaves = 0;

  @override
  Future<PlayerSnapshot> load() async => snapshot;

  @override
  Future<void> save(PlayerSnapshot next) async {
    final saveNumber = ++saveStarts;
    _concurrentSaves++;
    if (_concurrentSaves > maxConcurrentSaves) {
      maxConcurrentSaves = _concurrentSaves;
    }
    if (saveNumber == 1) {
      firstSaveStarted.complete();
      await releaseFirstSave.future;
    }
    snapshot = next;
    _concurrentSaves--;
    if (saveNumber == 2) secondSaveCompleted.complete();
  }
}
