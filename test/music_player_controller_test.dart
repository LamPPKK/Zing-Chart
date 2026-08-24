import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/data/listening_analytics_repository.dart';
import 'package:zmp3chart/models/listening_analytics.dart';
import 'package:zmp3chart/models/live_radio.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/playback_origin.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/song_radio.dart';
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
  const followedArtist = CatalogArtist(
    id: 'artist-a',
    name: 'Ca Sĩ A',
    aliasName: 'Ca-Si-A',
    avatar: 'https://photo-resize-zmp3.zmdcdn.me/w240/artist-a.jpg',
    externalUrl: 'https://zingmp3.vn/nghe-si/Ca-Si-A',
  );
  const savedCollection = CatalogCollection(
    id: 'collection-a',
    title: 'Top Hits A',
    artist: 'Ca Sĩ A',
    thumbnail: '',
    kind: CatalogCollectionKind.album,
    externalUrl: 'https://zingmp3.vn/album/Top-Hits-A/collection-a.html',
  );
  const liveRoom = LiveRadioRoom(
    id: 'vpop',
    title: 'V-POP',
    description: 'Nhạc Việt đang thịnh hành',
    thumbnail: 'https://images.example.com/live.jpg',
    listenerCount: 12500,
    hostName: 'Zing MP3',
    hostThumbnail: '',
    program: LiveRadioProgram(
      id: 'program-vpop',
      title: 'Nhạc Việt hôm nay',
      thumbnail: 'https://images.example.com/program.jpg',
      description: 'Phát trực tiếp',
      startTime: null,
      endTime: null,
    ),
  );

  group('PlaybackService controls', () {
    test('uses and restores the selected streaming quality', () async {
      final repository = MemoryLibraryRepository();
      final requested = <StreamingQualityPreference>[];
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        qualitySourceResolver: (code, quality) async {
          requested.add(quality);
          return 'https://audio.example.com/${quality.apiValue}/$code.mp3';
        },
        libraryRepository: repository,
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();

      controller.setStreamingQualityPreference(StreamingQualityPreference.high);
      await controller.playSong(songs.first);
      await _flushAsync();

      expect(requested, [StreamingQualityPreference.high]);
      expect(
        repository.snapshot.streamingQualityPreferenceIndex,
        StreamingQualityPreference.high.index,
      );
      controller.dispose();

      final restored = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: repository,
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await restored.initialize();
      expect(
        restored.streamingQualityPreference,
        StreamingQualityPreference.high,
      );
      restored.dispose();
    });

    test(
      'retries unavailable high quality with Auto and preserves the queue',
      () async {
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
        controller.setStreamingQualityPreference(
          StreamingQualityPreference.high,
        );

        await controller.playSong(songs[1], queue: songs);
        expect(controller.errorMessage, contains('320 kbps'));
        expect(audio.playedSources, isEmpty);

        await controller.retryPlayback(useAutomaticQuality: true);

        expect(requested, [
          StreamingQualityPreference.high,
          StreamingQualityPreference.automatic,
        ]);
        expect(
          controller.streamingQualityPreference,
          StreamingQualityPreference.automatic,
        );
        expect(controller.currentSong, songs[1]);
        expect(controller.queue, songs);
        expect(controller.currentIndex, 1);
        expect(controller.errorMessage, isNull);
        expect(controller.isPlaying, isTrue);
        expect(audio.playedSources, hasLength(1));
        controller.dispose();
      },
    );

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

    test('extends the queue with Song Radio at its boundary', () async {
      final audio = FakePlaybackAudioPlayer();
      var radioCalls = 0;
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        songRadioLoader: (code) async {
          radioCalls++;
          return SongRadio(
            seedId: code,
            recommendations: [_radioSong(songs[1]), _radioSong(songs[2])],
          );
        },
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      await controller.playSong(songs.first, queue: [songs.first]);

      await controller.next();

      expect(radioCalls, 1);
      expect(controller.currentSong, songs[1]);
      expect(controller.queue.map((song) => song.id), ['one', 'two', 'three']);
      expect(controller.isRadioSong(songs[1]), isTrue);
      expect(controller.isRadioSong(songs[2]), isTrue);
      expect(controller.playbackOrigin.kind, PlaybackOriginKind.songRadio);
      expect(controller.playbackOrigin.label, 'Song Radio · Một Bài Hát');
      expect(controller.radioErrorMessage, isNull);
      controller.dispose();
    });

    test('coalesces concurrent radio loads and advances only once', () async {
      final audio = FakePlaybackAudioPlayer();
      final radioResult = Completer<SongRadio>();
      var radioCalls = 0;
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        songRadioLoader: (code) {
          radioCalls++;
          return radioResult.future;
        },
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      await controller.playSong(songs.first, queue: [songs.first]);

      final firstNext = controller.next();
      final secondNext = controller.next();
      await Future<void>.delayed(Duration.zero);
      expect(radioCalls, 1);
      radioResult.complete(
        SongRadio(
          seedId: songs.first.code,
          recommendations: [_radioSong(songs[1])],
        ),
      );
      await Future.wait([firstNext, secondNext]);

      expect(controller.currentSong, songs[1]);
      expect(audio.playedSources, hasLength(2));
      controller.dispose();
    });

    test('keeps the current queue usable when Song Radio fails', () async {
      final audio = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        songRadioLoader: (_) async => throw Exception('radio unavailable'),
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      await controller.playSong(songs.first, queue: [songs.first]);

      final count = await controller.startSongRadio();

      expect(count, 0);
      expect(controller.queue, [songs.first]);
      expect(controller.radioErrorMessage, contains('radio unavailable'));
      expect(controller.isRadioLoading, isFalse);
      controller.dispose();
    });

    test(
      'restores and persists the autoplay recommendation preference',
      () async {
        final repository = MemoryLibraryRepository(
          const PlayerSnapshot(
            queue: songs,
            autoplayRecommendationsEnabled: false,
            volume: 0.35,
            radioSongIds: ['two'],
          ),
        );
        final audio = FakePlaybackAudioPlayer();
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          songRadioLoader: (code) async => SongRadio.empty(code),
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        expect(controller.autoplayRecommendationsEnabled, isFalse);
        expect(controller.volume, 0.35);
        expect(audio.volumeValues, [0.35]);
        expect(controller.isRadioSong(songs[1]), isTrue);

        controller.toggleAutoplayRecommendations();
        await _flushAsync();

        expect(controller.autoplayRecommendationsEnabled, isTrue);
        expect(repository.snapshot.autoplayRecommendationsEnabled, isTrue);
        controller.dispose();
      },
    );

    test(
      'persists playback origin and keeps it across queue navigation',
      () async {
        final repository = MemoryLibraryRepository();
        final audio = FakePlaybackAudioPlayer();
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        await controller.playSong(
          songs.first,
          queue: songs,
          origin: const PlaybackOrigin(
            kind: PlaybackOriginKind.collection,
            label: '  Album   chính thức  ',
          ),
        );
        await controller.next();
        await _flushAsync();

        expect(controller.currentSong, songs[1]);
        expect(controller.playbackOrigin.kind, PlaybackOriginKind.collection);
        expect(controller.playbackOrigin.label, 'Album chính thức');
        expect(repository.snapshot.playbackOrigin.label, 'Album chính thức');
        controller.dispose();

        final restored = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await restored.initialize();
        expect(restored.playbackOrigin.kind, PlaybackOriginKind.collection);
        expect(restored.playbackOrigin.label, 'Album chính thức');
        restored.dispose();
      },
    );

    test(
      'clears the queue without interrupting the current song or its origin',
      () async {
        final repository = MemoryLibraryRepository();
        final audio = FakePlaybackAudioPlayer();
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        await controller.playSong(
          songs[1],
          queue: songs,
          origin: const PlaybackOrigin(
            kind: PlaybackOriginKind.collection,
            label: 'Album chính thức',
          ),
        );
        audio.emitDuration(const Duration(minutes: 3));
        audio.emitPosition(const Duration(seconds: 42));
        await _flushAsync();
        final playCalls = audio.playedSources.length;
        final stopCalls = audio.stopCalls;

        expect(controller.canClearPlaybackQueue, isTrue);
        expect(controller.clearPlaybackQueue(), isTrue);
        await _flushAsync();

        expect(controller.queue, [songs[1]]);
        expect(controller.currentSong, songs[1]);
        expect(controller.currentIndex, 0);
        expect(controller.position, const Duration(seconds: 42));
        expect(controller.playbackOrigin.label, 'Album chính thức');
        expect(audio.playedSources, hasLength(playCalls));
        expect(audio.stopCalls, stopCalls);
        expect(controller.canClearPlaybackQueue, isFalse);
        expect(controller.clearPlaybackQueue(), isFalse);
        expect(repository.snapshot.queue, [songs[1]]);
        expect(repository.snapshot.playbackOrigin.label, 'Album chính thức');
        controller.dispose();
      },
    );

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

    test(
      'plays LIVE without polluting history, analytics or restore',
      () async {
        final audio = FakePlaybackAudioPlayer();
        final repository = MemoryLibraryRepository();
        var sourceCalls = 0;
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (_) async => throw StateError('unused'),
          liveRadioSourceResolver: (id) async {
            sourceCalls++;
            return 'https://proxy.example.com/v1/live-streams/$id-token';
          },
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();

        await controller.playLiveRadio(liveRoom);
        audio.emitDuration(const Duration(hours: 1));
        audio.emitPosition(const Duration(seconds: 40));
        await _flushAsync();

        expect(controller.isLiveRadio, isTrue);
        expect(controller.currentLiveRadio, liveRoom);
        expect(controller.currentSong?.displayTitle, 'V-POP');
        expect(controller.currentSong?.artistsNames, 'Nhạc Việt hôm nay');
        expect(controller.playbackOrigin.kind, PlaybackOriginKind.liveRadio);
        expect(controller.playbackOrigin.label, 'V-POP · LIVE');
        expect(controller.isPlaying, isTrue);
        expect(controller.canGoNext, isFalse);
        expect(controller.canGoPrevious, isFalse);
        expect(controller.history, isEmpty);
        expect(controller.hasAnalyticsActivity, isFalse);
        expect(repository.snapshot.currentSong, isNull);
        expect(repository.snapshot.queue, isEmpty);
        expect(repository.snapshot.position, Duration.zero);

        await controller.seek(const Duration(minutes: 5));
        expect(audio.seekTargets, isEmpty);
        await controller.stop();
        await controller.togglePlayPause();
        expect(
          sourceCalls,
          1,
          reason: 'Nguồn LIVE đã tải được có thể dùng lại.',
        );
        expect(audio.playedSources, hasLength(2));
        controller.dispose();
      },
    );

    test(
      'latest LIVE selection wins and a normal song exits LIVE mode',
      () async {
        final audio = FakePlaybackAudioPlayer();
        final firstSource = Completer<String>();
        final secondSource = Completer<String>();
        const secondRoom = LiveRadioRoom(
          id: 'kpop',
          title: 'K-POP',
          description: 'K-Pop LIVE',
          thumbnail: '',
          listenerCount: 500,
          hostName: '',
          hostThumbnail: '',
        );
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          liveRadioSourceResolver: (id) =>
              id == liveRoom.id ? firstSource.future : secondSource.future,
          libraryRepository: MemoryLibraryRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();

        final firstPlay = controller.playLiveRadio(liveRoom);
        await _flushAsync();
        final secondPlay = controller.playLiveRadio(secondRoom);
        secondSource.complete(
          'https://proxy.example.com/v1/live-streams/kpop-token',
        );
        await secondPlay;
        firstSource.complete(
          'https://proxy.example.com/v1/live-streams/vpop-token',
        );
        await firstPlay;

        expect(controller.currentLiveRadio, secondRoom);
        expect(audio.playedSources, hasLength(1));
        await controller.playSong(songs.first);
        expect(controller.isLiveRadio, isFalse);
        expect(controller.currentSong, songs.first);
        expect(controller.playbackOrigin, const PlaybackOrigin.chart());
        controller.dispose();
      },
    );
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

    test('applies and persists explicit settings selections', () async {
      final repository = MemoryLibraryRepository();
      final audio = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        songRadioLoader: (code) async => SongRadio.empty(code),
        libraryRepository: repository,
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();

      controller.setShuffleEnabled(true);
      controller.setRepeatMode(PlayerRepeatMode.one);
      controller.setAutoplayRecommendations(false);
      controller.setThemePreference(AppThemePreference.dark);
      controller.setAlwaysOpenFullscreenPlayer(true);
      controller.setCarModeEnabled(true);
      await controller.setVolume(0.42);
      await controller.toggleMute();
      expect(controller.isMuted, isTrue);
      await controller.toggleMute();
      await _flushAsync();

      expect(controller.shuffleEnabled, isTrue);
      expect(controller.repeatMode, PlayerRepeatMode.one);
      expect(controller.autoplayRecommendationsEnabled, isFalse);
      expect(controller.themePreference, AppThemePreference.dark);
      expect(controller.alwaysOpenFullscreenPlayer, isTrue);
      expect(controller.carModeEnabled, isTrue);
      expect(controller.volume, closeTo(0.42, 0.001));
      expect(controller.isMuted, isFalse);
      expect(audio.volumeValues, [1, 0.42, 0, 0.42]);
      expect(repository.snapshot.shuffleEnabled, isTrue);
      expect(repository.snapshot.repeatModeIndex, PlayerRepeatMode.one.index);
      expect(repository.snapshot.autoplayRecommendationsEnabled, isFalse);
      expect(repository.snapshot.alwaysOpenFullscreenPlayer, isTrue);
      expect(repository.snapshot.carModeEnabled, isTrue);
      expect(repository.snapshot.volume, closeTo(0.42, 0.001));
      expect(
        repository.snapshot.themePreferenceIndex,
        AppThemePreference.dark.index,
      );
      controller.dispose();
    });

    test('interleaves, marks and removes local Smart Shuffle songs', () async {
      final repository = MemoryLibraryRepository();
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: repository,
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      final baseQueue = [
        ...songs,
        const Song(
          id: 'four',
          name: 'bon',
          title: 'Bài Bốn',
          thumbnail: '',
          artistsNames: 'Ca Sĩ D',
          code: 'code-four',
        ),
      ];
      final catalog = [
        ...baseQueue,
        for (var index = 0; index < 8; index++)
          Song(
            id: 'smart-$index',
            name: 'smart-$index',
            title: 'Gợi ý $index',
            thumbnail: '',
            artistsNames: 'Nghệ sĩ gợi ý $index',
            code: 'smart-code-$index',
          ),
      ];
      controller.updateCatalog(catalog);
      await controller.playSong(baseQueue.first, queue: baseQueue);

      expect(controller.setSmartShuffleEnabled(true), isTrue);
      expect(controller.smartShuffleEnabled, isTrue);
      expect(controller.shuffleEnabled, isTrue);
      expect(controller.smartShuffleSongCount, 2);
      expect(controller.queue, hasLength(6));
      expect(controller.queue.take(3).map((song) => song.id), [
        'one',
        'two',
        'three',
      ]);
      expect(controller.isSmartShuffleSong(controller.queue[3]), isTrue);
      expect(controller.queue[4].id, 'four');
      expect(controller.isSmartShuffleSong(controller.queue[5]), isTrue);

      expect(controller.setSmartShuffleEnabled(false), isTrue);
      expect(controller.smartShuffleEnabled, isFalse);
      expect(controller.shuffleEnabled, isTrue);
      expect(controller.queue.map((song) => song.id), [
        'one',
        'two',
        'three',
        'four',
      ]);
      controller.dispose();
    });

    test(
      'persists Smart Shuffle markers and clears them with a new queue',
      () async {
        final repository = MemoryLibraryRepository();
        final catalog = [
          songs[0],
          songs[1],
          const Song(
            id: 'smart-persisted',
            name: 'smart-persisted',
            title: 'Gợi ý đã lưu',
            thumbnail: '',
            artistsNames: 'Nghệ sĩ mới',
            code: 'smart-persisted-code',
          ),
        ];
        final source = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await source.initialize();
        source.updateCatalog(catalog);
        await source.playSong(songs.first, queue: songs.take(2).toList());
        expect(source.setSmartShuffleEnabled(true), isTrue);
        await _flushAsync();
        expect(repository.snapshot.smartShuffleEnabled, isTrue);
        expect(repository.snapshot.smartShuffleSongIds, ['smart-persisted']);
        source.dispose();

        final restored = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await restored.initialize();
        expect(restored.smartShuffleEnabled, isTrue);
        expect(restored.smartShuffleSongCount, 1);
        expect(restored.shuffleEnabled, isTrue);

        await restored.playSong(songs.last, queue: [songs.last]);
        expect(restored.smartShuffleEnabled, isFalse);
        expect(restored.smartShuffleSongCount, 0);
        expect(restored.queue, [songs.last]);
        restored.dispose();
      },
    );

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

    test(
      'records qualified plays, completion and explicit early skips',
      () async {
        final audio = FakePlaybackAudioPlayer();
        final analyticsRepository = MemoryListeningAnalyticsRepository();
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: MemoryLibraryRepository(),
          analyticsRepository: analyticsRepository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();

        await controller.playSong(songs.first, queue: songs);
        audio.emitDuration(const Duration(minutes: 2));
        audio.emitPosition(const Duration(seconds: 5));
        await controller.next();
        await _flushAsync();

        var summary = controller.analyticsSummary(AnalyticsPeriod.sevenDays);
        expect(summary.earlySkips, 1);
        expect(summary.qualifiedPlays, 0);

        audio.emitDuration(const Duration(seconds: 20));
        audio.emitPosition(const Duration(seconds: 5));
        audio.emitPosition(const Duration(seconds: 10));
        audio.complete();
        await _flushAsync();

        summary = controller.analyticsSummary(AnalyticsPeriod.sevenDays);
        expect(summary.qualifiedPlays, 1);
        expect(summary.completions, 1);
        expect(summary.earlySkips, 1);
        controller.dispose();
      },
    );

    test(
      'Next at the queue end is an early skip while Stop is neutral',
      () async {
        final audio = FakePlaybackAudioPlayer();
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: MemoryLibraryRepository(),
          analyticsRepository: MemoryListeningAnalyticsRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();

        await controller.playSong(songs.first);
        audio.emitDuration(const Duration(minutes: 2));
        audio.emitPosition(const Duration(seconds: 5));
        await controller.stop();
        expect(
          controller.analyticsSummary(AnalyticsPeriod.sevenDays).earlySkips,
          0,
        );

        await controller.togglePlayPause();
        audio.emitPosition(const Duration(seconds: 5));
        await controller.next();
        expect(
          controller.analyticsSummary(AnalyticsPeriod.sevenDays).earlySkips,
          1,
        );
        controller.dispose();
      },
    );

    test('persists mood tags and analytics in backup v3', () async {
      final source = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        analyticsRepository: MemoryListeningAnalyticsRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await source.initialize();
      source.toggleMood(songs.first, MoodTag.focus);
      final backup = source.exportLibraryJson();

      final target = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        analyticsRepository: MemoryListeningAnalyticsRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await target.initialize();
      await target.importLibraryJson(backup, BackupImportMode.merge);

      expect(target.moodsFor(songs.first), {MoodTag.focus});
      expect(target.analyticsSnapshot.installationId, isNotEmpty);
      source.dispose();
      target.dispose();
    });

    test(
      'restores analytics after restart and clears it without favorites',
      () async {
        final analyticsRepository = MemoryListeningAnalyticsRepository();
        final libraryRepository = MemoryLibraryRepository();
        final audio = FakePlaybackAudioPlayer();
        final first = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: libraryRepository,
          analyticsRepository: analyticsRepository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await first.initialize();
        first.toggleLike(songs.first);
        first.toggleMood(songs.first, MoodTag.chill);
        await first.playSong(songs.first);
        audio.emitDuration(const Duration(seconds: 20));
        audio.emitPosition(const Duration(seconds: 5));
        audio.emitPosition(const Duration(seconds: 10));
        audio.complete();
        await _flushAsync();
        first.dispose();
        await _flushAsync();

        final restored = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: libraryRepository,
          analyticsRepository: analyticsRepository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await restored.initialize();
        expect(
          restored.analyticsSummary(AnalyticsPeriod.sevenDays).qualifiedPlays,
          1,
        );
        expect(restored.moodsFor(songs.first), {MoodTag.chill});
        expect(restored.isLiked(songs.first), isTrue);

        await restored.clearListeningHistoryAndStats();
        expect(restored.hasAnalyticsActivity, isFalse);
        expect(restored.history, isEmpty);
        expect(restored.isLiked(songs.first), isTrue);
        expect(restored.moodsFor(songs.first), {MoodTag.chill});
        restored.dispose();
      },
    );

    test('exports and imports library data with merge or overwrite', () async {
      final source = _controller(FakePlaybackAudioPlayer());
      await source.initialize();
      source.toggleLike(songs.first);
      source.toggleArtistFollow(followedArtist);
      source.toggleCollectionSaved(savedCollection);
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
      expect(merged.followedArtists, 1);
      expect(merged.savedCollections, 1);
      expect(
        target.likedSongs.map((song) => song.id),
        containsAll(['one', 'two']),
      );
      expect(target.playlists.single.name, 'Favorites 2026');
      expect(target.followedArtists.single.id, followedArtist.id);
      expect(target.savedCollections.single.id, savedCollection.id);
      expect(target.themePreference, AppThemePreference.light);

      await target.importLibraryJson(json, BackupImportMode.overwrite);
      expect(target.likedSongs.single.id, 'one');
      expect(target.followedArtists.single.name, followedArtist.name);
      expect(target.savedCollections.single.title, savedCollection.title);
      expect(target.recentSearches.single, 'Một Bài Hát');
      expect(target.themePreference, AppThemePreference.system);
      source.dispose();
      target.dispose();
    });

    test('restores followed artists after a local restart', () async {
      final repository = MemoryLibraryRepository();
      final source = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: repository,
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await source.initialize();
      expect(source.toggleArtistFollow(followedArtist), isTrue);
      expect(source.toggleCollectionSaved(savedCollection), isTrue);
      await _flushAsync();
      expect(repository.snapshot.followedArtists.single.id, followedArtist.id);
      expect(
        repository.snapshot.savedCollections.single.id,
        savedCollection.id,
      );
      source.dispose();

      final restored = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: repository,
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await restored.initialize();
      expect(restored.isArtistFollowed(followedArtist), isTrue);
      expect(restored.followedArtists.single.name, followedArtist.name);
      expect(restored.isCollectionSaved(savedCollection), isTrue);
      expect(restored.toggleArtistFollow(followedArtist), isFalse);
      expect(restored.toggleCollectionSaved(savedCollection), isFalse);
      restored.dispose();
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

CatalogSong _radioSong(Song song) => CatalogSong(
  song: song,
  duration: const Duration(minutes: 3),
  externalUrl: 'https://zingmp3.vn/bai-hat/${song.id}',
  playable: true,
);

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
