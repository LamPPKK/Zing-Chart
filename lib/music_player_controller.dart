import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'data/library_repository.dart';
import 'models/song.dart';
import 'services/system_media_bridge.dart';
import 'zing_mp3_api.dart';

typedef SongSourceResolver = Future<String> Function(String code);

enum PlayerRepeatMode { off, all, one }

class PlaybackService extends ChangeNotifier {
  PlaybackService({
    AudioPlayer? audioPlayer,
    SongSourceResolver? sourceResolver,
    LibraryRepository? libraryRepository,
    SystemMediaBridge? systemMediaBridge,
  }) : _audioPlayer = audioPlayer ?? AudioPlayer(),
       _sourceResolver = sourceResolver ?? ZingMP3API.getSongUrlByCode,
       _libraryRepository =
           libraryRepository ?? SharedPreferencesLibraryRepository(),
       _systemMediaBridge = systemMediaBridge;

  final AudioPlayer _audioPlayer;
  final SongSourceResolver _sourceResolver;
  final LibraryRepository _libraryRepository;
  SystemMediaBridge? _systemMediaBridge;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void> _playerCommandQueue = Future<void>.value();

  Song? _currentSong;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentSource;
  int _requestId = 0;
  int _activePlaybackRequestId = -1;
  String? _activePlaybackSongId;
  List<Song> _queue = const [];
  int _currentIndex = -1;
  bool _shuffleEnabled = false;
  PlayerRepeatMode _repeatMode = PlayerRepeatMode.off;
  final Map<String, Song> _likedSongs = {};
  Duration _restoredPosition = Duration.zero;
  String? _restoredSongId;
  int _lastSavedPositionBucket = -1;
  Future<void> _mediaPublishQueue = Future<void>.value();
  SystemMediaSnapshot? _pendingMediaSnapshot;
  bool _mediaPublishScheduled = false;

  Song? get currentSong => _currentSong;
  PlayerState get state => _state;
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _state == PlayerState.playing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasSong => _currentSong != null;
  List<Song> get queue => List<Song>.unmodifiable(_queue);
  List<Song> get likedSongs => List<Song>.unmodifiable(_likedSongs.values);
  int get currentIndex => _currentIndex;
  bool get shuffleEnabled => _shuffleEnabled;
  PlayerRepeatMode get repeatMode => _repeatMode;
  bool get canGoNext => _queue.length > 1;
  bool get canGoPrevious => _queue.length > 1;

  double get progress {
    if (_duration.inMilliseconds <= 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds).clamp(0, 1);
  }

