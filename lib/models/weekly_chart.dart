import 'catalog_search.dart';
import 'song.dart';

enum WeeklyChartRegion { vietnam, usuk, korea }

extension WeeklyChartRegionLabel on WeeklyChartRegion {
  String get label => switch (this) {
    WeeklyChartRegion.vietnam => 'VIỆT NAM',
    WeeklyChartRegion.usuk => 'US-UK',
    WeeklyChartRegion.korea => 'K-POP',
  };

  String get wireValue => switch (this) {
    WeeklyChartRegion.vietnam => 'vietnam',
    WeeklyChartRegion.usuk => 'usuk',
    WeeklyChartRegion.korea => 'korea',
  };
}

WeeklyChartRegion weeklyChartRegionFromWire(String value) => switch (value) {
  'vietnam' => WeeklyChartRegion.vietnam,
  'usuk' => WeeklyChartRegion.usuk,
  'korea' => WeeklyChartRegion.korea,
  _ => throw const FormatException('Invalid weekly chart region'),
};

class WeeklyChartEntry {
  const WeeklyChartEntry({
    required this.catalogSong,
    required this.albumTitle,
    required this.rank,
    required this.rankChange,
    required this.score,
  });

  final CatalogSong catalogSong;
  final String albumTitle;
  final int rank;
  final int rankChange;
  final int score;

  Song get song => catalogSong.song;
  bool get playable => catalogSong.playable;
}

class WeeklyChart {
  const WeeklyChart({
    required this.region,
    required this.title,
    required this.week,
    required this.year,
    required this.latestWeek,
    required this.startDate,
    required this.endDate,
    required this.updatedAt,
    required this.entries,
    required this.catalogPlaybackEnabled,
  });

  const WeeklyChart.empty([this.region = WeeklyChartRegion.vietnam])
    : title = 'Bảng Xếp Hạng Tuần',
      week = 0,
      year = 0,
      latestWeek = 0,
      startDate = '',
      endDate = '',
      updatedAt = null,
      entries = const [],
      catalogPlaybackEnabled = false;

  final WeeklyChartRegion region;
  final String title;
  final int week;
  final int year;
  final int latestWeek;
  final String startDate;
  final String endDate;
  final DateTime? updatedAt;
  final List<WeeklyChartEntry> entries;
  final bool catalogPlaybackEnabled;

  bool get isEmpty => entries.isEmpty;
  List<Song> get songs =>
      entries.map((entry) => entry.song).toList(growable: false);
  List<Song> get playableSongs => entries
      .where((entry) => entry.playable)
      .map((entry) => entry.song)
      .toList(growable: false);

  String get periodLabel {
    final range = startDate.isEmpty || endDate.isEmpty
        ? ''
        : ' ($startDate - $endDate)';
    return 'Tuần $week$range';
  }
}
