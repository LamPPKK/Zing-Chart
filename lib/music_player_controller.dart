import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'data/library_repository.dart';
import 'data/listening_analytics_repository.dart';
import 'models/catalog_search.dart';
import 'models/listening_analytics.dart';
import 'models/live_radio.dart';
import 'models/local_library.dart';
import 'models/playback_origin.dart';
import 'models/song.dart';
import 'models/song_radio.dart';
import 'services/listening_analytics_service.dart';
import 'services/local_mix_engine.dart';
import 'services/companion_surface_bridge.dart';
import 'services/playback_audio_player.dart';
import 'services/system_media_bridge.dart';
import 'zing_mp3_api.dart';

typedef SongSourceResolver = Future<String> Function(String code);
typedef QualitySongSourceResolver =
    Future<String> Function(String code, StreamingQualityPreference quality);
typedef SongRadioLoader = Future<SongRadio> Function(String code);
typedef LiveRadioSourceResolver = Future<String> Function(String id);

enum PlayerRepeatMode { off, all, one }

class PlaybackService extends ChangeNotifier {
  PlaybackService({
    AudioPlayer? audioPlayer,
    PlaybackAudioPlayer? playbackAudioPlayer,
    SongSourceResolver? sourceResolver,
    QualitySongSourceResolver? qualitySourceResolver,
    SongRadioLoader? songRadioLoader,
    LiveRadioSourceResolver? liveRadioSourceResolver,
    LibraryRepository? libraryRepository,
    ListeningAnalyticsRepository? analyticsRepository,
    ListeningAnalyticsService? analyticsService,
    LocalMixEngine? mixEngine,
    SystemMediaBridge? systemMediaBridge,
    CompanionSurfaceBridge? companionSurfaceBridge,
  }) : assert(audioPlayer == null || playbackAudioPlayer == null),
       _audioPlayer =
           playbackAudioPlayer ??
           AudioplayersPlaybackAudioPlayer(audioPlayer ?? AudioPlayer()),
       _sourceResolver = sourceResolver ?? ZingMP3API.getSongUrlByCode,
       _qualitySourceResolver = qualitySourceResolver,
       _songRadioLoader = songRadioLoader,
       _liveRadioSourceResolver = liveRadioSourceResolver,
       _autoplayRecommendationsEnabled = songRadioLoader != null,
       _libraryRepository =
           libraryRepository ?? SharedPreferencesLibraryRepository(),
       _analytics =
           analyticsService ??
           ListeningAnalyticsService(repository: analyticsRepository),
       _mixEngine = mixEngine ?? const LocalMixEngine(),
       _systemMediaBridge = systemMediaBridge,
       _companionSurfaceBridge = companionSurfaceBridge;

  final PlaybackAudioPlayer _audioPlayer;
  final SongSourceResolver _sourceResolver;
  final QualitySongSourceResolver? _qualitySourceResolver;
  final SongRadioLoader? _songRadioLoader;
  final LiveRadioSourceResolver? _liveRadioSourceResolver;
  final LibraryRepository _libraryRepository;
  final ListeningAnalyticsService _analytics;
  final LocalMixEngine _mixEngine;
  SystemMediaBridge? _systemMediaBridge;
  CompanionSurfaceBridge? _companionSurfaceBridge;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> _playerCommandQueue = Future<void>.value();

  Song? _currentSong;
  LiveRadioRoom? _currentLiveRadio;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentSource;
  PlaybackOrigin _playbackOrigin = const PlaybackOrigin.chart();
  int _requestId = 0;
  int _activePlaybackRequestId = -1;
  String? _activePlaybackSongId;
  List<Song> _queue = const [];
  int _currentIndex = -1;
  bool _shuffleEnabled = false;
  bool _smartShuffleEnabled = false;
  Set<String> _smartShuffleSongIds = const {};
  String? _smartShuffleMessage;
  PlayerRepeatMode _repeatMode = PlayerRepeatMode.off;
  bool _autoplayRecommendationsEnabled;
  bool _isRadioLoading = false;
  String? _radioErrorMessage;
  Set<String> _radioSongIds = const {};
  int _radioRequestId = 0;
  int _radioAdvanceRequestId = 0;
  Future<int>? _radioLoadFuture;
  String? _radioLoadSeedId;
  final Map<String, Song> _likedSongs = {};
  final Map<String, CatalogArtist> _followedArtists = {};
  final Map<String, CatalogCollection> _savedCollections = {};
  final Map<String, LocalPlaylist> _playlists = {};
  List<ListeningRecord> _history = const [];
  List<String> _recentSearches = const [];
  List<Song> _catalog = const [];
  AppThemePreference _themePreference = AppThemePreference.system;
  bool _alwaysOpenFullscreenPlayer = false;
  bool _carModeEnabled = false;
  double _volume = 1;
  double _volumeBeforeMute = 1;
  StreamingQualityPreference _streamingQualityPreference =
      StreamingQualityPreference.automatic;
  String? _activeHistoryRecordId;
  Duration _lastListeningPosition = Duration.zero;
  Timer? _sleepTimer;
  Duration? _sleepTimerRemaining;
  bool _sleepAfterCurrentSong = false;
  Duration _restoredPosition = Duration.zero;
  String? _restoredSongId;
  int _lastSavedPositionBucket = -1;
  Future<void> _mediaPublishQueue = Future<void>.value();
  SystemMediaSnapshot? _pendingMediaSnapshot;
  bool _mediaPublishScheduled = false;
  Future<void> _companionPublishQueue = Future<void>.value();
  CompanionPlayerSnapshot? _pendingCompanionSnapshot;
  bool _companionPublishScheduled = false;
  String? _lastCompanionPublishSignature;
  final ValueNotifier<int> _catalogRevision = ValueNotifier<int>(0);
  Future<void> _snapshotSaveFuture = Future<void>.value();
  PlayerSnapshot? _pendingSnapshot;
  bool _snapshotSaveScheduled = false;

  Song? get currentSong => _currentSong;
  PlaybackOrigin get playbackOrigin => _playbackOrigin;
  LiveRadioRoom? get currentLiveRadio => _currentLiveRadio;
  bool get isLiveRadio => _currentLiveRadio != null;
  bool get liveRadioAvailable => _liveRadioSourceResolver != null;
  PlayerState get state => _state;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _state == PlayerState.playing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasSong => _currentSong != null;
  List<Song> get queue => List<Song>.unmodifiable(_queue);
  List<Song> get likedSongs => List<Song>.unmodifiable(_likedSongs.values);
  List<CatalogArtist> get followedArtists => List<CatalogArtist>.unmodifiable(
    _followedArtists.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
  );
  List<CatalogCollection> get savedCollections =>
      List<CatalogCollection>.unmodifiable(_savedCollections.values);
  List<LocalPlaylist> get playlists => List<LocalPlaylist>.unmodifiable(
    _playlists.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );
  List<ListeningRecord> get history =>
      List<ListeningRecord>.unmodifiable(_history);
  List<String> get recentSearches => List<String>.unmodifiable(_recentSearches);
  AppThemePreference get themePreference => _themePreference;
  bool get alwaysOpenFullscreenPlayer => _alwaysOpenFullscreenPlayer;
  bool get carModeEnabled => _carModeEnabled;
  double get volume => _volume;
  bool get isMuted => _volume <= 0.001;
  StreamingQualityPreference get streamingQualityPreference =>
      _streamingQualityPreference;
  Duration? get sleepTimerRemaining => _sleepTimerRemaining;
  bool get sleepAfterCurrentSong => _sleepAfterCurrentSong;
  bool get hasSleepTimer =>
      _sleepTimerRemaining != null || _sleepAfterCurrentSong;
  int get currentIndex => _currentIndex;
  bool get shuffleEnabled => _shuffleEnabled;
  bool get smartShuffleEnabled => _smartShuffleEnabled;
  int get smartShuffleSongCount => _smartShuffleSongIds.length;
  String? get smartShuffleMessage => _smartShuffleMessage;
  PlayerRepeatMode get repeatMode => _repeatMode;
  bool get songRadioAvailable => _songRadioLoader != null;
  bool get autoplayRecommendationsEnabled =>
      _autoplayRecommendationsEnabled && _songRadioLoader != null;
  bool get isRadioLoading => _isRadioLoading;
  String? get radioErrorMessage => _radioErrorMessage;
  int get radioSongCount => _radioSongIds.length;
  bool get canGoNext =>
      !isLiveRadio &&
      _currentSong != null &&
      (_shuffleEnabled && _queue.length > 1 ||
          _currentIndex + 1 < _queue.length ||
          _repeatMode == PlayerRepeatMode.all ||
          autoplayRecommendationsEnabled);
  bool get canGoPrevious => !isLiveRadio && _queue.length > 1;
  bool get canClearPlaybackQueue =>
      !isLiveRadio &&
      _currentSong != null &&
      (_queue.length != 1 || _queue.first.id != _currentSong!.id);
  ListeningAnalyticsSnapshot get analyticsSnapshot => _analytics.snapshot;
  bool get hasAnalyticsActivity => _analytics.hasActivity;
  ValueListenable<int> get catalogChanges => _catalogRevision;

