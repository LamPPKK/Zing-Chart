import 'catalog_search.dart';
import 'weekly_chart.dart';

enum OfficialZingLinkKind {
  song,
  video,
  artist,
  collection,
  chart,
  newReleaseChart,
  weeklyChart,
  top100,
  releases,
  hub,
  liveRadio,
}

enum OfficialArtistSection { profile, songs, singles, videos }

/// A validated public page on Zing MP3 that can be opened inside #zingChart.
///
/// Parsing is intentionally fail-closed: the app never sends an arbitrary URL
/// to the proxy and only extracts bounded public identifiers from known paths.
class OfficialZingLink {
  const OfficialZingLink._({
    required this.kind,
    required this.uri,
    this.id = '',
    this.alias = '',
    this.collectionKind,
    this.weeklyRegion,
    this.artistSection = OfficialArtistSection.profile,
  });

  final OfficialZingLinkKind kind;
  final Uri uri;
  final String id;
  final String alias;
  final CatalogCollectionKind? collectionKind;
  final WeeklyChartRegion? weeklyRegion;
  final OfficialArtistSection artistSection;

  static OfficialZingLink? tryParse(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host.isEmpty ||
        uri.port != 443) {
      return null;
    }
    final host = uri.host.toLowerCase();
    if (host != 'zingmp3.vn' && !host.endsWith('.zingmp3.vn')) return null;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;

    if (segments.length == 1) {
      return switch (segments.single.toLowerCase()) {
        'zing-chart' => OfficialZingLink._(
          kind: OfficialZingLinkKind.chart,
          uri: uri,
        ),
        'moi-phat-hanh' => OfficialZingLink._(
          kind: OfficialZingLinkKind.newReleaseChart,
          uri: uri,
        ),
        'top100' => OfficialZingLink._(
          kind: OfficialZingLinkKind.top100,
          uri: uri,
        ),
        'radio' => OfficialZingLink._(
          kind: OfficialZingLinkKind.liveRadio,
          uri: uri,
        ),
        final alias when _isAlias(alias) && !_reservedRoots.contains(alias) =>
          OfficialZingLink._(
            kind: OfficialZingLinkKind.artist,
            uri: uri,
            alias: segments.single,
          ),
        _ => null,
      };
    }

    if (segments.length == 2 && segments.first == 'nghe-si') {
      final alias = segments.last;
      if (!_isAlias(alias)) return null;
      return OfficialZingLink._(
        kind: OfficialZingLinkKind.artist,
        uri: uri,
        alias: alias,
      );
    }

    if (segments.length == 2 && _isAlias(segments.first)) {
      final artistSection = switch (segments.last.toLowerCase()) {
        'bai-hat' => OfficialArtistSection.songs,
        'single' => OfficialArtistSection.singles,
        'video' => OfficialArtistSection.videos,
        _ => null,
      };
      if (artistSection != null && !_reservedRoots.contains(segments.first)) {
        return OfficialZingLink._(
          kind: OfficialZingLinkKind.artist,
          uri: uri,
          alias: segments.first,
          artistSection: artistSection,
        );
      }
    }

    if (segments.length == 2 && segments.first == 'new-release') {
      if (segments.last != 'song' && segments.last != 'album') return null;
      return OfficialZingLink._(kind: OfficialZingLinkKind.releases, uri: uri);
    }

    if (segments.length == 3 && segments[0] == 'link') {
      final id = segments[2];
      if (!_isId(id)) return null;
      if (segments[1] == 'song') {
        return OfficialZingLink._(
          kind: OfficialZingLinkKind.song,
          uri: uri,
          id: id,
        );
      }
      if (segments[1] == 'album') {
        return OfficialZingLink._(
          kind: OfficialZingLinkKind.collection,
          uri: uri,
          id: id,
          collectionKind: CatalogCollectionKind.album,
        );
      }
      return null;
    }

    if (segments.length == 3 && segments[0] == 'bai-hat') {
      final id = _htmlId(segments[2]);
      if (id == null || !_isSlug(segments[1])) return null;
      return OfficialZingLink._(
        kind: OfficialZingLinkKind.song,
        uri: uri,
        id: id,
      );
    }

    if (segments.length == 3 && segments[0] == 'video-clip') {
      final id = _htmlId(segments[2]);
      if (id == null || !_isSlug(segments[1])) return null;
      return OfficialZingLink._(
        kind: OfficialZingLinkKind.video,
        uri: uri,
        id: id,
      );
    }

    if (segments.length == 3 &&
        (segments[0] == 'album' || segments[0] == 'playlist')) {
      final id = _htmlId(segments[2]);
      if (id == null || !_isSlug(segments[1])) return null;
      return OfficialZingLink._(
        kind: OfficialZingLinkKind.collection,
        uri: uri,
        id: id,
        collectionKind: segments[0] == 'album'
            ? CatalogCollectionKind.album
            : CatalogCollectionKind.playlist,
      );
    }

    if (segments.length == 3 && segments[0] == 'hub') {
      final id = _htmlId(segments[2]);
      if (id == null || !_isSlug(segments[1])) return null;
      return OfficialZingLink._(
        kind: OfficialZingLinkKind.hub,
        uri: uri,
        id: id,
      );
    }

    if (segments.length == 3 && segments[0] == 'zing-chart-tuan') {
      final id = _htmlId(segments[2]);
      final region = id == null ? null : _weeklyChartIds[id];
      if (region == null || !_isSlug(segments[1])) return null;
      return OfficialZingLink._(
        kind: OfficialZingLinkKind.weeklyChart,
        uri: uri,
        id: id!,
        weeklyRegion: region,
      );
    }
    return null;
  }

  static bool looksLikeZingUrl(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null || !uri.hasScheme) return false;
    final host = uri.host.toLowerCase();
    return host == 'zingmp3.vn' || host.endsWith('.zingmp3.vn');
  }

  /// Whether [input] is an absolute URL-like value rather than a search term.
  ///
  /// URL input is always handled by the strict parser above. This prevents a
  /// pasted third-party or malformed URL from being forwarded to search APIs.
  static bool looksLikeAbsoluteUrl(String input) {
    final uri = Uri.tryParse(input.trim());
    return uri != null && uri.hasScheme;
  }
}

const _reservedRoots = <String>{
  'album',
  'bai-hat',
  'hub',
  'link',
  'moi-phat-hanh',
  'new-release',
  'nghe-si',
  'playlist',
  'radio',
  'single',
  'top100',
  'video',
  'video-clip',
  'zing-chart',
  'zing-chart-tuan',
};

const _weeklyChartIds = <String, WeeklyChartRegion>{
  'IWZ9Z08I': WeeklyChartRegion.vietnam,
  'IWZ9Z0BW': WeeklyChartRegion.usuk,
  'IWZ9Z0BO': WeeklyChartRegion.korea,
};

final _idPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
final _aliasPattern = RegExp(r'^[A-Za-z0-9._-]{1,128}$');
final _slugPattern = RegExp(r'^[A-Za-z0-9._-]{1,180}$');

bool _isId(String value) => _idPattern.hasMatch(value);
bool _isAlias(String value) => _aliasPattern.hasMatch(value);
bool _isSlug(String value) => _slugPattern.hasMatch(value);

String? _htmlId(String value) {
  if (!value.endsWith('.html')) return null;
  final id = value.substring(0, value.length - 5);
  return _isId(id) ? id : null;
}
