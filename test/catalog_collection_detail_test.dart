import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/song.dart';

void main() {
  test(
    'collection participants preserve official order and add track credits',
    () {
      const primary = CatalogArtist(
        id: 'primary',
        name: 'Nghệ Sĩ Chính',
        aliasName: 'Nghe-Si-Chinh',
        avatar: '',
      );
      const guest = CatalogArtist(
        id: 'guest',
        name: 'Khách Mời',
        aliasName: 'Khach-Moi',
        avatar: '',
      );
      const producer = CatalogArtist(
        id: 'producer',
        name: 'Nhà Sản Xuất',
        aliasName: 'Nha-San-Xuat',
        avatar: '',
      );
      const duplicatePrimary = CatalogArtist(
        id: 'primary',
        name: 'Tên Trùng Không Ghi Đè',
        aliasName: 'Ten-Trung',
        avatar: '',
      );
      const invalid = CatalogArtist(
        id: '',
        name: 'Không hợp lệ',
        aliasName: 'Khong-Hop-Le',
        avatar: '',
      );
      const detail = CatalogCollectionDetail(
        collection: CatalogCollection(
          id: 'album',
          title: 'Album Chính Thức',
          artist: 'Nghệ Sĩ Chính',
          thumbnail: '',
          kind: CatalogCollectionKind.album,
          externalUrl: '',
        ),
        artists: [primary, guest],
        description: '',
        year: '2026',
        genres: [],
        songs: [
          CatalogSong(
            song: Song(
              id: 'song',
              name: 'song',
              title: 'Bài hát',
              thumbnail: '',
              artistsNames: 'Nghệ Sĩ Chính, Nhà Sản Xuất',
              code: 'song-code',
            ),
            duration: Duration(minutes: 3),
            externalUrl: '',
            playable: true,
            artists: [duplicatePrimary, producer, invalid],
          ),
        ],
        catalogPlaybackEnabled: true,
      );

      expect(detail.participatingArtists.map((artist) => artist.id), [
        'primary',
        'guest',
        'producer',
      ]);
      expect(detail.participatingArtists.first.name, 'Nghệ Sĩ Chính');
    },
  );
}
