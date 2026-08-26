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

  String? get wireValue => switch (this) {
    CatalogSearchSection.all => null,
    CatalogSearchSection.songs => 'songs',
    CatalogSearchSection.collections => 'collections',
    CatalogSearchSection.artists => 'artists',
    CatalogSearchSection.videos => 'videos',
  };
}

CatalogSearchSection? catalogSearchSectionFromWire(String value) =>
    switch (value.trim().toLowerCase()) {
      'songs' => CatalogSearchSection.songs,
      'collections' => CatalogSearchSection.collections,
      'artists' => CatalogSearchSection.artists,
      'videos' => CatalogSearchSection.videos,
      _ => null,
    };

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

  /// Artists credited by the collection endpoint followed by any additional
  /// track-level contributors, preserving the first official occurrence.
  ///
  /// Some Zing album payloads expose only the primary artists at collection
  /// level while individual tracks contain the complete participant list.
  /// Keeping this merge local avoids extra network requests and still lets
  /// collection detail mirror the public "Nghệ Sĩ Tham Gia" rail.
  List<CatalogArtist> get participatingArtists {
    final byId = <String, CatalogArtist>{};

    void include(CatalogArtist artist) {
      final id = artist.id.trim();
      if (id.isEmpty || artist.name.trim().isEmpty) return;
      byId.putIfAbsent(id, () => artist);
    }

    for (final artist in artists) {
      include(artist);
    }
    for (final catalogSong in songs) {
      for (final artist in catalogSong.artists) {
        include(artist);
      }
    }
    return List<CatalogArtist>.unmodifiable(byId.values);
  }
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

/// One authoritative page from an official, typed Zing MP3 search section.
///
/// Aggregate search remains represented by [CatalogSearchResult]. Typed pages
/// deliberately keep their concrete item type so an artist or video payload
/// can never be interpreted as a playable song list.
sealed class CatalogSearchPage {
  const CatalogSearchPage({
    required this.query,
    required this.section,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
    required this.catalogPlaybackEnabled,
  });

  final String query;
  final CatalogSearchSection section;
  final int page;
  final int limit;
  final int? total;
  final bool hasMore;
  final bool catalogPlaybackEnabled;

  int get itemCount;
  CatalogSearchResult get asSearchResult;
  CatalogSearchPage append(CatalogSearchPage next);
}

class CatalogSongSearchPage extends CatalogSearchPage {
  CatalogSongSearchPage({
    required super.query,
    required super.page,
    required super.limit,
    required super.total,
    required super.hasMore,
    required super.catalogPlaybackEnabled,
    required List<CatalogSong> items,
  }) : items = List<CatalogSong>.unmodifiable(items),
       super(section: CatalogSearchSection.songs);

  final List<CatalogSong> items;

  @override
  int get itemCount => items.length;

  @override
  CatalogSearchResult get asSearchResult => CatalogSearchResult(
    query: query,
    songs: items,
    artists: const [],
    catalogPlaybackEnabled: catalogPlaybackEnabled,
  );

  @override
  CatalogSongSearchPage append(CatalogSearchPage next) {
    _validateSearchPageAppend(this, next);
    if (next is! CatalogSongSearchPage) {
      throw ArgumentError('Cannot append a different search result type.');
    }
    final byId = <String, CatalogSong>{};
    for (final item in [...items, ...next.items]) {
      byId.putIfAbsent(item.song.id, () => item);
    }
    return CatalogSongSearchPage(
      query: query,
      page: next.page,
      limit: limit,
      total: next.total ?? total,
      hasMore: next.hasMore,
      catalogPlaybackEnabled:
          catalogPlaybackEnabled && next.catalogPlaybackEnabled,
      items: byId.values.toList(growable: false),
    );
  }
}

class CatalogArtistSearchPage extends CatalogSearchPage {
  CatalogArtistSearchPage({
    required super.query,
    required super.page,
    required super.limit,
    required super.total,
    required super.hasMore,
    required super.catalogPlaybackEnabled,
    required List<CatalogArtist> items,
  }) : items = List<CatalogArtist>.unmodifiable(items),
       super(section: CatalogSearchSection.artists);

  final List<CatalogArtist> items;

