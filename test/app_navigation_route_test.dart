import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/app_navigation_route.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/official_zing_link.dart';
import 'package:zmp3chart/models/release_catalog.dart';

void main() {
  test('canonicalizes equivalent official routes without tracking data', () {
    final alias = OfficialZingLink.tryParse(
      'https://m.zingmp3.vn/Son-Tung-M-TP?utm_source=test#player',
    )!;
    final legacyArtist = OfficialZingLink.tryParse(
      'https://zingmp3.vn/nghe-si/Son-Tung-M-TP',
    )!;

    expect(alias.canonicalIdentity, legacyArtist.canonicalIdentity);
    expect(
      alias.canonicalUri,
      Uri.parse('https://zingmp3.vn/nghe-si/Son-Tung-M-TP'),
    );
    expect(
      OfficialZingLink.tryParse(alias.canonicalUri.toString())!.canonicalUri,
      alias.canonicalUri,
    );
  });

  test('canonical search keeps normalized Unicode query and typed section', () {
    final link = OfficialZingLink.tryParse(
      'https://m.zingmp3.vn/tim-kiem?'
      'q=%20S%C6%A1n%20%20T%C3%B9ng%20&utm_source=ignored',
    );

    // Search is intentionally strict: an extra tracking parameter is not a
    // canonical search contract and must fail closed.
    expect(link, isNull);

    final canonical = OfficialZingLink.tryParse(
      'https://m.zingmp3.vn/tim-kiem/bai-hat?'
      'q=%20S%C6%A1n%20%20T%C3%B9ng%20',
    )!;
    expect(canonical.searchSection, CatalogSearchSection.songs);
    expect(canonical.searchQuery, 'Sơn Tùng');
    expect(
      canonical.canonicalUri,
      Uri.parse(
        'https://zingmp3.vn/tim-kiem/bai-hat?'
        'q=S%C6%A1n+T%C3%B9ng',
      ),
    );
  });

  test('release routes preserve Songs and Albums as distinct identities', () {
    final songs = OfficialZingLink.tryParse(
      'https://zingmp3.vn/new-release/song?filter=all#catalog',
    )!;
    final albums = OfficialZingLink.tryParse(
      'https://zingmp3.vn/new-release/album?filter=all',
    )!;

    expect(songs.releaseContentType, ReleaseContentType.songs);
    expect(albums.releaseContentType, ReleaseContentType.albums);
    expect(songs.canonicalIdentity, isNot(albums.canonicalIdentity));
    expect(
      songs.canonicalUri,
      Uri.parse('https://zingmp3.vn/new-release/song?filter=all'),
    );
    expect(
      albums.canonicalUri,
      Uri.parse('https://zingmp3.vn/new-release/album?filter=all'),
    );
  });

  test('Web envelope round-trips official, shell and library routes', () {
    final base = Uri.parse('https://client.example/app/');
    final official = AppNavigationRoute.fromOfficialUrl(
      'https://zingmp3.vn/top100',
    )!;
    final officialLocation = official.webLocation();

    expect(officialLocation.path, '/');
    expect(
      officialLocation.queryParameters['open'],
      'https://zingmp3.vn/top100',
    );
    expect(
      AppNavigationRoute.tryParse(officialLocation)?.identity,
      official.identity,
    );

    const library = AppNavigationRoute.library(
      section: LibrarySection.playlists,
      playlistId: 'playlist-local_1',
    );
    final libraryLocation = library.webLocation();
    expect(libraryLocation.queryParameters, {
      'view': 'library',
      'section': 'playlists',
      'playlist': 'playlist-local_1',
    });
    expect(
      AppNavigationRoute.tryParse(libraryLocation)?.identity,
      library.identity,
    );

    const recent = AppNavigationRoute.library(section: LibrarySection.recent);
    expect(recent.webLocation().queryParameters, {
      'view': 'library',
      'section': 'recent',
    });
    expect(
      AppNavigationRoute.tryParse(recent.webLocation())?.identity,
      'shell:library:recent:',
    );

    const forYou = AppNavigationRoute.forYou();
    expect(forYou.identity, 'shell:for-you');
    expect(forYou.webLocation().queryParameters, {'view': 'for-you'});
    expect(
      AppNavigationRoute.tryParse(forYou.webLocation())?.shellDestination,
      AppShellDestination.forYou,
    );

    const discovery = AppNavigationRoute.discovery();
    final discoveryLocation = discovery.webLocation();
    expect(discoveryLocation.queryParameters, {'view': 'discovery'});
    expect(
      AppNavigationRoute.tryParse(discoveryLocation)?.shellDestination,
      AppShellDestination.discovery,
    );

    expect(
      AppNavigationRoute.tryParse(
        Uri.parse('https://client.example/app/?view=hubs'),
        basePath: '/app/',
        appBaseUri: base,
      )?.shellDestination,
      AppShellDestination.hubs,
    );
    expect(
      AppNavigationRoute.tryParse(
        Uri.parse('https://client.example/garbage?view=hubs'),
        basePath: '/app/',
        appBaseUri: base,
      ),
      isNull,
    );
  });

  test('For You mix routes round-trip with bounded canonical identities', () {
    const routes = [
      AppNavigationRoute.forYou(),
      AppNavigationRoute.forYou(mix: ForYouMix.daily),
      AppNavigationRoute.forYou(mix: ForYouMix.chill),
      AppNavigationRoute.forYou(mix: ForYouMix.gym),
      AppNavigationRoute.forYou(mix: ForYouMix.focus),
    ];

    for (final route in routes) {
      final location = route.webLocation();
      final parsed = AppNavigationRoute.tryParse(location);

      expect(location.path, '/', reason: route.identity);
      expect(location.queryParameters['view'], 'for-you');
      expect(location.queryParameters['mix'], route.forYouMix?.name);
      expect(parsed?.identity, route.identity);
      expect(parsed?.forYouMix, route.forYouMix);
    }

    expect(
      const AppNavigationRoute.forYou(
        mix: ForYouMix.daily,
      ).webLocation().toString(),
      '/?view=for-you&mix=daily',
    );
  });

  test(
    'accepts direct canonical app paths and rejects malformed envelopes',
    () {
      final direct = AppNavigationRoute.tryParse(
        Uri.parse('/tim-kiem/video?q=live%20session'),
      );
      expect(direct?.officialLink?.kind, OfficialZingLinkKind.search);
      expect(direct?.officialLink?.searchSection, CatalogSearchSection.videos);

      for (final uri in [
        '/?open=https%3A%2F%2Fzingmp3.vn%2Ftop100&open='
            'https%3A%2F%2Fzingmp3.vn%2Fradio',
        '/?open=https%3A%2F%2Fzingmp3.vn%2Ftop100&tracking=1',
        '/?view=library&section=unknown',
        '/?view=library&section=recent&playlist=playlist-1',
        '/?view=library&section=songs&playlist=private',
        '/?view=for-you&section=songs',
        '/?view=for-you&mix=unknown',
        '/?view=for-you&mix=',
        '/?view=for-you&mix=daily&mix=chill',
        '/?view=for-you&mix=daily&tracking=1',
        '/garbage?view=hubs',
        '/garbage?open=https%3A%2F%2Fzingmp3.vn%2Ftop100',
        '/unknown/path',
        'https://evil.example/?open='
            'https%3A%2F%2Fzingmp3.vn%2Ftop100',
        'https://evil.example/top100',
      ]) {
        expect(
          AppNavigationRoute.tryParse(Uri.parse(uri)),
          isNull,
          reason: uri,
        );
      }
    },
  );
}
