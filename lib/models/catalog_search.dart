import 'song.dart';

enum CatalogSearchSection { all, songs, collections, artists, videos }

extension CatalogSearchSectionLabel on CatalogSearchSection {
  String get label => switch (this) {
    CatalogSearchSection.all => 'TẤT CẢ',
    CatalogSearchSection.songs => 'BÀI HÁT',
    CatalogSearchSection.collections => 'PLAYLIST/ALBUM',
    CatalogSearchSection.artists => 'NGHỆ SĨ/OA',
    CatalogSearchSection.videos => 'MV',
  };
}

enum CatalogCollectionKind { playlist, album }

class CatalogArtist {
  const CatalogArtist({
    required this.id,
    required this.name,
    required this.aliasName,
    required this.avatar,
    this.externalUrl = '',
    this.totalFollow = 0,
  });

  final String id;
  final String name;
  final String aliasName;
  final String avatar;
  final String externalUrl;
  final int totalFollow;

  String get officialExternalUrl {
    if (externalUrl.isNotEmpty) return externalUrl;
    if (!RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(aliasName)) return '';
    return Uri.https('zingmp3.vn', '/nghe-si/$aliasName').toString();
  }
}

class CatalogSong {
  const CatalogSong({
    required this.song,
    required this.duration,
    required this.externalUrl,
    required this.playable,
    this.hasLyrics = false,
    this.artists = const [],
    this.album,
  });

  final Song song;
  final Duration duration;
  final String externalUrl;
  final bool playable;
  final bool hasLyrics;
  final List<CatalogArtist> artists;
  final CatalogCollection? album;
}

class CatalogVideo {
  const CatalogVideo({
    required this.id,
    required this.title,
    required this.artist,
    this.artists = const [],
    required this.thumbnail,
    required this.duration,
    required this.externalUrl,
  });

  final String id;
  final String title;
  final String artist;
  final List<CatalogArtist> artists;
  final String thumbnail;
  final Duration duration;
  final String externalUrl;

  CatalogArtist? get primaryArtist => artists.isEmpty ? null : artists.first;
}

class CatalogCollection {
  const CatalogCollection({
    required this.id,
    required this.title,
    required this.artist,
    this.artists = const [],
    required this.thumbnail,
    required this.kind,
    required this.externalUrl,
  });

  final String id;
  final String title;
  final String artist;
  final List<CatalogArtist> artists;
  final String thumbnail;
  final CatalogCollectionKind kind;
  final String externalUrl;

  String get kindLabel => switch (kind) {
    CatalogCollectionKind.playlist => 'PLAYLIST',
    CatalogCollectionKind.album => 'ALBUM',
  };
}

class CatalogCollectionDetail {
  const CatalogCollectionDetail({
    required this.collection,
    this.artists = const [],
    required this.description,
    required this.year,
    this.releasedAt,
    this.distributor = '',
    this.likeCount = 0,
    required this.genres,
    required this.songs,
    this.sections = const [],
    required this.catalogPlaybackEnabled,
  });

  final CatalogCollection collection;
  final List<CatalogArtist> artists;
  final String description;
  final String year;
  final DateTime? releasedAt;
  final String distributor;
  final int likeCount;
  final List<String> genres;
  final List<CatalogSong> songs;
  final List<CatalogCollectionSection> sections;
  final bool catalogPlaybackEnabled;

  Duration get totalDuration =>
      songs.fold(Duration.zero, (total, song) => total + song.duration);
}

class CatalogCollectionSection {
  const CatalogCollectionSection({
    required this.id,
    required this.title,
    required this.collections,
  });

  final String id;
  final String title;
  final List<CatalogCollection> collections;
}

class CatalogSearchResult {
  const CatalogSearchResult({
    required this.query,
    required this.songs,
    required this.artists,
    this.collections = const [],
    this.videos = const [],
    required this.catalogPlaybackEnabled,
  });

  const CatalogSearchResult.empty([String query = ''])
    : this(
        query: query,
        songs: const [],
        artists: const [],
        collections: const [],
        videos: const [],
        catalogPlaybackEnabled: false,
      );

  final String query;
  final List<CatalogSong> songs;
  final List<CatalogArtist> artists;
  final List<CatalogCollection> collections;
  final List<CatalogVideo> videos;
  final bool catalogPlaybackEnabled;

  bool get isEmpty =>
      songs.isEmpty && artists.isEmpty && collections.isEmpty && videos.isEmpty;
}
