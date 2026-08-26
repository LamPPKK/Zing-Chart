import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/song.dart';

void main() {
  group('CatalogSearchPage append', () {
    test('keeps song order and removes duplicate ids across pages', () {
      final first = CatalogSongSearchPage(
        query: 'Nàng thơ',
        page: 1,
        limit: 2,
        total: 3,
        hasMore: true,
        catalogPlaybackEnabled: true,
        items: [_song('one', 'Một'), _song('two', 'Hai')],
      );
      final second = CatalogSongSearchPage(
        query: 'Nàng thơ',
        page: 2,
        limit: 2,
        total: 3,
        hasMore: false,
        catalogPlaybackEnabled: true,
        items: [_song('two', 'Hai bị lặp'), _song('three', 'Ba')],
      );

      final merged = first.append(second);

      expect(merged.page, 2);
      expect(merged.hasMore, isFalse);
      expect(merged.total, 3);
      expect(merged.items.map((item) => item.song.id), ['one', 'two', 'three']);
      expect(merged.items[1].song.displayTitle, 'Hai');
      expect(merged.asSearchResult.songs, same(merged.items));
    });

    test('keeps the playback gate fail-closed while appending', () {
      final first = CatalogSongSearchPage(
        query: 'mix',
        page: 1,
        limit: 1,
        total: null,
        hasMore: true,
        catalogPlaybackEnabled: true,
        items: [_song('one', 'Một')],
      );
      final second = CatalogSongSearchPage(
        query: 'mix',
        page: 2,
        limit: 1,
        total: 2,
        hasMore: false,
        catalogPlaybackEnabled: false,
        items: [_song('two', 'Hai')],
      );

      final merged = first.append(second);

      expect(merged.catalogPlaybackEnabled, isFalse);
      expect(merged.asSearchResult.catalogPlaybackEnabled, isFalse);
      expect(merged.total, 2);
    });

    test('deduplicates every non-song typed page by public id', () {
      final artists =
          CatalogArtistSearchPage(
            query: 'mix',
            page: 1,
            limit: 2,
            total: 3,
            hasMore: true,
            catalogPlaybackEnabled: false,
            items: [_artist('artist-one', 'Một'), _artist('artist-two', 'Hai')],
          ).append(
            CatalogArtistSearchPage(
              query: 'mix',
              page: 2,
              limit: 2,
              total: 3,
              hasMore: false,
              catalogPlaybackEnabled: false,
              items: [
                _artist('artist-two', 'Hai bị lặp'),
                _artist('artist-three', 'Ba'),
              ],
            ),
          );
      final collections =
          CatalogCollectionSearchPage(
            query: 'mix',
            page: 1,
            limit: 2,
            total: 3,
            hasMore: true,
            catalogPlaybackEnabled: false,
            items: [
              _collection('collection-one', 'Một'),
              _collection('collection-two', 'Hai'),
            ],
          ).append(
            CatalogCollectionSearchPage(
              query: 'mix',
              page: 2,
              limit: 2,
              total: 3,
              hasMore: false,
              catalogPlaybackEnabled: false,
              items: [
                _collection('collection-two', 'Hai bị lặp'),
                _collection('collection-three', 'Ba'),
              ],
            ),
          );
      final videos =
          CatalogVideoSearchPage(
            query: 'mix',
            page: 1,
            limit: 2,
            total: 3,
            hasMore: true,
            catalogPlaybackEnabled: false,
            items: [_video('video-one', 'Một'), _video('video-two', 'Hai')],
          ).append(
            CatalogVideoSearchPage(
              query: 'mix',
              page: 2,
              limit: 2,
              total: 3,
              hasMore: false,
              catalogPlaybackEnabled: false,
              items: [
                _video('video-two', 'Hai bị lặp'),
                _video('video-three', 'Ba'),
              ],
            ),
          );

      expect(artists.items.map((item) => item.id), [
        'artist-one',
        'artist-two',
        'artist-three',
      ]);
      expect(collections.items.map((item) => item.id), [
        'collection-one',
        'collection-two',
        'collection-three',
      ]);
      expect(videos.items.map((item) => item.id), [
        'video-one',
        'video-two',
        'video-three',
      ]);
    });

    test('rejects non-contiguous, mismatched, and cross-type pages', () {
      final first = CatalogSongSearchPage(
        query: 'mix',
        page: 1,
        limit: 18,
        total: null,
        hasMore: true,
        catalogPlaybackEnabled: true,
        items: [_song('one', 'Một')],
      );

      expect(
        () => first.append(
          CatalogSongSearchPage(
            query: 'other',
            page: 2,
            limit: 18,
            total: null,
            hasMore: false,
            catalogPlaybackEnabled: true,
            items: [_song('two', 'Hai')],
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => first.append(
          CatalogSongSearchPage(
            query: 'mix',
            page: 3,
            limit: 18,
            total: null,
            hasMore: false,
            catalogPlaybackEnabled: true,
            items: [_song('three', 'Ba')],
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => first.append(
          CatalogArtistSearchPage(
            query: 'mix',
            page: 2,
            limit: 18,
            total: null,
            hasMore: false,
            catalogPlaybackEnabled: false,
            items: [_artist('artist-one', 'Một')],
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}

CatalogSong _song(String id, String title) => CatalogSong(
  song: Song(
    id: id,
    name: id,
    title: title,
    thumbnail: 'https://image.example.com/$id.jpg',
    artistsNames: 'Nghệ sĩ',
    code: 'code-$id',
  ),
  duration: const Duration(minutes: 3),
  externalUrl: 'https://zingmp3.vn/bai-hat/$id/$id.html',
  playable: true,
);

CatalogArtist _artist(String id, String name) => CatalogArtist(
  id: id,
  name: name,
  aliasName: id,
  avatar: 'https://image.example.com/$id.jpg',
  externalUrl: 'https://zingmp3.vn/nghe-si/$id',
);

CatalogCollection _collection(String id, String title) => CatalogCollection(
  id: id,
  title: title,
  artist: 'Nghệ sĩ',
  thumbnail: 'https://image.example.com/$id.jpg',
  kind: CatalogCollectionKind.playlist,
  externalUrl: 'https://zingmp3.vn/playlist/$id/$id.html',
);

CatalogVideo _video(String id, String title) => CatalogVideo(
  id: id,
  title: title,
  artist: 'Nghệ sĩ',
  thumbnail: 'https://image.example.com/$id.jpg',
  duration: const Duration(minutes: 3),
  externalUrl: 'https://zingmp3.vn/video-clip/$id/$id.html',
);