  Future<void> initialize() async {
    await _restoreSnapshot();
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
    await _audioPlayer.setAudioContext(
      AudioContextConfig(stayAwake: true).build(),
    );
    await _audioPlayer.setReleaseMode(ReleaseMode.stop);

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
          _notifyPlaybackChanged();
        }),
      )
      ..add(
        _audioPlayer.onPositionChanged.listen((position) {
          _position = position;
          _notifyPlaybackChanged();
          final bucket = position.inSeconds ~/ 5;
          if (bucket != _lastSavedPositionBucket) {
            _lastSavedPositionBucket = bucket;
            unawaited(_saveSnapshot());
          }
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
          _state = PlayerState.completed;
          _position = _duration;
          _notifyPlaybackChanged();
          unawaited(_handleTrackCompleted(completedRequestId, completedSongId));
        }),
      );
    _notifyPlaybackChanged();
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    if (queue != null && queue.isNotEmpty) {
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
      final source = await _sourceResolver(song.code);
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

  Future<void> togglePlayPause() async {
    if (_currentSong == null || _isLoading) return;
    _errorMessage = null;
    try {
      if (isPlaying) {
        await _runPlayerCommand(_audioPlayer.pause);
      } else if (_state == PlayerState.completed) {
        await _runPlayerCommand(() async {
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.resume();
        });
      } else if (_state == PlayerState.stopped && _currentSource != null) {
        final requestId = ++_requestId;
        await _runPlayerCommand(() async {
          _activePlaybackRequestId = requestId;
          _activePlaybackSongId = _currentSong!.id;
          await _audioPlayer.play(UrlSource(_currentSource!));
        });
      } else if (_state == PlayerState.stopped) {
        await playSong(_currentSong!);
      } else {
        await _runPlayerCommand(_audioPlayer.resume);
      }
    } catch (error) {
      _errorMessage = error.toString();
      _notifyPlaybackChanged();
    }
  }

  Future<void> stop() async {
    _requestId++;
    _activePlaybackRequestId = -1;
    _activePlaybackSongId = null;
    await _runPlayerCommand(_audioPlayer.stop);
    _state = PlayerState.stopped;
    _position = Duration.zero;
    _isLoading = false;
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
  }

  Future<void> next() async {
    if (_queue.isEmpty || _currentSong == null) return;
    final nextIndex = _shuffleEnabled && _queue.length > 1
        ? _randomIndexExcluding(_currentIndex)
        : _currentIndex + 1;
    if (nextIndex >= _queue.length) {
      if (_repeatMode == PlayerRepeatMode.all) {
        await _playQueueIndex(0);
      } else {
        await stop();
      }
      return;
    }
    await _playQueueIndex(nextIndex);
  }

  Future<void> previous() async {
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

  void toggleShuffle() {
    _shuffleEnabled = !_shuffleEnabled;
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
  }

  void cycleRepeatMode() {
    _repeatMode = switch (_repeatMode) {
      PlayerRepeatMode.off => PlayerRepeatMode.all,
      PlayerRepeatMode.all => PlayerRepeatMode.one,
      PlayerRepeatMode.one => PlayerRepeatMode.off,
    };
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
  }

  void toggleLike(Song song) {
    if (_likedSongs.containsKey(song.id)) {
      _likedSongs.remove(song.id);
    } else {
      _likedSongs[song.id] = song;
    }
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
  }

  bool isLiked(Song song) => _likedSongs.containsKey(song.id);

  bool addToQueue(Song song) {
    if (song.id == _currentSong?.id) return false;

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
    if (index < _currentIndex) _currentIndex--;
    _notifyPlaybackChanged();
    unawaited(_saveSnapshot());
  }

  Future<void> seek(Duration target) async {
    if (_duration == Duration.zero) return;
    final safeTarget = target < Duration.zero
        ? Duration.zero
        : target > _duration
        ? _duration
        : target;
    await _runPlayerCommand(() => _audioPlayer.seek(safeTarget));
  }

  void clearError() {
    _errorMessage = null;
    _notifyPlaybackChanged();
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
    if (_repeatMode == PlayerRepeatMode.one) {
      await playSong(_currentSong!);
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

  Future<void> _restoreSnapshot() async {
    final snapshot = await _libraryRepository.load();
    _likedSongs
      ..clear()
      ..addEntries(snapshot.likedSongs.map((song) => MapEntry(song.id, song)));
    _queue = List<Song>.unmodifiable(snapshot.queue);
    _currentSong = snapshot.currentSong;
    _currentIndex =
        snapshot.currentIndex >= 0 && snapshot.currentIndex < _queue.length
        ? snapshot.currentIndex
        : _queue.indexWhere((song) => song.id == _currentSong?.id);
    _position = snapshot.position;
    _restoredPosition = snapshot.position;
    _restoredSongId = snapshot.currentSong?.id;
    _shuffleEnabled = snapshot.shuffleEnabled;
    _repeatMode =
        PlayerRepeatMode.values[snapshot.repeatModeIndex.clamp(
          0,
          PlayerRepeatMode.values.length - 1,
        )];
  }

  Future<void> _saveSnapshot() async {
    try {
      await _libraryRepository.save(
        PlayerSnapshot(
          likedSongs: likedSongs,
          queue: queue,
          currentSong: currentSong,
          currentIndex: currentIndex,
          position: position,
          shuffleEnabled: shuffleEnabled,
          repeatModeIndex: repeatMode.index,
        ),
      );
    } catch (_) {
      // Playback remains usable when a platform storage backend is unavailable.
    }
  }

  void _notifyPlaybackChanged() {
    notifyListeners();
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

  @override
  void dispose() {
    unawaited(_saveSnapshot());
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    final bridge = _systemMediaBridge;
    if (bridge != null) unawaited(bridge.dispose());
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }
}

typedef MusicPlayerController = PlaybackService;
