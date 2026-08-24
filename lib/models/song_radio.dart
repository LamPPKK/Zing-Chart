import 'catalog_search.dart';
import 'song.dart';

class SongRadio {
  const SongRadio({required this.seedId, required this.recommendations});

  const SongRadio.empty([this.seedId = '']) : recommendations = const [];

  final String seedId;
  final List<CatalogSong> recommendations;

  bool get isEmpty => recommendations.isEmpty;

  List<Song> get songs => List<Song>.unmodifiable(
    recommendations.map((recommendation) => recommendation.song),
  );
}