  Duration get totalListeningTime =>
      _history.fold(Duration.zero, (total, record) => total + record.listened);

  List<SongListeningStat> get topSongStats {
    final values = <String, _MutableSongStat>{};
    for (final record in _history) {
      final stat = values.putIfAbsent(
        record.song.id,
        () => _MutableSongStat(record.song),
      );
      stat.playCount++;
      stat.listened += record.listened;
    }
    final result =
        values.values
            .map(
              (stat) => SongListeningStat(
                song: stat.song,
                playCount: stat.playCount,
                listened: stat.listened,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byPlays = b.playCount.compareTo(a.playCount);
            return byPlays != 0 ? byPlays : b.listened.compareTo(a.listened);
          });
    return List<SongListeningStat>.unmodifiable(result);
  }

  List<ArtistListeningStat> get topArtistStats {
    final values = <String, _MutableArtistStat>{};
    for (final record in _history) {
      final artists = record.song.artistsNames
          .split(RegExp(r'\s*[,;&]\s*'))
          .where((artist) => artist.trim().isNotEmpty);
      for (final artist in artists) {
        final stat = values.putIfAbsent(
          artist.toLowerCase(),
          () => _MutableArtistStat(artist),
        );
        stat.playCount++;
        stat.listened += record.listened;
      }
    }
    final result =
        values.values
            .map(
              (stat) => ArtistListeningStat(
                artist: stat.artist,
                playCount: stat.playCount,
                listened: stat.listened,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byPlays = b.playCount.compareTo(a.playCount);
            return byPlays != 0 ? byPlays : b.listened.compareTo(a.listened);
          });
    return List<ArtistListeningStat>.unmodifiable(result);
  }

  List<Song> get recentlyPlayed {
    final seen = <String>{};
    return _history
        .where((record) => seen.add(record.song.id))
        .map((record) => record.song)
        .take(20)
        .toList(growable: false);
  }

  List<Song> get dailyMix => dailyMixCollection.songs;

  MixCollection get dailyMixCollection => _mixEngine.buildDailyMix(
    candidates: _mixCandidates,
    likedSongIds: _likedSongs.keys.toSet(),
    analytics: _analytics,
  );

  MixCollection moodMix(MoodTag mood) => _mixEngine.buildMoodMix(
    mood: mood,
    candidates: _mixCandidates,
    likedSongIds: _likedSongs.keys.toSet(),
    analytics: _analytics,
  );

  Set<MoodTag> moodsFor(Song song) => _analytics.moodsFor(song);

  AnalyticsSummary analyticsSummary(AnalyticsPeriod period, {int? year}) =>
      _analytics.summary(period, year: year);

  WrappedSummary wrappedSummary(int year) => _analytics.wrapped(year);

  List<Song> get _mixCandidates {
    final songs = <String, Song>{};
    for (final song in _catalog) {
      songs.putIfAbsent(song.id, () => song);
    }
    for (final song in _likedSongs.values) {
      songs.putIfAbsent(song.id, () => song);
    }
    for (final playlist in _playlists.values) {
      for (final song in playlist.songs) {
        songs.putIfAbsent(song.id, () => song);
      }
    }
    for (final record in _history) {
      songs.putIfAbsent(record.song.id, () => record.song);
    }
    return songs.values.toList(growable: false);
  }

  double get progress {
    if (_duration.inMilliseconds <= 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0, 1);
  }

  Future<void> initialize() async {
    await _restoreSnapshot();
    await _analytics.initialize(legacyHistory: _history);
    if (_systemMediaBridge == null) {
      try {
        _systemMediaBridge = await createSystemMediaBridge();
      } catch (_) {
        _systemMediaBridge = NoopSystemMediaBridge();
      }
    }
    await _systemMediaBridge!.bind(
      SystemMediaCallbacks(
        play: () async {
          if (!isPlaying) await togglePlayPause();
        },
        pause: () async {
          if (isPlaying) await togglePlayPause();
        },
        stop: stop,
        next: next,
        previous: previous,
        seek: seek,
        setShuffle: (enabled) {
          if (_shuffleEnabled != enabled) toggleShuffle();
        },
        setRepeatMode: (mode) {
          if (isLiveRadio) return;
          final target = switch (mode) {
            SystemRepeatMode.none => PlayerRepeatMode.off,
            SystemRepeatMode.all => PlayerRepeatMode.all,
            SystemRepeatMode.one => PlayerRepeatMode.one,
          };
          if (_repeatMode != target) {
            _repeatMode = target;
            _notifyPlaybackChanged();
            unawaited(_saveSnapshot());
          }
        },
      ),
    );
    if (_companionSurfaceBridge == null) {
      try {
        _companionSurfaceBridge = await createCompanionSurfaceBridge();
      } catch (_) {
        _companionSurfaceBridge = NoopCompanionSurfaceBridge();
      }
    }
    await _companionSurfaceBridge!.bind(
      CompanionCallbacks(
        play: () async {
          if (!isPlaying) await togglePlayPause();
        },
        pause: () async {
          if (isPlaying) await togglePlayPause();
        },
        togglePlayPause: togglePlayPause,
        previous: previous,
        next: next,
        stop: stop,
        seekRelative: (delta) => seek(position + delta),
      ),
    );
    await _audioPlayer.setAudioContext(
      AudioContextConfig(stayAwake: true).build(),
    );
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);
    try {
      await _audioPlayer.setVolume(_volume);
    } catch (_) {
      // Volume control is optional on a few embedded playback backends.
    }

