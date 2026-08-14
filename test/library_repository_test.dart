import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/song.dart';

void main() {
  const song = Song(
    id: 'one',
    name: 'mot-bai-hat',
    title: 'Một Bài Hát',
    thumbnail: '',
    artistsNames: 'Ca Sĩ A',
    code: 'code-one',
  );

  test(
    'memory repository persists the complete local player snapshot',
    () async {
      final repository = MemoryLibraryRepository();
      const snapshot = PlayerSnapshot(
        likedSongs: [song],
        queue: [song],
        currentSong: song,
        currentIndex: 0,
        position: Duration(seconds: 42),
        shuffleEnabled: true,
        repeatModeIndex: 2,
      );

      await repository.save(snapshot);
      final restored = await repository.load();

      expect(restored.likedSongs.single.id, song.id);
      expect(restored.queue.single.id, song.id);
      expect(restored.currentSong?.id, song.id);
      expect(restored.position, const Duration(seconds: 42));
      expect(restored.shuffleEnabled, isTrue);
      expect(restored.repeatModeIndex, 2);
    },
  );
}
