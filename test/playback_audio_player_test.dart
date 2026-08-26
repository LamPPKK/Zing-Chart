import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/services/playback_audio_player.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AudioLogger.logLevel = AudioLogLevel.none;
  GlobalAudioplayersPlatformInterface.instance = _FakeGlobalAudioPlatform();

  late _FakeAudioPlatform platform;

  setUp(() {
    platform = _FakeAudioPlatform();
    AudioplayersPlatformInterface.instance = platform;
  });

  Future<AudioPlayer> createPlayer(String id) async {
    final player = AudioPlayer(playerId: id)..positionUpdater = null;
    await player.creatingCompleter.future;
    return player;
  }

  test(
    'prepares a silent standby and starts it before retiring the old deck',
    () async {
      final primary = await createPlayer('primary');
      final standby = await createPlayer('standby');
      final player = AudioplayersPlaybackAudioPlayer(primary, standby);
      addTearDown(player.dispose);
      final states = <PlayerState>[];
      final stateSubscription = player.onPlayerStateChanged.listen(states.add);
      addTearDown(stateSubscription.cancel);

      await player.setVolume(0.6);
      await player.play(UrlSource('https://audio.test/current.mp3'));
      platform.calls.clear();

      expect(
        await player.prepareNext(UrlSource('https://audio.test/next.mp3')),
        isTrue,
      );
      expect(player.supportsSeamlessPreload, isTrue);
      expect(
        platform.calls
            .where((call) => call.playerId == 'standby')
            .map((call) => (call.method, call.value)),
        containsAllInOrder([
          ('stop', null),
          ('setVolume', 0.0),
          ('setSourceUrl', 'https://audio.test/next.mp3'),
        ]),
      );
      expect(
        platform.calls.where(
          (call) => call.playerId == 'standby' && call.method == 'resume',
        ),
        isEmpty,
      );

      platform.calls.clear();
      expect(await player.promotePrepared(), isTrue);
      final resumeIndex = platform.calls.indexWhere(
        (call) => call.playerId == 'standby' && call.method == 'resume',
      );
      final oldStopIndex = platform.calls.indexWhere(
        (call) => call.playerId == 'primary' && call.method == 'stop',
      );
      expect(resumeIndex, greaterThanOrEqualTo(0));
      expect(oldStopIndex, greaterThan(resumeIndex));
      expect(states.last, PlayerState.playing);

      platform.calls.clear();
      await player.pause();
      final pauseCalls = platform.calls.where((call) => call.method == 'pause');
      expect(pauseCalls.single.playerId, 'standby');
    },
  );

  test('forwards events only from the active deck across promotion', () async {
    final primary = await createPlayer('primary');
    final standby = await createPlayer('standby');
    final player = AudioplayersPlaybackAudioPlayer(primary, standby);
    addTearDown(player.dispose);
    final durations = <Duration>[];
    var completions = 0;
    final durationSubscription = player.onDurationChanged.listen(durations.add);
    final completionSubscription = player.onPlayerComplete.listen(
      (_) => completions++,
    );
    addTearDown(durationSubscription.cancel);
    addTearDown(completionSubscription.cancel);

    platform.emitDuration('standby', const Duration(seconds: 90));
    platform.emitDuration('primary', const Duration(seconds: 120));
    await _flushEvents();
    expect(durations, [const Duration(seconds: 120)]);

    await player.prepareNext(UrlSource('https://audio.test/next.mp3'));
    await player.promotePrepared();
    await _flushEvents();
    durations.clear();

    platform.emitDuration('primary', const Duration(seconds: 121));
    platform.emitCompletion('primary');
    platform.emitDuration('standby', const Duration(seconds: 91));
    platform.emitCompletion('standby');
    await _flushEvents();

    expect(durations, [const Duration(seconds: 91)]);
    expect(completions, 1);
  });

  test('play, stop and cancel invalidate a prepared deck', () async {
    final primary = await createPlayer('primary');
    final standby = await createPlayer('standby');
    final player = AudioplayersPlaybackAudioPlayer(primary, standby);
    addTearDown(player.dispose);

    await player.prepareNext(UrlSource('https://audio.test/next.mp3'));
    await player.cancelPrepared();
    expect(await player.promotePrepared(), isFalse);

    await player.prepareNext(UrlSource('https://audio.test/next.mp3'));
    await player.play(UrlSource('https://audio.test/direct.mp3'));
    expect(await player.promotePrepared(), isFalse);

    await player.prepareNext(UrlSource('https://audio.test/next.mp3'));
    await player.stop();
    expect(await player.promotePrepared(), isFalse);
  });

  test(
    'standby failures fall back without replacing the active deck',
    () async {
      final primary = await createPlayer('primary');
      final standby = await createPlayer('standby');
      final player = AudioplayersPlaybackAudioPlayer(primary, standby);
      addTearDown(player.dispose);

      platform.failSourcePlayerId = 'standby';
      expect(
        await player.prepareNext(UrlSource('https://audio.test/broken.mp3')),
        isFalse,
      );
      platform.failSourcePlayerId = null;

      await player.play(UrlSource('https://audio.test/current.mp3'));
      await player.prepareNext(UrlSource('https://audio.test/next.mp3'));
      platform.failResumePlayerId = 'standby';
      expect(await player.promotePrepared(), isFalse);

      platform.calls.clear();
      await player.pause();
      expect(platform.calls.single.playerId, 'primary');
      expect(platform.calls.single.method, 'pause');
    },
  );

  test('fake defaults off and can model success and failures', () async {
    final disabled = FakePlaybackAudioPlayer();
    expect(disabled.supportsSeamlessPreload, isFalse);
    expect(
      await disabled.prepareNext(UrlSource('https://audio.test/next.mp3')),
      isFalse,
    );
    await disabled.dispose();

    final enabled = FakePlaybackAudioPlayer(supportsSeamlessPreload: true);
    final source = UrlSource('https://audio.test/next.mp3');
    expect(await enabled.prepareNext(source), isTrue);
    expect(enabled.preparedSource, same(source));
    expect(await enabled.promotePrepared(), isTrue);
    expect(enabled.playedSources, [source]);

    enabled.prepareNextSucceeds = false;
    expect(await enabled.prepareNext(source), isFalse);
    enabled.prepareNextSucceeds = true;
    enabled.promotePreparedSucceeds = false;
    expect(await enabled.prepareNext(source), isTrue);
    expect(await enabled.promotePrepared(), isFalse);
    await enabled.dispose();
  });
}

