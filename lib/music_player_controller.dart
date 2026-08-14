import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'data/library_repository.dart';
import 'models/local_library.dart';
import 'models/song.dart';
import 'services/playback_audio_player.dart';
import 'services/system_media_bridge.dart';
import 'zing_mp3_api.dart';

typedef SongSourceResolver = Future<String> Function(String code);

enum PlayerRepeatMode { off, all, one }

class PlaybackService extends ChangeNotifier {
  PlaybackService({
    AudioPlayer? audioPlayer,
    PlaybackAudioPlayer? playbackAudioPlayer,
    SongSourceResolver? sourceResolver,
    LibraryRepository? libraryRepository,
    SystemMediaBridge? systemMediaBridge,
  }) : assert(audioPlayer == null || playbackAudioPlayer == null),
       _audioPlayer =
           playbackAudioPlayer ??
           AudioplayersPlaybackAudioPlayer(audioPlayer ?? AudioPlayer()),
       _sourceResolver = sourceResolver ?? ZingMP3API.getSongUrlByCode,
       _libraryRepository =
           libraryRepository ?? SharedPreferencesLibraryRepository(),
       _systemMediaBridge = systemMediaBridge;

  final PlaybackAudioPlayer _audioPlayer;
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
  final Map<String, LocalPlaylist> _playlists = {};
  List<ListeningRecord> _history = const [];
  List<String> _recentSearches = const [];
  AppThemePreference _themePreference = AppThemePreference.system;
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
  Future<void> _snapshotSaveFuture = Future<void>.value();
  PlayerSnapshot? _pendingSnapshot;
  bool _snapshotSaveScheduled = false;

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
  List<LocalPlaylist> get playlists => List<LocalPlaylist>.unmodifiable(
    _playlists.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );
  List<ListeningRecord> get history =>
      List<ListeningRecord>.unmodifiable(_history);
  List<String> get recentSearches => List<String>.unmodifiable(_recentSearches);
  AppThemePreference get themePreference => _themePreference;
  Duration? get sleepTimerRemaining => _sleepTimerRemaining;
  bool get sleepAfterCurrentSong => _sleepAfterCurrentSong;
  bool get hasSleepTimer =>
      _sleepTimerRemaining != null || _sleepAfterCurrentSong;
  int get currentIndex => _currentIndex;
  bool get shuffleEnabled => _shuffleEnabled;
  PlayerRepeatMode get repeatMode => _repeatMode;
  bool get canGoNext => _queue.length > 1;
  bool get canGoPrevious => _queue.length > 1;

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

  List<Song> get dailyMix {
    final result = <Song>[];
    final seen = <String>{};
    for (final stat in topSongStats) {
      if (seen.add(stat.song.id)) result.add(stat.song);
    }
    for (final song in _likedSongs.values) {
      if (seen.add(song.id)) result.add(song);
    }
    return List<Song>.unmodifiable(result.take(25));
  }

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
          _recordListeningProgress(position);
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
      _recordPlaybackStarted(song);
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
        _recordPlaybackStarted(_currentSong!);
      } else if (_state == PlayerState.stopped && _currentSource != null) {
        final requestId = ++_requestId;
        await _runPlayerCommand(() async {
          _activePlaybackRequestId = requestId;
          _activePlaybackSongId = _currentSong!.id;
          await _audioPlayer.play(UrlSource(_currentSource!));
        });
        _recordPlaybackStarted(_currentSong!);
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
    _notifyLibraryChanged();
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

  LocalPlaylist createPlaylist(String name) {
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
    final playlist = LocalPlaylist(
      id: 'playlist-${now.microsecondsSinceEpoch.toRadixString(36)}',
      name: normalized,
      createdAt: now,
      updatedAt: now,
    );
    _playlists[playlist.id] = playlist;
    _notifyLibraryChanged();
    return playlist;
  }

  void renamePlaylist(String playlistId, String name) {
    final playlist = _playlists[playlistId];
    final normalized = name.trim();
    if (playlist == null || normalized.isEmpty || normalized.length > 60) {
      return;
    }
    _playlists[playlistId] = playlist.copyWith(
      name: normalized,
      updatedAt: DateTime.now().toUtc(),
    );
    _notifyLibraryChanged();
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

  void removeSongFromPlaylist(String playlistId, String songId) {
    final playlist = _playlists[playlistId];
    if (playlist == null || !playlist.songs.any((song) => song.id == songId)) {
      return;
    }
    _playlists[playlistId] = playlist.copyWith(
      songs: playlist.songs.where((song) => song.id != songId).toList(),
      updatedAt: DateTime.now().toUtc(),
    );
    _notifyLibraryChanged();
  }

  void reorderPlaylistSong(String playlistId, int oldIndex, int newIndex) {
    final playlist = _playlists[playlistId];
    if (playlist == null || oldIndex < 0 || oldIndex >= playlist.songs.length) {
      return;
    }
    if (newIndex > oldIndex) newIndex--;
    if (newIndex < 0 ||
        newIndex >= playlist.songs.length ||
        newIndex == oldIndex) {
      return;
    }
    final songs = [...playlist.songs];
    final song = songs.removeAt(oldIndex);
    songs.insert(newIndex, song);
    _playlists[playlistId] = playlist.copyWith(
      songs: songs,
      updatedAt: DateTime.now().toUtc(),
    );
    _notifyLibraryChanged();
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

  void cycleThemePreference() {
    _themePreference = switch (_themePreference) {
      AppThemePreference.system => AppThemePreference.light,
      AppThemePreference.light => AppThemePreference.dark,
      AppThemePreference.dark => AppThemePreference.system,
    };
    _notifyLibraryChanged();
  }

  String exportLibraryJson() => LibraryBackupData(
    likedSongs: likedSongs,
    playlists: playlists,
    history: history,
    recentSearches: recentSearches,
    themePreferenceIndex: themePreference.index,
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
    if (mode == BackupImportMode.overwrite) {
      _themePreference =
          AppThemePreference.values[backup.themePreferenceIndex.clamp(
            0,
            AppThemePreference.values.length - 1,
          )];
    }
    notifyListeners();
    await _saveSnapshot();
    return BackupImportResult(
      likedSongs: backup.likedSongs.length,
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
    _pendingSnapshot = PlayerSnapshot(
      likedSongs: likedSongs,
      queue: queue,
      currentSong: currentSong,
      currentIndex: currentIndex,
      position: position,
      shuffleEnabled: shuffleEnabled,
      repeatModeIndex: repeatMode.index,
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

  void _notifyLibraryChanged() {
    notifyListeners();
    unawaited(_saveSnapshot());
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

  @override
  void dispose() {
    _sleepTimer?.cancel();
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
