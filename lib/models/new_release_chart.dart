import 'catalog_search.dart';
import 'song.dart';

class NewReleaseEntry {
  const NewReleaseEntry({
    required this.catalogSong,
    required this.albumTitle,
    required this.rank,
    required this.rankChange,
    required this.releasedAt,
  });

  final CatalogSong catalogSong;
  final String albumTitle;
  final int rank;
  final int rankChange;
  final DateTime? releasedAt;

  Song get song => catalogSong.song;
  bool get playable => catalogSong.playable;
}

class NewReleaseChart {
  const NewReleaseChart({
    required this.title,
    required this.entries,
    required this.updatedAt,
    required this.catalogPlaybackEnabled,
  });

  const NewReleaseChart.empty()
    : this(
        title: 'BXH Nhạc Mới',
        entries: const [],
        updatedAt: null,
        catalogPlaybackEnabled: false,
      );

  final String title;
  final List<NewReleaseEntry> entries;
  final DateTime? updatedAt;
  final bool catalogPlaybackEnabled;

  List<Song> get songs =>
      entries.map((entry) => entry.song).toList(growable: false);
  List<Song> get playableSongs => entries
      .where((entry) => entry.playable)
      .map((entry) => entry.song)
      .toList(growable: false);
}
