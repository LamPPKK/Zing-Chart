import 'data/music_repository.dart';
import 'models/artist.dart';
import 'models/song.dart';

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

  static Future<String> getSongUrlByCode(String code) =>
      _client.getSongSource(code);

  static Future<(List<Song>, List<Artist>)> search(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return (<Song>[], <Artist>[]);
    final songs = await getZingChartSongs();
    return (
      songs
          .where(
            (song) =>
                song.displayTitle.toLowerCase().contains(normalized) ||
                song.artistsNames.toLowerCase().contains(normalized),
          )
          .toList(growable: false),
      <Artist>[],
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
