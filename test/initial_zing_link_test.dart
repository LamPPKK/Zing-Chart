import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
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
  });
}
