import 'catalog_search.dart';

class SongDetail {
  const SongDetail({
    required this.catalogSong,
    required this.artists,
    required this.album,
    required this.releasedAt,
    required this.distributor,
    required this.genres,
    required this.composers,
    required this.listenCount,
    required this.likeCount,
    required this.commentCount,
    required this.mv,
    required this.catalogPlaybackEnabled,
  });

  final CatalogSong catalogSong;
  final List<CatalogArtist> artists;
  final CatalogCollection? album;
  final DateTime? releasedAt;
  final String distributor;
  final List<String> genres;
  final List<CatalogArtist> composers;
  final int listenCount;
  final int likeCount;
  final int commentCount;
  final CatalogVideo? mv;
  final bool catalogPlaybackEnabled;
}
