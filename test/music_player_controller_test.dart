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
  const fourthSong = Song(
    id: 'four',
    name: 'bon',
    title: 'Bài Bốn',
    thumbnail: 'https://images.example.com/four.jpg',
    artistsNames: 'Ca Sĩ D',
    code: 'code-four',
  );
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
    test('restores streaming quality and Seamless Next preferences', () async {
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
      controller.setSeamlessPlaybackPreference(SeamlessPlaybackPreference.off);
      await controller.playSong(songs.first);
      await _flushAsync();

      expect(requested, [StreamingQualityPreference.high]);
      expect(
        repository.snapshot.streamingQualityPreferenceIndex,
        StreamingQualityPreference.high.index,
      );
      expect(
        repository.snapshot.seamlessPlaybackPreferenceIndex,
        SeamlessPlaybackPreference.off.index,
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
      expect(
        restored.seamlessPlaybackPreference,
        SeamlessPlaybackPreference.off,
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

    test('fails closed for locked songs across playback and queue', () async {
      const locked = Song(
        id: 'locked',
        name: 'locked',
        title: 'Bài bị giới hạn',
        thumbnail: '',
        artistsNames: 'Nghệ sĩ khóa',
        code: 'real-but-locked-code',
        playable: false,
      );
      final audio = FakePlaybackAudioPlayer();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();

      await controller.playSong(locked, queue: [locked, songs.first]);
      expect(controller.currentSong, isNull);
      expect(controller.queue, isEmpty);
      expect(audio.playedSources, isEmpty);
      expect(controller.addToQueue(locked), isFalse);

      await controller.playSong(songs.first, queue: [locked, ...songs]);
      expect(controller.currentSong, songs.first);
      expect(controller.queue, songs);
      expect(controller.queue, isNot(contains(locked)));

      await controller.playSong(songs.last, queue: const [locked]);
      expect(controller.currentSong, songs.last);
      expect(controller.queue, [songs.last]);
      controller.dispose();
    });

    test(
      'applies explicit shuffle inside a blocked play transaction',
      () async {
        final audio = BlockingStopPlaybackAudioPlayer();
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: MemoryLibraryRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs);
        var notifications = 0;
        controller.addListener(() => notifications++);
        final notificationsBeforePlay = notifications;
        audio.blockNextStop();

        final pending = controller.playSong(
          songs.last,
          queue: songs.reversed.toList(growable: false),
          origin: const PlaybackOrigin(
            kind: PlaybackOriginKind.forYou,
            label: 'Daily Mix',
          ),
          shuffleEnabled: true,
        );
        await audio.stopStarted;

        expect(notifications, notificationsBeforePlay);
        expect(controller.currentSong, songs.first);
        audio.releaseStop();
        await pending;

        expect(controller.currentSong, songs.last);
        expect(controller.shuffleEnabled, isTrue);
        expect(controller.queue, songs.reversed);
        expect(controller.playbackOrigin.kind, PlaybackOriginKind.forYou);
        expect(controller.playbackOrigin.label, 'Daily Mix');
        expect(notifications, greaterThan(notificationsBeforePlay));
        controller.dispose();
      },
    );

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

    test(
      'Repeat All Previous uses the predecessor of a middle start',
      () async {
        final controller = _controller(FakePlaybackAudioPlayer());
        await controller.initialize();
        await controller.playSong(songs[1], queue: songs);
        controller.setRepeatMode(PlayerRepeatMode.all);

        await controller.previous();

        expect(controller.currentSong, songs.first);
        controller.dispose();
      },
    );

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

    test('explicit Song Radio replaces unplayed shuffle future', () async {
      const recommendations = [
        Song(
          id: 'radio-one',
          name: 'radio-one',
          title: 'Radio Một',
          thumbnail: '',
          artistsNames: 'Radio Artist 1',
          code: 'radio-code-one',
        ),
        Song(
          id: 'radio-two',
          name: 'radio-two',
          title: 'Radio Hai',
          thumbnail: '',
          artistsNames: 'Radio Artist 2',
          code: 'radio-code-two',
        ),
      ];
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        songRadioLoader: (code) async => SongRadio(
          seedId: code,
          recommendations: recommendations.map(_radioSong).toList(),
        ),
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      await controller.playSong(songs[1], queue: songs);
      controller.setShuffleEnabled(true);

      await controller.startSongRadio();

      expect(controller.queue.map((song) => song.id), [
        'two',
        'radio-one',
        'radio-two',
      ]);
      expect(controller.nextSong, isNotNull);
      expect(controller.isRadioSong(controller.nextSong!), isTrue);
      final radioQueue = controller.queue.map((song) => song.id).toList();
      final originalFirst = controller.nextSong;
      expect(controller.reorderUpNext(1, 0), isTrue);
      expect(controller.queue.map((song) => song.id), radioQueue);
      expect(controller.nextSong, isNot(originalFirst));
      expect(controller.isRadioSong(controller.nextSong!), isTrue);
      controller.dispose();
    });

    test(
      'explicit Song Radio keeps provider order after an edited future overlap',
      () async {
        const radioFirst = Song(
          id: 'radio-first',
          name: 'radio-first',
          title: 'Radio Đầu',
          thumbnail: '',
          artistsNames: 'Radio Artist',
          code: 'radio-first-code',
        );
        const radioLast = Song(
          id: 'radio-last',
          name: 'radio-last',
          title: 'Radio Cuối',
          thumbnail: '',
          artistsNames: 'Radio Artist',
          code: 'radio-last-code',
        );
        final controller = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          songRadioLoader: (code) async => SongRadio(
            seedId: code,
            recommendations: [
              _radioSong(radioFirst),
              _radioSong(songs[2]),
              _radioSong(radioLast),
            ],
          ),
          libraryRepository: MemoryLibraryRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        await controller.playSong(songs.first, queue: [...songs, fourthSong]);
        expect(controller.reorderUpNext(2, 0), isTrue);
        expect(controller.upNextSongs, [fourthSong, songs[1], songs[2]]);

        await controller.startSongRadio();

        expect(controller.queue, [
          songs.first,
          radioFirst,
          songs[2],
          radioLast,
        ]);
        expect(controller.upNextSongs, [radioFirst, songs[2], radioLast]);
        controller.dispose();
      },
    );

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
        final bridge = RecordingSystemMediaBridge();
        var sourceCalls = 0;
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (_) async => throw StateError('unused'),
          liveRadioSourceResolver: (id) async {
            sourceCalls++;
            return 'https://proxy.example.com/v1/live-streams/$id-token';
          },
          libraryRepository: repository,
          systemMediaBridge: bridge,
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
        expect(bridge.snapshots.last.queue, [controller.currentSong]);
        expect(bridge.snapshots.last.queueIndex, 0);

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
    test('shuffle visits every queued song once before exhaustion', () async {
      final controller = _controller(FakePlaybackAudioPlayer());
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);
      controller.setShuffleEnabled(true);
      final visited = <String>[controller.currentSong!.id];

      while (controller.canGoNext) {
        await controller.next();
        visited.add(controller.currentSong!.id);
      }

      expect(visited, hasLength(songs.length));
      expect(visited.toSet(), songs.map((song) => song.id).toSet());
      expect(controller.canGoNext, isFalse);
      controller.dispose();
    });

    test(
      'shuffle Previous and forward follow the actual visit history',
      () async {
        final controller = _controller(FakePlaybackAudioPlayer());
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs);
        controller.setShuffleEnabled(true);

        await controller.next();
        final firstAdvance = controller.currentSong;
        await controller.next();
        final secondAdvance = controller.currentSong;
        await controller.previous();
        expect(controller.currentSong, firstAdvance);

        await controller.next();
        expect(controller.currentSong, secondAdvance);
        controller.dispose();
      },
    );

    test(
      'coalesces rapid queue navigation while the next song loads',
      () async {
        final audio = FakePlaybackAudioPlayer();
        final nextSource = Completer<String>();
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) {
            if (code == songs[1].code) return nextSource.future;
            return Future.value('https://audio.example.com/$code.mp3');
          },
          libraryRepository: MemoryLibraryRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs);

        final firstNext = controller.next();
        await _flushAsync();
        expect(controller.currentSong, songs[1]);
        expect(controller.isLoading, isTrue);

        final secondNext = controller.next();
        expect(identical(secondNext, firstNext), isTrue);
        nextSource.complete('https://audio.example.com/two.mp3');
        await Future.wait([firstNext, secondNext]);

        expect(controller.currentSong, songs[1]);
        expect(audio.playedSources, hasLength(2));
        await controller.previous();
        expect(controller.currentSong, songs.first);
        controller.dispose();
      },
    );

    test('direct selection rolls back a stale pending queue visit', () async {
      final audio = FakePlaybackAudioPlayer();
      final pendingSource = Completer<String>();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) => code == songs[1].code
            ? pendingSource.future
            : Future.value('https://audio.example.com/$code.mp3'),
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);

      final pendingNext = controller.next();
      await _flushAsync();
      expect(controller.currentSong, songs[1]);
      expect(controller.isLoading, isTrue);

      await controller.playSong(songs[2]);
      pendingSource.complete('https://audio.example.com/stale-two.mp3');
      await pendingNext;
      expect(controller.currentSong, songs[2]);
      expect(
        audio.playedSources.whereType<UrlSource>().map((source) => source.url),
        isNot(contains('https://audio.example.com/stale-two.mp3')),
      );

      await controller.previous();
      expect(controller.currentSong, songs.first);
      controller.dispose();
    });

    test('direct selection releases a stale navigation lock', () async {
      const fourth = Song(
        id: 'four',
        name: 'bon',
        title: 'Bài Bốn',
        thumbnail: '',
        artistsNames: 'Ca Sĩ D',
        code: 'code-four',
      );
      final audio = FakePlaybackAudioPlayer();
      final pendingSource = Completer<String>();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) => code == songs[1].code
            ? pendingSource.future
            : Future.value('https://audio.example.com/$code.mp3'),
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      await controller.playSong(songs.first, queue: [...songs, fourth]);

      final staleNext = controller.next();
      await _flushAsync();
      await controller.playSong(songs[2]);

      await controller.next().timeout(const Duration(seconds: 1));
      expect(controller.currentSong, fourth);

      pendingSource.complete('https://audio.example.com/stale-two.mp3');
      await staleNext;
      expect(controller.currentSong, fourth);
      controller.dispose();
    });

    test(
      'pending navigation rollback preserves a later Up Next edit',
      () async {
        final pendingSource = Completer<String>();
        final controller = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) => code == songs[1].code
              ? pendingSource.future
              : Future.value('https://audio.example.com/$code.mp3'),
          libraryRepository: MemoryLibraryRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        await controller.playSong(songs.first, queue: [...songs, fourthSong]);

        final staleNext = controller.next();
        await _flushAsync();
        expect(controller.currentSong, songs[1]);
        expect(controller.upNextSongs, [songs[2], fourthSong]);
        expect(controller.reorderUpNext(1, 0), isTrue);
        expect(controller.upNextSongs, [fourthSong, songs[2]]);

        await controller.playSong(fourthSong);

        expect(controller.currentSong, fourthSong);
        expect(controller.upNextSongs, [songs[2]]);
        pendingSource.complete('https://audio.example.com/stale-two.mp3');
        await staleNext;
        expect(controller.currentSong, fourthSong);
        await controller.next();
        expect(controller.currentSong, songs[2]);
        controller.dispose();
      },
    );

    test('Repeat All keeps an exact Up Next preview at cycle end', () async {
      for (final shuffled in [false, true]) {
        final controller = _controller(FakePlaybackAudioPlayer());
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs);
        controller.setShuffleEnabled(shuffled);
        while (controller.canGoNext) {
          await controller.next();
        }
        controller.setRepeatMode(PlayerRepeatMode.all);

        final preview = controller.nextSong;
        expect(preview, isNotNull);
        await controller.next();
        expect(controller.currentSong, preview);
        controller.dispose();
      }
    });

    test(
      'pending shuffled Repeat All boundary keeps its concrete future on direct selection',
      () async {
        final pendingSource = Completer<String>();
        String? blockedCode;
        var shouldBlock = false;
        final controller = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) {
            if (shouldBlock && code == blockedCode) {
              shouldBlock = false;
              return pendingSource.future;
            }
            return Future.value('https://audio.example.com/$code.mp3');
          },
          libraryRepository: MemoryLibraryRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        await controller.playSong(songs.first, queue: [...songs, fourthSong]);
        controller.setShuffleEnabled(true);
        while (controller.canGoNext) {
          await controller.next();
        }
        controller.setRepeatMode(PlayerRepeatMode.all);
        final preparedCycle = controller.upNextSongs;
        final pendingSong = preparedCycle.first;
        final committedTail = preparedCycle.skip(1).toList(growable: false);
        blockedCode = pendingSong.code;
        shouldBlock = true;

        final staleNext = controller.next();
        await _flushAsync();
        expect(controller.currentSong, pendingSong);
        expect(controller.isLoading, isTrue);
        expect(controller.upNextSongs, committedTail);

        const selectedIndex = 1;
        final selectedSong = committedTail[selectedIndex];
        final expectedRemaining = [...committedTail]..removeAt(selectedIndex);
        final revision = controller.upNextRevision;
        expect(await controller.playUpNext(selectedIndex, revision), isTrue);
        expect(controller.currentSong, selectedSong);
        expect(controller.upNextSongs, expectedRemaining);

        pendingSource.complete('https://audio.example.com/stale-boundary.mp3');
        await staleNext;
        expect(controller.currentSong, selectedSong);
        expect(controller.upNextSongs, expectedRemaining);
        controller.dispose();
      },
    );

    test(
      'reorders the actual shuffle future and restores the edited branch',
      () async {
        final repository = MemoryLibraryRepository();
        final source = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await source.initialize();
        final sourceQueue = [...songs, fourthSong];
        await source.playSong(sourceQueue.first, queue: sourceQueue);
        source.setShuffleEnabled(true);
        final originalQueueIds = source.queue.map((song) => song.id).toList();
        final before = source.upNextSongs;
        final moved = before.last;

        expect(source.reorderUpNext(before.length - 1, 0), isTrue);
        expect(source.upNextSongs.first, moved);
        expect(source.queue.map((song) => song.id), originalQueueIds);
        expect(source.playbackTimelineSongs.first, source.currentSong);
        expect(source.playbackTimelineSongs.skip(1), source.upNextSongs);
        await _flushAsync();

        final restored = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await restored.initialize();

        expect(
          restored.upNextSongs.map((song) => song.id),
          source.upNextSongs.map((song) => song.id),
        );
        expect(restored.reorderUpNext(-1, 0), isFalse);
        await restored.next();
        expect(restored.currentSong, moved);
        source.dispose();
        restored.dispose();
      },
    );

    test(
      'reordering forward history keeps the played Previous prefix',
      () async {
        final controller = _controller(FakePlaybackAudioPlayer());
        await controller.initialize();
        await controller.playSong(songs.first, queue: [...songs, fourthSong]);
        await controller.next();
        await controller.next();
        await controller.previous();
        expect(controller.currentSong, songs[1]);
        expect(controller.upNextSongs, [songs[2], fourthSong]);

        expect(controller.reorderUpNext(1, 0), isTrue);
        expect(controller.upNextSongs, [fourthSong, songs[2]]);
        await controller.next();
        expect(controller.currentSong, fourthSong);
        await controller.previous();
        expect(controller.currentSong, songs[1]);
        expect(controller.upNextSongs, [fourthSong, songs[2]]);
        controller.dispose();
      },
    );

    test(
      'direct play consumes the selected item from an edited future',
      () async {
        final controller = _controller(FakePlaybackAudioPlayer());
        await controller.initialize();
        await controller.playSong(songs.first, queue: [...songs, fourthSong]);
        expect(controller.reorderUpNext(2, 0), isTrue);
        expect(controller.upNextSongs, [fourthSong, songs[1], songs[2]]);

        await controller.playSong(fourthSong);

        expect(controller.currentSong, fourthSong);
        expect(controller.upNextSongs, [songs[1], songs[2]]);
        await controller.next();
        expect(controller.currentSong, songs[1]);
        controller.dispose();
      },
    );

    test(
      'plays the exact selected Up Next occurrence when IDs repeat',
      () async {
        final controller = _controller(FakePlaybackAudioPlayer());
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs);
        await controller.next();
        await controller.next();
        controller.setRepeatMode(PlayerRepeatMode.all);
        await controller.next();
        await controller.next();
        await controller.previous();
        await controller.previous();
        await controller.previous();
        expect(controller.upNextSongs, [
          songs[2],
          songs[0],
          songs[1],
          songs[2],
        ]);
        expect(controller.reorderUpNext(3, 1), isTrue);
        expect(controller.reorderUpNext(1, 2), isTrue);
        expect(controller.upNextSongs, [
          songs[2],
          songs[0],
          songs[2],
          songs[1],
        ]);

        final revision = controller.upNextRevision;
        expect(await controller.playUpNext(2, revision), isTrue);

        expect(controller.currentSong, songs[2]);
        expect(controller.upNextSongs, [songs[2], songs[0], songs[1]]);
        controller.dispose();
      },
    );

    test(
      'same-ID Up Next occurrence supersedes a stale navigation lock',
      () async {
        final staleSource = Completer<String>();
        var thirdSongSourceCalls = 0;
        final controller = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) {
            if (code == songs[2].code) {
              thirdSongSourceCalls++;
              if (thirdSongSourceCalls == 3) return staleSource.future;
            }
            return Future.value('https://audio.example.com/$code.mp3');
          },
          libraryRepository: MemoryLibraryRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs);
        await controller.next();
        await controller.next();
        controller.setRepeatMode(PlayerRepeatMode.all);
        await controller.next();
        await controller.next();
        await controller.previous();
        await controller.previous();
        await controller.previous();
        expect(controller.reorderUpNext(3, 1), isTrue);
        expect(controller.upNextSongs, [
          songs[2],
          songs[2],
          songs[0],
          songs[1],
        ]);

        final staleNext = controller.next();
        await _flushAsync();
        expect(controller.currentSong, songs[2]);
        expect(controller.isLoading, isTrue);
        expect(controller.upNextSongs.first, songs[2]);

        final revision = controller.upNextRevision;
        expect(await controller.playUpNext(0, revision), isTrue);
        expect(controller.currentSong, songs[2]);
        await controller.next().timeout(const Duration(seconds: 1));
        expect(controller.currentSong, songs[0]);

        staleSource.complete('https://audio.example.com/stale-three.mp3');
        await staleNext;
        expect(controller.currentSong, songs[0]);
        controller.dispose();
      },
    );

    test(
      'stale Up Next revision rejects a rapid tap while stop hangs',
      () async {
        final audio = BlockingStopPlaybackAudioPlayer();
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: MemoryLibraryRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs);
        await controller.next();
        await controller.next();
        controller.setRepeatMode(PlayerRepeatMode.all);
        await controller.next();
        await controller.next();
        await controller.previous();
        await controller.previous();
        await controller.previous();
        expect(controller.reorderUpNext(3, 1), isTrue);
        expect(controller.reorderUpNext(1, 2), isTrue);
        expect(controller.upNextSongs, [
          songs[2],
          songs[0],
          songs[2],
          songs[1],
        ]);
        final staleRevision = controller.upNextRevision;
        audio.blockNextStop();

        final firstTap = controller.playUpNext(2, staleRevision);
        await audio.stopStarted;
        expect(controller.upNextSongs, [songs[2], songs[0], songs[1]]);

        expect(
          await controller
              .playUpNext(2, staleRevision)
              .timeout(const Duration(seconds: 1)),
          isFalse,
        );
        expect(controller.upNextSongs, [songs[2], songs[0], songs[1]]);

        audio.releaseStop();
        expect(await firstTap, isTrue);
        expect(controller.currentSong, songs[2]);
        controller.dispose();
      },
    );

    test('reorders and restores a Repeat All boundary timeline', () async {
      final repository = MemoryLibraryRepository();
      final source = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: repository,
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await source.initialize();
      await source.playSong(songs.first, queue: songs);
      while (source.canGoNext) {
        await source.next();
      }
      source.setRepeatMode(PlayerRepeatMode.all);
      final before = source.upNextSongs;
      final moved = before.last;

      expect(source.reorderUpNext(before.length - 1, 0), isTrue);
      expect(source.nextSong, moved);
      await _flushAsync();

      final restored = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: repository,
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await restored.initialize();
      expect(restored.nextSong, moved);
      final unconsumedBoundary = restored.upNextSongs;
      restored.setRepeatMode(PlayerRepeatMode.off);
      expect(restored.upNextSongs, isEmpty);
      expect(restored.canGoNext, isFalse);
      restored.setRepeatMode(PlayerRepeatMode.all);
      expect(restored.upNextSongs, isNot(unconsumedBoundary));
      expect(restored.upNextSongs, hasLength(songs.length));
      await restored.next();
      expect(restored.currentSong, isNotNull);
      source.dispose();
      restored.dispose();
    });

    test(
      'Repeat All boundary provenance becomes a normal cycle after Next',
      () async {
        final repository = MemoryLibraryRepository();
        final source = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await source.initialize();
        await source.playSong(songs.first, queue: songs);
        while (source.canGoNext) {
          await source.next();
        }
        source.setRepeatMode(PlayerRepeatMode.all);
        final boundary = source.upNextSongs;
        expect(source.reorderUpNext(0, boundary.length - 1), isTrue);
        await source.next();
        final remainingCycle = source.upNextSongs;
        expect(remainingCycle, hasLength(songs.length - 1));
        await _flushAsync();

        final restored = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await restored.initialize();
        expect(restored.upNextSongs, remainingCycle);

        restored.setRepeatMode(PlayerRepeatMode.off);

        expect(restored.upNextSongs, remainingCycle);
        while (restored.canGoNext) {
          await restored.next();
        }
        expect(restored.canGoNext, isFalse);
        source.dispose();
        restored.dispose();
      },
    );

    test('direct Up Next selection crosses the Repeat All boundary', () async {
      final controller = _controller(FakePlaybackAudioPlayer());
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);
      while (controller.canGoNext) {
        await controller.next();
      }
      controller.setRepeatMode(PlayerRepeatMode.all);
      final preparedCycle = controller.upNextSongs;

      final revision = controller.upNextRevision;
      expect(await controller.playUpNext(1, revision), isTrue);
      expect(controller.currentSong, preparedCycle[1]);
      final remainingCycle = controller.upNextSongs;
      controller.setRepeatMode(PlayerRepeatMode.off);

      expect(controller.upNextSongs, remainingCycle);
      expect(controller.upNextSongs, hasLength(songs.length - 1));
      controller.dispose();
    });

    test('system repeat callback clears an unconsumed boundary plan', () async {
      final bridge = RecordingSystemMediaBridge();
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: bridge,
      );
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);
      while (controller.canGoNext) {
        await controller.next();
      }
      controller.setRepeatMode(PlayerRepeatMode.all);
      expect(controller.reorderUpNext(0, songs.length - 1), isTrue);
      expect(controller.upNextSongs, hasLength(songs.length));

      bridge.callbacks.setRepeatMode(SystemRepeatMode.none);

      expect(controller.repeatMode, PlayerRepeatMode.off);
      expect(controller.upNextSongs, isEmpty);
      expect(controller.canGoNext, isFalse);
      controller.dispose();
    });

    test(
      'Add to Queue overrides shuffle and navigator state survives restart',
      () async {
        final repository = MemoryLibraryRepository();
        final source = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await source.initialize();
        await source.playSong(songs.first, queue: songs);
        source.setShuffleEnabled(true);
        expect(source.addToQueue(songs.last), isTrue);
        expect(source.nextSong, songs.last);
        await _flushAsync();

        final restored = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await restored.initialize();

        expect(restored.shuffleEnabled, isTrue);
        expect(restored.nextSong, songs.last);
        await restored.next();
        expect(restored.currentSong, songs.last);
        source.dispose();
        restored.dispose();
      },
    );

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
      expect(bridge.snapshots.last.canGoPrevious, isFalse);
      expect(bridge.snapshots.last.canGoNext, isTrue);
      bridge.callbacks.setShuffle(true);
      final before = controller.upNextSongs;
      final beforeTimeline = [
        controller.currentSong!.id,
        ...before.map((song) => song.id),
      ];
      expect(controller.reorderUpNext(before.length - 1, 0), isTrue);
      await _flushAsync();
      expect(
        bridge.snapshots.last.queue.map((song) => song.id),
        controller.playbackTimelineSongs.map((song) => song.id),
      );
      expect(bridge.snapshots.last.queueIndex, 0);
      expect(
        bridge.snapshots.last.queue.map((song) => song.id),
        isNot(beforeTimeline),
      );
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
      final actualUpcomingIds = controller.upNextSongs
          .map((song) => song.id)
          .toList(growable: false);
      final smartIds = controller.queue
          .where(controller.isSmartShuffleSong)
          .map((song) => song.id)
          .toSet();
      expect(actualUpcomingIds.toSet(), {'two', 'three', 'four', ...smartIds});
      expect(smartIds, isNot(contains(actualUpcomingIds.last)));
      final smartQueue = controller.queue.map((song) => song.id).toList();
      expect(controller.reorderUpNext(actualUpcomingIds.length - 1, 0), isTrue);
      expect(controller.queue.map((song) => song.id), smartQueue);
      expect(controller.nextSong?.id, actualUpcomingIds.last);

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

    test('removes and restores playlist songs at their original index without '
        'mutating playback queue', () async {
      final controller = _controller(FakePlaybackAudioPlayer());
      await controller.initialize();
      await controller.playSong(songs[1], queue: songs);
      final playlist = controller.createPlaylist(
        'Local mix',
        initialSongs: songs,
      );
      final queueBeforeEdit = controller.queue;

      expect(
        () => controller.playlists.single.songs.removeLast(),
        throwsUnsupportedError,
      );
      final removal = controller.removeSongFromPlaylist(playlist.id, 'two');
      expect(removal, isNotNull);
      expect(removal!.index, 1);
      expect(removal.song, songs[1]);
      expect(controller.playlists.single.songs.map((song) => song.id), [
        'one',
        'three',
      ]);
      expect(controller.queue, queueBeforeEdit);
      expect(controller.currentSong, songs[1]);

      expect(controller.restoreSongToPlaylist(removal), isTrue);
      expect(controller.playlists.single.songs.map((song) => song.id), [
        'one',
        'two',
        'three',
      ]);
      expect(controller.restoreSongToPlaylist(removal), isFalse);
      expect(controller.queue, queueBeforeEdit);
      controller.dispose();
    });

    test(
      'moves playlist songs by exact TV index and persists the order',
      () async {
        final repository = MemoryLibraryRepository();
        final source = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await source.initialize();
        final playlist = source.createPlaylist(
          'Remote order',
          initialSongs: songs,
        );

        expect(source.reorderPlaylistSongItem(playlist.id, 0, 1), isTrue);
        expect(source.reorderPlaylistSongItem(playlist.id, 1, 2), isTrue);
        expect(source.reorderPlaylistSongItem(playlist.id, 2, 2), isFalse);
        expect(source.playlists.single.songs.map((song) => song.id), [
          'two',
          'three',
          'one',
        ]);
        await _flushAsync();
        source.dispose();
        await _flushAsync();

        final restored = PlaybackService(
          playbackAudioPlayer: FakePlaybackAudioPlayer(),
          sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
          libraryRepository: repository,
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await restored.initialize();
        expect(restored.playlists.single.songs.map((song) => song.id), [
          'two',
          'three',
          'one',
        ]);
        restored.dispose();
      },
    );

    test('rename keeps playlist names unique', () async {
      final controller = _controller(FakePlaybackAudioPlayer());
      await controller.initialize();
      final first = controller.createPlaylist('Buổi sáng');
      final second = controller.createPlaylist('Buổi tối');

      expect(
        () => controller.renamePlaylist(second.id, '  BUỔI SÁNG  '),
        throwsArgumentError,
      );
      expect(controller.renamePlaylist(first.id, 'Buổi sáng'), isFalse);
      expect(
        controller.playlists.map((playlist) => playlist.name),
        containsAll(['Buổi sáng', 'Buổi tối']),
      );
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

    test(
      'preloads only the first True Up Next item and promotes it on completion',
      () async {
        final audio = FakePlaybackAudioPlayer(supportsSeamlessPreload: true);
        final resolvedCodes = <String>[];
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) async {
            resolvedCodes.add(code);
            return 'https://audio.example.com/$code.mp3';
          },
          libraryRepository: MemoryLibraryRepository(),
          analyticsRepository: MemoryListeningAnalyticsRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs);
        audio.emitDuration(const Duration(minutes: 3));
        audio.emitPosition(const Duration(minutes: 2, seconds: 29));
        await _flushAsync();

        expect(audio.preparedSources, isEmpty);
        expect(resolvedCodes, ['code-one']);

        audio.emitPosition(const Duration(minutes: 2, seconds: 30));
        await _flushAsync();
        await _flushAsync();

        expect(audio.preparedSources, hasLength(1));
        expect(
          (audio.preparedSources.single as UrlSource).url,
          'https://audio.example.com/code-two.mp3',
        );
        expect(resolvedCodes, ['code-one', 'code-two']);

        audio.complete();
        await _flushAsync();
        await _flushAsync();

        expect(controller.currentSong, songs[1]);
        expect(audio.promotePreparedCalls, 1);
        expect(audio.playedSources, hasLength(2));
        expect(resolvedCodes, ['code-one', 'code-two']);
        expect(
          controller.analyticsSummary(AnalyticsPeriod.sevenDays).completions,
          1,
        );
        controller.dispose();
      },
    );

    test(
      'reorders invalidate a prepared deck before the new target preloads',
      () async {
        final audio = FakePlaybackAudioPlayer(supportsSeamlessPreload: true);
        final controller = _controller(audio);
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs);
        audio.emitDuration(const Duration(minutes: 3));
        audio.emitPosition(const Duration(minutes: 2, seconds: 31));
        await _flushAsync();
        await _flushAsync();
        expect(
          (audio.preparedSources.single as UrlSource).url,
          endsWith('/code-two.mp3'),
        );

        expect(controller.reorderUpNext(0, 1), isTrue);
        await _flushAsync();
        expect(audio.preparedSource, isNull);
        audio.emitPosition(const Duration(minutes: 2, seconds: 32));
        await _flushAsync();
        await _flushAsync();

        expect(audio.preparedSources, hasLength(2));
        expect(
          (audio.preparedSources.last as UrlSource).url,
          endsWith('/code-three.mp3'),
        );
        controller.dispose();
      },
    );

    test(
      'a hung stale resolver cannot block or cancel a later preload',
      () async {
        final audio = FakePlaybackAudioPlayer(supportsSeamlessPreload: true);
        final staleResolution = Completer<String>();
        var codeTwoRequests = 0;
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) {
            if (code == songs[1].code && codeTwoRequests++ == 0) {
              return staleResolution.future;
            }
            return Future.value('https://audio.example.com/$code.mp3');
          },
          libraryRepository: MemoryLibraryRepository(),
          analyticsRepository: MemoryListeningAnalyticsRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs);
        audio.emitDuration(const Duration(minutes: 3));
        audio.emitPosition(const Duration(minutes: 2, seconds: 31));
        await _flushAsync();

        expect(codeTwoRequests, 1);
        expect(audio.preparedSources, isEmpty);

        await controller.next();
        expect(controller.currentSong, songs[1]);
        expect(codeTwoRequests, 2);

        audio.emitDuration(const Duration(minutes: 3));
        audio.emitPosition(const Duration(minutes: 2, seconds: 31));
        await _flushAsync();
        await _flushAsync();

        expect(audio.preparedSources, hasLength(1));
        expect(
          (audio.preparedSources.single as UrlSource).url,
          endsWith('/code-three.mp3'),
        );

        staleResolution.complete(
          'https://audio.example.com/stale-code-two.mp3',
        );
        await _flushAsync();

        expect(
          (audio.preparedSource as UrlSource).url,
          endsWith('/code-three.mp3'),
        );
        controller.dispose();
      },
    );

    test(
      'a stale resolver error cannot cancel a later prepared deck',
      () async {
        final audio = FakePlaybackAudioPlayer(supportsSeamlessPreload: true);
        final staleResolution = Completer<String>();
        var codeTwoRequests = 0;
        final controller = PlaybackService(
          playbackAudioPlayer: audio,
          sourceResolver: (code) {
            if (code == songs[1].code && codeTwoRequests++ == 0) {
              return staleResolution.future;
            }
            return Future.value('https://audio.example.com/$code.mp3');
          },
          libraryRepository: MemoryLibraryRepository(),
          analyticsRepository: MemoryListeningAnalyticsRepository(),
          systemMediaBridge: NoopSystemMediaBridge(),
        );
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs);
        audio.emitDuration(const Duration(minutes: 3));
        audio.emitPosition(const Duration(minutes: 2, seconds: 31));
        await _flushAsync();

        await controller.next();
        audio.emitDuration(const Duration(minutes: 3));
        audio.emitPosition(const Duration(minutes: 2, seconds: 31));
        await _flushAsync();
        await _flushAsync();
        expect(
          (audio.preparedSource as UrlSource).url,
          endsWith('/code-three.mp3'),
        );

        staleResolution.completeError(StateError('stale preload failed'));
        await _flushAsync();

        expect(
          (audio.preparedSource as UrlSource).url,
          endsWith('/code-three.mp3'),
        );
        audio.complete();
        await _flushAsync();
        await _flushAsync();
        expect(controller.currentSong, songs[2]);
        expect(audio.promotePreparedCalls, 1);
        controller.dispose();
      },
    );

    test('a final position tick cannot retain preload after pause', () async {
      final audio = BlockingPausePlaybackAudioPlayer(
        supportsSeamlessPreload: true,
      );
      final controller = _controller(audio);
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);
      audio.emitDuration(const Duration(minutes: 3));
      audio.emitPosition(const Duration(minutes: 2, seconds: 29));
      await _flushAsync();
      expect(audio.preparedSources, isEmpty);

      audio.blockNextPause();
      final pause = controller.togglePlayPause();
      await audio.pauseStarted;
      audio.emitPosition(const Duration(minutes: 2, seconds: 31));
      await _flushAsync();
      await _flushAsync();
      expect(audio.preparedSource, isNotNull);

      audio.releasePause();
      await pause;
      await _flushAsync();

      expect(controller.state, PlayerState.paused);
      expect(audio.preparedSource, isNull);
      controller.dispose();
    });

    test(
      'failed preload falls back to the normal source without stalling',
      () async {
        final audio = FakePlaybackAudioPlayer(
          supportsSeamlessPreload: true,
          prepareNextSucceeds: false,
        );
        final controller = _controller(audio);
        await controller.initialize();
        await controller.playSong(songs.first, queue: songs);
        audio.emitDuration(const Duration(minutes: 3));
        audio.emitPosition(const Duration(minutes: 2, seconds: 31));
        await _flushAsync();
        await _flushAsync();
        expect(audio.preparedSources, hasLength(1));

        audio.complete();
        await _flushAsync();
        await _flushAsync();

        expect(controller.currentSong, songs[1]);
        expect(controller.isPlaying, isTrue);
        expect(audio.promotePreparedCalls, 0);
        expect(audio.playedSources, hasLength(2));
        controller.dispose();
      },
    );

    test('manual Next cancels preload and remains an early skip', () async {
      final audio = FakePlaybackAudioPlayer(supportsSeamlessPreload: true);
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
        libraryRepository: MemoryLibraryRepository(),
        analyticsRepository: MemoryListeningAnalyticsRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);
      audio.emitDuration(const Duration(seconds: 20));
      audio.emitPosition(const Duration(seconds: 1));
      await _flushAsync();
      await _flushAsync();
      expect(audio.preparedSource, isNotNull);

      await controller.next();

      expect(controller.currentSong, songs[1]);
      expect(audio.promotePreparedCalls, 0);
      expect(audio.preparedSource, isNull);
      expect(
        controller.analyticsSummary(AnalyticsPeriod.sevenDays).earlySkips,
        1,
      );
      controller.dispose();
    });

    test('off, Repeat One and sleep-after-current never preload', () async {
      final audio = FakePlaybackAudioPlayer(supportsSeamlessPreload: true);
      final controller = _controller(audio);
      await controller.initialize();
      await controller.playSong(songs.first, queue: songs);
      audio.emitDuration(const Duration(minutes: 3));

      controller.setSeamlessPlaybackPreference(SeamlessPlaybackPreference.off);
      audio.emitPosition(const Duration(minutes: 2, seconds: 31));
      await _flushAsync();
      expect(audio.preparedSources, isEmpty);

      controller.setSeamlessPlaybackPreference(
        SeamlessPlaybackPreference.automatic,
      );
      controller.setRepeatMode(PlayerRepeatMode.one);
      audio.emitPosition(const Duration(minutes: 2, seconds: 32));
      await _flushAsync();
      expect(audio.preparedSources, isEmpty);

      controller.setRepeatMode(PlayerRepeatMode.off);
      controller.setSleepAfterCurrentSong();
      audio.emitPosition(const Duration(minutes: 2, seconds: 33));
      await _flushAsync();
      expect(audio.preparedSources, isEmpty);
      controller.dispose();
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

class BlockingStopPlaybackAudioPlayer extends FakePlaybackAudioPlayer {
  Completer<void>? _stopGate;
  Completer<void>? _stopStarted;

  void blockNextStop() {
    _stopGate = Completer<void>();
    _stopStarted = Completer<void>();
  }

  Future<void> get stopStarted => _stopStarted!.future;

  void releaseStop() {
    final gate = _stopGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<void> stop() async {
    final gate = _stopGate;
    if (gate != null && !gate.isCompleted) {
      final started = _stopStarted;
      if (started != null && !started.isCompleted) started.complete();
      await gate.future;
      _stopGate = null;
      _stopStarted = null;
    }
    await super.stop();
  }
}

class BlockingPausePlaybackAudioPlayer extends FakePlaybackAudioPlayer {
  BlockingPausePlaybackAudioPlayer({super.supportsSeamlessPreload});

  Completer<void>? _pauseGate;
  Completer<void>? _pauseStarted;

  void blockNextPause() {
    _pauseGate = Completer<void>();
    _pauseStarted = Completer<void>();
  }

  Future<void> get pauseStarted => _pauseStarted!.future;

  void releasePause() {
    final gate = _pauseGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<void> pause() async {
    final gate = _pauseGate;
    if (gate != null && !gate.isCompleted) {
      final started = _pauseStarted;
      if (started != null && !started.isCompleted) started.complete();
      await gate.future;
      _pauseGate = null;
      _pauseStarted = null;
    }
    await super.pause();
  }
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
