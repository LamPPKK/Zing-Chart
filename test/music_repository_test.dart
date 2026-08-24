import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/data/music_repository.dart';
import 'package:zmp3chart/models/chart_snapshot.dart';
import 'package:zmp3chart/models/local_library.dart';
import 'package:zmp3chart/models/weekly_chart.dart';

void main() {
  group('ProxyMusicRepository', () {
    test('requests the selected streaming bitrate from the proxy', () async {
      final adapter = _StaticAdapter(
        body: '{"url":"https://proxy.example.com/v1/streams/signed-token"}',
      );
      final repository = _repository(adapter);

      await repository.getSongSource(
        'code-one',
        quality: StreamingQualityPreference.high,
      );

      expect(adapter.lastOptions?.queryParameters['quality'], '320');
    });

    test('maps the proxy chart and source contracts', () async {
      final repository = _repository(_FixtureAdapter());

      final snapshot = await repository.getChartSnapshot();
      final newReleases = await repository.getNewReleaseChart();
      final discoveryCategories = await repository.getDiscoveryCategories();
      final discoveryRecommendations = await repository
          .getDiscoveryRecommendations();
      final discovery = await repository.getDiscoveryHome(categoryId: '14');
      final hubHome = await repository.getHubHome();
      final hubDetail = await repository.getHubDetail('hub-sleep');
      final top100 = await repository.getTop100();
      final releaseCatalog = await repository.getReleaseCatalog();
      final weeklyChart = await repository.getWeeklyChart(
        WeeklyChartRegion.vietnam,
        week: 33,
        year: 2026,
      );
      final artistDetail = await repository.getArtistDetail('Hoang-Dung');
      final songs = snapshot.songs;
      final search = await repository.searchCatalog('Nàng thơ');
      final suggestions = await repository.getSearchSuggestions('Nàng');
      final collection = await repository.getCollection('collection-one');
      final songDetail = await repository.getSongDetail('code-one');
      final lyrics = await repository.getSongLyrics('code-one');
      final radio = await repository.getSongRadio('code-one');
      final liveRadio = await repository.getLiveRadio();
      final liveSource = await repository.getLiveRadioSource('room-one');
      final source = await repository.getSongSource('code-one');

      expect(songs.single.id, 'one');
      expect(songs.single.displayTitle, 'Một Bài Hát');
      expect(snapshot.series['one'], hasLength(2));
      expect(snapshot.series['one']!.last.counter, 140);
      expect(snapshot.maxScore, 140);
      expect(snapshot.songMetadata['one']?.albumTitle, 'Một Bài Hát (Single)');
      expect(
        snapshot.songMetadata['one']?.duration,
        const Duration(seconds: 218),
      );
      expect(snapshot.songMetadata['one']?.rankChange, 3);
      expect(snapshot.songMetadata['one']?.artists.single.id, 'artist-one');
      expect(snapshot.songMetadata['one']?.artists.single.name, 'Ca Sĩ A');
      expect(snapshot.songMetadata['one']?.album?.id, 'album-one');
      final restoredSnapshot = ChartSnapshot.fromJson(snapshot.toJson());
      expect(
        restoredSnapshot.songMetadata['one']?.albumTitle,
        'Một Bài Hát (Single)',
      );
      expect(
        restoredSnapshot.songMetadata['one']?.duration,
        const Duration(seconds: 218),
      );
      expect(restoredSnapshot.songMetadata['one']?.rankChange, 3);
      expect(
        restoredSnapshot.songMetadata['one']?.artists.single.aliasName,
        'Ca-Si-A',
      );
      expect(restoredSnapshot.songMetadata['one']?.album?.id, 'album-one');
      expect(newReleases.title, 'BXH Nhạc Mới');
      expect(newReleases.entries.single.rank, 1);
      expect(newReleases.entries.single.rankChange, 3);
      expect(newReleases.entries.single.albumTitle, 'Single mới');
      expect(newReleases.entries.single.catalogSong.playable, isTrue);
      expect(
        newReleases.entries.single.catalogSong.duration,
        const Duration(seconds: 218),
      );
      expect(
        newReleases.entries.single.catalogSong.artists.single.id,
        'new-artist-one',
      );
      expect(newReleases.entries.single.catalogSong.album?.id, 'new-album-one');
      expect(discoveryCategories.items.map((item) => item.name), [
        'Thư giãn',
        'Làm việc',
        'Trending',
        'Ngủ ngon',
        'Tập luyện',
      ]);
      expect(
        discoveryRecommendations.playableEntries.single.song.id,
        'recommended-one',
      );
      expect(
        discoveryRecommendations.playableEntries.single.song.displayTitle,
        'Bài Hát Gợi Ý',
      );
      expect(
        discoveryRecommendations.playableEntries.single.artists.single.id,
        'recommended-artist-one',
      );
      expect(
        discoveryRecommendations.playableEntries.single.album?.id,
        'recommended-album-one',
      );
      expect(discoveryRecommendations.catalogPlaybackEnabled, isTrue);
      expect(discovery.categoryId, '14');
      expect(discovery.quickPlay.single.collection.id, 'quick-one');
      expect(
        discovery.quickPlay.single.description,
        'Playlist mở nhanh từ trang Khám phá.',
      );
      expect(discovery.banners.single.id, 'banner-one');
      expect(discovery.videos.single.id, 'mv-one');
      expect(discovery.videos.single.title, 'MV Nổi Bật');
      expect(discovery.sections.single.title, 'Top 100');
      expect(
        discovery.sections.single.collections.single.collection.title,
        'Top 100 Nhạc Trẻ',
      );
      expect(
        discovery.sections.single.collections.single.description,
        'Các ca khúc nổi bật.',
      );
      expect(hubHome.featured.single.title, 'Top 100');
      expect(hubHome.topics.single.title, 'Ngủ Ngon');
      expect(hubHome.genres.single.collections.single.collection.id, 'top-one');
      expect(hubDetail.hub.id, 'hub-sleep');
      expect(hubDetail.sections.single.title, 'Nổi bật');
      expect(top100.sections.single.title, 'Nhạc Việt Nam');
      expect(releaseCatalog.songs.single.song.displayTitle, 'Giữa Thiên Hà');
      expect(releaseCatalog.songs.single.region.name, 'vietnam');
      expect(releaseCatalog.songs.single.playable, isTrue);
      expect(
        releaseCatalog.songs.single.catalogSong.artists.single.id,
        'release-artist-one',
      );
      expect(
        releaseCatalog.songs.single.catalogSong.album?.id,
        'release-track-album',
      );
      expect(
        releaseCatalog.songs.single.catalogSong.duration,
        const Duration(seconds: 174),
      );
      expect(releaseCatalog.albums.single.collection.title, 'Edge of Calm');
      expect(releaseCatalog.albums.single.region.name, 'korea');
      expect(weeklyChart.region, WeeklyChartRegion.vietnam);
      expect(weeklyChart.periodLabel, 'Tuần 33 (10/08 - 16/08)');
      expect(weeklyChart.entries.single.rank, 1);
      expect(weeklyChart.entries.single.rankChange, 2);
      expect(weeklyChart.entries.single.score, 2526);
      expect(weeklyChart.entries.single.albumTitle, 'Album tuần');
      expect(
        weeklyChart.entries.single.catalogSong.artists.single.id,
        'weekly-artist-one',
      );
      expect(
        weeklyChart.entries.single.catalogSong.album?.id,
        'weekly-album-one',
      );
      expect(weeklyChart.playableSongs.single.id, 'weekly-one');
      expect(artistDetail.artist.name, 'Hoàng Dũng');
      expect(
        artistDetail.artist.officialExternalUrl,
        'https://zingmp3.vn/nghe-si/Hoang-Dung',
      );
      expect(artistDetail.totalFollow, 123456);
      expect(artistDetail.playableSongCount, 1);
      expect(artistDetail.featuredSongs.single.song.id, 'featured-one');
      expect(artistDetail.songs.single.artists.single.id, 'artist-one');
      expect(artistDetail.songs.single.album?.id, 'album-track-one');
      expect(artistDetail.videos.single.title, 'Nàng Thơ (MV)');
      expect(
        artistDetail.videos.single.externalUrl,
        'https://zingmp3.vn/video-clip/nang-tho/artist-video-one.html',
      );
      expect(artistDetail.collectionSections.single.title, 'Album');
      expect(artistDetail.relatedArtists.single.name, 'Vũ.');
      expect(search.query, 'Nàng thơ');
      expect(search.songs.single.song.id, 'search-one');
      expect(search.songs.single.song.code, 'search-source-one');
      expect(search.songs.single.playable, isTrue);
      expect(search.songs.single.hasLyrics, isTrue);
      expect(search.songs.single.duration, const Duration(seconds: 254));
      expect(search.songs.single.artists.single.id, 'artist-one');
      expect(search.songs.single.album?.id, 'search-track-album');
      expect(search.artists.single.name, 'Hoàng Dũng');
      expect(search.artists.single.totalFollow, 2600000);
      expect(
        search.artists.single.officialExternalUrl,
        'https://zingmp3.vn/nghe-si/Hoang-Dung',
      );
      expect(search.collections.single.title, 'Tuyển tập Nàng Thơ');
      expect(search.videos.single.title, 'Nàng Thơ (MV)');
      expect(search.videos.single.duration, const Duration(seconds: 267));
      expect(search.videos.single.primaryArtist?.id, 'artist-one');
      expect(search.videos.single.artists, hasLength(1));
      expect(
        search.videos.single.primaryArtist?.avatar,
        'https://image.example.com/artist.jpg',
      );
      expect(suggestions.query, 'Nàng');
      expect(suggestions.keywords, ['Nàng thơ', 'Nàng thơ Hoàng Dũng']);
      expect(suggestions.songs.single.id, 'suggestion-one');
      expect(suggestions.songs.single.title, 'Nàng Thơ');
      expect(suggestions.songs.single.artist, 'Hoàng Dũng');
      expect(suggestions.songs.single.duration, const Duration(seconds: 254));
      expect(
        suggestions.songs.single.externalUrl,
        'https://zingmp3.vn/bai-hat/nang-tho/suggestion-one.html',
      );
      expect(collection.collection.id, 'collection-one');
      expect(collection.artists.single.id, 'artist-one');
      expect(collection.artists.single.aliasName, 'Hoang-Dung');
      expect(collection.songs.single.song.displayTitle, 'Nàng Thơ');
      expect(collection.totalDuration, const Duration(seconds: 254));
      expect(collection.likeCount, 2200000);
      expect(
        collection.releasedAt,
        DateTime.fromMillisecondsSinceEpoch(1_787_240_400_000),
      );
      expect(collection.distributor, 'Zing Music Distribution');
      expect(collection.sections.single.id, 'appears-in');
      expect(collection.sections.single.collections.single.id, 'related-one');
      expect(collection.songs.single.artists.single.id, 'artist-one');
      expect(collection.songs.single.artists.single.name, 'Hoàng Dũng');
      expect(collection.songs.single.album?.id, 'album-track-one');
      expect(collection.songs.single.album?.title, '25');
      expect(songDetail.catalogSong.song.displayTitle, 'Một Bài Hát');
      expect(songDetail.catalogSong.hasLyrics, isTrue);
      expect(songDetail.album?.title, 'Một Bài Hát (Single)');
      expect(songDetail.artists.single.name, 'Ca Sĩ');
      expect(songDetail.composers.single.name, 'Nhạc Sĩ');
      expect(songDetail.genres, ['Việt Nam', 'V-Pop']);
      expect(songDetail.distributor, 'Zing Music Distribution');
      expect(
        songDetail.releasedAt,
        DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
      );
      expect(songDetail.listenCount, 1234567);
      expect(songDetail.likeCount, 45678);
      expect(songDetail.commentCount, 321);
      expect(songDetail.mv?.externalUrl, contains('/video-clip/'));
      expect(lyrics.songId, 'code-one');
      expect(lyrics.synced, isTrue);
      expect(lyrics.lines, hasLength(2));
      expect(lyrics.lines.first.text, 'Một ngày mình gặp nhau');
      expect(lyrics.wordSynced, isTrue);
      expect(lyrics.lines.first.words.map((word) => word.text), [
        'Một',
        'ngày',
        'mình',
        'gặp nhau',
      ]);
      expect(
        lyrics.lines.first.activeWordIndex(const Duration(milliseconds: 1850)),
        2,
      );
      expect(lyrics.activeLineIndex(const Duration(milliseconds: 2500)), 1);
      expect(radio.seedId, 'code-one');
      expect(radio.recommendations.single.song.id, 'radio-one');
      expect(radio.recommendations.single.playable, isTrue);
      expect(liveRadio.rooms.single.id, 'room-one');
      expect(liveRadio.rooms.single.title, 'V-POP');
      expect(liveRadio.rooms.single.program?.title, 'Nhạc Việt hôm nay');
      expect(liveRadio.rooms.single.listenerCount, 12500);
      expect(
        liveSource,
        'https://proxy.example.com/v1/live-streams/encrypted-token',
      );
      expect(source, 'https://proxy.example.com/v1/streams/signed-token');
    });

    test('accepts only the configured first-party stream relay', () async {
      final localRepository = _repository(
        _StaticAdapter(
          body: '{"url":"http://127.0.0.1:8080/v1/streams/local-token"}',
        ),
        baseUrl: 'http://localhost:8080',
      );
      final crossOriginRepository = _repository(
        _StaticAdapter(
          body: '{"url":"https://audio.example.com/v1/streams/signed-token"}',
        ),
      );

      expect(
        await localRepository.getSongSource('code'),
        'http://127.0.0.1:8080/v1/streams/local-token',
      );
      await expectLater(
        crossOriginRepository.getSongSource('code'),
        throwsA(isA<MusicRepositoryException>()),
      );
    });

    test('drops untrusted artist profile links from catalog search', () async {
      final repository = _repository(
        _StaticAdapter(
          body:
              '{"query":"artist","catalogPlaybackEnabled":true,'
              '"songs":[],"collections":[],"videos":[],'
              '"artists":[{"id":"artist-one","name":"Nghệ Sĩ",'
              '"aliasName":"Nghe-Si","avatar":"",'
              '"externalUrl":"https://evil.example/nghe-si/Nghe-Si"}]}',
        ),
      );

      final result = await repository.searchCatalog('artist');

      expect(result.artists, isEmpty);
    });

    test(
      'drops untrusted chart artist and album navigation metadata',
      () async {
        final repository = _repository(
          _StaticAdapter(
            body:
                '{"songs":[{"id":"one","code":"code-one",'
                '"title":"Một Bài Hát","artist":"Ca Sĩ A","albumCover":"",'
                '"artists":[{"id":"artist-one","name":"Ca Sĩ A",'
                '"aliasName":"Ca-Si-A","avatar":"",'
                '"externalUrl":"https://evil.example/nghe-si/Ca-Si-A"}],'
                '"album":{"id":"album-one","title":"Album Một",'
                '"artist":"Ca Sĩ A","thumbnail":"","kind":"album",'
                '"externalUrl":"https://evil.example/album/album-one"}}],'
                '"chart":{"series":{},"minScore":0,"maxScore":0}}',
          ),
        );

        final snapshot = await repository.getChartSnapshot();

        expect(snapshot.songs.single.id, 'one');
        expect(snapshot.songMetadata['one']?.artists, isEmpty);
        expect(snapshot.songMetadata['one']?.album, isNull);
      },
    );

    test('rejects malformed chart and insecure source responses', () async {
      final malformedChart = _repository(
        _StaticAdapter(body: '{"unexpected":true}'),
      );
      final insecureSource = _repository(
        _StaticAdapter(body: '{"url":"http://audio.example.com/song.mp3"}'),
      );
      final malformedLyrics = _repository(
        _StaticAdapter(
          body:
              '{"songId":"code","synced":true,"lines":['
              '{"startTimeMs":2000,"endTimeMs":1000,"text":"Lỗi"}]}',
        ),
      );
      final malformedLyricWords = _repository(
        _StaticAdapter(
          body:
              '{"songId":"code","synced":true,"lines":['
              '{"startTimeMs":1000,"endTimeMs":3000,"text":"Sai nhịp",'
              '"words":[{"startTimeMs":900,"endTimeMs":1400,"text":"Sai"}]}]}',
        ),
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
      await expectLater(
        malformedLyrics.getSongLyrics('code'),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('lời bài hát không hợp lệ'),
          ),
        ),
      );
      await expectLater(
        malformedLyricWords.getSongLyrics('code'),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('lời bài hát không hợp lệ'),
          ),
        ),
      );
    });

    test('rejects an untrusted MV handoff URL in search results', () async {
      final repository = _repository(
        _StaticAdapter(
          body:
              '{"query":"mv","catalogPlaybackEnabled":true,'
              '"songs":[],"artists":[],"collections":[],'
              '"videos":[{"id":"video-one","title":"MV lỗi",'
              '"artist":"Nghệ sĩ","thumbnail":"",'
              '"durationSeconds":200,'
              '"externalUrl":"https://evil.example/video-clip/video-one"}]}',
        ),
      );

      await expectLater(
        repository.searchCatalog('mv'),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('tìm kiếm không hợp lệ'),
          ),
        ),
      );
    });

    test('rejects an untrusted MV handoff URL in song detail', () async {
      final repository = _repository(
        _StaticAdapter(
          body:
              '{"song":{"id":"code","code":"code","title":"Bài hát",'
              '"artist":"Nghệ sĩ","albumCover":"","durationSeconds":200,'
              '"externalUrl":"https://zingmp3.vn/bai-hat/bai-hat/code.html",'
              '"playable":true},"artists":[],"releasedAt":0,'
              '"distributor":"","genres":[],"composers":[],'
              '"listenCount":0,"likeCount":0,"commentCount":0,'
              '"mv":{"id":"code","title":"MV lỗi","artist":"Nghệ sĩ",'
              '"thumbnail":"","durationSeconds":200,'
              '"externalUrl":"https://evil.example/video-clip/code"},'
              '"catalogPlaybackEnabled":true}',
        ),
      );

      await expectLater(
        repository.getSongDetail('code'),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('thông tin bài hát không hợp lệ'),
          ),
        ),
      );
    });

    test('rejects an untrusted MV handoff URL in artist detail', () async {
      final repository = _repository(
        _StaticAdapter(
          body:
              '{"artist":{"id":"artist-one","name":"Hoàng Dũng",'
              '"aliasName":"Hoang-Dung","avatar":"",'
              '"externalUrl":"https://zingmp3.vn/nghe-si/Hoang-Dung"},'
              '"songs":[{"id":"song-one","code":"song-one",'
              '"title":"Nàng Thơ","artist":"Hoàng Dũng","albumCover":"",'
              '"durationSeconds":254,"externalUrl":"","playable":true}],'
              '"videos":[{"id":"evil-video","title":"MV lỗi",'
              '"artist":"Hoàng Dũng","thumbnail":"","durationSeconds":254,'
              '"externalUrl":"https://evil.example/video-clip/evil-video"}],'
              '"collectionSections":[],"relatedArtists":[]}',
        ),
      );

      await expectLater(
        repository.getArtistDetail('Hoang-Dung'),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('hồ sơ nghệ sĩ không hợp lệ'),
          ),
        ),
      );
    });

    test('rejects untrusted or mismatched search suggestions', () async {
      final untrusted = _repository(
        _StaticAdapter(
          body:
              '{"query":"Nàng","keywords":[],"songs":['
              '{"id":"one","title":"Nàng Thơ","artist":"Hoàng Dũng",'
              '"thumbnail":"","durationSeconds":254,'
              '"externalUrl":"https://attacker.example/bai-hat/one"}]}',
        ),
      );
      final mismatched = _repository(
        _StaticAdapter(body: '{"query":"Khác","keywords":[],"songs":[]}'),
      );

      await expectLater(
        untrusted.getSearchSuggestions('Nàng'),
        throwsA(isA<MusicRepositoryException>()),
      );
      await expectLater(
        mismatched.getSearchSuggestions('Nàng'),
        throwsA(isA<MusicRepositoryException>()),
      );
      await expectLater(
        mismatched.getSearchSuggestions('  '),
        throwsA(isA<MusicRepositoryException>()),
      );
    });

    test('accepts a Discovery Home containing only Quick Play', () async {
      final repository = _repository(
        _StaticAdapter(
          body:
              '{"categoryId":"-1","updatedAt":1787249000000,'
              '"quickPlay":[{"id":"quick-only","title":"V-Pop Mở Nhanh",'
              '"artist":"Nhiều nghệ sĩ",'
              '"artists":[{"id":"artist-one","name":"Ca Sĩ A",'
              '"aliasName":"Ca-Si-A","avatar":"",'
              '"externalUrl":"https://zingmp3.vn/nghe-si/Ca-Si-A"}],'
              '"thumbnail":"https://image.example.com/quick-only.jpg",'
              '"kind":"playlist",'
              '"externalUrl":"https://zingmp3.vn/album/quick-only.html",'
              '"description":"Playlist mở nhanh."}],'
              '"banners":[],"sections":[]}',
        ),
      );

      final home = await repository.getDiscoveryHome();

      expect(home.quickPlay.single.collection.id, 'quick-only');
      expect(home.quickPlay.single.collection.artists.single.id, 'artist-one');
      expect(home.banners, isEmpty);
      expect(home.sections, isEmpty);
      expect(home.isEmpty, isFalse);
    });

    test('drops untrusted artist links from Discovery collections', () async {
      final repository = _repository(
        _StaticAdapter(
          body:
              '{"categoryId":"-1","updatedAt":1787249000000,'
              '"quickPlay":[{"id":"quick-safe","title":"V-Pop Mở Nhanh",'
              '"artist":"Ca Sĩ A",'
              '"artists":[{"id":"artist-one","name":"Ca Sĩ A",'
              '"aliasName":"Ca-Si-A","avatar":"",'
              '"externalUrl":"https://evil.example/nghe-si/Ca-Si-A"}],'
              '"thumbnail":"https://image.example.com/quick-safe.jpg",'
              '"kind":"playlist",'
              '"externalUrl":"https://zingmp3.vn/album/quick-safe.html",'
              '"description":"Playlist an toàn."}],'
              '"banners":[],"sections":[]}',
        ),
      );

      final home = await repository.getDiscoveryHome();

      expect(home.quickPlay.single.collection.id, 'quick-safe');
      expect(home.quickPlay.single.collection.artists, isEmpty);
    });

    test('accepts only trusted official MVs in Discovery Home', () async {
      final repository = _repository(
        _StaticAdapter(
          body:
              '{"categoryId":"-1","updatedAt":1787249000000,'
              '"quickPlay":[],"banners":[],"sections":[],'
              '"videos":[{"id":"mv-only","title":"MV chính thức",'
              '"artist":"Nghệ sĩ Việt",'
              '"thumbnail":"https://image.example.com/mv-only.jpg",'
              '"durationSeconds":201,'
              '"externalUrl":"https://zingmp3.vn/video-clip/mv-chinh-thuc/mv-only.html"}]}',
        ),
      );

      final home = await repository.getDiscoveryHome();

      expect(home.videos.single.id, 'mv-only');
      expect(home.isEmpty, isFalse);

      final untrusted = _repository(
        _StaticAdapter(
          body:
              '{"categoryId":"-1","updatedAt":1787249000000,'
              '"quickPlay":[],"banners":[],"sections":[],'
              '"videos":[{"id":"mv-evil","title":"MV lỗi",'
              '"artist":"","thumbnail":"https://image.example.com/mv.jpg",'
              '"durationSeconds":201,'
              '"externalUrl":"https://evil.example/video-clip/mv-evil"}]}',
        ),
      );
      await expectLater(
        untrusted.getDiscoveryHome(),
        throwsA(isA<MusicRepositoryException>()),
      );
    });

    test(
      'rejects invalid or mismatched Discovery category responses',
      () async {
        final mismatched = _repository(
          _StaticAdapter(
            body:
                '{"categoryId":"13","updatedAt":1,"banners":[],"sections":['
                '{"id":"work","title":"Làm việc","collections":['
                '{"id":"work-one","title":"Tập trung","artist":"Nhiều nghệ sĩ",'
                '"thumbnail":"","kind":"playlist","externalUrl":"",'
                '"description":"Nhạc tập trung."}]}]}',
          ),
        );

        await expectLater(
          mismatched.getDiscoveryHome(categoryId: '14'),
          throwsA(isA<MusicRepositoryException>()),
        );
        await expectLater(
          mismatched.getDiscoveryHome(categoryId: '1000'),
          throwsA(isA<MusicRepositoryException>()),
        );
      },
    );

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
        repository.getSongDetail('bad code'),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('không hợp lệ'),
          ),
        ),
      );
      await expectLater(
        repository.getSongLyrics('bad code'),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('không hợp lệ'),
          ),
        ),
      );
      await expectLater(
        repository.getSongRadio('bad code'),
        throwsA(
          isA<MusicRepositoryException>().having(
            (error) => error.message,
            'message',
            contains('không hợp lệ'),
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

    test(
      'single-flight caches lyrics but allows empty results to refresh',
      () async {
        final lyricsAdapter = _StaticAdapter(
          body:
              '{"songId":"code","synced":false,"lines":['
              '{"startTimeMs":0,"endTimeMs":0,"text":"Một dòng lời"}]}',
        );
        final lyricsRepository = CachingMusicRepository(
          _repository(lyricsAdapter),
        );
        await Future.wait([
          lyricsRepository.getSongLyrics('code'),
          lyricsRepository.getSongLyrics('code'),
        ]);
        await lyricsRepository.getSongLyrics('code');
        expect(lyricsAdapter.calls, 1);

        final emptyAdapter = _StaticAdapter(
          body: '{"songId":"empty","synced":false,"lines":[]}',
        );
        final emptyRepository = CachingMusicRepository(
          _repository(emptyAdapter),
        );
        await emptyRepository.getSongLyrics('empty');
        await emptyRepository.getSongLyrics('empty');
        expect(emptyAdapter.calls, 2);
      },
    );

    test('single-flight caches validated song detail', () async {
      final detailAdapter = _StaticAdapter(
        body:
            '{"song":{"id":"code","code":"code","title":"Bài hát",'
            '"artist":"Nghệ sĩ","albumCover":"","durationSeconds":200,'
            '"externalUrl":"https://zingmp3.vn/bai-hat/bai-hat/code.html",'
            '"playable":true,"hasLyrics":false},'
            '"artists":[],"releasedAt":0,"distributor":"",'
            '"genres":[],"composers":[],"listenCount":0,'
            '"likeCount":0,"commentCount":0,'
            '"catalogPlaybackEnabled":true}',
      );
      final repository = CachingMusicRepository(_repository(detailAdapter));

      await Future.wait([
        repository.getSongDetail('code'),
        repository.getSongDetail('code'),
      ]);
      await repository.getSongDetail('code');

      expect(detailAdapter.calls, 1);
    });

    test(
      'single-flight caches song radio but allows empty results to refresh',
      () async {
        final radioAdapter = _StaticAdapter(
          body:
              '{"seedId":"seed","catalogPlaybackEnabled":true,"songs":['
              '{"id":"radio","code":"radio","title":"Bài tương tự",'
              '"artist":"Nghệ sĩ","albumCover":"https://image.example/radio.jpg",'
              '"durationSeconds":200,"externalUrl":"https://zingmp3.vn/bai-hat/radio",'
              '"playable":true}]}',
        );
        final radioRepository = CachingMusicRepository(
          _repository(radioAdapter),
        );
        await Future.wait([
          radioRepository.getSongRadio('seed'),
          radioRepository.getSongRadio('seed'),
        ]);
        await radioRepository.getSongRadio('seed');
        expect(radioAdapter.calls, 1);

        final emptyAdapter = _StaticAdapter(
          body: '{"seedId":"empty","catalogPlaybackEnabled":true,"songs":[]}',
        );
        final emptyRepository = CachingMusicRepository(
          _repository(emptyAdapter),
        );
        await emptyRepository.getSongRadio('empty');
        await emptyRepository.getSongRadio('empty');
        expect(emptyAdapter.calls, 2);
      },
    );

    test('single-flights live directory without keeping stale rooms', () async {
      final adapter = _StaticAdapter(
        body:
            '{"updatedAt":1787255000000,"rooms":[{"id":"room",'
            '"title":"V-POP","description":"Nhạc Việt",'
            '"thumbnail":"https://image.example.com/live.jpg",'
            '"listenerCount":42,"hostName":"#zingChart",'
            '"hostThumbnail":"","program":null}]}',
      );
      final repository = CachingMusicRepository(_repository(adapter));

      await Future.wait([repository.getLiveRadio(), repository.getLiveRadio()]);
      await repository.getLiveRadio();

      expect(
        adapter.calls,
        2,
        reason: 'Chỉ gộp request đang chạy, không cache stale.',
      );
    });
  });
}

