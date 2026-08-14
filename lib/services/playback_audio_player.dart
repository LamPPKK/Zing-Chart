import 'package:audioplayers/audioplayers.dart';

abstract interface class PlaybackAudioPlayer {
  Stream<PlayerState> get onPlayerStateChanged;

  Stream<Duration> get onDurationChanged;

  Stream<Duration> get onPositionChanged;

  Stream<void> get onPlayerComplete;

  Future<void> setAudioContext(AudioContext context);

  Future<void> setReleaseMode(ReleaseMode releaseMode);

  Future<void> play(Source source);

  Future<void> pause();

  Future<void> stop();

  Future<void> resume();

  Future<void> seek(Duration position);

  Future<void> dispose();
}

class AudioplayersPlaybackAudioPlayer implements PlaybackAudioPlayer {
  AudioplayersPlaybackAudioPlayer([AudioPlayer? player])
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<PlayerState> get onPlayerStateChanged => _player.onPlayerStateChanged;

  @override
  Stream<Duration> get onDurationChanged => _player.onDurationChanged;

  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  @override
  Stream<void> get onPlayerComplete => _player.onPlayerComplete;

  @override
  Future<void> setAudioContext(AudioContext context) =>
      _player.setAudioContext(context);

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) =>
      _player.setReleaseMode(releaseMode);

  @override
  Future<void> play(Source source) => _player.play(source);

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}
