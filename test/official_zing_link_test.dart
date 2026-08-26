import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/catalog_search.dart';
import 'package:zmp3chart/models/official_zing_link.dart';
import 'package:zmp3chart/models/weekly_chart.dart';

void main() {
  test('parses strict official search routes and their sections', () {
    final cases = <String, CatalogSearchSection>{
      'https://zingmp3.vn/tim-kiem?q=lofi': CatalogSearchSection.all,
      'https://zingmp3.vn/tim-kiem/tat-ca?q=lofi': CatalogSearchSection.all,
      'https://zingmp3.vn/tim-kiem/bai-hat?q=lofi': CatalogSearchSection.songs,
      'https://zingmp3.vn/tim-kiem/playlist?q=lofi':
          CatalogSearchSection.collections,
      'https://zingmp3.vn/tim-kiem/artist?q=lofi': CatalogSearchSection.artists,
      'https://zingmp3.vn/tim-kiem/video?q=lofi': CatalogSearchSection.videos,
    };

    for (final MapEntry(key: url, value: section) in cases.entries) {
      final link = OfficialZingLink.tryParse(url);
      expect(link?.kind, OfficialZingLinkKind.search, reason: url);
      expect(link?.searchQuery, 'lofi', reason: url);
      expect(link?.searchSection, section, reason: url);
    }

    final normalized = OfficialZingLink.tryParse(
      'https://zingmp3.vn/tim-kiem/bai-hat?'
      'q=%20S%C6%A1n%20%20T%C3%B9ng%20',
    );
    expect(normalized?.searchQuery, 'Sơn Tùng');
    expect(normalized?.searchSection, CatalogSearchSection.songs);
  });

  test('rejects malformed official search routes and queries', () {
    final overLimit = List.filled(101, 'a').join();
    for (final value in [
      'https://zingmp3.vn/tim-kiem',
      'https://zingmp3.vn/tim-kiem?q=',
      'https://zingmp3.vn/tim-kiem?q=%20%20',
      'https://zingmp3.vn/tim-kiem?q=one&q=two',
      'https://zingmp3.vn/tim-kiem?q=lofi%09mix',
      'https://zingmp3.vn/tim-kiem?q=lofi%00mix',
      'https://zingmp3.vn/tim-kiem?q=$overLimit',
      'https://zingmp3.vn/tim-kiem/unknown?q=lofi',
      'https://zingmp3.vn/tim-kiem/bai-hat/extra?q=lofi',
    ]) {
      expect(OfficialZingLink.tryParse(value), isNull, reason: value);
    }
  });

  test('parses official Zing song, collection and artist links', () {
    final song = OfficialZingLink.tryParse(
      'https://zingmp3.vn/bai-hat/Mot-Bai-Hat/SONG_1.html',
    );
    expect(song?.kind, OfficialZingLinkKind.song);
    expect(song?.id, 'SONG_1');

    final video = OfficialZingLink.tryParse(
      'https://zingmp3.vn/video-clip/Mot-MV/MV_1.html',
    );
    expect(video?.kind, OfficialZingLinkKind.video);
    expect(video?.id, 'MV_1');

    final album = OfficialZingLink.tryParse(
      'https://m.zingmp3.vn/link/album/ALBUM-1',
    );
    expect(album?.kind, OfficialZingLinkKind.collection);
    expect(album?.id, 'ALBUM-1');
    expect(album?.collectionKind, CatalogCollectionKind.album);

    final playlist = OfficialZingLink.tryParse(
      'https://zingmp3.vn/playlist/Nhac-Hay/PLAYLIST1.html',
    );
    expect(playlist?.kind, OfficialZingLinkKind.collection);
    expect(playlist?.collectionKind, CatalogCollectionKind.playlist);

    expect(
      OfficialZingLink.tryParse('https://zingmp3.vn/Taylor-Swift')?.alias,
      'Taylor-Swift',
    );
    expect(
      OfficialZingLink.tryParse(
        'https://zingmp3.vn/nghe-si/Son-Tung-M-TP',
      )?.kind,
      OfficialZingLinkKind.artist,
    );

    final artistSongs = OfficialZingLink.tryParse(
      'https://zingmp3.vn/Son-Tung-M-TP/bai-hat',
    );
    expect(artistSongs?.kind, OfficialZingLinkKind.artist);
    expect(artistSongs?.alias, 'Son-Tung-M-TP');
    expect(artistSongs?.artistSection, OfficialArtistSection.songs);
    expect(
      OfficialZingLink.tryParse(
        'https://zingmp3.vn/Son-Tung-M-TP/single',
      )?.artistSection,
      OfficialArtistSection.singles,
    );
    expect(
      OfficialZingLink.tryParse(
        'https://zingmp3.vn/Son-Tung-M-TP/video',
      )?.artistSection,
      OfficialArtistSection.videos,
    );
  });

  test('parses public catalog destinations from current Zing routes', () {
    expect(
      OfficialZingLink.tryParse('https://zingmp3.vn/zing-chart')?.kind,
      OfficialZingLinkKind.chart,
    );
    expect(
      OfficialZingLink.tryParse('https://zingmp3.vn/moi-phat-hanh')?.kind,
      OfficialZingLinkKind.newReleaseChart,
    );
    expect(
      OfficialZingLink.tryParse(
        'https://zingmp3.vn/new-release/song?filter=all',
      )?.kind,
      OfficialZingLinkKind.releases,
    );
    expect(
      OfficialZingLink.tryParse('https://zingmp3.vn/top100')?.kind,
      OfficialZingLinkKind.top100,
    );
    expect(
      OfficialZingLink.tryParse(
        'https://zingmp3.vn/hub/Remix/IWZ9Z0BO.html',
      )?.id,
      'IWZ9Z0BO',
    );
    final weekly = OfficialZingLink.tryParse(
      'https://zingmp3.vn/zing-chart-tuan/Bai-hat-US-UK/IWZ9Z0BW.html',
    );
    expect(weekly?.kind, OfficialZingLinkKind.weeklyChart);
    expect(weekly?.weeklyRegion, WeeklyChartRegion.usuk);
  });

  test('rejects untrusted hosts, credentials and malformed identifiers', () {
    for (final value in [
      'http://zingmp3.vn/bai-hat/Test/SONG1.html',
      'https://user@zingmp3.vn/bai-hat/Test/SONG1.html',
      'https://zingmp3.vn.evil.example/bai-hat/Test/SONG1.html',
      'https://zingmp3.vn/link/album/ALBUM1/extra',
      'https://zingmp3.vn/bai-hat/Test/SONG%201.html',
      'https://zingmp3.vn/video-clip/Test/MV%201.html',
      'https://zingmp3.vn/video-clip/Test/MV1.html/extra',
      'https://zingmp3.vn/zing-chart-tuan/Test/UNKNOWN.html',
      'https://zingmp3.vn/new-release/video',
      'https://zingmp3.vn/Son-Tung-M-TP/bai-hat/extra',
      'https://zingmp3.vn/Son-Tung-M-TP/unknown',
    ]) {
      expect(OfficialZingLink.tryParse(value), isNull, reason: value);
    }
    expect(
      OfficialZingLink.looksLikeZingUrl(
        'https://zingmp3.vn/link/album/ALBUM1/extra',
      ),
      isTrue,
    );
  });

  test('recognizes absolute URL input before it can become a search query', () {
    expect(
      OfficialZingLink.looksLikeAbsoluteUrl('https://evil.example/song'),
      isTrue,
    );
    expect(OfficialZingLink.looksLikeAbsoluteUrl('https://'), isTrue);
    expect(OfficialZingLink.looksLikeAbsoluteUrl('zingchart://open'), isTrue);
    expect(
      OfficialZingLink.looksLikeAbsoluteUrl('file:///private/song'),
      isTrue,
    );
    expect(
      OfficialZingLink.looksLikeAbsoluteUrl('mailto:user@example.com'),
      isTrue,
    );
    expect(
      OfficialZingLink.looksLikeAbsoluteUrl('data:text/plain,test'),
      isTrue,
    );
    expect(OfficialZingLink.looksLikeAbsoluteUrl('tình yêu'), isFalse);
  });
}