ProxyMusicRepository _repository(
  HttpClientAdapter adapter, {
  String baseUrl = 'https://proxy.example.com',
}) {
  final dio = Dio(BaseOptions(baseUrl: baseUrl))..httpClientAdapter = adapter;
  return ProxyMusicRepository(baseUrl: baseUrl, dio: dio);
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
        '{"songs":[{"id":"one","title":"Một Bài Hát","albumCover":"https://image.example.com/one.jpg","artist":"Ca Sĩ A","code":"code-one","albumTitle":"Một Bài Hát (Single)",'
        '"artists":[{"id":"artist-one","name":"Ca Sĩ A","aliasName":"Ca-Si-A","avatar":"https://image.example.com/artist.jpg","externalUrl":"https://zingmp3.vn/nghe-si/Ca-Si-A"}],'
        '"album":{"id":"album-one","title":"Một Bài Hát (Single)","artist":"Ca Sĩ A","thumbnail":"https://image.example.com/album.jpg","kind":"album","externalUrl":"https://zingmp3.vn/album/mot-bai-hat/album-one.html"},'
        '"durationSeconds":218,"rank":1,"rankChange":3}],'
        '"chart":{"series":{"one":[{"time":1000,"hour":"08","counter":100},{"time":2000,"hour":"09","counter":140}]},'
        '"minScore":0,"maxScore":140,"updatedAt":2000}}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/search/suggestions')) {
      return ResponseBody.fromString(
        '{"query":"Nàng","keywords":["Nàng thơ","Nàng thơ Hoàng Dũng"],'
        '"songs":[{"id":"suggestion-one","title":"Nàng Thơ",'
        '"artist":"Hoàng Dũng","thumbnail":"https://image.example.com/suggestion.jpg",'
        '"durationSeconds":254,'
        '"externalUrl":"https://zingmp3.vn/bai-hat/nang-tho/suggestion-one.html"}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/search')) {
      return ResponseBody.fromString(
        '{"query":"Nàng thơ","catalogPlaybackEnabled":true,'
        '"songs":[{"id":"search-one","code":"search-source-one",'
        '"title":"Nàng Thơ","artist":"Hoàng Dũng",'
        '"artists":[{"id":"artist-one","name":"Hoàng Dũng","aliasName":"Hoang-Dung","avatar":"https://image.example.com/artist.jpg","externalUrl":"https://zingmp3.vn/nghe-si/Hoang-Dung"}],'
        '"albumCover":"https://image.example.com/search.jpg",'
        '"album":{"id":"search-track-album","title":"Nàng Thơ (Single)","artist":"Hoàng Dũng","thumbnail":"https://image.example.com/search-album.jpg","kind":"album","externalUrl":"https://zingmp3.vn/album/nang-tho/search-track-album.html"},'
        '"durationSeconds":254,"externalUrl":"https://zingmp3.vn/link/song/search-one",'
        '"playable":true,"hasLyrics":true}],'
        '"artists":[{"id":"artist-one","name":"Hoàng Dũng",'
        '"aliasName":"Hoang-Dung","avatar":"https://image.example.com/artist.jpg",'
        '"externalUrl":"https://zingmp3.vn/nghe-si/Hoang-Dung","totalFollow":2600000},'
        '{"id":"untrusted-artist","name":"Không tin cậy",'
        '"aliasName":"Khong-Tin-Cay","avatar":"",'
        '"externalUrl":"https://evil.example/nghe-si/Khong-Tin-Cay"}],'
        '"collections":[{"id":"collection-one","title":"Tuyển tập Nàng Thơ",'
        '"artist":"Hoàng Dũng","thumbnail":"https://image.example.com/collection.jpg",'
        '"kind":"playlist","externalUrl":"https://zingmp3.vn/link/album/collection-one"}],'
        '"videos":[{"id":"video-one","title":"Nàng Thơ (MV)",'
        '"artist":"Hoàng Dũng","artists":[{"id":"artist-one","name":"Hoàng Dũng","aliasName":"Hoang-Dung","avatar":"https://image.example.com/artist.jpg","externalUrl":"https://zingmp3.vn/nghe-si/Hoang-Dung"},{"id":"unsafe-video-artist","name":"Không an toàn","aliasName":"Khong-An-Toan","avatar":"http://image.example.com/unsafe.jpg","externalUrl":"https://zingmp3.vn/nghe-si/Khong-An-Toan"}],'
        '"thumbnail":"https://image.example.com/video.jpg",'
        '"durationSeconds":267,'
        '"externalUrl":"https://zingmp3.vn/video-clip/nang-tho/video-one.html"}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/charts/new-releases')) {
      return ResponseBody.fromString(
        '{"title":"BXH Nhạc Mới","updatedAt":1787248103000,'
        '"catalogPlaybackEnabled":true,"songs":[{"id":"new-one",'
        '"code":"new-source-one","title":"Bài Hát Mới",'
        '"artist":"Ca Sĩ Mới",'
        '"artists":[{"id":"new-artist-one","name":"Ca Sĩ Mới",'
        '"aliasName":"Ca-Si-Moi","avatar":"https://image.example.com/new-artist.jpg",'
        '"externalUrl":"https://zingmp3.vn/nghe-si/Ca-Si-Moi"}],'
        '"albumCover":"https://image.example.com/new.jpg",'
        '"album":{"id":"new-album-one","title":"Single mới",'
        '"artist":"Ca Sĩ Mới","thumbnail":"https://image.example.com/new-album.jpg",'
        '"kind":"album","externalUrl":"https://zingmp3.vn/album/single-moi/new-album-one.html"},'
        '"albumTitle":"Single mới","durationSeconds":218,'
        '"externalUrl":"https://zingmp3.vn/bai-hat/new-one.html",'
        '"rank":1,"rankChange":3,"releasedAt":1787200000,"playable":true}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/charts/weekly')) {
      return ResponseBody.fromString(
        '{"region":"vietnam","title":"Bảng Xếp Hạng Tuần",'
        '"week":33,"year":2026,"latestWeek":33,"startDate":"10/08",'
        '"endDate":"16/08","updatedAt":1787248103000,'
        '"catalogPlaybackEnabled":true,"songs":[{"id":"weekly-one",'
        '"code":"weekly-source-one","title":"Bài Hát Tuần",'
        '"artist":"Nghệ Sĩ Tuần",'
        '"artists":[{"id":"weekly-artist-one","name":"Nghệ Sĩ Tuần",'
        '"aliasName":"Nghe-Si-Tuan","avatar":"https://image.example.com/weekly-artist.jpg",'
        '"externalUrl":"https://zingmp3.vn/nghe-si/Nghe-Si-Tuan"}],'
        '"albumCover":"https://image.example.com/weekly.jpg",'
        '"album":{"id":"weekly-album-one","title":"Album tuần",'
        '"artist":"Nghệ Sĩ Tuần","thumbnail":"https://image.example.com/weekly-album.jpg",'
        '"kind":"album","externalUrl":"https://zingmp3.vn/album/album-tuan/weekly-album-one.html"},'
        '"albumTitle":"Album tuần","durationSeconds":225,'
        '"externalUrl":"https://zingmp3.vn/bai-hat/weekly-one.html",'
        '"rank":1,"rankChange":2,"score":2526,"playable":true}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/discovery/categories')) {
      return ResponseBody.fromString(
        '{"updatedAt":1787248900000,"items":['
        '{"id":"14","name":"Thư giãn"},'
        '{"id":"13","name":"Làm việc"},'
        '{"id":"21","name":"Trending"},'
        '{"id":"18","name":"Ngủ ngon"},'
        '{"id":"15","name":"Tập luyện"}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/discovery/recommendations')) {
      return ResponseBody.fromString(
        '{"updatedAt":1787248950000,"catalogPlaybackEnabled":true,'
        '"songs":[{"id":"recommended-one","code":"recommended-source-one",'
        '"title":"Bài Hát Gợi Ý","artist":"Nghệ Sĩ Gợi Ý",'
        '"artists":[{"id":"recommended-artist-one",'
        '"name":"Nghệ Sĩ Gợi Ý","aliasName":"Nghe-Si-Goi-Y",'
        '"avatar":"https://image.example.com/recommended-artist.jpg",'
        '"externalUrl":"https://zingmp3.vn/nghe-si/Nghe-Si-Goi-Y"}],'
        '"albumCover":"https://image.example.com/recommended.jpg",'
        '"album":{"id":"recommended-album-one",'
        '"title":"Bài Hát Gợi Ý (Single)","artist":"Nghệ Sĩ Gợi Ý",'
        '"thumbnail":"https://image.example.com/recommended-album.jpg",'
        '"kind":"album",'
        '"externalUrl":"https://zingmp3.vn/album/goi-y/recommended-album-one.html"},'
        '"durationSeconds":245,'
        '"externalUrl":"https://zingmp3.vn/bai-hat/recommended-one.html",'
        '"playable":true}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/discovery/home')) {
      final categoryId =
          options.queryParameters['categoryId']?.toString() ?? '-1';
      return ResponseBody.fromString(
        '{"categoryId":"$categoryId","updatedAt":1787249000000,'
        '"quickPlay":[{"id":"quick-one","title":"V-Pop Gây Bão",'
        '"artist":"Nhiều nghệ sĩ",'
        '"thumbnail":"https://image.example.com/quick-play.jpg",'
        '"kind":"playlist",'
        '"externalUrl":"https://zingmp3.vn/album/quick-one.html",'
        '"description":"Playlist mở nhanh từ trang Khám phá."}],'
        '"banners":[{"id":"banner-one",'
        '"image":"https://image.example.com/banner.jpg"}],'
        '"videos":[{"id":"mv-one","title":"MV Nổi Bật",'
        '"artist":"Nghệ sĩ MV",'
        '"thumbnail":"https://image.example.com/mv.jpg",'
        '"durationSeconds":245,'
        '"externalUrl":"https://zingmp3.vn/video-clip/mv-noi-bat/mv-one.html"}],'
        '"sections":[{"id":"top-100","title":"Top 100",'
        '"collections":[{"id":"top-one","title":"Top 100 Nhạc Trẻ",'
        '"artist":"Nhiều nghệ sĩ",'
        '"thumbnail":"https://image.example.com/top.jpg",'
        '"kind":"playlist",'
        '"externalUrl":"https://zingmp3.vn/album/top-one.html",'
        '"description":"Các ca khúc nổi bật."}]}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/hubs')) {
      return ResponseBody.fromString(
        '{"updatedAt":1787250000000,'
        '"featured":[{"id":"hub-top","title":"Top 100",'
        '"description":"Nghe nhiều nhất.","image":"https://image.example.com/hub-top.jpg",'
        '"externalUrl":"https://zingmp3.vn/hub/top-100/hub-top.html",'
        '"collections":[]}],"nations":[],'
        '"topics":[{"id":"hub-sleep","title":"Ngủ Ngon",'
        '"description":"","image":"https://image.example.com/hub-sleep.jpg",'
        '"externalUrl":"https://zingmp3.vn/hub/ngu-ngon/hub-sleep.html",'
        '"collections":[]}],'
        '"genres":[{"id":"hub-vietnam","title":"Nhạc Việt",'
        '"description":"","image":"https://image.example.com/hub-vietnam.jpg",'
        '"externalUrl":"https://zingmp3.vn/hub/nhac-viet/hub-vietnam.html",'
        '"collections":[{"id":"top-one","title":"Top 100 Nhạc Trẻ",'
        '"artist":"Nhiều nghệ sĩ","thumbnail":"https://image.example.com/top.jpg",'
        '"kind":"playlist","externalUrl":"https://zingmp3.vn/album/top-one.html",'
        '"description":"Các ca khúc nổi bật."}]}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/hubs/hub-sleep')) {
      return ResponseBody.fromString(
        '{"id":"hub-sleep","title":"Ngủ Ngon","description":"",'
        '"image":"https://image.example.com/hub-sleep.jpg",'
        '"externalUrl":"https://zingmp3.vn/hub/ngu-ngon/hub-sleep.html",'
        '"collections":[],"sections":[{"id":"featured","title":"Nổi bật",'
        '"collections":[{"id":"top-one","title":"Nhạc Gối Đầu Giường",'
        '"artist":"Nhiều nghệ sĩ","thumbnail":"https://image.example.com/sleep.jpg",'
        '"kind":"playlist","externalUrl":"https://zingmp3.vn/album/sleep.html",'
        '"description":"Nhạc dịu nhẹ."}]}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/top-100')) {
      return ResponseBody.fromString(
        '{"updatedAt":1787250100000,"sections":[{"id":"vietnam",'
        '"title":"Nhạc Việt Nam","collections":[{"id":"top-one",'
        '"title":"Top 100 Nhạc Trẻ","artist":"Nhiều nghệ sĩ",'
        '"thumbnail":"https://image.example.com/top.jpg","kind":"playlist",'
        '"externalUrl":"https://zingmp3.vn/album/top-one.html",'
        '"description":"Các ca khúc nổi bật."}]}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/releases')) {
      return ResponseBody.fromString(
        '{"updatedAt":1787254004584,"catalogPlaybackEnabled":true,'
        '"songs":[{"id":"release-song-one","code":"release-source-one",'
        '"title":"Giữa Thiên Hà","artist":"Yeolan, CoolKid",'
        '"artists":[{"id":"release-artist-one","name":"Yeolan","aliasName":"Yeolan","avatar":"https://image.example.com/release-artist.jpg","externalUrl":"https://zingmp3.vn/nghe-si/Yeolan"}],'
        '"albumCover":"https://image.example.com/release-song.jpg",'
        '"album":{"id":"release-track-album","title":"Giữa Thiên Hà (Single)","artist":"Yeolan, CoolKid","thumbnail":"https://image.example.com/release-track-album.jpg","kind":"album","externalUrl":"https://zingmp3.vn/album/giua-thien-ha/release-track-album.html"},'
        '"durationSeconds":174,"externalUrl":"https://zingmp3.vn/bai-hat/release-song-one.html",'
        '"playable":true,"releasedAt":1787230800,"region":"vietnam"}],'
        '"albums":[{"id":"release-album-one","title":"Edge of Calm",'
        '"artist":"Tiffany Young","thumbnail":"https://image.example.com/release-album.jpg",'
        '"kind":"album","externalUrl":"https://zingmp3.vn/album/release-album-one.html",'
        '"releasedAt":1787158800,"region":"korea"}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/collections/collection-one')) {
      return ResponseBody.fromString(
        '{"id":"collection-one","title":"Tuyển tập Nàng Thơ",'
        '"artist":"Hoàng Dũng","thumbnail":"https://image.example.com/collection.jpg",'
        '"kind":"playlist","externalUrl":"https://zingmp3.vn/album/collection-one.html",'
        '"artists":[{"id":"artist-one","name":"Hoàng Dũng",'
        '"aliasName":"Hoang-Dung","avatar":"https://image.example.com/artist.jpg",'
        '"externalUrl":"https://zingmp3.vn/nghe-si/Hoang-Dung"}],'
        '"description":"Những bài hát nổi bật","year":"2026",'
        '"releasedAt":1787240400000,"distributor":"Zing Music Distribution",'
        '"likeCount":2200000,"genres":["V-Pop"],'
        '"sections":[{"id":"appears-in","title":"Hoàng Dũng Xuất Hiện Trong",'
        '"collections":[{"id":"related-one","title":"Indie Việt",'
        '"artist":"Hoàng Dũng, Vũ.","thumbnail":"https://image.example.com/related.jpg",'
        '"kind":"playlist","externalUrl":"https://zingmp3.vn/album/indie-viet/related-one.html"},'
        '{"id":"evil-one","title":"Không an toàn","artist":"",'
        '"thumbnail":"","kind":"playlist",'
        '"externalUrl":"https://evil.example/album/evil-one.html"}]}],'
        '"catalogPlaybackEnabled":true,"songs":[{"id":"search-one",'
        '"code":"search-source-one","title":"Nàng Thơ","artist":"Hoàng Dũng",'
        '"artists":[{"id":"artist-one","name":"Hoàng Dũng",'
        '"aliasName":"Hoang-Dung","avatar":"https://image.example.com/artist.jpg",'
        '"externalUrl":"https://zingmp3.vn/nghe-si/Hoang-Dung"},'
        '{"id":"evil-artist","name":"Kẻ xấu","aliasName":"Ke-Xau",'
        '"avatar":"","externalUrl":"https://evil.example/nghe-si/Ke-Xau"}],'
        '"album":{"id":"album-track-one","title":"25","artist":"Hoàng Dũng",'
        '"thumbnail":"https://image.example.com/album.jpg","kind":"album",'
        '"externalUrl":"https://zingmp3.vn/album/25/album-track-one.html"},'
        '"albumCover":"https://image.example.com/search.jpg","durationSeconds":254,'
        '"externalUrl":"https://zingmp3.vn/link/song/search-one","playable":true}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/artists/Hoang-Dung')) {
      return ResponseBody.fromString(
        '{"artist":{"id":"artist-one","name":"Hoàng Dũng",'
        '"aliasName":"Hoang-Dung","avatar":"https://image.example.com/artist.jpg",'
        '"externalUrl":"https://zingmp3.vn/nghe-si/Hoang-Dung"},'
        '"cover":"https://image.example.com/artist-cover.jpg",'
        '"biography":"Nghệ sĩ indie Việt Nam.","realName":"Nguyễn Hoàng Dũng",'
        '"national":"Việt Nam","birthday":"04/11/1995",'
        '"totalFollow":123456,"awardCount":2,"catalogPlaybackEnabled":true,'
        '"featuredSongs":[{"id":"featured-one","code":"featured-one",'
        '"title":"Bài Nổi Bật","artist":"Hoàng Dũng","albumCover":"",'
        '"durationSeconds":180,"externalUrl":"https://zingmp3.vn/link/song/featured-one",'
        '"playable":true}],'
        '"songs":[{"id":"search-one","code":"search-source-one",'
        '"title":"Nàng Thơ","artist":"Hoàng Dũng",'
        '"artists":[{"id":"artist-one","name":"Hoàng Dũng",'
        '"aliasName":"Hoang-Dung","avatar":"https://image.example.com/artist.jpg",'
        '"externalUrl":"https://zingmp3.vn/nghe-si/Hoang-Dung"}],'
        '"album":{"id":"album-track-one","title":"25","artist":"Hoàng Dũng",'
        '"thumbnail":"https://image.example.com/album.jpg","kind":"album",'
        '"externalUrl":"https://zingmp3.vn/album/25/album-track-one.html"},'
        '"albumCover":"https://image.example.com/search.jpg","durationSeconds":254,'
        '"externalUrl":"https://zingmp3.vn/link/song/search-one","playable":true}],'
        '"videos":[{"id":"artist-video-one","title":"Nàng Thơ (MV)",'
        '"artist":"Hoàng Dũng","thumbnail":"https://image.example.com/video.jpg",'
        '"durationSeconds":267,'
        '"externalUrl":"https://zingmp3.vn/video-clip/nang-tho/artist-video-one.html"}],'
        '"collectionSections":[{"id":"aAlbum-1","title":"Album",'
        '"collections":[{"id":"collection-one","title":"25",'
        '"artist":"Hoàng Dũng","thumbnail":"https://image.example.com/collection.jpg",'
        '"kind":"album","externalUrl":"https://zingmp3.vn/album/25.html"}]}],'
        '"relatedArtists":[{"id":"artist-two","name":"Vũ.",'
        '"aliasName":"Vu","avatar":"https://image.example.com/vu.jpg",'
        '"externalUrl":"https://zingmp3.vn/nghe-si/Vu"}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/songs/code-one/detail')) {
      return ResponseBody.fromString(
        '{"song":{"id":"code-one","code":"code-one",'
        '"title":"Một Bài Hát","artist":"Ca Sĩ",'
        '"albumCover":"https://image.example.com/song-detail.jpg",'
        '"durationSeconds":222,"externalUrl":"https://zingmp3.vn/bai-hat/mot-bai-hat/code-one.html",'
        '"playable":true,"hasLyrics":true},'
        '"artists":[{"id":"artist-one","name":"Ca Sĩ",'
        '"aliasName":"Ca-Si","avatar":"https://image.example.com/artist.jpg",'
        '"externalUrl":"https://zingmp3.vn/nghe-si/Ca-Si"}],'
        '"album":{"id":"album-one","title":"Một Bài Hát (Single)",'
        '"artist":"Ca Sĩ","thumbnail":"https://image.example.com/album.jpg",'
        '"kind":"album","externalUrl":"https://zingmp3.vn/album/mot-bai-hat/album-one.html"},'
        '"releasedAt":1700000000000,"distributor":"Zing Music Distribution",'
        '"genres":["Việt Nam","V-Pop"],'
        '"composers":[{"id":"composer-one","name":"Nhạc Sĩ",'
        '"aliasName":"Nhac-Si","avatar":"",'
        '"externalUrl":"https://zingmp3.vn/nghe-si/Nhac-Si"}],'
        '"listenCount":1234567,"likeCount":45678,"commentCount":321,'
        '"mv":{"id":"code-one","title":"Một Bài Hát",'
        '"artist":"Ca Sĩ","thumbnail":"https://image.example.com/song-detail.jpg",'
        '"durationSeconds":222,'
        '"externalUrl":"https://zingmp3.vn/video-clip/mot-bai-hat/code-one.html"},'
        '"catalogPlaybackEnabled":true}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/songs/code-one/lyrics')) {
      return ResponseBody.fromString(
        '{"songId":"code-one","synced":true,"lines":['
        '{"startTimeMs":1200,"endTimeMs":2200,"text":"Một ngày mình gặp nhau",'
        '"words":[{"startTimeMs":1200,"endTimeMs":1500,"text":"Một"},'
        '{"startTimeMs":1500,"endTimeMs":1800,"text":"ngày"},'
        '{"startTimeMs":1800,"endTimeMs":2000,"text":"mình"},'
        '{"startTimeMs":2000,"endTimeMs":2200,"text":"gặp nhau"}]},'
        '{"startTimeMs":2300,"endTimeMs":3600,"text":"Ta đã biết yêu thương"}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/songs/code-one/radio')) {
      return ResponseBody.fromString(
        '{"seedId":"code-one","catalogPlaybackEnabled":true,"songs":['
        '{"id":"radio-one","code":"radio-one","title":"Bài Radio",'
        '"artist":"Ca Sĩ Radio","albumCover":"https://image.example.com/radio.jpg",'
        '"durationSeconds":205,"externalUrl":"https://zingmp3.vn/bai-hat/radio-one.html",'
        '"playable":true}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/radio')) {
      return ResponseBody.fromString(
        '{"updatedAt":1787255000000,"rooms":[{"id":"room-one",'
        '"title":"V-POP","description":"Nhạc Việt đang thịnh hành",'
        '"thumbnail":"https://image.example.com/live.jpg",'
        '"listenerCount":12500,"hostName":"Zing MP3",'
        '"hostThumbnail":"https://image.example.com/host.jpg",'
        '"program":{"id":"program-one","title":"Nhạc Việt hôm nay",'
        '"thumbnail":"https://image.example.com/program.jpg",'
        '"description":"Các ca khúc V-Pop",'
        '"startTime":1787250000000,"endTime":1787260000000}}]}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    if (options.path.endsWith('/v1/radio/room-one/source')) {
      return ResponseBody.fromString(
        '{"url":"https://proxy.example.com/v1/live-streams/encrypted-token"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      '{"url":"https://proxy.example.com/v1/streams/signed-token"}',
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
  int calls = 0;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    lastOptions = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
