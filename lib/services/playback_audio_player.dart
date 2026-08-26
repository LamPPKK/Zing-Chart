import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

abstract interface class PlaybackAudioPlayer {
  Stream<PlayerState> get onPlayerStateChanged;

  Stream<Duration> get onDurationChanged;

  Stream<Duration> get onPositionChanged;

  Stream<void> get onPlayerComplete;

  bool get supportsSeamlessPreload;

  Future<void> setAudioContext(AudioContext context);

  Future<void> setReleaseMode(ReleaseMode releaseMode);

  Future<void> setVolume(double volume);

  Future<void> play(Source source);

  Future<void> pause();

  Future<void> stop();

  Future<void> resume();

  Future<void> seek(Duration position);

  Future<bool> prepareNext(Source source);

  Future<bool> promotePrepared();

  Future<void> cancelPrepared();

  Future<void> dispose();
}

class AudioplayersPlaybackAudioPlayer implements PlaybackAudioPlayer {
  AudioplayersPlaybackAudioPlayer([
    AudioPlayer? player,
    AudioPlayer? standbyPlayer,
  ]) : _activePlayer = player ?? AudioPlayer(),
       _standbyPlayer = standbyPlayer ?? AudioPlayer(),
       _standbyOperational = true {
    _standbyOperational = !identical(_activePlayer, _standbyPlayer);
    _bindActiveStreams();
  }

  AudioPlayer _activePlayer;
  AudioPlayer _standbyPlayer;
  bool _standbyOperational;
  bool _hasPreparedSource = false;
  bool _disposed = false;
  double _volume = 1;
  int _preparationGeneration = 0;
  int _activeStreamGeneration = 0;

  final _states = StreamController<PlayerState>.broadcast(sync: true);
  final _durations = StreamController<Duration>.broadcast(sync: true);
  final _positions = StreamController<Duration>.broadcast(sync: true);
  final _completions = StreamController<void>.broadcast(sync: true);
  final List<StreamSubscription<dynamic>> _activeSubscriptions = [];

  @override
  Stream<PlayerState> get onPlayerStateChanged => _states.stream;

  @override
  Stream<Duration> get onDurationChanged => _durations.stream;

  @override
  Stream<Duration> get onPositionChanged => _positions.stream;

  @override
  Stream<void> get onPlayerComplete => _completions.stream;

  @override
  bool get supportsSeamlessPreload =>
      !_disposed &&
      _standbyOperational &&
      !identical(_activePlayer, _standbyPlayer);

