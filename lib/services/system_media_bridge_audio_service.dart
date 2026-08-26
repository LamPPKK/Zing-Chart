import 'package:audio_service/audio_service.dart';

import '../models/song.dart';
import 'system_media_bridge.dart';

class AudioServiceMediaBridge extends BaseAudioHandler
    with SeekHandler
    implements SystemMediaBridge {
  AudioServiceMediaBridge._();

  late SystemMediaCallbacks _callbacks;
  String? _publishedSongId;
  String? _publishedQueueSignature;

  static Future<SystemMediaBridge> create() async {
    final bridge = AudioServiceMediaBridge._();
    await AudioService.init<AudioServiceMediaBridge>(
      builder: () => bridge,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'software.baycho.zmp3chart.playback',
        androidNotificationChannelName: '#zingChart đang phát',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
      ),
    );
    return bridge;
  }

  @override
  Future<void> bind(SystemMediaCallbacks callbacks) async {
    _callbacks = callbacks;
  }

  @override
  Future<void> play() => _callbacks.play();

  @override
  Future<void> pause() => _callbacks.pause();

  @override
  Future<void> stop() => _callbacks.stop();

  @override
  Future<void> skipToNext() => _callbacks.next();

  @override
  Future<void> skipToPrevious() => _callbacks.previous();

  @override
  Future<void> seek(Duration position) => _callbacks.seek(position);

  @override
  Future<void> publish(SystemMediaSnapshot snapshot) async {
    final item = snapshot.song == null
        ? null
        : _mediaItem(snapshot.song!, duration: snapshot.duration);
    if (item?.id != _publishedSongId) {
      _publishedSongId = item?.id;
      mediaItem.add(item);
    }
    final queueSignature = snapshot.queue.map((song) => song.id).join('|');
    if (queueSignature != _publishedQueueSignature) {
      _publishedQueueSignature = queueSignature;
      queue.add(snapshot.queue.map(_mediaItem).toList(growable: false));
    }

    final controls = [
      if (snapshot.canGoPrevious) MediaControl.skipToPrevious,
      if (snapshot.status == SystemPlaybackStatus.playing)
        MediaControl.pause
      else
        MediaControl.play,
      if (snapshot.canGoNext) MediaControl.skipToNext,
      MediaControl.stop,
    ];

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: List<int>.generate(
          controls.length.clamp(0, 3),
          (index) => index,
        ),
        processingState: switch (snapshot.status) {
          SystemPlaybackStatus.loading => AudioProcessingState.loading,
          SystemPlaybackStatus.stopped => AudioProcessingState.idle,
          _ => AudioProcessingState.ready,
        },
        playing: snapshot.status == SystemPlaybackStatus.playing,
        updatePosition: snapshot.position,
        bufferedPosition: snapshot.duration,
        queueIndex: snapshot.queueIndex < 0 ? null : snapshot.queueIndex,
        shuffleMode: snapshot.shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: switch (snapshot.repeatMode) {
          SystemRepeatMode.none => AudioServiceRepeatMode.none,
          SystemRepeatMode.all => AudioServiceRepeatMode.all,
          SystemRepeatMode.one => AudioServiceRepeatMode.one,
        },
      ),
    );
  }

  MediaItem _mediaItem(Song song, {Duration? duration}) => MediaItem(
    id: song.id,
    title: song.displayTitle,
    artist: song.artistsNames,
    duration: duration,
    artUri: Uri.tryParse(song.thumbnail),
  );

  @override
  Future<void> dispose() async {
    await super.stop();
  }
}
