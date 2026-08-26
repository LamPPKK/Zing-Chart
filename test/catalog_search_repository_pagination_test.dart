import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/music_repository.dart';
import 'package:zmp3chart/models/catalog_search.dart';

void main() {
  group('ProxyMusicRepository typed search', () {
    test('sends exact paging parameters and decodes every item type', () async {
      final adapter = _TypedSearchAdapter();
      final repository = _repository(adapter);

      final pages = <CatalogSearchPage>[];
      for (final section in const [
        CatalogSearchSection.songs,
        CatalogSearchSection.artists,
        CatalogSearchSection.collections,
        CatalogSearchSection.videos,
      ]) {
        pages.add(
          await repository.searchCatalogPage(
            '  Nàng    thơ  ',
            section,
            page: 2,
            limit: 7,
          ),
        );
      }

      expect(adapter.requests, hasLength(4));
      for (var index = 0; index < adapter.requests.length; index++) {
        final request = adapter.requests[index];
        expect(request.path, endsWith('/v1/search'));
        expect(request.queryParameters, {
          'q': 'Nàng thơ',
          'type': const ['songs', 'artists', 'collections', 'videos'][index],
          'page': 2,
          'limit': 7,
        });
      }

      expect(pages[0], isA<CatalogSongSearchPage>());
      expect(
        (pages[0] as CatalogSongSearchPage).items.single.song.id,
        'song-one',
      );
      expect(pages[1], isA<CatalogArtistSearchPage>());
      expect(
        (pages[1] as CatalogArtistSearchPage).items.single.id,
        'artist-one',
      );
      expect(pages[2], isA<CatalogCollectionSearchPage>());
      expect(
        (pages[2] as CatalogCollectionSearchPage).items.single.id,
        'collection-one',
      );
      expect(pages[3], isA<CatalogVideoSearchPage>());
      expect((pages[3] as CatalogVideoSearchPage).items.single.id, 'video-one');
      expect(pages.every((page) => page.page == 2 && page.limit == 7), isTrue);
      expect(pages.every((page) => page.total == 20 && page.hasMore), isTrue);
    });

    test('rejects a payload whose echoed request does not match', () async {
      final repository = _repository(
        _TypedSearchAdapter(responseOverrides: const {'page': 3}),
      );

      await expectLater(
        repository.searchCatalogPage(
          'mix',
          CatalogSearchSection.songs,
          page: 2,
          limit: 7,
        ),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            'Phản hồi trang tìm kiếm không hợp lệ.',
          ),
        ),
      );
    });

    test('preserves the structured unavailable error code from the proxy', () {
      final repository = _repository(
        _TypedSearchAdapter(
          statusCode: 501,
          fixedBody: const {
            'error': {
              'code': 'SEARCH_PAGINATION_UNAVAILABLE',
              'message': 'Typed search needs official credentials.',
            },
          },
        ),
      );

      expect(
        repository.searchCatalogPage('mix', CatalogSearchSection.songs),
        throwsA(
          isA<MusicRepositoryException>()
              .having(
                (error) => error.code,
                'code',
                'SEARCH_PAGINATION_UNAVAILABLE',
              )
              .having(
                (error) => error.message,
                'message',
                'Typed search needs official credentials.',
              ),
        ),
      );
    });

    test('rejects aggregate paging and out-of-range page arguments', () async {
      final adapter = _TypedSearchAdapter();
      final repository = _repository(adapter);

      await expectLater(
        repository.searchCatalogPage('mix', CatalogSearchSection.all),
        throwsA(isA<MusicRepositoryException>()),
      );
      await expectLater(
        repository.searchCatalogPage(
          'mix',
          CatalogSearchSection.songs,
          page: 0,
        ),
        throwsA(isA<MusicRepositoryException>()),
      );
      await expectLater(
        repository.searchCatalogPage(
          'mix',
          CatalogSearchSection.songs,
          limit: 51,
        ),
        throwsA(isA<MusicRepositoryException>()),
      );
      expect(adapter.requests, isEmpty);
    });
  });
}

ProxyMusicRepository _repository(HttpClientAdapter adapter) {
  const baseUrl = 'https://proxy.example.com';
  final dio = Dio(BaseOptions(baseUrl: baseUrl))..httpClientAdapter = adapter;
  return ProxyMusicRepository(baseUrl: baseUrl, dio: dio);
}

class _TypedSearchAdapter implements HttpClientAdapter {
  _TypedSearchAdapter({
    this.statusCode = 200,
    this.fixedBody,
    this.responseOverrides = const {},
  });

  final int statusCode;
  final Map<String, dynamic>? fixedBody;
  final Map<String, dynamic> responseOverrides;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final type = options.queryParameters['type']?.toString() ?? '';
    final body =
        fixedBody ??
        <String, dynamic>{
          'query': options.queryParameters['q'],
          'type': type,
          'page': options.queryParameters['page'],
          'limit': options.queryParameters['limit'],
          'total': 20,
          'hasMore': true,
          'catalogPlaybackEnabled': type == 'songs',
          'items': [_itemFor(type)],
          ...responseOverrides,
        };
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Map<String, dynamic> _itemFor(String type) => switch (type) {
    'songs' => {
      'id': 'song-one',
      'code': 'source-one',
      'title': 'Nàng Thơ',
      'artist': 'Hoàng Dũng',
      'albumCover': 'https://image.example.com/song.jpg',
      'durationSeconds': 254,
      'externalUrl': 'https://zingmp3.vn/bai-hat/nang-tho/song-one.html',
      'playable': true,
      'hasLyrics': true,
    },
    'artists' => {
      'id': 'artist-one',
      'name': 'Hoàng Dũng',
      'aliasName': 'Hoang-Dung',
      'avatar': 'https://image.example.com/artist.jpg',
      'externalUrl': 'https://zingmp3.vn/nghe-si/Hoang-Dung',
      'totalFollow': 2600000,
    },
    'collections' => {
      'id': 'collection-one',
      'title': 'Tuyển tập Nàng Thơ',
      'artist': 'Hoàng Dũng',
      'thumbnail': 'https://image.example.com/collection.jpg',
      'kind': 'playlist',
      'externalUrl':
          'https://zingmp3.vn/playlist/tuyen-tap-nang-tho/collection-one.html',
    },
    'videos' => {
      'id': 'video-one',
      'title': 'Nàng Thơ (MV)',
      'artist': 'Hoàng Dũng',
      'thumbnail': 'https://image.example.com/video.jpg',
      'durationSeconds': 267,
      'externalUrl': 'https://zingmp3.vn/video-clip/nang-tho/video-one.html',
    },
    _ => throw StateError('Unexpected typed search request: $type'),
  };

  @override
  void close({bool force = false}) {}
}
