import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/music_repository.dart';

void main() {
  test('maps the proxy chart and source contracts', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://proxy.example.com'))
      ..httpClientAdapter = _FixtureAdapter();
    final repository = ProxyMusicRepository(
      baseUrl: 'https://proxy.example.com',
      dio: dio,
    );

    final songs = await repository.getChartSongs();
    final source = await repository.getSongSource('code-one');

    expect(songs.single.id, 'one');
    expect(songs.single.displayTitle, 'Một Bài Hát');
    expect(source, 'https://audio.example.com/one.mp3');
  });
}

class _FixtureAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/v1/chart')) {
      return ResponseBody.fromString(
        '{"songs":[{"id":"one","title":"Một Bài Hát","albumCover":"https://image.example.com/one.jpg","artist":"Ca Sĩ A","code":"code-one","rank":1}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      '{"url":"https://audio.example.com/one.mp3"}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
