import 'data/music_repository.dart';
import 'models/artist.dart';
import 'models/catalog_search.dart';
import 'models/catalog_artist_detail.dart';
import 'models/catalog_hub.dart';
import 'models/chart_snapshot.dart';
import 'models/discovery_home.dart';
import 'models/live_radio.dart';
import 'models/new_release_chart.dart';
import 'models/release_catalog.dart';
import 'models/song.dart';
import 'models/song_detail.dart';
import 'models/song_lyrics.dart';
import 'models/song_radio.dart';
import 'models/search_suggestions.dart';
import 'models/weekly_chart.dart';

/// Compatibility facade retained for the existing screens. All network calls
/// are routed through the configured first-party proxy repository.
class ZingMP3API {
  static MusicRepository? _repository;

  static void configure(MusicRepository repository) {
    _repository = repository;
  }

  static MusicRepository get _client {
    final repository = _repository;
    if (repository == null) {
      throw const MusicRepositoryException(
        'MusicRepository chưa được cấu hình.',
      );
    }
    return repository;
  }

  static Future<List<Song>> getZingChartSongs() => _client.getChartSongs();

  static Future<ChartSnapshot> getZingChartSnapshot() =>
      _client.getChartSnapshot();

  static Future<NewReleaseChart> getNewReleaseChart() =>
      _client.getNewReleaseChart();

  static Future<WeeklyChart> getWeeklyChart(
    WeeklyChartRegion region, {
    int? week,
    int? year,
  }) => _client.getWeeklyChart(region, week: week, year: year);

  static Future<DiscoveryHome> getDiscoveryHome() => _client.getDiscoveryHome();

  static Future<DiscoveryCategories> getDiscoveryCategories() =>
      _client.getDiscoveryCategories();

  static Future<DiscoveryRecommendations> getDiscoveryRecommendations() =>
      _client.getDiscoveryRecommendations();

  static Future<DiscoveryHome> getDiscoveryCategoryHome(String categoryId) =>
      _client.getDiscoveryHome(categoryId: categoryId);

  static Future<CatalogHubHome> getHubHome() => _client.getHubHome();

  static Future<CatalogHubDetail> getHubDetail(String id) =>
      _client.getHubDetail(id);

  static Future<Top100Catalog> getTop100() => _client.getTop100();

  static Future<ReleaseCatalog> getReleaseCatalog() =>
      _client.getReleaseCatalog();

  static Future<CatalogArtistDetail> getArtistDetail(String alias) =>
      _client.getArtistDetail(alias);

  static Future<String> getSongUrlByCode(String code) =>
      _client.getSongSource(code);

  static Future<SongLyrics> getSongLyrics(String code) =>
      _client.getSongLyrics(code);

  static Future<SongDetail> getSongDetail(String songId) =>
      _client.getSongDetail(songId);

  static Future<SongRadio> getSongRadio(String code) =>
      _client.getSongRadio(code);

  static Future<LiveRadioSnapshot> getLiveRadio() => _client.getLiveRadio();

  static Future<String> getLiveRadioSource(String id) =>
      _client.getLiveRadioSource(id);

  static Future<CatalogSearchResult> searchCatalog(String query) =>
      _client.searchCatalog(query);

  static Future<SearchSuggestionSnapshot> getSearchSuggestions(String query) =>
      _client.getSearchSuggestions(query);

  static Future<CatalogCollectionDetail> getCollection(String id) =>
      _client.getCollection(id);

  static Future<(List<Song>, List<Artist>)> search(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return (<Song>[], <Artist>[]);
    final result = await searchCatalog(normalized);
    return (
      result.songs.map((item) => item.song).toList(growable: false),
      result.artists
          .map(
            (artist) => Artist(
              aliasName: artist.aliasName,
              thumb: artist.avatar,
              name: artist.name,
              block: 'false',
              id: artist.id,
            ),
          )
          .toList(growable: false),
    );
  }
}

typedef ZingApiException = MusicRepositoryException;

String normalizeSongSource(String source) {
  final normalized = source.trim();
  if (normalized.startsWith('//')) return 'https:$normalized';
  if (normalized.startsWith('http://')) {
    return normalized.replaceFirst('http://', 'https://');
  }
  if (normalized.startsWith('https://')) return normalized;
  return Uri.https('m.zingmp3.vn', normalized).toString();
}
