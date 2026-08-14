import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/music_repository.dart';

void main() {
  group('ProxyMusicRepository', () {
    test('maps the proxy chart and source contracts', () async {
      final repository = _repository(_FixtureAdapter());

      final songs = await repository.getChartSongs();
      final source = await repository.getSongSource('code-one');

      expect(songs.single.id, 'one');
      expect(songs.single.displayTitle, 'Một Bài Hát');
      expect(source, 'https://audio.example.com/one.mp3');
    });

    test('rejects malformed chart and insecure source responses', () async {
      final malformedChart = _repository(
        _StaticAdapter(body: '{"unexpected":true}'),
      );
      final insecureSource = _repository(
        _StaticAdapter(body: '{"url":"http://audio.example.com/song.mp3"}'),
      );

      await expectLater(
        malformedChart.getChartSongs(),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('không hợp lệ'),
          ),
        ),
      );
      await expectLater(
        insecureSource.getSongSource('code'),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('Nguồn phát'),
          ),
        ),
      );
    });

    test('validates codes and maps sanitized proxy errors', () async {
      final repository = _repository(
        _StaticAdapter(
          body:
              '{"error":{"code":"UPSTREAM","message":"Dịch vụ nguồn đang bận."}}',
          statusCode: 503,
        ),
      );

      await expectLater(
        repository.getSongSource('  '),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('không có mã'),
          ),
        ),
      );
      await expectLater(
        repository.getChartSongs(),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            'Dịch vụ nguồn đang bận.',
          ),
        ),
      );
    });
  });
}

ProxyMusicRepository _repository(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://proxy.example.com'))
    ..httpClientAdapter = adapter;
  return ProxyMusicRepository(baseUrl: 'https://proxy.example.com', dio: dio);
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

class _StaticAdapter implements HttpClientAdapter {
  _StaticAdapter({required this.body, this.statusCode = 200});

  final String body;
  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
