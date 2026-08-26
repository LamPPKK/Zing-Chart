import 'catalog_search.dart';
import 'release_catalog.dart';
import 'weekly_chart.dart';

enum OfficialZingLinkKind {
  search,
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
    this.searchQuery = '',
    this.searchSection = CatalogSearchSection.all,
    this.releaseContentType,
  });

  final OfficialZingLinkKind kind;
  final Uri uri;
  final String id;
  final String alias;
  final CatalogCollectionKind? collectionKind;
  final WeeklyChartRegion? weeklyRegion;
  final OfficialArtistSection artistSection;
  final String searchQuery;
  final CatalogSearchSection searchSection;
  final ReleaseContentType? releaseContentType;

  /// Stable semantic identity. Presentation slugs, subdomains, tracking query
  /// parameters, and fragments never create a second app-history entry.
  String get canonicalIdentity => switch (kind) {
    OfficialZingLinkKind.search =>
      'search:${searchSection.name}:${searchQuery.toLowerCase()}',
    OfficialZingLinkKind.song => 'song:$id',
    OfficialZingLinkKind.video => 'video:$id',
    OfficialZingLinkKind.artist =>
      'artist:${alias.toLowerCase()}:${artistSection.name}',
    OfficialZingLinkKind.collection => 'collection:${collectionKind!.name}:$id',
    OfficialZingLinkKind.chart => 'catalog:chart',
    OfficialZingLinkKind.newReleaseChart => 'catalog:new-release-chart',
    OfficialZingLinkKind.weeklyChart => 'catalog:weekly:${weeklyRegion!.name}',
    OfficialZingLinkKind.top100 => 'catalog:top100',
    OfficialZingLinkKind.releases =>
      'catalog:releases:${releaseContentType!.name}',
    OfficialZingLinkKind.hub => 'hub:$id',
    OfficialZingLinkKind.liveRadio => 'catalog:radio',
  };

  /// Canonical public Zing URL used for sharing and the Web `open` envelope.
  /// It always uses the primary host and strips fragments/tracking parameters.
  Uri get canonicalUri => switch (kind) {
    OfficialZingLinkKind.search => Uri.https(
      'zingmp3.vn',
      switch (searchSection) {
        CatalogSearchSection.all => '/tim-kiem/tat-ca',
        CatalogSearchSection.songs => '/tim-kiem/bai-hat',
        CatalogSearchSection.collections => '/tim-kiem/playlist',
        CatalogSearchSection.artists => '/tim-kiem/artist',
        CatalogSearchSection.videos => '/tim-kiem/video',
      },
      {'q': searchQuery},
    ),
    OfficialZingLinkKind.song => _canonicalPrettyOrLink(
      uri,
      prettyRoot: 'bai-hat',
      fallbackPath: '/link/song/$id',
    ),
    OfficialZingLinkKind.video => _canonicalPrettyOrLink(
      uri,
      prettyRoot: 'video-clip',
      fallbackPath: '/video-clip/video/$id.html',
    ),
    OfficialZingLinkKind.artist => Uri.https(
      'zingmp3.vn',
      switch (artistSection) {
        OfficialArtistSection.profile => '/nghe-si/$alias',
        OfficialArtistSection.songs => '/$alias/bai-hat',
        OfficialArtistSection.singles => '/$alias/single',
        OfficialArtistSection.videos => '/$alias/video',
      },
    ),
    OfficialZingLinkKind.collection =>
      collectionKind == CatalogCollectionKind.album
          ? _canonicalPrettyOrLink(
              uri,
              prettyRoot: 'album',
              fallbackPath: '/link/album/$id',
            )
          : _canonicalPrettyOrLink(
              uri,
              prettyRoot: 'playlist',
              fallbackPath: '/playlist/playlist/$id.html',
            ),
    OfficialZingLinkKind.chart => Uri.https('zingmp3.vn', '/zing-chart'),
    OfficialZingLinkKind.newReleaseChart => Uri.https(
      'zingmp3.vn',
      '/moi-phat-hanh',
    ),
    OfficialZingLinkKind.weeklyChart => Uri.https(
      'zingmp3.vn',
      switch (weeklyRegion!) {
        WeeklyChartRegion.vietnam =>
          '/zing-chart-tuan/Bai-hat-Viet-Nam/IWZ9Z08I.html',
        WeeklyChartRegion.usuk =>
          '/zing-chart-tuan/Bai-hat-US-UK/IWZ9Z0BW.html',
        WeeklyChartRegion.korea =>
          '/zing-chart-tuan/Bai-hat-KPop/IWZ9Z0BO.html',
      },
    ),
    OfficialZingLinkKind.top100 => Uri.https('zingmp3.vn', '/top100'),
    OfficialZingLinkKind.releases => Uri.https(
      'zingmp3.vn',
      releaseContentType == ReleaseContentType.albums
          ? '/new-release/album'
          : '/new-release/song',
    ),
    OfficialZingLinkKind.hub => _canonicalPrettyOrLink(
      uri,
      prettyRoot: 'hub',
      fallbackPath: '/hub/hub/$id.html',
    ),
    OfficialZingLinkKind.liveRadio => Uri.https('zingmp3.vn', '/radio'),
  };

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

    if (segments.first == 'tim-kiem') {
      final section = switch (segments.length) {
        1 => CatalogSearchSection.all,
        2 => switch (segments.last) {
          'tat-ca' => CatalogSearchSection.all,
          'bai-hat' => CatalogSearchSection.songs,
          'playlist' => CatalogSearchSection.collections,
          'artist' => CatalogSearchSection.artists,
          'video' => CatalogSearchSection.videos,
          _ => null,
        },
        _ => null,
      };
      if (section == null) return null;
      final searchQuery = _searchQuery(uri);
      if (searchQuery == null) return null;
      return OfficialZingLink._(
        kind: OfficialZingLinkKind.search,
        uri: uri,
        searchQuery: searchQuery,
        searchSection: section,
      );
    }

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
        final alias when _isAlias(alias) && !_isReservedRoot(alias) =>
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
      if (artistSection != null && !_isReservedRoot(segments.first)) {
        return OfficialZingLink._(
          kind: OfficialZingLinkKind.artist,
          uri: uri,
          alias: segments.first,
          artistSection: artistSection,
        );
      }
    }

    if (segments.length == 2 && segments.first == 'new-release') {
      final releaseContentType = switch (segments.last) {
        'song' => ReleaseContentType.songs,
        'album' => ReleaseContentType.albums,
        _ => null,
      };
      if (releaseContentType == null) return null;
      return OfficialZingLink._(
        kind: OfficialZingLinkKind.releases,
        uri: uri,
        releaseContentType: releaseContentType,
      );
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
  'tim-kiem',
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
final _controlCharacterPattern = RegExp(r'[\u0000-\u001F\u007F-\u009F]');

bool _isId(String value) => _idPattern.hasMatch(value);
bool _isAlias(String value) => _aliasPattern.hasMatch(value);
bool _isSlug(String value) => _slugPattern.hasMatch(value);
bool _isReservedRoot(String value) =>
    _reservedRoots.contains(value.toLowerCase());

String? _searchQuery(Uri uri) {
  if (uri.queryParametersAll.length != 1) return null;
  final values = uri.queryParametersAll['q'];
  if (values == null || values.length != 1) return null;
  final rawQuery = values.single;
  if (_controlCharacterPattern.hasMatch(rawQuery)) return null;
  final normalizedQuery = rawQuery.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalizedQuery.isEmpty || normalizedQuery.length > 100) return null;
  return normalizedQuery;
}

String? _htmlId(String value) {
  if (!value.endsWith('.html')) return null;
  final id = value.substring(0, value.length - 5);
  return _isId(id) ? id : null;
}

Uri _canonicalPrettyOrLink(
  Uri original, {
  required String prettyRoot,
  required String fallbackPath,
}) {
  final segments = original.pathSegments;
  final path = segments.length == 3 && segments.first == prettyRoot
      ? '/${segments.join('/')}'
      : fallbackPath;
  return Uri.https('zingmp3.vn', path);
}
