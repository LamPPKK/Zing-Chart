import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:zmp3chart/models/app_navigation_route.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/official_zing_link.dart';
import 'package:zmp3chart/platform/initial_zing_link.dart';

void main() {
  test('extracts an official URL from the Web open query', () {
    expect(
      extractOfficialZingUrl(
        baseUri: Uri.parse(
          'https://client.example/open?open='
          'https%3A%2F%2Fzingmp3.vn%2Flink%2Falbum%2FALBUM1',
        ),
        defaultRouteName: '/',
      ),
      'https://zingmp3.vn/link/album/ALBUM1',
    );
  });

  test('extracts a dynamic Web open query from route information', () {
    expect(
      officialZingUrlFromRouteInformation(
        RouteInformation(
          uri: Uri.parse('/?open=https%3A%2F%2Fzingmp3.vn%2Ftop100'),
        ),
      ),
      'https://zingmp3.vn/top100',
    );
  });

  test('decodes canonical app envelopes and direct official paths', () {
    final library = appNavigationRouteFromRouteInformation(
      RouteInformation(
        uri: Uri.parse(
          '/app/?view=library&section=playlists&playlist=playlist-1',
        ),
      ),
      basePath: '/app/',
    );
    expect(library?.shellDestination, AppShellDestination.library);
    expect(library?.librarySection, LibrarySection.playlists);
    expect(library?.playlistId, 'playlist-1');

    final recent = appNavigationRouteFromRouteInformation(
      RouteInformation(uri: Uri.parse('/app/?view=library&section=recent')),
      basePath: '/app/',
    );
    expect(recent?.shellDestination, AppShellDestination.library);
    expect(recent?.librarySection, LibrarySection.recent);
    expect(recent?.playlistId, isNull);

    final direct = appNavigationRouteFromRouteInformation(
      RouteInformation(uri: Uri.parse('/new-release/album')),
    );
    expect(direct?.officialLink?.kind, OfficialZingLinkKind.releases);
    expect(direct?.officialLink?.canonicalUri.path, '/new-release/album');
  });

  test('decodes a direct canonical path from the logical Web route', () {
    final route = extractInitialAppNavigationRoute(
      baseUri: Uri.parse('https://client.example/new-release/album'),
      defaultRouteName: '/new-release/album',
    );

    expect(route?.officialLink?.kind, OfficialZingLinkKind.releases);
    expect(route?.officialLink?.canonicalUri.path, '/new-release/album');
  });

  test('decodes and canonicalizes a direct artist albums Web route', () {
    final route = extractInitialAppNavigationRoute(
      baseUri: Uri.parse(
        'https://client.example/Son-Tung-M-TP/album?utm_source=share',
      ),
      defaultRouteName: '/Son-Tung-M-TP/album?utm_source=share',
    );

    expect(route?.officialLink?.kind, OfficialZingLinkKind.artist);
    expect(route?.officialLink?.alias, 'Son-Tung-M-TP');
    expect(route?.officialLink?.artistSection, OfficialArtistSection.albums);
    expect(
      route?.officialLink?.canonicalUri,
      Uri.parse('https://zingmp3.vn/Son-Tung-M-TP/album'),
    );
  });

  test('preserves an explicit Discovery route across a browser reload', () {
    final route = extractInitialAppNavigationRoute(
      baseUri: Uri.parse('https://client.example/?view=discovery'),
      defaultRouteName: '/?view=discovery',
    );

    expect(route?.shellDestination, AppShellDestination.discovery);
  });

  test('does not mistake a clean custom deployment base for an artist', () {
    expect(
      extractInitialAppNavigationRoute(
        baseUri: Uri.parse('https://client.example/app/'),
        defaultRouteName: '/',
      ),
      isNull,
    );
  });

  test('preserves official search links through Web open routes', () {
    const officialUrl =
        'https://zingmp3.vn/tim-kiem/bai-hat?q=S%C6%A1n%20T%C3%B9ng';
    final extracted = extractOfficialZingUrl(
      baseUri: Uri.https('client.example', '/open', {'open': officialUrl}),
      defaultRouteName: '/',
    );

    expect(extracted, officialUrl);
    final link = OfficialZingLink.tryParse(extracted!);
    expect(link?.kind, OfficialZingLinkKind.search);
    expect(link?.searchQuery, 'Sơn Tùng');
    expect(link?.searchSection, CatalogSearchSection.songs);
  });

  test('preserves official search links through custom-scheme routes', () {
    const officialUrl = 'https://zingmp3.vn/tim-kiem/video?q=live%20session';
    final route = Uri(
      scheme: 'zingchart',
      host: 'open',
      queryParameters: {'url': officialUrl},
    ).toString();
    final extracted = officialZingUrlFromRouteName(route);

    expect(extracted, officialUrl);
    final link = OfficialZingLink.tryParse(extracted!);
    expect(link?.kind, OfficialZingLinkKind.search);
    expect(link?.searchQuery, 'live session');
    expect(link?.searchSection, CatalogSearchSection.videos);
  });

  test('extracts direct Android and custom-scheme launch routes', () {
    expect(
      extractOfficialZingUrl(
        baseUri: Uri.parse('https://client.example/'),
        defaultRouteName: 'https://zingmp3.vn/bai-hat/Test/SONG1.html',
      ),
      'https://zingmp3.vn/bai-hat/Test/SONG1.html',
    );
    expect(
      extractOfficialZingUrl(
        baseUri: Uri.parse('https://client.example/'),
        defaultRouteName:
            'zingchart://open?url=https%3A%2F%2Fzingmp3.vn%2FTaylor-Swift',
      ),
      'https://zingmp3.vn/Taylor-Swift',
    );
    expect(
      extractOfficialZingUrl(
        baseUri: Uri.parse('https://client.example/'),
        defaultRouteName: '/',
        arguments: const [
          'zingchart://open?url=https%3A%2F%2Fzingmp3.vn%2Ftop100',
        ],
      ),
      'https://zingmp3.vn/top100',
    );
  });

  test('fails closed for malicious or unsupported launch routes', () {
    expect(
      extractOfficialZingUrl(
        baseUri: Uri.parse(
          'https://client.example/open?open='
          'https%3A%2F%2Fevil.example%2Flink%2Falbum%2FALBUM1',
        ),
        defaultRouteName: '/',
      ),
      isNull,
    );
    expect(
      extractOfficialZingUrl(
        baseUri: Uri.parse('https://client.example/'),
        defaultRouteName:
            'zingchart://open?url=https%3A%2F%2Fzingmp3.vn%2Funknown%2Fpath',
      ),
      isNull,
    );
    expect(
      appNavigationRouteFromRouteName(
        'zingchart://open?url=https%3A%2F%2Fzingmp3.vn%2Ftop100&'
        'url=https%3A%2F%2Fzingmp3.vn%2Fradio',
      ),
      isNull,
    );
    expect(
      appNavigationRouteFromRouteName(
        'https://evil.example/?open='
        'https%3A%2F%2Fzingmp3.vn%2Ftop100',
      ),
      isNull,
    );
    expect(
      appNavigationRouteFromRouteName(
        'zingchart://open?url='
        'https%3A%2F%2Fzingmp3.vn%2Ftop100%23player#outer',
      ),
      isNull,
    );
  });
}