  @override
  int get itemCount => items.length;

  @override
  CatalogSearchResult get asSearchResult => CatalogSearchResult(
    query: query,
    songs: const [],
    artists: items,
    catalogPlaybackEnabled: catalogPlaybackEnabled,
  );

  @override
  CatalogArtistSearchPage append(CatalogSearchPage next) {
    _validateSearchPageAppend(this, next);
    if (next is! CatalogArtistSearchPage) {
      throw ArgumentError('Cannot append a different search result type.');
    }
    final byId = <String, CatalogArtist>{};
    for (final item in [...items, ...next.items]) {
      byId.putIfAbsent(item.id, () => item);
    }
    return CatalogArtistSearchPage(
      query: query,
      page: next.page,
      limit: limit,
      total: next.total ?? total,
      hasMore: next.hasMore,
      catalogPlaybackEnabled:
          catalogPlaybackEnabled && next.catalogPlaybackEnabled,
      items: byId.values.toList(growable: false),
    );
  }
}

class CatalogCollectionSearchPage extends CatalogSearchPage {
  CatalogCollectionSearchPage({
    required super.query,
    required super.page,
    required super.limit,
    required super.total,
    required super.hasMore,
    required super.catalogPlaybackEnabled,
    required List<CatalogCollection> items,
  }) : items = List<CatalogCollection>.unmodifiable(items),
       super(section: CatalogSearchSection.collections);

  final List<CatalogCollection> items;

  @override
  int get itemCount => items.length;

  @override
  CatalogSearchResult get asSearchResult => CatalogSearchResult(
    query: query,
    songs: const [],
    artists: const [],
    collections: items,
    catalogPlaybackEnabled: catalogPlaybackEnabled,
  );

  @override
  CatalogCollectionSearchPage append(CatalogSearchPage next) {
    _validateSearchPageAppend(this, next);
    if (next is! CatalogCollectionSearchPage) {
      throw ArgumentError('Cannot append a different search result type.');
    }
    final byId = <String, CatalogCollection>{};
    for (final item in [...items, ...next.items]) {
      byId.putIfAbsent(item.id, () => item);
    }
    return CatalogCollectionSearchPage(
      query: query,
      page: next.page,
      limit: limit,
      total: next.total ?? total,
      hasMore: next.hasMore,
      catalogPlaybackEnabled:
          catalogPlaybackEnabled && next.catalogPlaybackEnabled,
      items: byId.values.toList(growable: false),
    );
  }
}

class CatalogVideoSearchPage extends CatalogSearchPage {
  CatalogVideoSearchPage({
    required super.query,
    required super.page,
    required super.limit,
    required super.total,
    required super.hasMore,
    required super.catalogPlaybackEnabled,
    required List<CatalogVideo> items,
  }) : items = List<CatalogVideo>.unmodifiable(items),
       super(section: CatalogSearchSection.videos);

  final List<CatalogVideo> items;

  @override
  int get itemCount => items.length;

  @override
  CatalogSearchResult get asSearchResult => CatalogSearchResult(
    query: query,
    songs: const [],
    artists: const [],
    videos: items,
    catalogPlaybackEnabled: catalogPlaybackEnabled,
  );

  @override
  CatalogVideoSearchPage append(CatalogSearchPage next) {
    _validateSearchPageAppend(this, next);
    if (next is! CatalogVideoSearchPage) {
      throw ArgumentError('Cannot append a different search result type.');
    }
    final byId = <String, CatalogVideo>{};
    for (final item in [...items, ...next.items]) {
      byId.putIfAbsent(item.id, () => item);
    }
    return CatalogVideoSearchPage(
      query: query,
      page: next.page,
      limit: limit,
      total: next.total ?? total,
      hasMore: next.hasMore,
      catalogPlaybackEnabled:
          catalogPlaybackEnabled && next.catalogPlaybackEnabled,
      items: byId.values.toList(growable: false),
    );
  }
}

void _validateSearchPageAppend(
  CatalogSearchPage current,
  CatalogSearchPage next,
) {
  if (current.query != next.query ||
      current.section != next.section ||
      current.limit != next.limit ||
      next.page != current.page + 1) {
    throw ArgumentError('Search pages are not contiguous.');
  }
}
