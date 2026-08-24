import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/listening_analytics.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/music_player_scope.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const song = Song(
    id: 'scope-song',
    name: 'scope-song',
    title: 'Scope Song',
    thumbnail: '',
    artistsNames: 'Scope Artist',
    code: 'scope-code',
  );

  test(
    'catalog changes exclude playback ticks, volume and quality updates',
    () async {
      final audio = FakePlaybackAudioPlayer();
      final controller = _controller(audio);
      await controller.initialize();
      var playbackNotifications = 0;
      var catalogNotifications = 0;
      controller.addListener(() => playbackNotifications++);
      controller.catalogChanges.addListener(() => catalogNotifications++);

      audio.emitDuration(const Duration(minutes: 3));
      audio.emitPosition(const Duration(seconds: 12));
      await controller.setVolume(0.6);
      controller.setStreamingQualityPreference(StreamingQualityPreference.high);

      expect(playbackNotifications, 4);
      expect(catalogNotifications, 0);

      controller.toggleLike(song);
      controller.toggleMood(song, MoodTag.chill);
      controller.updateCatalog(const [song]);

      expect(catalogNotifications, 3);
      controller.dispose();
    },
  );

  testWidgets('non-dependent scope reads rebuild only for catalog changes', (
    tester,
  ) async {
    final audio = FakePlaybackAudioPlayer();
    final controller = _controller(audio);
    await controller.initialize();
    var inheritedBuilds = 0;
    var readBuilds = 0;
    var catalogBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MusicPlayerScope(
          controller: controller,
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  MusicPlayerScope.of(context);
                  inheritedBuilds++;
                  return const Text('Theo dõi toàn bộ player');
                },
              ),
              Builder(
                builder: (context) {
                  final player = MusicPlayerScope.read(context);
                  readBuilds++;
                  return AnimatedBuilder(
                    animation: player.catalogChanges,
                    builder: (context, _) {
                      catalogBuilds++;
                      return const Text('Chỉ theo dõi catalog');
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    expect((inheritedBuilds, readBuilds, catalogBuilds), (1, 1, 1));

    audio.emitPosition(const Duration(seconds: 18));
    await tester.pump();

    expect(inheritedBuilds, 2);
    expect(readBuilds, 1);
    expect(catalogBuilds, 1);

    controller.toggleLike(song);
    await tester.pump();

    expect(inheritedBuilds, 3);
    expect(readBuilds, 1);
    expect(catalogBuilds, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

PlaybackService _controller(FakePlaybackAudioPlayer audio) => PlaybackService(
  playbackAudioPlayer: audio,
  sourceResolver: (code) async => 'https://audio.example.com/$code.mp3',
  libraryRepository: MemoryLibraryRepository(),
  systemMediaBridge: NoopSystemMediaBridge(),
);