    _subscriptions
      ..add(
        _audioPlayer.onPlayerStateChanged.listen((state) {
          _state = state;
          _notifyPlaybackChanged();
        }),
      )
      ..add(
        _audioPlayer.onDurationChanged.listen((duration) {
          _duration = duration;
          if (!isLiveRadio) _analytics.updateDuration(duration);
          _notifyPlaybackChanged(catalogChanged: false);
        }),
      )
      ..add(
        _audioPlayer.onPositionChanged.listen((position) {
          if (!isLiveRadio) {
            _recordListeningProgress(position);
            _analytics.recordProgress(position);
            final bucket = position.inSeconds ~/ 5;
            if (bucket != _lastSavedPositionBucket) {
              _lastSavedPositionBucket = bucket;
              unawaited(_saveSnapshot());
            }
          }
          _position = position;
          _notifyPlaybackChanged(catalogChanged: false);
        }),
      )
      ..add(
        _audioPlayer.onPlayerComplete.listen((_) {
          final completedRequestId = _activePlaybackRequestId;
          final completedSongId = _activePlaybackSongId;
          if (completedRequestId != _requestId ||
              completedSongId == null ||
              completedSongId != _currentSong?.id) {
            return;
          }
          if (!isLiveRadio) _analytics.completeSession();
          _state = PlayerState.completed;
          _position = _duration;
          _notifyPlaybackChanged();
          unawaited(_handleTrackCompleted(completedRequestId, completedSongId));
        }),
      );
    _notifyPlaybackChanged();
  }

  Future<void> playSong(
    Song song, {
    List<Song>? queue,
    PlaybackOrigin? origin,
  }) async {
    _analytics.finishSession(earlySkip: true);
    final wasLiveRadio = isLiveRadio;
    _currentLiveRadio = null;
    _cancelRadioLoad(clearError: true);
    if (origin != null) {
      final label = PlaybackOrigin.sanitizeLabel(origin.label);
      _playbackOrigin = label.isEmpty
          ? const PlaybackOrigin.chart()
          : PlaybackOrigin(kind: origin.kind, label: label);
    } else if (wasLiveRadio) {
      _playbackOrigin = const PlaybackOrigin.chart();
    }
    if (queue != null && queue.isNotEmpty) {
      _radioSongIds = const {};
      _clearSmartShuffleState();
      _queue = List<Song>.unmodifiable(queue);
      _currentIndex = _queue.indexWhere((item) => item.id == song.id);
    } else if (_queue.isEmpty) {
      _queue = [song];
      _currentIndex = 0;
    } else {
      final index = _queue.indexWhere((item) => item.id == song.id);
      if (index >= 0) {
        _currentIndex = index;
      } else {
        _queue = [..._queue, song];
        _currentIndex = _queue.length - 1;
      }
    }

    final requestId = ++_requestId;
    _activePlaybackRequestId = -1;
    _activePlaybackSongId = null;
    if (song.id != _restoredSongId) _restoredPosition = Duration.zero;
    await _runPlayerCommand(_audioPlayer.stop);
    if (requestId != _requestId) return;
    _currentSong = song;
    _state = PlayerState.stopped;
    _position = Duration.zero;
    _duration = Duration.zero;
    _errorMessage = null;
    _currentSource = null;
    _isLoading = true;
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());

    try {
      final source = await _resolveSongSource(song.code);
      if (requestId != _requestId) return;
      _currentSource = source;
      await _runPlayerCommand(() async {
        if (requestId != _requestId) return;
        _activePlaybackRequestId = requestId;
        _activePlaybackSongId = song.id;
        await _audioPlayer.play(UrlSource(source));
        if (_restoredPosition > Duration.zero) {
          await _audioPlayer.seek(_restoredPosition);
          _position = _restoredPosition;
          _restoredPosition = Duration.zero;
          _restoredSongId = null;
        }
        if (requestId != _requestId) await _audioPlayer.stop();
      });
      if (requestId != _requestId) return;
      _recordPlaybackStarted(song);
      _analytics.startSession(song);
      _analytics.updateDuration(_duration);
      _analytics.finishSeek(_position);
    } catch (error) {
      if (requestId != _requestId) return;
      _state = PlayerState.stopped;
      await _runPlayerCommand(_audioPlayer.stop);
      _errorMessage = error.toString();
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        _notifyPlaybackChanged();
        unawaited(_saveSnapshot());
      }
    }
  }

  Future<void> playLiveRadio(LiveRadioRoom room) async {
    final resolver = _liveRadioSourceResolver;
    if (resolver == null) return;
    _analytics.finishSession(earlySkip: true);
    _cancelRadioLoad(clearError: true);
    _playbackOrigin = PlaybackOrigin(
      kind: PlaybackOriginKind.liveRadio,
      label: PlaybackOrigin.sanitizeLabel('${room.title} · LIVE'),
    );
    final requestId = ++_requestId;
    _activePlaybackRequestId = -1;
    _activePlaybackSongId = null;
    _activeHistoryRecordId = null;
    _lastListeningPosition = Duration.zero;
    _sleepAfterCurrentSong = false;
    await _runPlayerCommand(_audioPlayer.stop);
    if (requestId != _requestId) return;

    final artwork = room.program?.thumbnail.trim().isNotEmpty == true
        ? room.program!.thumbnail
        : room.thumbnail;
    final subtitle = room.program?.title.trim().isNotEmpty == true
        ? room.program!.title
        : room.hostName.trim().isNotEmpty
        ? room.hostName
        : 'Phòng Nhạc LIVE';
    final liveSong = Song(
      id: 'live:${room.id}',
      name: room.title,
      title: room.title,
      thumbnail: artwork,
      artistsNames: subtitle,
      code: room.id,
    );
    _currentLiveRadio = room;
    _currentSong = liveSong;
    _queue = [liveSong];
    _currentIndex = 0;
    _radioSongIds = const {};
    _clearSmartShuffleState();
    _state = PlayerState.stopped;
    _position = Duration.zero;
    _duration = Duration.zero;
    _currentSource = null;
    _errorMessage = null;
    _isLoading = true;
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());

    try {
      final source = await resolver(room.id);
      if (requestId != _requestId || _currentLiveRadio?.id != room.id) return;
      _currentSource = source;
      await _runPlayerCommand(() async {
        if (requestId != _requestId || _currentLiveRadio?.id != room.id) {
          return;
        }
        _activePlaybackRequestId = requestId;
        _activePlaybackSongId = liveSong.id;
        await _audioPlayer.play(UrlSource(source));
        if (requestId != _requestId || _currentLiveRadio?.id != room.id) {
          await _audioPlayer.stop();
        }
      });
    } catch (error) {
      if (requestId != _requestId || _currentLiveRadio?.id != room.id) return;
      _state = PlayerState.stopped;
      await _runPlayerCommand(_audioPlayer.stop);
      _currentSource = null;
      _errorMessage = error.toString();
    } finally {
      if (requestId == _requestId && _currentLiveRadio?.id == room.id) {
        _isLoading = false;
        _notifyPlaybackChanged();
        unawaited(_saveSnapshot());
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (_currentSong == null || _isLoading) return;
    _errorMessage = null;
    try {
      if (isPlaying) {
        await _runPlayerCommand(_audioPlayer.pause);
      } else if (isLiveRadio && _state == PlayerState.completed) {
        await playLiveRadio(_currentLiveRadio!);
      } else if (_state == PlayerState.completed) {
        await _runPlayerCommand(() async {
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.resume();
        });
        if (!isLiveRadio) {
          _recordPlaybackStarted(_currentSong!);
          _analytics.startSession(_currentSong!);
          _analytics.updateDuration(_duration);
        }
      } else if (_state == PlayerState.stopped && _currentSource != null) {
        final requestId = ++_requestId;
        await _runPlayerCommand(() async {
          _activePlaybackRequestId = requestId;
          _activePlaybackSongId = _currentSong!.id;
          await _audioPlayer.play(UrlSource(_currentSource!));
        });
        if (!isLiveRadio) {
          _recordPlaybackStarted(_currentSong!);
          _analytics.startSession(_currentSong!);
          _analytics.updateDuration(_duration);
        }
      } else if (_state == PlayerState.stopped) {
        if (isLiveRadio) {
          await playLiveRadio(_currentLiveRadio!);
        } else {
          await playSong(_currentSong!);
        }
      } else {
        await _runPlayerCommand(_audioPlayer.resume);
      }
    } catch (error) {
      _errorMessage = error.toString();
      _notifyPlaybackChanged();
    }
  }

  Future<void> stop() async {
    _analytics.finishSession(earlySkip: false);
    _cancelRadioLoad();
    _requestId++;
    _activePlaybackRequestId = -1;
    _activePlaybackSongId = null;
    _activeHistoryRecordId = null;
    _lastListeningPosition = Duration.zero;
    await _runPlayerCommand(_audioPlayer.stop);
    _state = PlayerState.stopped;
    _position = Duration.zero;
    _isLoading = false;
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
  }

  Future<void> next() async {
    if (isLiveRadio) return;
    if (_queue.isEmpty || _currentSong == null) return;
    final nextIndex = _shuffleEnabled && _queue.length > 1
        ? _randomIndexExcluding(_currentIndex)
        : _currentIndex + 1;
    if (nextIndex >= _queue.length) {
      if (_repeatMode == PlayerRepeatMode.all) {
        await _playQueueIndex(0);
      } else if (autoplayRecommendationsEnabled) {
        final advanceRequestId = ++_radioAdvanceRequestId;
        final seedSongId = _currentSong!.id;
        final endingIndex = _currentIndex;
        final appended = await _appendRadioRecommendations(_currentSong!);
        if (appended > 0 &&
            advanceRequestId == _radioAdvanceRequestId &&
            seedSongId == _currentSong?.id &&
            endingIndex + 1 < _queue.length) {
          _playbackOrigin = PlaybackOrigin(
            kind: PlaybackOriginKind.songRadio,
            label: PlaybackOrigin.sanitizeLabel(
              'Song Radio · ${_currentSong!.displayTitle}',
            ),
          );
          await _playQueueIndex(endingIndex + 1);
        } else if (advanceRequestId == _radioAdvanceRequestId &&
            seedSongId == _currentSong?.id) {
          _analytics.finishSession(earlySkip: true);
          await stop();
        }
      } else {
        _analytics.finishSession(earlySkip: true);
        await stop();
      }
      return;
    }
    await _playQueueIndex(nextIndex);
  }

  Future<void> previous() async {
    if (isLiveRadio) return;
    if (_queue.isEmpty || _currentSong == null) return;
    if (_position > const Duration(seconds: 4)) {
      await seek(Duration.zero);
      return;
    }
    final previousIndex = _currentIndex <= 0
        ? (_repeatMode == PlayerRepeatMode.all ? _queue.length - 1 : 0)
        : _currentIndex - 1;
    await _playQueueIndex(previousIndex);
  }

  void setShuffleEnabled(bool enabled) {
    if (isLiveRadio) return;
    if (!enabled && _smartShuffleEnabled) {
      _removeSmartShuffleSongs();
      _clearSmartShuffleState();
    }
    if (_shuffleEnabled == enabled && !_smartShuffleEnabled) return;
    _shuffleEnabled = enabled;
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
  }

  void toggleShuffle() => setShuffleEnabled(!_shuffleEnabled);

  bool isSmartShuffleSong(Song song) => _smartShuffleSongIds.contains(song.id);

  bool setSmartShuffleEnabled(bool enabled) {
    if (isLiveRadio) return false;
    if (!enabled) {
      if (!_smartShuffleEnabled && _smartShuffleSongIds.isEmpty) return true;
      _removeSmartShuffleSongs();
      _clearSmartShuffleState();
      _notifyPlaybackChanged();
      unawaited(_saveSnapshot());
      return true;
    }
    if (_smartShuffleEnabled) return true;
    if (_queue.isEmpty || _currentSong == null) {
      _smartShuffleMessage = 'Hãy chọn một bài trước khi bật Smart Shuffle.';
      _notifyPlaybackChanged();
      return false;
    }

    _removeSmartShuffleSongs();
    final suggestions = _mixEngine.buildSmartShuffle(
      queue: _queue,
      catalog: _catalog,
      likedSongIds: _likedSongs.keys.toSet(),
      analytics: _analytics,
    );
    if (suggestions.isEmpty) {
      _smartShuffleMessage =
          'Catalog hiện tại chưa có bài phù hợp để thêm thông minh.';
      _notifyPlaybackChanged();
      return false;
    }

    _queue = List<Song>.unmodifiable(
      _interleaveSmartShuffleSuggestions(_queue, suggestions),
    );
    _smartShuffleSongIds = Set<String>.unmodifiable(
      suggestions.map((song) => song.id),
    );
    _currentIndex = _queue.indexWhere((song) => song.id == _currentSong?.id);
    _smartShuffleEnabled = true;
    _shuffleEnabled = true;
    _smartShuffleMessage =
        'Đã thêm ${suggestions.length} bài từ catalog hiện tại.';
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
    return true;
  }

  bool refreshSmartShuffle() {
    if (isLiveRadio || _queue.isEmpty || _currentSong == null) return false;
    _removeSmartShuffleSongs();
    _clearSmartShuffleState();
    return setSmartShuffleEnabled(true);
  }

  void setRepeatMode(PlayerRepeatMode mode) {
    if (isLiveRadio) return;
    if (_repeatMode == mode) return;
    _repeatMode = mode;
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
  }

  void cycleRepeatMode() {
    final next = switch (_repeatMode) {
      PlayerRepeatMode.off => PlayerRepeatMode.all,
      PlayerRepeatMode.all => PlayerRepeatMode.one,
      PlayerRepeatMode.one => PlayerRepeatMode.off,
    };
    setRepeatMode(next);
  }

  void setAutoplayRecommendations(bool enabled) {
    final next = enabled && _songRadioLoader != null;
    if (_autoplayRecommendationsEnabled == next) return;
    _autoplayRecommendationsEnabled = next;
    if (!next) _cancelRadioLoad(clearError: true);
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
  }

  void toggleAutoplayRecommendations() =>
      setAutoplayRecommendations(!autoplayRecommendationsEnabled);

  bool isRadioSong(Song song) => _radioSongIds.contains(song.id);

  Future<int> startSongRadio([Song? seed]) async {
    final seedSong = seed ?? _currentSong;
    if (seedSong == null || seedSong.code.trim().isEmpty) {
      _radioErrorMessage = 'Bài hát này chưa hỗ trợ Song Radio.';
      _notifyPlaybackChanged();
      return 0;
    }
    if (_songRadioLoader == null) {
      _radioErrorMessage = 'Song Radio chưa được cấu hình trên thiết bị này.';
      _notifyPlaybackChanged();
      return 0;
    }
    if (_currentSong?.id != seedSong.id) {
      await playSong(
        seedSong,
        queue: [seedSong],
        origin: PlaybackOrigin(
          kind: PlaybackOriginKind.songRadio,
          label: 'Song Radio · ${seedSong.displayTitle}',
        ),
      );
    }
    if (_smartShuffleEnabled || _smartShuffleSongIds.isNotEmpty) {
      _removeSmartShuffleSongs();
      _clearSmartShuffleState();
      _currentIndex = _queue.indexWhere((song) => song.id == _currentSong?.id);
    }
    setAutoplayRecommendations(true);
    final appended = await _appendRadioRecommendations(seedSong);
    if (appended > 0) {
      _playbackOrigin = PlaybackOrigin(
        kind: PlaybackOriginKind.songRadio,
        label: PlaybackOrigin.sanitizeLabel(
          'Song Radio · ${seedSong.displayTitle}',
        ),
      );
      _notifyPlaybackChanged();
      unawaited(_saveSnapshot());
    }
    return appended;
  }

  void toggleLike(Song song) {
    if (_likedSongs.containsKey(song.id)) {
      _likedSongs.remove(song.id);
    } else {
      _likedSongs[song.id] = song;
    }
    _notifyLibraryChanged();
  }

  bool isLiked(Song song) => _likedSongs.containsKey(song.id);

  bool isArtistFollowed(CatalogArtist artist) =>
      _followedArtists.containsKey(artist.id);

  bool toggleArtistFollow(CatalogArtist artist) {
    final wasFollowed = _followedArtists.remove(artist.id) != null;
    if (!wasFollowed) _followedArtists[artist.id] = artist;
    _notifyLibraryChanged();
    return !wasFollowed;
  }

  bool isCollectionSaved(CatalogCollection collection) =>
      _savedCollections.containsKey(collection.id);

  bool toggleCollectionSaved(CatalogCollection collection) {
    final wasSaved = _savedCollections.remove(collection.id) != null;
    if (!wasSaved) _savedCollections[collection.id] = collection;
    _notifyLibraryChanged();
    return !wasSaved;
  }

  void updateCatalog(List<Song> songs) {
    final nextIds = songs.map((song) => song.id).join('|');
    final currentIds = _catalog.map((song) => song.id).join('|');
    if (nextIds == currentIds) return;
    _catalog = List<Song>.unmodifiable(songs);
    _notifyCatalogChanged();
    notifyListeners();
  }

  bool toggleMood(Song song, MoodTag mood) {
    final added = _analytics.toggleMood(song, mood);
    _notifyCatalogChanged();
    notifyListeners();
    return added;
  }

  bool addToQueue(Song song) {
    if (song.id == _currentSong?.id) return false;

    _promoteSmartShuffleSong(song.id);

    final updatedQueue = [..._queue];
    final existingIndex = updatedQueue.indexWhere((item) => item.id == song.id);
    if (_currentIndex < 0) {
      if (existingIndex >= 0) return false;
      updatedQueue.add(song);
    } else {
      if (existingIndex == _currentIndex + 1) return false;
      if (existingIndex >= 0) updatedQueue.removeAt(existingIndex);
      final playingIndex = updatedQueue.indexWhere(
        (item) => item.id == _currentSong?.id,
      );
      updatedQueue.insert(
        playingIndex >= 0 ? playingIndex + 1 : updatedQueue.length,
        song,
      );
    }
    _queue = List<Song>.unmodifiable(updatedQueue);
    _currentIndex = _queue.indexWhere((item) => item.id == _currentSong?.id);
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
    return true;
  }

  void removeFromQueue(Song song) {
    final index = _queue.indexWhere((item) => item.id == song.id);
    if (index < 0 || song.id == _currentSong?.id) return;
    _queue = [..._queue]..removeAt(index);
    _radioSongIds = Set<String>.unmodifiable(
      _radioSongIds.where((id) => id != song.id),
    );
    _smartShuffleSongIds = Set<String>.unmodifiable(
      _smartShuffleSongIds.where((id) => id != song.id),
    );
    if (_smartShuffleSongIds.isEmpty) _smartShuffleEnabled = false;
    if (index < _currentIndex) _currentIndex--;
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
  }

  /// Removes every queued item except the song that is currently playing.
  ///
  /// Native playback, progress, listening analytics and the playback origin
  /// remain untouched. Any in-flight radio expansion is cancelled so the
  /// cleared queue cannot be repopulated by an older request.
  bool clearPlaybackQueue() {
    final current = _currentSong;
    if (isLiveRadio || current == null || !canClearPlaybackQueue) return false;
    _cancelRadioLoad(clearError: true);
    _queue = List<Song>.unmodifiable([current]);
    _currentIndex = 0;
    _radioSongIds = const {};
    _clearSmartShuffleState();
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
    return true;
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex > oldIndex) newIndex--;
    _moveQueueItem(oldIndex, newIndex);
  }

  void reorderQueueItem(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    _moveQueueItem(oldIndex, newIndex);
  }

  void _moveQueueItem(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _queue.length || newIndex == oldIndex) {
      return;
    }
    final updated = [..._queue];
    final song = updated.removeAt(oldIndex);
    updated.insert(newIndex, song);
    _queue = List<Song>.unmodifiable(updated);
    _currentIndex = _queue.indexWhere((item) => item.id == _currentSong?.id);
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
  }

  LocalPlaylist createPlaylist(
    String name, {
    List<Song> initialSongs = const [],
  }) {
    final normalized = name.trim();
    if (normalized.isEmpty || normalized.length > 60) {
      throw ArgumentError('Tên playlist phải có từ 1 đến 60 ký tự.');
    }
    if (_playlists.values.any(
      (playlist) => playlist.name.toLowerCase() == normalized.toLowerCase(),
    )) {
      throw ArgumentError('Playlist này đã tồn tại.');
    }
    final now = DateTime.now().toUtc();
    final uniqueSongs = <String, Song>{};
    for (final song in initialSongs) {
      uniqueSongs.putIfAbsent(song.id, () => song);
    }
    final playlist = LocalPlaylist(
      id: 'playlist-${now.microsecondsSinceEpoch.toRadixString(36)}',
      name: normalized,
      createdAt: now,
      updatedAt: now,
      songs: uniqueSongs.values.toList(growable: false),
    );
    _playlists[playlist.id] = playlist;
    _notifyLibraryChanged();
    return playlist;
  }

  bool renamePlaylist(String playlistId, String name) {
    final playlist = _playlists[playlistId];
    final normalized = name.trim();
    if (playlist == null) return false;
    if (normalized.isEmpty || normalized.length > 60) {
      throw ArgumentError('Tên playlist phải có từ 1 đến 60 ký tự.');
    }
    if (_playlists.values.any(
      (candidate) =>
          candidate.id != playlistId &&
          candidate.name.toLowerCase() == normalized.toLowerCase(),
    )) {
      throw ArgumentError('Playlist này đã tồn tại.');
    }
    if (playlist.name == normalized) return false;
    _playlists[playlistId] = playlist.copyWith(
      name: normalized,
      updatedAt: DateTime.now().toUtc(),
    );
    _notifyLibraryChanged();
    return true;
  }

  void deletePlaylist(String playlistId) {
    if (_playlists.remove(playlistId) != null) _notifyLibraryChanged();
  }

  bool addSongToPlaylist(String playlistId, Song song) {
    final playlist = _playlists[playlistId];
    if (playlist == null || playlist.songs.any((item) => item.id == song.id)) {
      return false;
    }
    _playlists[playlistId] = playlist.copyWith(
      songs: [...playlist.songs, song],
      updatedAt: DateTime.now().toUtc(),
    );
    _notifyLibraryChanged();
    return true;
  }

  RemovedPlaylistSong? removeSongFromPlaylist(
    String playlistId,
    String songId,
  ) {
    final playlist = _playlists[playlistId];
    if (playlist == null) return null;
    final index = playlist.songs.indexWhere((song) => song.id == songId);
    if (index < 0) return null;
    final songs = [...playlist.songs];
    final song = songs.removeAt(index);
    _playlists[playlistId] = playlist.copyWith(
      songs: songs,
      updatedAt: DateTime.now().toUtc(),
    );
    _notifyLibraryChanged();
    return (playlistId: playlistId, song: song, index: index);
  }

  bool restoreSongToPlaylist(RemovedPlaylistSong removal) {
    final playlist = _playlists[removal.playlistId];
    if (playlist == null ||
        playlist.songs.any((song) => song.id == removal.song.id)) {
      return false;
    }
    final songs = [...playlist.songs];
    songs.insert(removal.index.clamp(0, songs.length), removal.song);
    _playlists[removal.playlistId] = playlist.copyWith(
      songs: songs,
      updatedAt: DateTime.now().toUtc(),
    );
    _notifyLibraryChanged();
    return true;
  }

  bool reorderPlaylistSong(String playlistId, int oldIndex, int newIndex) {
    final playlist = _playlists[playlistId];
    if (playlist == null || oldIndex < 0 || oldIndex >= playlist.songs.length) {
      return false;
    }
    if (newIndex > oldIndex) newIndex--;
    if (newIndex < 0 ||
        newIndex >= playlist.songs.length ||
        newIndex == oldIndex) {
      return false;
    }
    return _movePlaylistSong(playlist, oldIndex, newIndex);
  }

  bool reorderPlaylistSongItem(
    String playlistId,
    int oldIndex,
    int targetIndex,
  ) {
    final playlist = _playlists[playlistId];
    if (playlist == null ||
        oldIndex < 0 ||
        oldIndex >= playlist.songs.length ||
        targetIndex < 0 ||
        targetIndex >= playlist.songs.length ||
        targetIndex == oldIndex) {
      return false;
    }
    return _movePlaylistSong(playlist, oldIndex, targetIndex);
  }

  bool _movePlaylistSong(
    LocalPlaylist playlist,
    int oldIndex,
    int targetIndex,
  ) {
    final songs = [...playlist.songs];
    final song = songs.removeAt(oldIndex);
    songs.insert(targetIndex, song);
    _playlists[playlist.id] = playlist.copyWith(
      songs: songs,
      updatedAt: DateTime.now().toUtc(),
    );
    _notifyLibraryChanged();
    return true;
  }

  void recordSearch(String query) {
    final normalized = query.trim();
    if (normalized.length < 2) return;
    _recentSearches = [
      normalized,
      ..._recentSearches.where(
        (item) => item.toLowerCase() != normalized.toLowerCase(),
      ),
    ].take(8).toList(growable: false);
    _notifyLibraryChanged();
  }

  void clearRecentSearches() {
    if (_recentSearches.isEmpty) return;
    _recentSearches = const [];
    _notifyLibraryChanged();
  }

  void setThemePreference(AppThemePreference preference) {
    if (_themePreference == preference) return;
    _themePreference = preference;
    _notifyLibraryChanged();
  }

  void setAlwaysOpenFullscreenPlayer(bool enabled) {
    if (_alwaysOpenFullscreenPlayer == enabled) return;
    _alwaysOpenFullscreenPlayer = enabled;
    _notifyLibraryChanged();
  }

  void setCarModeEnabled(bool enabled) {
    if (_carModeEnabled == enabled) return;
    _carModeEnabled = enabled;
    _notifyLibraryChanged();
  }

  Future<void> setVolume(double value) async {
    final safeVolume = value.isFinite ? value.clamp(0, 1).toDouble() : 1.0;
    if ((_volume - safeVolume).abs() < 0.001) return;
    _volume = safeVolume;
    if (safeVolume > 0.001) _volumeBeforeMute = safeVolume;
    _notifyPlaybackChanged(catalogChanged: false);
    unawaited(_saveSnapshot());
    try {
      await _runPlayerCommand(() => _audioPlayer.setVolume(safeVolume));
    } catch (_) {
      // Keep playback usable when a platform backend has no volume surface.
    }
  }

  Future<void> toggleMute() =>
      setVolume(isMuted ? _volumeBeforeMute.clamp(0.05, 1) : 0);

  void setStreamingQualityPreference(StreamingQualityPreference preference) {
    if (_streamingQualityPreference == preference) return;
    _streamingQualityPreference = preference;
    _notifyPlaybackChanged(catalogChanged: false);
    unawaited(_saveSnapshot());
  }

  Future<void> retryPlayback({bool useAutomaticQuality = false}) async {
    if (_isLoading) return;
    final liveRadio = _currentLiveRadio;
    if (liveRadio != null) {
      await playLiveRadio(liveRadio);
      return;
    }
    final song = _currentSong;
    if (song == null) return;
    if (useAutomaticQuality) {
      setStreamingQualityPreference(StreamingQualityPreference.automatic);
    }
    await playSong(song, queue: _queue);
  }

  Future<String> _resolveSongSource(String code) {
    final resolver = _qualitySourceResolver;
    return resolver == null
        ? _sourceResolver(code)
        : resolver(code, _streamingQualityPreference);
  }

  void cycleThemePreference() {
    final next = switch (_themePreference) {
      AppThemePreference.system => AppThemePreference.light,
      AppThemePreference.light => AppThemePreference.dark,
      AppThemePreference.dark => AppThemePreference.system,
    };
    setThemePreference(next);
  }

  String exportLibraryJson() => LibraryBackupData(
    likedSongs: likedSongs,
    followedArtists: followedArtists,
    savedCollections: savedCollections,
    playlists: playlists,
    history: history,
    recentSearches: recentSearches,
    themePreferenceIndex: themePreference.index,
    analytics: _analytics.snapshot,
  ).encode();

  Future<BackupImportResult> importLibraryJson(
    String source,
    BackupImportMode mode,
  ) async {
    final backup = LibraryBackupData.decode(source);
    if (mode == BackupImportMode.overwrite) {
      _likedSongs
        ..clear()
        ..addEntries(backup.likedSongs.map((song) => MapEntry(song.id, song)));
      _followedArtists
        ..clear()
        ..addEntries(
          backup.followedArtists.map((artist) => MapEntry(artist.id, artist)),
        );
      _savedCollections
        ..clear()
        ..addEntries(
          backup.savedCollections.map(
            (collection) => MapEntry(collection.id, collection),
          ),
        );
      _playlists
        ..clear()
        ..addEntries(
          backup.playlists.map((playlist) => MapEntry(playlist.id, playlist)),
        );
      _history = List<ListeningRecord>.unmodifiable(backup.history.take(500));
      _recentSearches = List<String>.unmodifiable(
        backup.recentSearches.take(8),
      );
    } else {
      for (final song in backup.likedSongs) {
        _likedSongs.putIfAbsent(song.id, () => song);
      }
      for (final artist in backup.followedArtists) {
        _followedArtists.putIfAbsent(artist.id, () => artist);
      }
      for (final collection in backup.savedCollections) {
        _savedCollections.putIfAbsent(collection.id, () => collection);
      }
      for (final incoming in backup.playlists) {
        final current = _playlists[incoming.id];
        if (current == null) {
          _playlists[incoming.id] = incoming;
          continue;
        }
        final songs = <String, Song>{
          for (final song in current.songs) song.id: song,
          for (final song in incoming.songs) song.id: song,
        };
        final incomingIsNewer = incoming.updatedAt.isAfter(current.updatedAt);
        _playlists[incoming.id] = current.copyWith(
          name: incomingIsNewer ? incoming.name : current.name,
          songs: songs.values.toList(growable: false),
          updatedAt: incomingIsNewer ? incoming.updatedAt : current.updatedAt,
        );
      }
      final historyById = <String, ListeningRecord>{
        for (final record in _history) record.id: record,
        for (final record in backup.history) record.id: record,
      };
      _history = historyById.values.toList()
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
      _history = List<ListeningRecord>.unmodifiable(_history.take(500));
      final searches = <String, String>{};
      for (final query in [...backup.recentSearches, ..._recentSearches]) {
        searches.putIfAbsent(query.toLowerCase(), () => query);
      }
      _recentSearches = List<String>.unmodifiable(searches.values.take(8));
    }
    final incomingAnalytics = backup.analytics;
    if (incomingAnalytics != null) {
      if (mode == BackupImportMode.overwrite) {
        await _analytics.overwriteSnapshot(incomingAnalytics);
      } else {
        await _analytics.mergeSnapshot(incomingAnalytics);
      }
    }
    if (mode == BackupImportMode.overwrite) {
      _themePreference =
          AppThemePreference.values[backup.themePreferenceIndex.clamp(
            0,
            AppThemePreference.values.length - 1,
          )];
    }
    _notifyCatalogChanged();
    notifyListeners();
    await _saveSnapshot();
    return BackupImportResult(
      likedSongs: backup.likedSongs.length,
      followedArtists: backup.followedArtists.length,
      savedCollections: backup.savedCollections.length,
      playlists: backup.playlists.length,
      historyRecords: backup.history.length,
    );
  }

  void setSleepTimer(Duration duration) {
    if (duration <= Duration.zero) {
      cancelSleepTimer();
      return;
    }
    _sleepTimer?.cancel();
    _sleepAfterCurrentSong = false;
    _sleepTimerRemaining = duration;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _sleepTimerRemaining;
      if (remaining == null || remaining <= const Duration(seconds: 1)) {
        timer.cancel();
        _sleepTimer = null;
        _sleepTimerRemaining = null;
        notifyListeners();
        unawaited(stop());
        return;
      }
      _sleepTimerRemaining = remaining - const Duration(seconds: 1);
      notifyListeners();
    });
    notifyListeners();
  }

  void setSleepAfterCurrentSong() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerRemaining = null;
    _sleepAfterCurrentSong = true;
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerRemaining = null;
    _sleepAfterCurrentSong = false;
    notifyListeners();
  }

  Future<void> seek(Duration target) async {
    if (isLiveRadio) return;
    if (_duration == Duration.zero) return;
    final safeTarget = target < Duration.zero
        ? Duration.zero
        : target > _duration
        ? _duration
        : target;
    _analytics.beginSeek(safeTarget);
    try {
      await _runPlayerCommand(() => _audioPlayer.seek(safeTarget));
      _analytics.finishSeek(safeTarget);
    } catch (_) {
      _analytics.finishSeek(_position);
      rethrow;
    }
  }

  void clearError() {
    _errorMessage = null;
    _notifyPlaybackChanged();
  }

  Future<void> clearListeningHistoryAndStats() async {
    _history = const [];
    _activeHistoryRecordId = null;
    _lastListeningPosition = Duration.zero;
    await _analytics.clearActivity();
    _notifyCatalogChanged();
    notifyListeners();
    await _saveSnapshot();
  }

  Future<int> _appendRadioRecommendations(Song seed) {
    final pending = _radioLoadFuture;
    if (pending != null && _radioLoadSeedId == seed.id) return pending;

    late final Future<int> operation;
    operation = _loadRadioRecommendations(seed).whenComplete(() {
      if (identical(_radioLoadFuture, operation)) {
        _radioLoadFuture = null;
        _radioLoadSeedId = null;
      }
    });
    _radioLoadSeedId = seed.id;
    _radioLoadFuture = operation;
    return operation;
  }

  Future<int> _loadRadioRecommendations(Song seed) async {
    final loader = _songRadioLoader;
    if (loader == null) return 0;
    final requestId = ++_radioRequestId;
    _isRadioLoading = true;
    _radioErrorMessage = null;
    _notifyPlaybackChanged();
    try {
      final radio = await loader(seed.code);
      if (requestId != _radioRequestId || _currentSong?.id != seed.id) {
        return 0;
      }
      final seedIndex = _queue.indexWhere((song) => song.id == seed.id);
      final prefix = seedIndex < 0
          ? <Song>[seed]
          : _queue.take(seedIndex + 1).toList(growable: false);
      final seen = prefix.map((song) => song.id).toSet();
      final appended = radio.songs
          .where((song) => song.code.isNotEmpty && seen.add(song.id))
          .take(30)
          .toList(growable: false);
      if (appended.isEmpty) {
        _radioErrorMessage = 'Chưa tìm thấy bài tương tự phù hợp.';
        return 0;
      }
      _queue = List<Song>.unmodifiable([...prefix, ...appended]);
      _currentIndex = _queue.indexWhere((song) => song.id == _currentSong?.id);
      final retainedIds = prefix.map((song) => song.id).toSet();
      _radioSongIds = Set<String>.unmodifiable({
        ..._radioSongIds.where(retainedIds.contains),
        ...appended.map((song) => song.id),
      });
      _radioErrorMessage = null;
      unawaited(_saveSnapshot());
      return appended.length;
    } catch (error) {
      if (requestId == _radioRequestId) {
        _radioErrorMessage = error.toString();
      }
      return 0;
    } finally {
      if (requestId == _radioRequestId) {
        _isRadioLoading = false;
        _notifyPlaybackChanged();
      }
    }
  }

  void _cancelRadioLoad({bool clearError = false}) {
    _radioRequestId++;
    _radioAdvanceRequestId++;
    _radioLoadFuture = null;
    _radioLoadSeedId = null;
    _isRadioLoading = false;
    if (clearError) _radioErrorMessage = null;
  }

  Future<void> _runPlayerCommand(Future<void> Function() command) {
    final completer = Completer<void>();
    _playerCommandQueue = _playerCommandQueue.then((_) async {
      try {
        await command();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _handleTrackCompleted(
    int completedRequestId,
    String? completedSongId,
  ) async {
    if (completedRequestId != _requestId ||
        completedSongId == null ||
        completedSongId != _currentSong?.id) {
      return;
    }
    if (isLiveRadio) return;
    if (_repeatMode == PlayerRepeatMode.one) {
      if (_sleepAfterCurrentSong) {
        cancelSleepTimer();
        await stop();
        return;
      }
      await playSong(_currentSong!);
      return;
    }
    if (_sleepAfterCurrentSong) {
      cancelSleepTimer();
      await stop();
      return;
    }
    await next();
  }

  Future<void> _playQueueIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await playSong(_queue[index]);
  }

  int _randomIndexExcluding(int excluded) {
    final seed = DateTime.now().microsecondsSinceEpoch;
    var index = seed % _queue.length;
    if (index == excluded) index = (index + 1) % _queue.length;
    return index;
  }

  List<Song> _interleaveSmartShuffleSuggestions(
    List<Song> queue,
    List<Song> suggestions,
  ) {
    final result = <Song>[];
    var suggestionIndex = 0;
    for (var index = 0; index < queue.length; index++) {
      result.add(queue[index]);
      final closesGroup = (index + 1) % 3 == 0 || index == queue.length - 1;
      if (closesGroup && suggestionIndex < suggestions.length) {
        result.add(suggestions[suggestionIndex++]);
      }
    }
    while (suggestionIndex < suggestions.length) {
      result.add(suggestions[suggestionIndex++]);
    }
    return result;
  }

  void _removeSmartShuffleSongs() {
    if (_smartShuffleSongIds.isEmpty) return;
    final currentId = _currentSong?.id;
    _queue = List<Song>.unmodifiable(
      _queue.where(
        (song) =>
            song.id == currentId || !_smartShuffleSongIds.contains(song.id),
      ),
    );
    _currentIndex = _queue.indexWhere((song) => song.id == currentId);
  }

  void _clearSmartShuffleState() {
    _smartShuffleEnabled = false;
    _smartShuffleSongIds = const {};
    _smartShuffleMessage = null;
  }

  void _promoteSmartShuffleSong(String songId) {
    if (!_smartShuffleSongIds.contains(songId)) return;
    _smartShuffleSongIds = Set<String>.unmodifiable(
      _smartShuffleSongIds.where((id) => id != songId),
    );
    if (_smartShuffleSongIds.isEmpty) _smartShuffleEnabled = false;
  }

  Future<void> _restoreSnapshot() async {
    _currentLiveRadio = null;
    final snapshot = await _libraryRepository.load();
    _likedSongs
      ..clear()
      ..addEntries(snapshot.likedSongs.map((song) => MapEntry(song.id, song)));
    _followedArtists
      ..clear()
      ..addEntries(
        snapshot.followedArtists.map((artist) => MapEntry(artist.id, artist)),
      );
    _savedCollections
      ..clear()
      ..addEntries(
        snapshot.savedCollections.map(
          (collection) => MapEntry(collection.id, collection),
        ),
      );
    _queue = List<Song>.unmodifiable(snapshot.queue);
    _currentSong = snapshot.currentSong;
    _playbackOrigin = snapshot.playbackOrigin;
    _currentIndex =
        snapshot.currentIndex >= 0 && snapshot.currentIndex < _queue.length
        ? snapshot.currentIndex
        : _queue.indexWhere((song) => song.id == _currentSong?.id);
    _position = snapshot.position;
    _restoredPosition = snapshot.position;
    _restoredSongId = snapshot.currentSong?.id;
    final restoredQueueIds = _queue.map((song) => song.id).toSet();
    _smartShuffleSongIds = Set<String>.unmodifiable(
      snapshot.smartShuffleSongIds.where(restoredQueueIds.contains),
    );
    _smartShuffleEnabled =
        snapshot.smartShuffleEnabled && _smartShuffleSongIds.isNotEmpty;
    _shuffleEnabled = snapshot.shuffleEnabled || _smartShuffleEnabled;
    _repeatMode =
        PlayerRepeatMode.values[snapshot.repeatModeIndex.clamp(
          0,
          PlayerRepeatMode.values.length - 1,
        )];
    _autoplayRecommendationsEnabled =
        _songRadioLoader != null && snapshot.autoplayRecommendationsEnabled;
    _alwaysOpenFullscreenPlayer = snapshot.alwaysOpenFullscreenPlayer;
    _carModeEnabled = snapshot.carModeEnabled;
    _volume = snapshot.volume;
    _volumeBeforeMute = _volume > 0.001 ? _volume : 1;
    _streamingQualityPreference =
        StreamingQualityPreference.values[snapshot
            .streamingQualityPreferenceIndex
            .clamp(0, StreamingQualityPreference.values.length - 1)];
    _radioSongIds = Set<String>.unmodifiable(
      snapshot.radioSongIds.where(restoredQueueIds.contains),
    );
    _playlists
      ..clear()
      ..addEntries(
        snapshot.playlists.map((playlist) => MapEntry(playlist.id, playlist)),
      );
    _history = List<ListeningRecord>.unmodifiable(snapshot.history);
    _recentSearches = List<String>.unmodifiable(snapshot.recentSearches);
    _themePreference =
        AppThemePreference.values[snapshot.themePreferenceIndex.clamp(
          0,
          AppThemePreference.values.length - 1,
        )];
  }

  Future<void> _saveSnapshot() {
    final persistPlayback = !isLiveRadio;
    _pendingSnapshot = PlayerSnapshot(
      likedSongs: likedSongs,
      followedArtists: followedArtists,
      savedCollections: savedCollections,
      queue: persistPlayback ? queue : const [],
      currentSong: persistPlayback ? currentSong : null,
      playbackOrigin: persistPlayback
          ? playbackOrigin
          : const PlaybackOrigin.chart(),
      currentIndex: persistPlayback ? currentIndex : -1,
      position: persistPlayback ? position : Duration.zero,
      shuffleEnabled: shuffleEnabled,
      smartShuffleEnabled: persistPlayback && smartShuffleEnabled,
      smartShuffleSongIds: persistPlayback
          ? _smartShuffleSongIds.toList(growable: false)
          : const [],
      repeatModeIndex: repeatMode.index,
      autoplayRecommendationsEnabled: autoplayRecommendationsEnabled,
      alwaysOpenFullscreenPlayer: alwaysOpenFullscreenPlayer,
      carModeEnabled: carModeEnabled,
      volume: volume,
      streamingQualityPreferenceIndex: streamingQualityPreference.index,
      radioSongIds: persistPlayback
          ? _radioSongIds.toList(growable: false)
          : const [],
      playlists: playlists,
      history: history,
      recentSearches: recentSearches,
      themePreferenceIndex: themePreference.index,
    );
    if (!_snapshotSaveScheduled) {
      _snapshotSaveScheduled = true;
      _snapshotSaveFuture = _snapshotSaveFuture.then(
        (_) => _drainSnapshotSaves(),
      );
    }
    return _snapshotSaveFuture;
  }

  Future<void> _drainSnapshotSaves() async {
    while (_pendingSnapshot != null) {
      final snapshot = _pendingSnapshot!;
      _pendingSnapshot = null;
      try {
        await _libraryRepository.save(snapshot);
      } catch (_) {
        // Playback remains usable when a platform storage backend is unavailable.
      }
    }
    _snapshotSaveScheduled = false;
  }

  void _notifyPlaybackChanged({bool catalogChanged = true}) {
    if (catalogChanged) _notifyCatalogChanged();
    notifyListeners();
    _publishCompanionSnapshot();
    final bridge = _systemMediaBridge;
    if (bridge == null) return;
    _pendingMediaSnapshot = SystemMediaSnapshot(
      song: currentSong,
      queue: queue,
      queueIndex: currentIndex,
      status: isLoading
          ? SystemPlaybackStatus.loading
          : switch (state) {
              PlayerState.playing => SystemPlaybackStatus.playing,
              PlayerState.paused => SystemPlaybackStatus.paused,
              _ => SystemPlaybackStatus.stopped,
            },
      position: position,
      duration: duration,
      shuffleEnabled: shuffleEnabled,
      repeatMode: switch (repeatMode) {
        PlayerRepeatMode.off => SystemRepeatMode.none,
        PlayerRepeatMode.all => SystemRepeatMode.all,
        PlayerRepeatMode.one => SystemRepeatMode.one,
      },
    );
    if (_mediaPublishScheduled) return;
    _mediaPublishScheduled = true;
    _mediaPublishQueue = _mediaPublishQueue.then((_) => _drainMediaPublish());
  }

  void _notifyLibraryChanged() {
    _notifyCatalogChanged();
    notifyListeners();
    unawaited(_saveSnapshot());
  }

  void _notifyCatalogChanged() {
    _catalogRevision.value++;
  }

  void _recordPlaybackStarted(Song song) {
    final now = DateTime.now().toUtc();
    final record = ListeningRecord(
      id: '${song.id}-${now.microsecondsSinceEpoch}',
      song: song,
      playedAt: now,
    );
    _history = List<ListeningRecord>.unmodifiable(
      [record, ..._history].take(500),
    );
    _activeHistoryRecordId = record.id;
    _lastListeningPosition = Duration.zero;
    _notifyLibraryChanged();
  }

  void _recordListeningProgress(Duration nextPosition) {
    final recordId = _activeHistoryRecordId;
    if (recordId == null) {
      _lastListeningPosition = nextPosition;
      return;
    }
    final delta = nextPosition - _lastListeningPosition;
    _lastListeningPosition = nextPosition;
    if (delta <= Duration.zero || delta > const Duration(seconds: 5)) return;
    final index = _history.indexWhere((record) => record.id == recordId);
    if (index < 0) return;
    final updated = [..._history];
    updated[index] = updated[index].copyWith(
      listened: updated[index].listened + delta,
    );
    _history = List<ListeningRecord>.unmodifiable(updated);
  }

  Future<void> _drainMediaPublish() async {
    while (_pendingMediaSnapshot != null) {
      final snapshot = _pendingMediaSnapshot!;
      _pendingMediaSnapshot = null;
      try {
        await _systemMediaBridge?.publish(snapshot);
      } catch (_) {
        // System controls are optional and must not break in-app playback.
      }
    }
    _mediaPublishScheduled = false;
  }

  void _publishCompanionSnapshot() {
    final bridge = _companionSurfaceBridge;
    if (bridge == null) return;
    final snapshot = CompanionPlayerSnapshot(
      song: currentSong,
      status: isLoading
          ? CompanionPlaybackStatus.loading
          : switch (state) {
              PlayerState.playing => CompanionPlaybackStatus.playing,
              PlayerState.paused => CompanionPlaybackStatus.paused,
              _ => CompanionPlaybackStatus.idle,
            },
      position: position,
      duration: duration,
      canGoPrevious: canGoPrevious,
      canGoNext: canGoNext,
      updatedAt: DateTime.now().toUtc(),
    );
    if (snapshot.publishSignature == _lastCompanionPublishSignature) return;
    _lastCompanionPublishSignature = snapshot.publishSignature;
    _pendingCompanionSnapshot = snapshot;
    if (_companionPublishScheduled) return;
    _companionPublishScheduled = true;
    _companionPublishQueue = _companionPublishQueue.then(
      (_) => _drainCompanionPublish(),
    );
  }

  Future<void> _drainCompanionPublish() async {
    while (_pendingCompanionSnapshot != null) {
      final snapshot = _pendingCompanionSnapshot!;
      _pendingCompanionSnapshot = null;
      try {
        await _companionSurfaceBridge?.publish(snapshot);
      } catch (_) {
        // Widgets and watch companions are optional playback surfaces.
      }
    }
    _companionPublishScheduled = false;
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    unawaited(_saveSnapshot());
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    final bridge = _systemMediaBridge;
    if (bridge != null) unawaited(bridge.dispose());
    final companionBridge = _companionSurfaceBridge;
    if (companionBridge != null) unawaited(companionBridge.dispose());
    _analytics.dispose();
    _catalogRevision.dispose();
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }
}

class _MutableSongStat {
  _MutableSongStat(this.song);

  final Song song;
  int playCount = 0;
  Duration listened = Duration.zero;
}

class _MutableArtistStat {
  _MutableArtistStat(this.artist);

  final String artist;
  int playCount = 0;
  Duration listened = Duration.zero;
}

typedef MusicPlayerController = PlaybackService;
