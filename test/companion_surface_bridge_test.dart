import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/services/companion_surface_bridge.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const song = Song(
    id: 'companion-song',
    name: 'companion-song',
    title: 'Đường Về',
    thumbnail: 'https://images.example.com/duong-ve.jpg',
    artistsNames: 'Ban Nhạc A',
    code: 'companion-code',
  );

  test('serializes a versioned native companion snapshot', () {
    final snapshot = CompanionPlayerSnapshot(
      song: song,
      status: CompanionPlaybackStatus.playing,
      position: const Duration(seconds: 12),
      duration: const Duration(minutes: 3),
      canGoPrevious: true,
      canGoNext: false,
      updatedAt: DateTime.utc(2026, 8, 15),
    );

    expect(snapshot.toMap(), {
      'schemaVersion': 1,
      'songId': 'companion-song',
      'title': 'Đường Về',
      'artist': 'Ban Nhạc A',
      'artworkUrl': 'https://images.example.com/duong-ve.jpg',
      'status': 'playing',
      'isPlaying': true,
      'positionMs': 12000,
      'durationMs': 180000,
      'canGoPrevious': true,
      'canGoNext': false,
      'updatedAtMs': DateTime.utc(2026, 8, 15).millisecondsSinceEpoch,
    });
  });

  test(
    'watch and widget commands control the shared playback service',
    () async {
      final audio = FakePlaybackAudioPlayer();
      final companion = _FakeCompanionSurfaceBridge();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (_) async => 'https://audio.example.com/song.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
        companionSurfaceBridge: companion,
      );
      await controller.initialize();
      await controller.playSong(song);
      audio.emitDuration(const Duration(minutes: 3));
      audio.emitPosition(const Duration(seconds: 30));
      await _flushAsync();

      expect(companion.snapshots.last.song, song);
      expect(companion.snapshots.last.status, CompanionPlaybackStatus.playing);

      await companion.callbacks!.seekRelative(const Duration(seconds: 10));
      expect(audio.seekTargets.last, const Duration(seconds: 40));
      await companion.callbacks!.pause();
      expect(audio.pauseCalls, 1);
      await companion.callbacks!.play();
      expect(audio.resumeCalls, 1);
      await companion.callbacks!.stop();
      expect(audio.stopCalls, greaterThanOrEqualTo(2));

      controller.dispose();
    },
  );

  test(
    'coalesces position updates into fifteen-second companion buckets',
    () async {
      final audio = FakePlaybackAudioPlayer();
      final companion = _FakeCompanionSurfaceBridge();
      final controller = PlaybackService(
        playbackAudioPlayer: audio,
        sourceResolver: (_) async => 'https://audio.example.com/song.mp3',
        libraryRepository: MemoryLibraryRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
        companionSurfaceBridge: companion,
      );
      await controller.initialize();
      await controller.playSong(song);
      await _flushAsync();

      // Previous becomes available after four seconds so it can restart the
      // current song. Let that intentional capability update publish before
      // measuring position-only coalescing within the same time bucket.
      audio.emitPosition(const Duration(seconds: 5));
      await _flushAsync();
      expect(companion.snapshots.last.canGoPrevious, isTrue);
      final before = companion.snapshots.length;

      audio.emitPosition(const Duration(seconds: 7));
      audio.emitPosition(const Duration(seconds: 14));
      await _flushAsync();
      expect(companion.snapshots.length, before);

      audio.emitPosition(const Duration(seconds: 15));
      await _flushAsync();
      expect(companion.snapshots.length, before + 1);

      controller.dispose();
    },
  );
}

class _FakeCompanionSurfaceBridge implements CompanionSurfaceBridge {
  CompanionCallbacks? callbacks;
  final snapshots = <CompanionPlayerSnapshot>[];

  @override
  Future<void> bind(CompanionCallbacks callbacks) async {
    this.callbacks = callbacks;
  }

  @override
  Future<void> publish(CompanionPlayerSnapshot snapshot) async {
    snapshots.add(snapshot);
  }

  @override
  Future<void> dispose() async {}
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
