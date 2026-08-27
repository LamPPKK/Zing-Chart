import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/music_repository.dart';

void main() {
  group('ProxyMusicRepository artist song pagination', () {
    test('sends exact parameters and decodes a trusted page', () async {
      final adapter = _ArtistSongAdapter();
      final repository = _repository(adapter);

      final page = await repository.getArtistSongs(
        'ARTIST1',
        page: 2,
        limit: 25,
      );

      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.path,
        endsWith('/v1/artists/ARTIST1/songs'),
      );
      expect(adapter.requests.single.queryParameters, {'page': 2, 'limit': 25});
      expect(page.artistId, 'ARTIST1');
      expect(page.page, 2);
      expect(page.limit, 25);
      expect(page.total, 51);
      expect(page.hasMore, isTrue);
      expect(page.items.single.song.id, 'SONG2');
      expect(page.items.single.playable, isTrue);
      expect(page.catalogPlaybackEnabled, isTrue);
    });

    test(
      'synthesizes profile page one from songs plus compact metadata',
      () async {
        final adapter = _ArtistSongAdapter(profile: true);
        final repository = _repository(adapter);

        final detail = await repository.getArtistDetail('Nghe-Si');

        expect(detail.songPage?.artistId, 'ARTIST1');
        expect(detail.songPage?.page, 1);
        expect(detail.songPage?.limit, 50);
        expect(detail.songPage?.total, 51);
        expect(detail.songPage?.hasMore, isTrue);
        expect(detail.songPage?.items.single.song.id, 'SONG2');
        expect(detail.songs.single.song.id, 'SONG2');
        expect(detail.totalSongCount, 51);
      },
    );

    test('rejects mismatched echo and unsafe song URLs', () async {
      for (final overrides in [
        const <String, dynamic>{'artistId': 'OTHER'},
        <String, dynamic>{
          'items': [
            {..._songJson(), 'code': 'DIFFERENT_SONG'},
          ],
        },
        const <String, dynamic>{
          'items': [
            {
              'id': 'SONG2',
              'code': 'SONG2',
              'title': 'Bài trang hai',
              'artist': 'Nghệ sĩ',
              'albumCover': 'https://image.example.com/song.jpg',
              'durationSeconds': 180,
              'externalUrl': 'https://evil.example.com/song',
              'playable': true,
            },
          ],
        },
      ]) {
        final repository = _repository(
          _ArtistSongAdapter(responseOverrides: overrides),
        );
        await expectLater(
          repository.getArtistSongs('ARTIST1', page: 2, limit: 25),
          throwsA(
            isA<MusicRepositoryException>().having(
              (error) => error.message,
              'message',
              'Phản hồi trang bài hát nghệ sĩ không hợp lệ.',
            ),
          ),
        );
      }
    });

    test('deduplicates conflicting playability fail closed', () async {
      final repository = _repository(
        _ArtistSongAdapter(
          responseOverrides: {
            'items': [
              _songJson(),
              {..._songJson(), 'playable': false},
            ],
          },
        ),
      );

      final page = await repository.getArtistSongs(
        'ARTIST1',
        page: 2,
        limit: 25,
      );

      expect(page.items, hasLength(1));
      expect(page.items.single.playable, isFalse);
      expect(page.items.single.song.playable, isFalse);
    });

    test('rejects hasMore after the maximum page', () async {
      final repository = _repository(_ArtistSongAdapter());

      await expectLater(
        repository.getArtistSongs('ARTIST1', page: 100),
        throwsA(isA<MusicRepositoryException>()),
      );
    });

    test(
      'preserves structured capability errors and validates locally',
      () async {
        final unavailable = _repository(
          _ArtistSongAdapter(
            statusCode: 501,
            fixedBody: const {
              'error': {
                'code': 'ARTIST_SONG_PAGINATION_UNAVAILABLE',
                'message': 'Chưa cấu hình catalog nghệ sĩ.',
              },
            },
          ),
        );

        await expectLater(
          unavailable.getArtistSongs('ARTIST1'),
          throwsA(
            isA<MusicRepositoryException>()
                .having(
                  (error) => error.code,
                  'code',
                  'ARTIST_SONG_PAGINATION_UNAVAILABLE',
                )
                .having(
                  (error) => error.message,
                  'message',
                  'Chưa cấu hình catalog nghệ sĩ.',
                ),
          ),
        );

        final adapter = _ArtistSongAdapter();
        final repository = _repository(adapter);
        await expectLater(
          repository.getArtistSongs('bad id'),
          throwsA(isA<MusicRepositoryException>()),
        );
        await expectLater(
          repository.getArtistSongs('ARTIST1', page: 101),
          throwsA(isA<MusicRepositoryException>()),
        );
        await expectLater(
          repository.getArtistSongs('ARTIST1', limit: 0),
          throwsA(isA<MusicRepositoryException>()),
        );
        expect(adapter.requests, isEmpty);
      },
    );
  });
}

ProxyMusicRepository _repository(HttpClientAdapter adapter) {
  const baseUrl = 'https://proxy.example.com';
  final dio = Dio(BaseOptions(baseUrl: baseUrl))..httpClientAdapter = adapter;
  return ProxyMusicRepository(baseUrl: baseUrl, dio: dio);
}

class _ArtistSongAdapter implements HttpClientAdapter {
  _ArtistSongAdapter({
    this.statusCode = 200,
    this.fixedBody,
    this.responseOverrides = const {},
    this.profile = false,
  });

  final int statusCode;
  final Map<String, dynamic>? fixedBody;
  final Map<String, dynamic> responseOverrides;
  final bool profile;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = fixedBody ?? (profile ? _profileBody() : _pageBody(options));
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  Map<String, dynamic> _pageBody(RequestOptions options) => <String, dynamic>{
    'artistId': 'ARTIST1',
    'page': options.queryParameters['page'],
    'limit': options.queryParameters['limit'],
    'total': 51,
    'hasMore': true,
    'items': [_songJson()],
    'catalogPlaybackEnabled': true,
    ...responseOverrides,
  };

  Map<String, dynamic> _profileBody() => {
    'artist': {
      'id': 'ARTIST1',
      'name': 'Nghệ sĩ',
      'aliasName': 'Nghe-Si',
      'avatar': 'https://image.example.com/artist.jpg',
      'externalUrl': 'https://zingmp3.vn/nghe-si/Nghe-Si',
    },
    'cover': '',
    'biography': '',
    'realName': '',
    'national': '',
    'birthday': '',
    'totalFollow': 0,
    'awardCount': 0,
    'songs': [_songJson()],
    'featuredSongs': [_songJson()],
    'songPage': {'page': 1, 'limit': 50, 'total': 51, 'hasMore': true},
    'videos': <dynamic>[],
    'collectionSections': <dynamic>[],
    'relatedArtists': <dynamic>[],
    'catalogPlaybackEnabled': true,
  };

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _songJson() => {
  'id': 'SONG2',
  'code': 'SONG2',
  'title': 'Bài trang hai',
  'artist': 'Nghệ sĩ',
  'albumCover': 'https://image.example.com/song.jpg',
  'durationSeconds': 180,
  'externalUrl': 'https://zingmp3.vn/bai-hat/bai-trang-hai/SONG2.html',
  'playable': true,
};
