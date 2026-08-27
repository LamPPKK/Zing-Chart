import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_artist_detail.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/song.dart';

void main() {
  test('artist song pages append in order, dedupe, and fail closed', () {
    final first = _page(
      page: 1,
      total: 3,
      hasMore: true,
      playbackEnabled: true,
      items: [_song('one'), _song('two')],
    );
    final second = _page(
      page: 2,
      total: 3,
      hasMore: false,
      playbackEnabled: false,
      items: [_song('two', playable: false), _song('three')],
    );

    final merged = first.append(second);

    expect(merged.items.map((item) => item.song.id), ['one', 'two', 'three']);
    expect(merged.page, 2);
    expect(merged.total, 3);
    expect(merged.hasMore, isFalse);
    expect(merged.catalogPlaybackEnabled, isFalse);
    final deduplicated = merged.items.firstWhere(
      (item) => item.song.id == 'two',
    );
    expect(deduplicated.playable, isFalse);
    expect(deduplicated.song.playable, isFalse);
  });

  test('artist song pages reject stale or unrelated responses', () {
    final first = _page(
      page: 1,
      total: null,
      hasMore: true,
      playbackEnabled: true,
      items: [_song('one')],
    );

    expect(
      () => first.append(
        _page(
          artistId: 'other',
          page: 2,
          total: null,
          hasMore: false,
          playbackEnabled: true,
          items: [_song('two')],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => first.append(
        _page(
          page: 3,
          total: null,
          hasMore: false,
          playbackEnabled: true,
          items: [_song('three')],
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => first.append(
        CatalogArtistSongPage(
          artistId: 'artist',
          page: 2,
          limit: 25,
          total: null,
          hasMore: false,
          items: [_song('two')],
          catalogPlaybackEnabled: true,
        ),
      ),
      throwsArgumentError,
    );
  });

  test(
    'artist detail count and replacement honor the global playback gate',
    () {
      final detail = CatalogArtistDetail(
        artist: _artist,
        cover: '',
        biography: '',
        realName: '',
        national: '',
        birthday: '',
        totalFollow: 0,
        awardCount: 0,
        songs: [_song('one')],
        collectionSections: const [],
        relatedArtists: const [],
        catalogPlaybackEnabled: false,
      );
      final page = _page(
        page: 1,
        total: 12,
        hasMore: true,
        playbackEnabled: true,
        items: [_song('two')],
      );

      final updated = detail.withSongPage(page);

      expect(updated.songs.single.song.id, 'two');
      expect(updated.totalSongCount, 12);
      expect(updated.catalogPlaybackEnabled, isFalse);
      expect(updated.playableSongCount, 0);
      expect(
        () => detail.withSongPage(
          _page(
            artistId: 'other',
            page: 1,
            total: 1,
            hasMore: false,
            playbackEnabled: true,
            items: [_song('other')],
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test('completed artist pages report the usable song count', () {
    final detail = CatalogArtistDetail(
      artist: _artist,
      cover: '',
      biography: '',
      realName: '',
      national: '',
      birthday: '',
      totalFollow: 0,
      awardCount: 0,
      songs: [_song('one')],
      songPage: _page(
        page: 3,
        total: 12,
        hasMore: false,
        playbackEnabled: true,
        items: [_song('one')],
      ),
      collectionSections: const [],
      relatedArtists: const [],
      catalogPlaybackEnabled: true,
    );

    expect(detail.totalSongCount, 1);
  });
}

CatalogArtistSongPage _page({
  String artistId = 'artist',
  required int page,
  required int? total,
  required bool hasMore,
  required bool playbackEnabled,
  required List<CatalogSong> items,
}) => CatalogArtistSongPage(
  artistId: artistId,
  page: page,
  limit: 50,
  total: total,
  hasMore: hasMore,
  items: items,
  catalogPlaybackEnabled: playbackEnabled,
);

CatalogSong _song(String id, {bool playable = true}) => CatalogSong(
  song: Song(
    id: id,
    name: id,
    title: id,
    thumbnail: '',
    artistsNames: 'Nghệ sĩ',
    code: 'source-$id',
    playable: playable,
  ),
  duration: const Duration(minutes: 3),
  externalUrl: 'https://zingmp3.vn/bai-hat/$id/$id.html',
  playable: playable,
);

const _artist = CatalogArtist(
  id: 'artist',
  name: 'Nghệ sĩ',
  aliasName: 'Nghe-Si',
  avatar: '',
);
