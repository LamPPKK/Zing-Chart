import 'catalog_search.dart';
import 'song.dart';

CatalogSong _lockCatalogSong(CatalogSong item) => CatalogSong(
  song: Song(
    id: item.song.id,
    name: item.song.name,
    title: item.song.title,
    thumbnail: item.song.thumbnail,
    artistsNames: item.song.artistsNames,
    code: item.song.code,
    playable: false,
  ),
  duration: item.duration,
  externalUrl: item.externalUrl,
  playable: false,
  hasLyrics: item.hasLyrics,
  artists: item.artists,
  album: item.album,
);

class CatalogArtistCollectionSection {
  const CatalogArtistCollectionSection({
    required this.id,
    required this.title,
    required this.collections,
  });

  final String id;
  final String title;
  final List<CatalogCollection> collections;
}

class CatalogArtistSongPage {
  const CatalogArtistSongPage({
    required this.artistId,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
    required this.items,
    required this.catalogPlaybackEnabled,
  });

  final String artistId;
  final int page;
  final int limit;
  final int? total;
  final bool hasMore;
  final List<CatalogSong> items;
  final bool catalogPlaybackEnabled;

  CatalogArtistSongPage append(CatalogArtistSongPage next) {
    if (next.artistId != artistId ||
        next.page != page + 1 ||
        next.limit != limit) {
      throw ArgumentError('Cannot append an unrelated artist song page.');
    }
    final byId = <String, CatalogSong>{};
    for (final item in [...items, ...next.items]) {
      final existing = byId[item.song.id];
      if (existing == null) {
        byId[item.song.id] = item;
      } else if (!existing.playable ||
          !existing.song.playable ||
          !item.playable ||
          !item.song.playable) {
        byId[item.song.id] = _lockCatalogSong(existing);
      }
    }
    return CatalogArtistSongPage(
      artistId: artistId,
      page: next.page,
      limit: limit,
      total: next.total ?? total,
      hasMore: next.hasMore,
      items: byId.values.toList(growable: false),
      catalogPlaybackEnabled:
          catalogPlaybackEnabled && next.catalogPlaybackEnabled,
    );
  }
}

class CatalogArtistDetail {
  const CatalogArtistDetail({
    required this.artist,
    required this.cover,
    required this.biography,
    required this.realName,
    required this.national,
    required this.birthday,
    required this.totalFollow,
    required this.awardCount,
    required this.songs,
    this.songPage,
    this.featuredSongs = const [],
    this.videos = const [],
    required this.collectionSections,
    required this.relatedArtists,
    required this.catalogPlaybackEnabled,
  });

  final CatalogArtist artist;
  final String cover;
  final String biography;
  final String realName;
  final String national;
  final String birthday;
  final int totalFollow;
  final int awardCount;
  final List<CatalogSong> songs;
  final CatalogArtistSongPage? songPage;
  final List<CatalogSong> featuredSongs;
  final List<CatalogVideo> videos;
  final List<CatalogArtistCollectionSection> collectionSections;
  final List<CatalogArtist> relatedArtists;
  final bool catalogPlaybackEnabled;

  int get playableSongCount =>
      catalogPlaybackEnabled ? songs.where((song) => song.playable).length : 0;

  int get totalSongCount {
    final page = songPage;
    if (page != null && !page.hasMore) return songs.length;
    final total = page?.total;
    return total != null && total > songs.length ? total : songs.length;
  }

  CatalogArtistDetail withSongPage(CatalogArtistSongPage page) {
    if (page.artistId != artist.id) {
      throw ArgumentError('Cannot attach another artist song page.');
    }
    return CatalogArtistDetail(
      artist: artist,
      cover: cover,
      biography: biography,
      realName: realName,
      national: national,
      birthday: birthday,
      totalFollow: totalFollow,
      awardCount: awardCount,
      songs: page.items,
      songPage: page,
      featuredSongs: featuredSongs,
      videos: videos,
      collectionSections: collectionSections,
      relatedArtists: relatedArtists,
      catalogPlaybackEnabled:
          catalogPlaybackEnabled && page.catalogPlaybackEnabled,
    );
  }
}
