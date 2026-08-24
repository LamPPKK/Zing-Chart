import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
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
