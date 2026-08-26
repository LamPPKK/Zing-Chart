import 'official_zing_link.dart';

enum AppShellDestination { discovery, hubs, library, forYou }

enum LibrarySection { overview, songs, playlists, albums, artists }

/// A bounded, serializable destination for the app shell.
///
/// Only public catalog identity is written to a URL. Loaded catalog payloads,
/// player state, favorites, history, and analytics remain in memory/on device.
class AppNavigationRoute {
  const AppNavigationRoute._({
    this.shellDestination,
    this.officialLink,
    this.librarySection = LibrarySection.overview,
    this.playlistId,
  }) : assert((shellDestination == null) != (officialLink == null));

  const AppNavigationRoute.discovery()
    : this._(shellDestination: AppShellDestination.discovery);

  const AppNavigationRoute.hubs()
    : this._(shellDestination: AppShellDestination.hubs);

  const AppNavigationRoute.forYou()
    : this._(shellDestination: AppShellDestination.forYou);

  const AppNavigationRoute.library({
    LibrarySection section = LibrarySection.overview,
    String? playlistId,
  }) : this._(
         shellDestination: AppShellDestination.library,
         librarySection: section,
         playlistId: playlistId,
       );

  AppNavigationRoute.official(OfficialZingLink link)
    : this._(officialLink: link);

  final AppShellDestination? shellDestination;
  final OfficialZingLink? officialLink;
  final LibrarySection librarySection;
  final String? playlistId;

  bool get isOfficial => officialLink != null;

  String get identity {
    final official = officialLink;
    if (official != null) return official.canonicalIdentity;
    return switch (shellDestination!) {
      AppShellDestination.discovery => 'shell:discovery',
      AppShellDestination.hubs => 'shell:hubs',
      AppShellDestination.forYou => 'shell:for-you',
      AppShellDestination.library =>
        'shell:library:${librarySection.name}:${playlistId ?? ''}',
    };
  }

  /// Logical browser route. Flutter's URL strategy adds any deployment base
  /// path, so this must never include the physical `<base href>` itself.
  Uri webLocation() {
    final official = officialLink;
    if (official != null) {
      return Uri(
        path: '/',
        queryParameters: {'open': official.canonicalUri.toString()},
      );
    }
    return switch (shellDestination!) {
      AppShellDestination.discovery => Uri(
        path: '/',
        queryParameters: const {'view': 'discovery'},
      ),
      AppShellDestination.hubs => Uri(
        path: '/',
        queryParameters: const {'view': 'hubs'},
      ),
      AppShellDestination.forYou => Uri(
        path: '/',
        queryParameters: const {'view': 'for-you'},
      ),
      AppShellDestination.library => Uri(
        path: '/',
        queryParameters: {
          'view': 'library',
          'section': librarySection.name,
          if (playlistId case final id?) 'playlist': id,
        },
      ),
    };
  }

  static AppNavigationRoute? fromOfficialUrl(String input) {
    final link = OfficialZingLink.tryParse(input);
    return link == null ? null : AppNavigationRoute.official(link);
  }

  /// Decodes either the documented Web envelope or a direct canonical Zing
  /// path delivered by a hosting/router layer.
  static AppNavigationRoute? tryParse(
    Uri uri, {
    String basePath = '/',
    Uri? appBaseUri,
  }) {
    if (uri.fragment.isNotEmpty || uri.userInfo.isNotEmpty) return null;

    final direct = OfficialZingLink.tryParse(uri.toString());
    if (direct != null) return AppNavigationRoute.official(direct);
    if (!_isAppRouteUri(uri, appBaseUri)) return null;

    final parameters = uri.queryParametersAll;
    if (parameters.containsKey('open')) {
      if (!_isRouteBasePath(uri.path, basePath)) return null;
      if (parameters.length != 1) return null;
      final values = parameters['open']!;
      if (values.length != 1) return null;
      return fromOfficialUrl(values.single);
    }

    if (parameters.containsKey('view')) {
      if (!_isRouteBasePath(uri.path, basePath)) return null;
      final viewValues = parameters['view']!;
      if (viewValues.length != 1) return null;
      final view = viewValues.single;
      if (view == 'discovery' || view == 'hubs' || view == 'for-you') {
        if (parameters.length != 1) return null;
        return switch (view) {
          'discovery' => const AppNavigationRoute.discovery(),
          'hubs' => const AppNavigationRoute.hubs(),
          _ => const AppNavigationRoute.forYou(),
        };
      }
      if (view != 'library' ||
          parameters.keys.any(
            (key) => key != 'view' && key != 'section' && key != 'playlist',
          )) {
        return null;
      }
      final sectionValues = parameters['section'];
      if (sectionValues != null && sectionValues.length != 1) return null;
      final section = _librarySection(sectionValues?.single ?? 'overview');
      if (section == null) return null;
      final playlistValues = parameters['playlist'];
      if (playlistValues != null && playlistValues.length != 1) return null;
      final playlistId = playlistValues?.single;
      if (playlistId != null &&
          (section != LibrarySection.playlists ||
              !_playlistIdPattern.hasMatch(playlistId))) {
        return null;
      }
      return AppNavigationRoute.library(
        section: section,
        playlistId: playlistId,
      );
    }

    // A path-strategy host may forward `/album/...` or `/tim-kiem/...`
    // directly. Rebuild only a known Zing route and validate it fail-closed.
    if (parameters.isNotEmpty || uri.path != basePath && uri.path != '/') {
      final candidate = Uri(
        scheme: 'https',
        host: 'zingmp3.vn',
        path: uri.path,
        query: uri.hasQuery ? uri.query : null,
      );
      final official = OfficialZingLink.tryParse(candidate.toString());
      if (official != null) return AppNavigationRoute.official(official);
    }

    if (parameters.isEmpty && _isRouteBasePath(uri.path, basePath)) {
      return const AppNavigationRoute.discovery();
    }
    return null;
  }
}

bool _isRouteBasePath(String path, String basePath) {
  String normalize(String value) {
    if (value.isEmpty || value == '/') return '/';
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  return normalize(path) == normalize(basePath);
}

bool _isAppRouteUri(Uri uri, Uri? appBaseUri) {
  if (!uri.hasScheme && !uri.hasAuthority) return true;
  if (appBaseUri == null || !appBaseUri.hasScheme || !appBaseUri.hasAuthority) {
    return false;
  }
  return uri.scheme.toLowerCase() == appBaseUri.scheme.toLowerCase() &&
      uri.host.toLowerCase() == appBaseUri.host.toLowerCase() &&
      uri.port == appBaseUri.port;
}

final _playlistIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

LibrarySection? _librarySection(String value) => switch (value) {
  'overview' => LibrarySection.overview,
  'songs' => LibrarySection.songs,
  'playlists' => LibrarySection.playlists,
  'albums' => LibrarySection.albums,
  'artists' => LibrarySection.artists,
  _ => null,
};
