import 'dart:async';

import 'package:smtc_windows/smtc_windows.dart';

import 'system_media_bridge.dart';

class WindowsSystemMediaBridge implements SystemMediaBridge {
  WindowsSystemMediaBridge._(this._smtc);

  final SMTCWindows _smtc;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  SystemMediaSnapshot? _lastSnapshot;
  String? _publishedSongId;

  static Future<SystemMediaBridge> create() async {
    await SMTCWindows.initialize();
    return WindowsSystemMediaBridge._(
      SMTCWindows(
        config: const SMTCConfig(
          playEnabled: true,
          pauseEnabled: true,
          nextEnabled: true,
          prevEnabled: true,
          stopEnabled: true,
          fastForwardEnabled: true,
          rewindEnabled: true,
        ),
      ),
    );
  }

  @override
  Future<void> bind(SystemMediaCallbacks callbacks) async {
    _subscriptions.add(
      _smtc.buttonPressStream.listen((button) {
        unawaited(switch (button) {
          PressedButton.play => callbacks.play(),
          PressedButton.pause => callbacks.pause(),
          PressedButton.stop => callbacks.stop(),
          PressedButton.next => callbacks.next(),
          PressedButton.previous => callbacks.previous(),
          PressedButton.fastForward => callbacks.seek(
            (_lastSnapshot?.position ?? Duration.zero) +
                const Duration(seconds: 10),
          ),
          PressedButton.rewind => callbacks.seek(
            (_lastSnapshot?.position ?? Duration.zero) -
                const Duration(seconds: 10),
          ),
          _ => Future<void>.value(),
        });
      }),
    );
    _subscriptions
      ..add(_smtc.shuffleChangeStream.listen(callbacks.setShuffle))
      ..add(
        _smtc.repeatModeChangeStream.listen((mode) {
          callbacks.setRepeatMode(switch (mode) {
            RepeatMode.none => SystemRepeatMode.none,
            RepeatMode.list => SystemRepeatMode.all,
            RepeatMode.track => SystemRepeatMode.one,
          });
        }),
      );
  }

  @override
  Future<void> publish(SystemMediaSnapshot snapshot) async {
    _lastSnapshot = snapshot;
    if (_smtc.isNextEnabled != snapshot.canGoNext) {
      await _smtc.setIsNextEnabled(snapshot.canGoNext);
    }
    if (_smtc.isPrevEnabled != snapshot.canGoPrevious) {
      await _smtc.setIsPrevEnabled(snapshot.canGoPrevious);
    }
    final song = snapshot.song;
    if (song == null) {
      await _smtc.clearMetadata();
      await _smtc.setPlaybackStatus(PlaybackStatus.stopped);
      return;
    }
    if (!_smtc.enabled) await _smtc.enableSmtc();
    if (_publishedSongId != song.id) {
      _publishedSongId = song.id;
      await _smtc.updateMetadata(
        MusicMetadata(
          title: song.displayTitle,
          artist: song.artistsNames,
          albumArtist: song.artistsNames,
          thumbnail: song.thumbnail,
        ),
      );
    }
    await _smtc.updateTimeline(
      PlaybackTimeline(
        startTimeMs: 0,
        endTimeMs: snapshot.duration.inMilliseconds,
        positionMs: snapshot.position.inMilliseconds,
        minSeekTimeMs: 0,
        maxSeekTimeMs: snapshot.duration.inMilliseconds,
      ),
    );
    await _smtc.setPlaybackStatus(switch (snapshot.status) {
      SystemPlaybackStatus.playing => PlaybackStatus.playing,
      SystemPlaybackStatus.paused => PlaybackStatus.paused,
      _ => PlaybackStatus.stopped,
    });
    await _smtc.setShuffleEnabled(snapshot.shuffleEnabled);
    await _smtc.setRepeatMode(switch (snapshot.repeatMode) {
      SystemRepeatMode.none => RepeatMode.none,
      SystemRepeatMode.all => RepeatMode.list,
      SystemRepeatMode.one => RepeatMode.track,
    });
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _smtc.dispose();
  }
}
