import 'catalog_search.dart';

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
  final List<CatalogSong> featuredSongs;
  final List<CatalogVideo> videos;
  final List<CatalogArtistCollectionSection> collectionSections;
  final List<CatalogArtist> relatedArtists;
  final bool catalogPlaybackEnabled;

  int get playableSongCount => songs.where((song) => song.playable).length;
}
