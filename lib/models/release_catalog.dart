import 'catalog_search.dart';
import 'song.dart';

enum ReleaseContentType { songs, albums }

extension ReleaseContentTypeLabel on ReleaseContentType {
  String get label => switch (this) {
    ReleaseContentType.songs => 'BÀI HÁT',
    ReleaseContentType.albums => 'ALBUM',
  };
}

enum ReleaseRegion { all, vietnam, usuk, korea, other }

extension ReleaseRegionLabel on ReleaseRegion {
  String get label => switch (this) {
    ReleaseRegion.all => 'TẤT CẢ',
    ReleaseRegion.vietnam => 'VIỆT NAM',
    ReleaseRegion.usuk => 'ÂU MỸ',
    ReleaseRegion.korea => 'HÀN QUỐC',
    ReleaseRegion.other => 'KHÁC',
  };

  String get wireValue => switch (this) {
    ReleaseRegion.all => 'all',
    ReleaseRegion.vietnam => 'vietnam',
    ReleaseRegion.usuk => 'usuk',
    ReleaseRegion.korea => 'korea',
    ReleaseRegion.other => 'other',
  };

  /// Public filter value used by Zing MP3's `/new-release/*` pages.
  String get zingFilterValue => switch (this) {
    ReleaseRegion.all => 'all',
    ReleaseRegion.vietnam => 'vpop',
    ReleaseRegion.usuk => 'usuk',
    ReleaseRegion.korea => 'kpop',
    ReleaseRegion.other => 'other',
  };
}

ReleaseRegion releaseRegionFromWire(String value) => switch (value) {
  'vietnam' => ReleaseRegion.vietnam,
  'usuk' => ReleaseRegion.usuk,
  'korea' => ReleaseRegion.korea,
  'other' => ReleaseRegion.other,
  _ => throw const FormatException('Invalid release region'),
};

ReleaseRegion releaseRegionFromZingFilter(String value) => switch (value) {
  'all' => ReleaseRegion.all,
  'vpop' => ReleaseRegion.vietnam,
  'usuk' => ReleaseRegion.usuk,
  'kpop' => ReleaseRegion.korea,
  'other' => ReleaseRegion.other,
  _ => throw const FormatException('Invalid Zing release filter'),
};

class ReleaseSong {
  const ReleaseSong({
    required this.catalogSong,
    required this.releasedAt,
    required this.region,
  });

  final CatalogSong catalogSong;
  final DateTime? releasedAt;
  final ReleaseRegion region;

  Song get song => catalogSong.song;
  bool get playable => catalogSong.playable;
}

class ReleaseAlbum {
  const ReleaseAlbum({
    required this.collection,
    required this.releasedAt,
    required this.region,
  });

  final CatalogCollection collection;
  final DateTime? releasedAt;
  final ReleaseRegion region;
}

class ReleaseCatalog {
  const ReleaseCatalog({
    required this.updatedAt,
    required this.songs,
    required this.albums,
    required this.catalogPlaybackEnabled,
  });

  const ReleaseCatalog.empty()
    : this(
        updatedAt: null,
        songs: const [],
        albums: const [],
        catalogPlaybackEnabled: false,
      );

  final DateTime? updatedAt;
  final List<ReleaseSong> songs;
  final List<ReleaseAlbum> albums;
  final bool catalogPlaybackEnabled;

  bool get isEmpty => songs.isEmpty && albums.isEmpty;

  List<ReleaseSong> songsFor(ReleaseRegion region) =>
      region == ReleaseRegion.all
      ? songs
      : songs.where((item) => item.region == region).toList(growable: false);

  List<ReleaseAlbum> albumsFor(ReleaseRegion region) =>
      region == ReleaseRegion.all
      ? albums
      : albums.where((item) => item.region == region).toList(growable: false);
}