Future<void> _flushEvents() => Future<void>.delayed(Duration.zero);

class _PlatformCall {
  const _PlatformCall(this.playerId, this.method, [this.value]);

  final String playerId;
  final String method;
  final Object? value;
}

class _FakeAudioPlatform extends AudioplayersPlatformInterface {
  final List<_PlatformCall> calls = [];
  final Map<String, StreamController<AudioEvent>> _events = {};
  String? failSourcePlayerId;
  String? failResumePlayerId;

  @override
  Future<void> create(String playerId) async {
    calls.add(_PlatformCall(playerId, 'create'));
    _events[playerId] = StreamController<AudioEvent>.broadcast(sync: true);
  }

  @override
  Future<void> dispose(String playerId) async {
    calls.add(_PlatformCall(playerId, 'dispose'));
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> emitError(String playerId, String code, String message) async {}

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<int?> getCurrentPosition(String playerId) async {
    calls.add(_PlatformCall(playerId, 'getCurrentPosition'));
    return 0;
  }

  @override
  Future<int?> getDuration(String playerId) async {
    calls.add(_PlatformCall(playerId, 'getDuration'));
    return 0;
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      _events[playerId]!.stream;

  @override
  Future<void> pause(String playerId) async {
    calls.add(_PlatformCall(playerId, 'pause'));
  }

  @override
  Future<void> release(String playerId) async {
    calls.add(_PlatformCall(playerId, 'release'));
  }

  @override
  Future<void> resume(String playerId) async {
    calls.add(_PlatformCall(playerId, 'resume'));
    if (playerId == failResumePlayerId) {
      throw PlatformException(code: 'resume_failed');
    }
  }

  @override
  Future<void> seek(String playerId, Duration position) async {
    calls.add(_PlatformCall(playerId, 'seek', position));
    _events[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.seekComplete),
    );
  }

  @override
  Future<void> setAudioContext(
    String playerId,
    AudioContext audioContext,
  ) async {
    calls.add(_PlatformCall(playerId, 'setAudioContext', audioContext));
  }

  @override
  Future<void> setBalance(String playerId, double balance) async {
    calls.add(_PlatformCall(playerId, 'setBalance', balance));
  }

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {
    calls.add(_PlatformCall(playerId, 'setPlaybackRate', playbackRate));
  }

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {
    calls.add(_PlatformCall(playerId, 'setPlayerMode', playerMode));
  }

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {
    calls.add(_PlatformCall(playerId, 'setReleaseMode', releaseMode));
  }

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) async {
    calls.add(_PlatformCall(playerId, 'setSourceBytes', bytes));
    _emitPrepared(playerId);
  }

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    calls.add(_PlatformCall(playerId, 'setSourceUrl', url));
    if (playerId == failSourcePlayerId) {
      final error = PlatformException(code: 'source_failed');
      _events[playerId]?.addError(error);
      throw error;
    }
    _emitPrepared(playerId);
  }

  @override
  Future<void> setVolume(String playerId, double volume) async {
    calls.add(_PlatformCall(playerId, 'setVolume', volume));
  }

  @override
  Future<void> stop(String playerId) async {
    calls.add(_PlatformCall(playerId, 'stop'));
  }

  void emitDuration(String playerId, Duration duration) {
    _events[playerId]?.add(
      AudioEvent(eventType: AudioEventType.duration, duration: duration),
    );
  }

  void emitCompletion(String playerId) {
    _events[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.complete),
    );
  }

  void _emitPrepared(String playerId) {
    _events[playerId]?.add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }
}

class _FakeGlobalAudioPlatform extends GlobalAudioplayersPlatformInterface {
  final _events = StreamController<GlobalAudioEvent>.broadcast();

  @override
  Future<void> emitGlobalError(String code, String message) async {
    _events.addError(PlatformException(code: code, message: message));
  }

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => _events.stream;

  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}
}
