import '../models/song.dart';

export 'system_media_bridge_factory.dart' show createSystemMediaBridge;

enum SystemPlaybackStatus { stopped, paused, playing, loading }

enum SystemRepeatMode { none, all, one }

class SystemMediaCallbacks {
  const SystemMediaCallbacks({
    required this.play,
    required this.pause,
    required this.stop,
    required this.next,
    required this.previous,
    required this.seek,
    required this.setShuffle,
    required this.setRepeatMode,
  });

  final Future<void> Function() play;
  final Future<void> Function() pause;
  final Future<void> Function() stop;
  final Future<void> Function() next;
  final Future<void> Function() previous;
  final Future<void> Function(Duration position) seek;
  final void Function(bool enabled) setShuffle;
  final void Function(SystemRepeatMode mode) setRepeatMode;
}

class SystemMediaSnapshot {
  const SystemMediaSnapshot({
    required this.song,
    required this.queue,
    required this.queueIndex,
    required this.status,
    required this.position,
    required this.duration,
    required this.shuffleEnabled,
    required this.repeatMode,
  });

  final Song? song;
  final List<Song> queue;
  final int queueIndex;
  final SystemPlaybackStatus status;
  final Duration position;
  final Duration duration;
  final bool shuffleEnabled;
  final SystemRepeatMode repeatMode;
}

abstract interface class SystemMediaBridge {
  Future<void> bind(SystemMediaCallbacks callbacks);

  Future<void> publish(SystemMediaSnapshot snapshot);

  Future<void> dispose();
}

class NoopSystemMediaBridge implements SystemMediaBridge {
  @override
  Future<void> bind(SystemMediaCallbacks callbacks) async {}

  @override
  Future<void> publish(SystemMediaSnapshot snapshot) async {}

  @override
  Future<void> dispose() async {}
}