  @override
  Future<void> setAudioContext(AudioContext context) async {
    await _activePlayer.setAudioContext(context);
    await _configureStandby((player) => player.setAudioContext(context));
  }

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    await _activePlayer.setReleaseMode(releaseMode);
    await _configureStandby((player) => player.setReleaseMode(releaseMode));
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    await _activePlayer.setVolume(volume);
    if (!supportsSeamlessPreload) return;
    try {
      await _standbyPlayer.setVolume(0);
    } catch (_) {
      _standbyOperational = false;
      _invalidatePrepared();
    }
  }

  @override
  Future<void> play(Source source) async {
    await cancelPrepared();
    await _activePlayer.play(source);
  }

  @override
  Future<void> pause() => _activePlayer.pause();

  @override
  Future<void> stop() async {
    final standbyCleanup = cancelPrepared();
    try {
      await _activePlayer.stop();
    } finally {
      await standbyCleanup;
    }
  }

  @override
  Future<void> resume() => _activePlayer.resume();

  @override
  Future<void> seek(Duration position) => _activePlayer.seek(position);

  @override
  Future<bool> prepareNext(Source source) async {
    if (!supportsSeamlessPreload) return false;
    final generation = ++_preparationGeneration;
    _hasPreparedSource = false;
    final standby = _standbyPlayer;
    try {
      await standby.stop();
      if (!_preparationIsCurrent(generation, standby)) return false;
      await standby.setVolume(0);
      if (!_preparationIsCurrent(generation, standby)) return false;
      await standby.setSource(source);
      if (!_preparationIsCurrent(generation, standby)) return false;
      _hasPreparedSource = true;
      return true;
    } catch (_) {
      if (_preparationIsCurrent(generation, standby)) {
        _hasPreparedSource = false;
        await _silenceAndStop(standby);
      }
      return false;
    }
  }

  @override
  Future<bool> promotePrepared() async {
    if (!supportsSeamlessPreload || !_hasPreparedSource) return false;
    final generation = ++_preparationGeneration;
    _hasPreparedSource = false;
    final previous = _activePlayer;
    final prepared = _standbyPlayer;

    try {
      await prepared.setVolume(_volume);
      if (!_preparationIsCurrent(generation, prepared)) {
        await _silenceAndStop(prepared);
        return false;
      }

      // Start the prepared deck while the old deck is still alive. Only after
      // resume succeeds do we switch the public event streams and stop it.
      await prepared.resume();
      if (!_preparationIsCurrent(generation, prepared)) {
        await _silenceAndStop(prepared);
        return false;
      }
    } catch (_) {
      await _silenceAndStop(prepared);
      return false;
    }

    _activePlayer = prepared;
    _standbyPlayer = previous;
    _bindActiveStreams();
    if (!_states.isClosed) _states.add(PlayerState.playing);

    // Promotion has already succeeded, so a failure while retiring the old
    // deck must not make the caller start the same track a second time.
    await _silenceAndStop(previous);
    unawaited(_publishActivePositionAndDuration());
    return true;
  }

  @override
  Future<void> cancelPrepared() async {
    _invalidatePrepared();
    if (identical(_activePlayer, _standbyPlayer)) return;
    await _silenceAndStop(_standbyPlayer);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _invalidatePrepared();
    _activeStreamGeneration++;
    final subscriptions = List<StreamSubscription<dynamic>>.of(
      _activeSubscriptions,
    );
    _activeSubscriptions.clear();
    await Future.wait(
      subscriptions.map((subscription) => subscription.cancel()),
    );

    try {
      if (identical(_activePlayer, _standbyPlayer)) {
        await _activePlayer.dispose();
      } else {
        await Future.wait([_activePlayer.dispose(), _standbyPlayer.dispose()]);
      }
    } finally {
      await Future.wait([
        _states.close(),
        _durations.close(),
        _positions.close(),
        _completions.close(),
      ]);
    }
  }

  Future<void> _configureStandby(
    Future<void> Function(AudioPlayer player) configure,
  ) async {
    if (!supportsSeamlessPreload) return;
    try {
      await configure(_standbyPlayer);
    } catch (_) {
      _standbyOperational = false;
      _invalidatePrepared();
      await _silenceAndStop(_standbyPlayer);
    }
  }

  bool _preparationIsCurrent(int generation, AudioPlayer player) =>
      !_disposed &&
      supportsSeamlessPreload &&
      generation == _preparationGeneration &&
      identical(player, _standbyPlayer);

  void _invalidatePrepared() {
    _preparationGeneration++;
    _hasPreparedSource = false;
  }

  Future<void> _silenceAndStop(AudioPlayer player) async {
    try {
      await player.setVolume(0);
    } catch (_) {
      // Cleanup is best-effort and must not interrupt the active deck.
    }
    try {
      await player.stop();
    } catch (_) {
      // A failed standby cleanup is never surfaced as an active-playback error.
    }
  }

  void _bindActiveStreams() {
    final generation = ++_activeStreamGeneration;
    final previousSubscriptions = List<StreamSubscription<dynamic>>.of(
      _activeSubscriptions,
    );
    _activeSubscriptions.clear();
    for (final subscription in previousSubscriptions) {
      unawaited(subscription.cancel());
    }

    final active = _activePlayer;
    _activeSubscriptions
      ..add(
        active.onPlayerStateChanged.listen(
          (state) => _forwardActiveEvent(generation, active, _states, state),
          onError: (Object error, StackTrace stackTrace) => _forwardActiveError(
            generation,
            active,
            _states,
            error,
            stackTrace,
          ),
        ),
      )
      ..add(
        active.onDurationChanged.listen(
          (duration) =>
              _forwardActiveEvent(generation, active, _durations, duration),
          onError: (Object error, StackTrace stackTrace) => _forwardActiveError(
            generation,
            active,
            _durations,
            error,
            stackTrace,
          ),
        ),
      )
      ..add(
        active.onPositionChanged.listen(
          (position) =>
              _forwardActiveEvent(generation, active, _positions, position),
          onError: (Object error, StackTrace stackTrace) => _forwardActiveError(
            generation,
            active,
            _positions,
            error,
            stackTrace,
          ),
        ),
      )
      ..add(
        active.onPlayerComplete.listen(
          (_) => _forwardActiveEvent(generation, active, _completions, null),
          onError: (Object error, StackTrace stackTrace) => _forwardActiveError(
            generation,
            active,
            _completions,
            error,
            stackTrace,
          ),
        ),
      );
  }

  void _forwardActiveEvent<T>(
    int generation,
    AudioPlayer player,
    StreamController<T> controller,
    T event,
  ) {
    if (_disposed ||
        controller.isClosed ||
        generation != _activeStreamGeneration ||
        !identical(player, _activePlayer)) {
      return;
    }
    controller.add(event);
  }

  void _forwardActiveError<T>(
    int generation,
    AudioPlayer player,
    StreamController<T> controller,
    Object error,
    StackTrace stackTrace,
  ) {
    if (_disposed ||
        controller.isClosed ||
        generation != _activeStreamGeneration ||
        !identical(player, _activePlayer)) {
      return;
    }
    controller.addError(error, stackTrace);
  }

  Future<void> _publishActivePositionAndDuration() async {
    final generation = _activeStreamGeneration;
    final active = _activePlayer;
    try {
      final values = await Future.wait<Duration?>([
        active.getCurrentPosition(),
        active.getDuration(),
      ]);
      if (_disposed ||
          generation != _activeStreamGeneration ||
          !identical(active, _activePlayer)) {
        return;
      }
      final position = values[0];
      final duration = values[1];
      if (position != null && !_positions.isClosed) _positions.add(position);
      if (duration != null && !_durations.isClosed) _durations.add(duration);
    } catch (_) {
      // Native backends normally publish both values after resume. Snapshot
      // lookup is only a best-effort bridge for backends that do not.
    }
  }
}
