import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/data/listening_analytics_repository.dart';
import 'package:zmp3chart/models/listening_analytics.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/music_player_controller.dart';
import 'package:zmp3chart/services/system_media_bridge.dart';
import 'package:zmp3chart/theme/app_theme.dart';
import 'package:zmp3chart/widgets/for_you_hub.dart';

import 'support/fake_playback_audio_player.dart';

void main() {
  const songs = [
    Song(
      id: 'one',
      name: 'one',
      title: 'Đi giữa mùa hè',
      thumbnail: '',
      artistsNames: 'Ca sĩ A',
      code: 'one',
    ),
    Song(
      id: 'two',
      name: 'two',
      title: 'Một ngày rất xanh',
      thumbnail: '',
      artistsNames: 'Ca sĩ B',
      code: 'two',
    ),
    Song(
      id: 'three',
      name: 'three',
      title: 'Thành phố ngủ quên',
      thumbnail: '',
      artistsNames: 'Ca sĩ C',
      code: 'three',
    ),
  ];
  final cases = <String, Size>{
    '360': const Size(360, 900),
    '768': const Size(768, 1024),
    '1440': const Size(1440, 900),
    'tv_1920': const Size(1920, 1080),
  };

  for (final entry in cases.entries) {
    testWidgets('For You golden ${entry.key}', (tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = PlaybackService(
        playbackAudioPlayer: FakePlaybackAudioPlayer(),
        libraryRepository: MemoryLibraryRepository(),
        analyticsRepository: MemoryListeningAnalyticsRepository(),
        systemMediaBridge: NoopSystemMediaBridge(),
      );
      await controller.initialize();
      controller.updateCatalog(songs);
      controller.toggleLike(songs.first);
      controller.toggleMood(songs[1], MoodTag.chill);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildZingDarkTheme(tvMode: entry.key.startsWith('tv_')),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ForYouHub(
                controller: controller,
                now: DateTime(2026, 8, 15),
                onPlaySongs: (_) {},
                onOpenAnalytics: () {},
                onOpenWrapped: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/for_you_${entry.key}.png'),
      );
    });
  }
}
