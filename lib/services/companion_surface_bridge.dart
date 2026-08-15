import '../models/song.dart';

export 'companion_surface_bridge_factory.dart'
    show createCompanionSurfaceBridge;

enum CompanionPlaybackStatus { idle, loading, paused, playing }

enum CompanionCommand {
  play,
  pause,
  togglePlayPause,
  previous,
  next,
  stop,
  seekBackward,
  seekForward,
}

class CompanionPlayerSnapshot {
  const CompanionPlayerSnapshot({
    required this.song,
    required this.status,
    required this.position,
    required this.duration,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.updatedAt,
  });

  final Song? song;
  final CompanionPlaybackStatus status;
  final Duration position;
  final Duration duration;
  final bool canGoPrevious;
  final bool canGoNext;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'schemaVersion': 1,
    'songId': song?.id,
    'title': song?.displayTitle ?? '#zingChart',
    'artist': song?.artistsNames ?? 'Chưa chọn bài hát',
    'artworkUrl': song?.thumbnail ?? '',
    'status': status.name,
    'isPlaying': status == CompanionPlaybackStatus.playing,
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'canGoPrevious': canGoPrevious,
    'canGoNext': canGoNext,
    'updatedAtMs': updatedAt.millisecondsSinceEpoch,
  };

  /// Native surfaces extrapolate playback from [updatedAt], so publishing one
  /// position sample every 15 seconds is enough and avoids waking launchers and
  /// watches on every audioplayers position event.
  String get publishSignature => [
    song?.id ?? '',
    status.name,
    duration.inMilliseconds,
    position.inSeconds ~/ 15,
    canGoPrevious,
    canGoNext,
  ].join('|');
}

class CompanionCallbacks {
  const CompanionCallbacks({
    required this.play,
    required this.pause,
    required this.togglePlayPause,
    required this.previous,
    required this.next,
    required this.stop,
    required this.seekRelative,
  });

  final Future<void> Function() play;
  final Future<void> Function() pause;
  final Future<void> Function() togglePlayPause;
  final Future<void> Function() previous;
  final Future<void> Function() next;
  final Future<void> Function() stop;
  final Future<void> Function(Duration delta) seekRelative;
}

abstract interface class CompanionSurfaceBridge {
  Future<void> bind(CompanionCallbacks callbacks);

  Future<void> publish(CompanionPlayerSnapshot snapshot);

  Future<void> dispose();
}

class NoopCompanionSurfaceBridge implements CompanionSurfaceBridge {
  @override
  Future<void> bind(CompanionCallbacks callbacks) async {}

  @override
  Future<void> publish(CompanionPlayerSnapshot snapshot) async {}

  @override
  Future<void> dispose() async {}
}
