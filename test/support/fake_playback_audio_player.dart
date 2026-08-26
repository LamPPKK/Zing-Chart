import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:zmp3chart/services/playback_audio_player.dart';

class FakePlaybackAudioPlayer implements PlaybackAudioPlayer {
  FakePlaybackAudioPlayer({
    this.supportsSeamlessPreload = false,
    this.prepareNextSucceeds = true,
    this.promotePreparedSucceeds = true,
  });

  final _states = StreamController<PlayerState>.broadcast(sync: true);
  final _durations = StreamController<Duration>.broadcast(sync: true);
  final _positions = StreamController<Duration>.broadcast(sync: true);
  final _completions = StreamController<void>.broadcast(sync: true);

  final List<Source> playedSources = [];
  final List<Source> preparedSources = [];
  final List<Duration> seekTargets = [];
  final List<double> volumeValues = [];
  final List<String> commandLog = [];
  int pauseCalls = 0;
  int stopCalls = 0;
  int resumeCalls = 0;
  int promotePreparedCalls = 0;
  int cancelPreparedCalls = 0;
  int disposeCalls = 0;
  @override
  final bool supportsSeamlessPreload;
  bool prepareNextSucceeds;
  bool promotePreparedSucceeds;
  AudioContext? audioContext;
  ReleaseMode? releaseMode;
  Object? playError;
  Source? _preparedSource;

  Source? get preparedSource => _preparedSource;

  @override
  Stream<PlayerState> get onPlayerStateChanged => _states.stream;

  @override
  Stream<Duration> get onDurationChanged => _durations.stream;

  @override
  Stream<Duration> get onPositionChanged => _positions.stream;

  @override
  Stream<void> get onPlayerComplete => _completions.stream;

  @override
  Future<void> setAudioContext(AudioContext context) async {
    commandLog.add('setAudioContext');
    audioContext = context;
  }

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    commandLog.add('setReleaseMode:${releaseMode.name}');
    this.releaseMode = releaseMode;
  }

  @override
  Future<void> setVolume(double volume) async {
    commandLog.add('setVolume:$volume');
    volumeValues.add(volume);
  }

  @override
  Future<void> play(Source source) async {
    _cancelPrepared(recordCall: true);
    commandLog.add('play');
    if (playError case final error?) throw error;
    playedSources.add(source);
    _states.add(PlayerState.playing);
  }

  @override
  Future<void> pause() async {
    commandLog.add('pause');
    pauseCalls++;
    _states.add(PlayerState.paused);
  }

  @override
  Future<void> stop() async {
    _cancelPrepared(recordCall: true);
    commandLog.add('stop');
    stopCalls++;
    _states.add(PlayerState.stopped);
    _positions.add(Duration.zero);
  }

  @override
  Future<void> resume() async {
    commandLog.add('resume');
    resumeCalls++;
    _states.add(PlayerState.playing);
  }

  @override
  Future<void> seek(Duration position) async {
    commandLog.add('seek:${position.inMilliseconds}');
    seekTargets.add(position);
    _positions.add(position);
  }

  @override
  Future<bool> prepareNext(Source source) async {
    commandLog.add('prepareNext');
    preparedSources.add(source);
    if (!supportsSeamlessPreload || !prepareNextSucceeds) {
      _preparedSource = null;
      return false;
    }
    _preparedSource = source;
    return true;
  }

  @override
  Future<bool> promotePrepared() async {
    commandLog.add('promotePrepared');
    promotePreparedCalls++;
    final source = _preparedSource;
    if (!supportsSeamlessPreload ||
        !promotePreparedSucceeds ||
        source == null) {
      return false;
    }
    _preparedSource = null;
    playedSources.add(source);
    _states.add(PlayerState.playing);
    return true;
  }

  @override
  Future<void> cancelPrepared() async {
    _cancelPrepared(recordCall: true);
  }

  void emitDuration(Duration duration) => _durations.add(duration);

  void emitPosition(Duration position) => _positions.add(position);

  void complete() => _completions.add(null);

  @override
  Future<void> dispose() async {
    _cancelPrepared(recordCall: true);
    commandLog.add('dispose');
    disposeCalls++;
    await Future.wait([
      _states.close(),
      _durations.close(),
      _positions.close(),
      _completions.close(),
    ]);
  }

  void _cancelPrepared({required bool recordCall}) {
    if (recordCall) {
      commandLog.add('cancelPrepared');
      cancelPreparedCalls++;
    }
    _preparedSource = null;
  }
}
