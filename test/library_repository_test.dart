import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/library_repository.dart';
import 'package:zmp3chart/models/local_library.dart';
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

  test('player snapshot round-trips every persisted field', () {
    final now = DateTime.utc(2026, 8, 14, 10);
    final snapshot = PlayerSnapshot(
      likedSongs: [song],
      queue: [song],
      currentSong: song,
      currentIndex: 0,
      position: Duration(milliseconds: 42500),
      shuffleEnabled: true,
      repeatModeIndex: 2,
      playlists: [
        LocalPlaylist(
          id: 'road-trip',
          name: 'Road trip',
          createdAt: now,
          updatedAt: now,
          songs: const [song],
        ),
      ],
      history: [
        ListeningRecord(
          id: 'listen-1',
          song: song,
          playedAt: now,
          listened: const Duration(minutes: 3),
        ),
      ],
      recentSearches: const ['Ca Sĩ A'],
      themePreferenceIndex: AppThemePreference.light.index,
    );

    final restored = PlayerSnapshot.fromJson(snapshot.toJson());

    expect(restored.likedSongs.single.id, song.id);
    expect(restored.queue.single.code, song.code);
    expect(restored.currentSong?.displayTitle, song.displayTitle);
    expect(restored.currentIndex, 0);
    expect(restored.position, const Duration(milliseconds: 42500));
    expect(restored.shuffleEnabled, isTrue);
    expect(restored.repeatModeIndex, 2);
    expect(restored.playlists.single.name, 'Road trip');
    expect(restored.playlists.single.songs.single.id, song.id);
    expect(restored.history.single.listened, const Duration(minutes: 3));
    expect(restored.recentSearches, ['Ca Sĩ A']);
    expect(restored.themePreferenceIndex, AppThemePreference.light.index);
  });

  test('library backup validates its schema and round-trips local data', () {
    final now = DateTime.utc(2026, 8, 14, 10);
    final backup = LibraryBackupData(
      likedSongs: const [song],
      playlists: [
        LocalPlaylist(
          id: 'focus',
          name: 'Tập trung',
          createdAt: now,
          updatedAt: now,
          songs: const [song],
        ),
      ],
      history: [ListeningRecord(id: 'record', song: song, playedAt: now)],
      recentSearches: const ['Một Bài Hát'],
      themePreferenceIndex: AppThemePreference.dark.index,
    );

    final restored = LibraryBackupData.decode(backup.encode());

    expect(restored.likedSongs.single.id, song.id);
    expect(restored.playlists.single.name, 'Tập trung');
    expect(restored.history.single.id, 'record');
    expect(restored.recentSearches.single, 'Một Bài Hát');
    expect(restored.themePreferenceIndex, AppThemePreference.dark.index);
    expect(
      () => LibraryBackupData.decode('{"version":1}'),
      throwsFormatException,
    );
    expect(
      () => LibraryBackupData.decode(
        '{"schema":"zingchart-library","version":1,'
        '"library":{"likedSongs":[{"id":1}]}}',
      ),
      throwsFormatException,
      reason:
          'Nested type errors must be reported as a recoverable format error.',
    );
  });

  test('player snapshot safely defaults malformed optional values', () {
    final restored = PlayerSnapshot.fromJson({
      'likedSongs': 'not-a-list',
      'queue': [
        <String, dynamic>{'id': ''},
        song.toJson(),
        'not-a-song',
      ],
      'currentSong': 'not-an-object',
      'currentIndex': null,
      'positionMs': null,
      'shuffleEnabled': 'yes',
      'repeatModeIndex': null,
    });

    expect(restored.likedSongs, isEmpty);
    expect(restored.queue.single.id, song.id);
    expect(restored.currentSong, isNull);
    expect(restored.currentIndex, -1);
    expect(restored.position, Duration.zero);
    expect(restored.shuffleEnabled, isFalse);
    expect(restored.repeatModeIndex, 0);
  });
}
