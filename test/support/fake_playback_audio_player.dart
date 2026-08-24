import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:zmp3chart/services/playback_audio_player.dart';

class FakePlaybackAudioPlayer implements PlaybackAudioPlayer {
  final _states = StreamController<PlayerState>.broadcast(sync: true);
  final _durations = StreamController<Duration>.broadcast(sync: true);
  final _positions = StreamController<Duration>.broadcast(sync: true);
  final _completions = StreamController<void>.broadcast(sync: true);

  final List<Source> playedSources = [];
  final List<Duration> seekTargets = [];
  final List<double> volumeValues = [];
  int pauseCalls = 0;
  int stopCalls = 0;
  int resumeCalls = 0;
  int disposeCalls = 0;
  AudioContext? audioContext;
  ReleaseMode? releaseMode;
  Object? playError;

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
    audioContext = context;
  }

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    this.releaseMode = releaseMode;
  }

  @override
  Future<void> setVolume(double volume) async {
    volumeValues.add(volume);
  }

  @override
  Future<void> play(Source source) async {
    if (playError case final error?) throw error;
    playedSources.add(source);
    _states.add(PlayerState.playing);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _states.add(PlayerState.paused);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _states.add(PlayerState.stopped);
    _positions.add(Duration.zero);
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    _states.add(PlayerState.playing);
  }

  @override
  Future<void> seek(Duration position) async {
    seekTargets.add(position);
    _positions.add(position);
  }

  void emitDuration(Duration duration) => _durations.add(duration);

  void emitPosition(Duration position) => _positions.add(position);

  void complete() => _completions.add(null);

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await Future.wait([
      _states.close(),
      _durations.close(),
      _positions.close(),
      _completions.close(),
    ]);
  }
}
