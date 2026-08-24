import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/catalog_search.dart';
import '../models/catalog_artist_detail.dart';
import '../models/catalog_hub.dart';
import '../models/chart_snapshot.dart';
import '../models/discovery_home.dart';
import '../models/live_radio.dart';
import '../models/local_library.dart';
import '../models/new_release_chart.dart';
import '../models/release_catalog.dart';
import '../models/song.dart';
import '../models/song_detail.dart';
import '../models/song_lyrics.dart';
import '../models/song_radio.dart';
import '../models/search_suggestions.dart';
import '../models/weekly_chart.dart';

abstract interface class MusicRepository {
  Future<ChartSnapshot> getChartSnapshot();

  Future<List<Song>> getChartSongs();

  Future<NewReleaseChart> getNewReleaseChart();

  Future<WeeklyChart> getWeeklyChart(
    WeeklyChartRegion region, {
    int? week,
    int? year,
  });

  Future<DiscoveryCategories> getDiscoveryCategories();

  Future<DiscoveryRecommendations> getDiscoveryRecommendations();

  Future<DiscoveryHome> getDiscoveryHome({String categoryId = '-1'});

  Future<CatalogHubHome> getHubHome();

  Future<CatalogHubDetail> getHubDetail(String id);

  Future<Top100Catalog> getTop100();

  Future<ReleaseCatalog> getReleaseCatalog();

  Future<CatalogArtistDetail> getArtistDetail(String alias);

  Future<CatalogSearchResult> searchCatalog(String query);

  Future<SearchSuggestionSnapshot> getSearchSuggestions(String query);

  Future<CatalogCollectionDetail> getCollection(String id);

  Future<SongDetail> getSongDetail(String songId);

  Future<SongLyrics> getSongLyrics(String code);

  Future<SongRadio> getSongRadio(String code);

  Future<LiveRadioSnapshot> getLiveRadio();

  Future<String> getLiveRadioSource(String id);

  Future<String> getSongSource(
    String code, {
    StreamingQualityPreference quality = StreamingQualityPreference.automatic,
  });
}

bool _isTrustedCatalogPage(Uri? uri) {
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.host.isEmpty ||
      (uri.port != 443)) {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host != 'zingmp3.vn' && !host.endsWith('.zingmp3.vn')) return false;
  return uri.path.startsWith('/bai-hat/') || uri.path.startsWith('/link/song/');
}

bool _isTrustedVideoPage(Uri? uri) {
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.host.isEmpty ||
      uri.port != 443) {
    return false;
  }
  final host = uri.host.toLowerCase();
  return (host == 'zingmp3.vn' || host.endsWith('.zingmp3.vn')) &&
      uri.path.startsWith('/video-clip/');
}

bool _isTrustedCollectionPage(Uri? uri) {
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.host.isEmpty ||
      uri.port != 443) {
    return false;
  }
  final host = uri.host.toLowerCase();
  if (host != 'zingmp3.vn' && !host.endsWith('.zingmp3.vn')) return false;
  if (uri.path.startsWith('/album/') || uri.path.startsWith('/playlist/')) {
    return true;
  }
  final segments = uri.pathSegments;
  return segments.length == 3 &&
      segments[0] == 'link' &&
      segments[1] == 'album' &&
      RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(segments[2]);
}

bool _isTrustedArtistPage(Uri? uri) {
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.host.isEmpty ||
      uri.port != 443) {
    return false;
  }
  final host = uri.host.toLowerCase();
  return (host == 'zingmp3.vn' || host.endsWith('.zingmp3.vn')) &&
      uri.path.startsWith('/nghe-si/');
}

bool _isSafeHttpsResource(String value, {bool allowEmpty = true}) {
  if (value.isEmpty) return allowEmpty;
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      uri.host.isNotEmpty &&
      uri.port == 443;
}

class ProxyMusicRepository implements MusicRepository {
  ProxyMusicRepository({required String baseUrl, Dio? dio})
    : _baseUri = Uri.parse(baseUrl),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 15),
              headers: const {'Accept': 'application/json'},
            ),
          );

  final Uri _baseUri;
  final Dio _dio;

  @override
  Future<ChartSnapshot> getChartSnapshot() async {
    try {
      final response = await _dio.get<dynamic>('/v1/chart');
      final data = response.data;
      final rawSongs = data is Map<String, dynamic> ? data['songs'] : null;
      if (rawSongs is! List) {
        throw const FormatException('Missing songs');
      }
      final songs = <Song>[];
      final songMetadata = <String, ChartSongMetadata>{};
      final catalogIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
      for (final json in rawSongs.whereType<Map<String, dynamic>>()) {
        final song = Song(
          id: json['id']?.toString() ?? '',
          name: json['title']?.toString() ?? '',
          title: json['title']?.toString() ?? '',
          thumbnail: json['albumCover']?.toString() ?? '',
          artistsNames: json['artist']?.toString() ?? '',
          code: json['code']?.toString() ?? '',
        );
        if (song.id.isEmpty || song.displayTitle.isEmpty) continue;
        songs.add(song);
        final rawAlbumTitle = json['albumTitle']?.toString().trim() ?? '';
        final rawDurationSeconds =
            (json['durationSeconds'] as num?)?.toInt() ?? 0;
        final durationSeconds = rawDurationSeconds.clamp(0, 86_400).toInt();
        final rawRankChange = (json['rankChange'] as num?)?.toInt();
        final rankChange = rawRankChange?.clamp(-100, 100).toInt();
        final rawArtists = json['artists'];
        final artists = rawArtists is List
            ? rawArtists
                  .whereType<Map<String, dynamic>>()
                  .map(_artistFromJson)
                  .where(
                    (artist) =>
                        catalogIdPattern.hasMatch(artist.id) &&
                        artist.name.isNotEmpty &&
                        artist.name.length <= 300 &&
                        RegExp(
                          r'^[A-Za-z0-9_-]{1,200}$',
                        ).hasMatch(artist.aliasName) &&
                        _isSafeHttpsResource(artist.avatar) &&
                        _isTrustedArtistPage(
                          Uri.tryParse(artist.officialExternalUrl),
                        ),
                  )
                  .take(10)
                  .toList(growable: false)
            : const <CatalogArtist>[];
        CatalogCollection? album;
        final rawAlbum = json['album'];
        if (rawAlbum is Map<String, dynamic>) {
          final candidate = _collectionFromJson(rawAlbum);
          if (candidate.kind == CatalogCollectionKind.album &&
              catalogIdPattern.hasMatch(candidate.id) &&
              candidate.title.isNotEmpty &&
              candidate.title.length <= 300 &&
              _isSafeHttpsResource(candidate.thumbnail) &&
              _isTrustedCollectionPage(Uri.tryParse(candidate.externalUrl))) {
            album = candidate;
          }
        }
        songMetadata[song.id] = ChartSongMetadata(
          albumTitle: rawAlbumTitle.length <= 300
              ? rawAlbumTitle
              : rawAlbumTitle.substring(0, 300),
          duration: Duration(seconds: durationSeconds),
          rankChange: rankChange,
          artists: artists,
          album: album,
        );
      }
      final rawChart = data is Map<String, dynamic> ? data['chart'] : null;
      final chart = rawChart is Map<String, dynamic>
          ? rawChart
          : const <String, dynamic>{};
      final rawSeries = chart['series'];
      final validSongIds = songs.map((song) => song.id).toSet();
      final series = rawSeries is Map<String, dynamic>
          ? rawSeries.map((songId, rawPoints) {
              if (!validSongIds.contains(songId) || rawPoints is! List) {
                return MapEntry(songId, const <ChartPoint>[]);
              }
              return MapEntry(
                songId,
                rawPoints
                    .whereType<Map<String, dynamic>>()
                    .map(ChartPoint.fromJson)
                    .where((point) => point.counter >= 0)
                    .toList(growable: false),
              );
            })
          : const <String, List<ChartPoint>>{};
      final updatedAt = (chart['updatedAt'] as num?)?.toInt();
      return ChartSnapshot(
        songs: songs,
        songMetadata: Map.unmodifiable(songMetadata),
        series: Map.unmodifiable(
          Map.fromEntries(
            series.entries.where(
              (entry) =>
                  validSongIds.contains(entry.key) && entry.value.length > 1,
            ),
          ),
        ),
        minScore: (chart['minScore'] as num?)?.toDouble() ?? 0,
        maxScore: (chart['maxScore'] as num?)?.toDouble() ?? 0,
        updatedAt: updatedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updatedAt),
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi bảng xếp hạng không hợp lệ.',
      );
    }
  }

  @override
  Future<List<Song>> getChartSongs() async => (await getChartSnapshot()).songs;

  @override
  Future<NewReleaseChart> getNewReleaseChart() async {
    try {
      final response = await _dio.get<dynamic>('/v1/charts/new-releases');
      final data = response.data;
      if (data is! Map<String, dynamic> || data['songs'] is! List) {
        throw const FormatException('Missing new-release chart');
      }
      final rawSongs = data['songs'] as List;
      final entries = rawSongs.indexed
          .where((entry) => entry.$2 is Map<String, dynamic>)
          .map((entry) {
            final json = entry.$2 as Map<String, dynamic>;
            final catalogSong = _catalogSongFromJson(json);
            final releasedAtSeconds =
                (json['releasedAt'] as num?)?.toInt() ?? 0;
            return NewReleaseEntry(
              catalogSong: catalogSong,
              albumTitle: json['albumTitle']?.toString().trim() ?? '',
              rank: (json['rank'] as num?)?.toInt() ?? entry.$1 + 1,
              rankChange: (json['rankChange'] as num?)?.toInt() ?? 0,
              releasedAt: releasedAtSeconds <= 0
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      releasedAtSeconds * 1000,
                    ),
            );
          })
          .where(
            (entry) =>
                entry.song.id.isNotEmpty &&
                entry.song.displayTitle.isNotEmpty &&
                entry.rank > 0,
          )
          .toList(growable: false);
      if (entries.isEmpty) {
        throw const FormatException('New-release chart has no songs');
      }
      final updatedAt = (data['updatedAt'] as num?)?.toInt() ?? 0;
      return NewReleaseChart(
        title: data['title']?.toString().trim().isNotEmpty == true
            ? data['title'].toString().trim()
            : 'BXH Nhạc Mới',
        entries: entries,
        updatedAt: updatedAt <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updatedAt),
        catalogPlaybackEnabled: data['catalogPlaybackEnabled'] == true,
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi BXH Nhạc Mới không hợp lệ.',
      );
    }
  }

  @override
  Future<WeeklyChart> getWeeklyChart(
    WeeklyChartRegion region, {
    int? week,
    int? year,
  }) async {
    if ((week == null) != (year == null) ||
        (week != null && (week < 1 || week > 53)) ||
        (year != null && (year < 2000 || year > 2100))) {
      throw const MusicRepositoryException(
        'Tuần hoặc năm của bảng xếp hạng không hợp lệ.',
      );
    }
    try {
      final response = await _dio.get<dynamic>(
        '/v1/charts/weekly',
        queryParameters: {
          'region': region.wireValue,
          if (week != null) 'week': week,
          if (year != null) 'year': year,
        },
      );
      final data = response.data;
      if (data is! Map<String, dynamic> || data['songs'] is! List) {
        throw const FormatException('Missing weekly chart');
      }
      final mappedRegion = weeklyChartRegionFromWire(
        data['region']?.toString().trim() ?? '',
      );
      if (mappedRegion != region) {
        throw const FormatException('Mismatched weekly chart region');
      }
      final entries = (data['songs'] as List)
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => WeeklyChartEntry(
              catalogSong: _catalogSongFromJson(json),
              albumTitle: json['albumTitle']?.toString().trim() ?? '',
              rank: (json['rank'] as num?)?.toInt() ?? 0,
              rankChange: (json['rankChange'] as num?)?.toInt() ?? 0,
              score: (json['score'] as num?)?.toInt() ?? 0,
            ),
          )
          .where(
            (entry) =>
                entry.rank > 0 &&
                entry.song.id.isNotEmpty &&
                entry.song.displayTitle.isNotEmpty,
          )
          .toList(growable: false);
      final responseWeek = (data['week'] as num?)?.toInt() ?? 0;
      final responseYear = (data['year'] as num?)?.toInt() ?? 0;
      if (entries.isEmpty ||
          responseWeek < 1 ||
          responseWeek > 53 ||
          responseYear < 2000) {
        throw const FormatException('Weekly chart has no songs');
      }
      final updatedAt = (data['updatedAt'] as num?)?.toInt() ?? 0;
      return WeeklyChart(
        region: mappedRegion,
        title: data['title']?.toString().trim().isNotEmpty == true
            ? data['title'].toString().trim()
            : 'Bảng Xếp Hạng Tuần',
        week: responseWeek,
        year: responseYear,
        latestWeek: (data['latestWeek'] as num?)?.toInt() ?? responseWeek,
        startDate: data['startDate']?.toString().trim() ?? '',
        endDate: data['endDate']?.toString().trim() ?? '',
        updatedAt: updatedAt <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updatedAt),
        entries: entries,
        catalogPlaybackEnabled: data['catalogPlaybackEnabled'] == true,
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi bảng xếp hạng tuần không hợp lệ.',
      );
    }
  }

  @override
  Future<DiscoveryCategories> getDiscoveryCategories() async {
    try {
      final response = await _dio.get<dynamic>('/v1/discovery/categories');
      final data = response.data;
      if (data is! Map<String, dynamic> || data['items'] is! List) {
        throw const FormatException('Missing discovery categories');
      }
      final byId = <String, DiscoveryCategory>{};
      for (final raw in data['items'] as List) {
        if (raw is! Map<String, dynamic>) continue;
        final id = raw['id']?.toString().trim() ?? '';
        final name =
            raw['name']?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ??
            '';
        if (!RegExp(r'^[1-9]\d{0,2}$').hasMatch(id) ||
            name.isEmpty ||
            name.length > 40) {
          continue;
        }
        byId.putIfAbsent(id, () => DiscoveryCategory(id: id, name: name));
        if (byId.length == 12) break;
      }
      if (byId.isEmpty) {
        throw const FormatException('Discovery categories are empty');
      }
      final updatedAt = (data['updatedAt'] as num?)?.toInt() ?? 0;
      return DiscoveryCategories(
        updatedAt: updatedAt <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updatedAt),
        items: byId.values.toList(growable: false),
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi danh mục Khám phá không hợp lệ.',
      );
    }
  }

  @override
  Future<DiscoveryHome> getDiscoveryHome({String categoryId = '-1'}) async {
    final normalizedCategoryId = categoryId.trim();
    if (!RegExp(r'^(?:-1|[1-9]\d{0,2})$').hasMatch(normalizedCategoryId)) {
      throw const MusicRepositoryException('Danh mục Khám phá không hợp lệ.');
    }
    try {
      final response = await _dio.get<dynamic>(
        '/v1/discovery/home',
        queryParameters: {'categoryId': normalizedCategoryId},
      );
      final data = response.data;
      final rawVideos = data is Map<String, dynamic> ? data['videos'] : null;
      if (data is! Map<String, dynamic> ||
          data['quickPlay'] is! List ||
          data['banners'] is! List ||
          data['sections'] is! List ||
          (rawVideos != null && rawVideos is! List)) {
        throw const FormatException('Missing discovery home');
      }
      if (data['categoryId']?.toString().trim() != normalizedCategoryId) {
        throw const FormatException('Mismatched discovery category');
      }
      final quickPlay = (data['quickPlay'] as List)
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => DiscoveryCollection(
              collection: _collectionFromJson(json),
              description: json['description']?.toString().trim() ?? '',
            ),
          )
          .where(
            (item) =>
                item.collection.id.isNotEmpty &&
                item.collection.title.isNotEmpty &&
                item.collection.thumbnail.isNotEmpty &&
                item.collection.externalUrl.isNotEmpty,
          )
          .take(10)
          .toList(growable: false);
      final banners = (data['banners'] as List)
          .whereType<Map<String, dynamic>>()
          .map((json) {
            final rawCollection = json['collection'];
            return DiscoveryBanner(
              id: json['id']?.toString().trim() ?? '',
              image: json['image']?.toString().trim() ?? '',
              collection: rawCollection is Map<String, dynamic>
                  ? _collectionFromJson(rawCollection)
                  : null,
            );
          })
          .where((banner) => banner.id.isNotEmpty && banner.image.isNotEmpty)
          .toList(growable: false);
      final videos = (rawVideos is List ? rawVideos : const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(_catalogVideoFromJson)
          .take(12)
          .toList(growable: false);
      final sections = (data['sections'] as List)
          .whereType<Map<String, dynamic>>()
          .map((json) {
            final rawCollections = json['collections'];
            if (rawCollections is! List) {
              throw const FormatException('Missing discovery collections');
            }
            final collections = rawCollections
                .whereType<Map<String, dynamic>>()
                .map(
                  (item) => DiscoveryCollection(
                    collection: _collectionFromJson(item),
                    description: item['description']?.toString().trim() ?? '',
                  ),
                )
                .where(
                  (item) =>
                      item.collection.id.isNotEmpty &&
                      item.collection.title.isNotEmpty,
                )
                .toList(growable: false);
            return DiscoverySection(
              id: json['id']?.toString().trim() ?? '',
              title: json['title']?.toString().trim() ?? '',
              collections: collections,
            );
          })
          .where(
            (section) =>
                section.id.isNotEmpty &&
                section.title.isNotEmpty &&
                section.collections.isNotEmpty,
          )
          .toList(growable: false);
      if (quickPlay.isEmpty &&
          banners.isEmpty &&
          videos.isEmpty &&
          sections.isEmpty) {
        throw const FormatException('Discovery home has no usable content');
      }
      final updatedAt = (data['updatedAt'] as num?)?.toInt() ?? 0;
      return DiscoveryHome(
        categoryId: normalizedCategoryId,
        updatedAt: updatedAt <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updatedAt),
        quickPlay: quickPlay,
        banners: banners,
        videos: videos,
        sections: sections,
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi trang Khám phá không hợp lệ.',
      );
    }
  }

  @override
  Future<DiscoveryRecommendations> getDiscoveryRecommendations() async {
    try {
      final response = await _dio.get<dynamic>('/v1/discovery/recommendations');
      final data = response.data;
      if (data is! Map<String, dynamic> || data['songs'] is! List) {
        throw const FormatException('Missing discovery recommendations');
      }
      final entries = (data['songs'] as List)
          .whereType<Map<String, dynamic>>()
          .map(_catalogSongFromJson)
          .where(
            (entry) =>
                entry.playable &&
                entry.song.id.isNotEmpty &&
                entry.song.displayTitle.isNotEmpty,
          )
          .take(12)
          .toList(growable: false);
      if (entries.isEmpty || data['catalogPlaybackEnabled'] != true) {
        throw const FormatException('No playable discovery recommendations');
      }
      final updatedAt = (data['updatedAt'] as num?)?.toInt() ?? 0;
      return DiscoveryRecommendations(
        updatedAt: updatedAt <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updatedAt),
        entries: entries,
        catalogPlaybackEnabled: true,
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi gợi ý bài hát không hợp lệ.',
      );
    }
  }

  @override
  Future<CatalogHubHome> getHubHome() async {
    try {
      final response = await _dio.get<dynamic>('/v1/hubs');
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Missing hub home');
      }
      final featured = _hubListFromJson(data['featured']);
      final nations = _hubListFromJson(data['nations']);
      final topics = _hubListFromJson(data['topics']);
      final genres = _hubListFromJson(data['genres']);
      if (featured.isEmpty || genres.isEmpty) {
        throw const FormatException('Hub home has no catalog groups');
      }
      final updatedAt = (data['updatedAt'] as num?)?.toInt() ?? 0;
      return CatalogHubHome(
        updatedAt: updatedAt <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updatedAt),
        featured: featured,
        nations: nations,
        topics: topics,
        genres: genres,
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi Chủ đề & Thể loại không hợp lệ.',
      );
    }
  }

  @override
  Future<CatalogHubDetail> getHubDetail(String id) async {
    final normalizedId = id.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalizedId)) {
      throw const MusicRepositoryException('Mã chủ đề không hợp lệ.');
    }
    try {
      final response = await _dio.get<dynamic>(
        '/v1/hubs/${Uri.encodeComponent(normalizedId)}',
      );
      final data = response.data;
      if (data is! Map<String, dynamic> || data['sections'] is! List) {
        throw const FormatException('Missing hub detail');
      }
      final hub = _hubFromJson(data);
      final sections = _sectionListFromJson(data['sections']);
      if (hub.id != normalizedId || sections.isEmpty) {
        throw const FormatException('Invalid hub detail');
      }
      return CatalogHubDetail(hub: hub, sections: sections);
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi chi tiết chủ đề không hợp lệ.',
      );
    }
  }

  @override
  Future<Top100Catalog> getTop100() async {
    try {
      final response = await _dio.get<dynamic>('/v1/top-100');
      final data = response.data;
      if (data is! Map<String, dynamic> || data['sections'] is! List) {
        throw const FormatException('Missing Top 100');
      }
      final sections = _sectionListFromJson(data['sections']);
      if (sections.isEmpty) {
        throw const FormatException('Top 100 has no sections');
      }
      final updatedAt = (data['updatedAt'] as num?)?.toInt() ?? 0;
      return Top100Catalog(
        updatedAt: updatedAt <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updatedAt),
        sections: sections,
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException('Phản hồi Top 100 không hợp lệ.');
    }
  }

  @override
  Future<ReleaseCatalog> getReleaseCatalog() async {
    try {
      final response = await _dio.get<dynamic>('/v1/releases');
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['songs'] is! List ||
          data['albums'] is! List) {
        throw const FormatException('Missing release catalog');
      }
      final songs = (data['songs'] as List)
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => ReleaseSong(
              catalogSong: _catalogSongFromJson(json),
              releasedAt: _releasedAtFromJson(json),
              region: releaseRegionFromWire(
                json['region']?.toString().trim() ?? '',
              ),
            ),
          )
          .where(
            (item) =>
                item.song.id.isNotEmpty && item.song.displayTitle.isNotEmpty,
          )
          .toList(growable: false);
      final albums = (data['albums'] as List)
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => ReleaseAlbum(
              collection: _collectionFromJson(json),
              releasedAt: _releasedAtFromJson(json),
              region: releaseRegionFromWire(
                json['region']?.toString().trim() ?? '',
              ),
            ),
          )
          .where(
            (item) =>
                item.collection.id.isNotEmpty &&
                item.collection.title.isNotEmpty &&
                item.collection.kind == CatalogCollectionKind.album,
          )
          .toList(growable: false);
      if (songs.isEmpty || albums.isEmpty) {
        throw const FormatException('Release catalog has no usable items');
      }
      final updatedAt = (data['updatedAt'] as num?)?.toInt() ?? 0;
      return ReleaseCatalog(
        updatedAt: updatedAt <= 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updatedAt),
        songs: songs,
        albums: albums,
        catalogPlaybackEnabled: data['catalogPlaybackEnabled'] == true,
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi Mới Phát Hành không hợp lệ.',
      );
    }
  }

  @override
  Future<CatalogSearchResult> searchCatalog(String query) async {
    final normalizedQuery = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedQuery.isEmpty || normalizedQuery.length > 100) {
      throw const MusicRepositoryException(
        'Từ khóa tìm kiếm phải có từ 1 đến 100 ký tự.',
      );
    }

    try {
      final response = await _dio.get<dynamic>(
        '/v1/search',
        queryParameters: {'q': normalizedQuery},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Missing search payload');
      }
      final rawSongs = data['songs'];
      final rawArtists = data['artists'];
      final rawCollections = data['collections'];
      final rawVideos = data['videos'];
      if (rawSongs is! List ||
          rawArtists is! List ||
          rawCollections is! List ||
          rawVideos is! List) {
        throw const FormatException('Missing search results');
      }

      final songs = rawSongs
          .whereType<Map<String, dynamic>>()
          .map(_catalogSongFromJson)
          .where(
            (item) =>
                item.song.id.isNotEmpty && item.song.displayTitle.isNotEmpty,
          )
          .toList(growable: false);
      final artists = rawArtists
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => CatalogArtist(
              id: json['id']?.toString().trim() ?? '',
              name: json['name']?.toString().trim() ?? '',
              aliasName: json['aliasName']?.toString().trim() ?? '',
              avatar: json['avatar']?.toString().trim() ?? '',
              externalUrl: json['externalUrl']?.toString().trim() ?? '',
              totalFollow: ((json['totalFollow'] as num?)?.toInt() ?? 0)
                  .clamp(0, 2147483647)
                  .toInt(),
            ),
          )
          .where(
            (artist) =>
                artist.id.isNotEmpty &&
                artist.name.isNotEmpty &&
                artist.aliasName.isNotEmpty &&
                _isTrustedArtistPage(Uri.tryParse(artist.officialExternalUrl)),
          )
          .toList(growable: false);
      final collections = rawCollections
          .whereType<Map<String, dynamic>>()
          .map(_collectionFromJson)
          .where(
            (collection) =>
                collection.id.isNotEmpty && collection.title.isNotEmpty,
          )
          .toList(growable: false);
      final videos = rawVideos
          .whereType<Map<String, dynamic>>()
          .map(_catalogVideoFromJson)
          .take(20)
          .toList(growable: false);
      return CatalogSearchResult(
        query: data['query']?.toString().trim() ?? normalizedQuery,
        songs: songs,
        artists: artists,
        collections: collections,
        videos: videos,
        catalogPlaybackEnabled: data['catalogPlaybackEnabled'] == true,
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException('Phản hồi tìm kiếm không hợp lệ.');
    }
  }

  @override
  Future<SearchSuggestionSnapshot> getSearchSuggestions(String query) async {
    final normalizedQuery = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedQuery.isEmpty || normalizedQuery.length > 100) {
      throw const MusicRepositoryException(
        'Từ khóa gợi ý phải có từ 1 đến 100 ký tự.',
      );
    }
    try {
      final response = await _dio.get<dynamic>(
        '/v1/search/suggestions',
        queryParameters: {'q': normalizedQuery},
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['keywords'] is! List ||
          data['songs'] is! List) {
        throw const FormatException('Missing search suggestions');
      }
      final responseQuery = data['query']?.toString().trim() ?? '';
      if (responseQuery.toLowerCase() != normalizedQuery.toLowerCase()) {
        throw const FormatException('Mismatched suggestion query');
      }
      final keywordByKey = <String, String>{};
      for (final rawKeyword in data['keywords'] as List) {
        if (rawKeyword is! String) continue;
        final keyword = rawKeyword.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (keyword.isEmpty || keyword.length > 100) continue;
        keywordByKey.putIfAbsent(keyword.toLowerCase(), () => keyword);
        if (keywordByKey.length == 4) break;
      }
      final songs = (data['songs'] as List)
          .whereType<Map<String, dynamic>>()
          .map((json) {
            final externalUrl = json['externalUrl']?.toString().trim() ?? '';
            final uri = Uri.tryParse(externalUrl);
            if (!_isTrustedCatalogPage(uri)) {
              throw const FormatException('Untrusted suggestion URL');
            }
            return SearchSuggestionSong(
              id: json['id']?.toString().trim() ?? '',
              title: json['title']?.toString().trim() ?? '',
              artist: json['artist']?.toString().trim() ?? '',
              thumbnail: json['thumbnail']?.toString().trim() ?? '',
              duration: Duration(
                seconds: ((json['durationSeconds'] as num?)?.toInt() ?? 0)
                    .clamp(0, 86400),
              ),
              externalUrl: externalUrl,
            );
          })
          .where((song) => song.id.isNotEmpty && song.title.isNotEmpty)
          .take(6)
          .toList(growable: false);
      return SearchSuggestionSnapshot(
        query: normalizedQuery,
        keywords: keywordByKey.values.toList(growable: false),
        songs: songs,
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi gợi ý tìm kiếm không hợp lệ.',
      );
    }
  }

  @override
  Future<CatalogArtistDetail> getArtistDetail(String alias) async {
    final normalizedAlias = alias.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalizedAlias)) {
      throw const MusicRepositoryException('Định danh nghệ sĩ không hợp lệ.');
    }
    try {
      final response = await _dio.get<dynamic>(
        '/v1/artists/${Uri.encodeComponent(normalizedAlias)}',
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Missing artist payload');
      }
      final rawArtist = data['artist'];
      final rawFeaturedSongs = data['featuredSongs'];
      final rawSongs = data['songs'];
      final rawVideos = data['videos'];
      final rawSections = data['collectionSections'];
      final rawRelated = data['relatedArtists'];
      if (rawArtist is! Map<String, dynamic> ||
          rawSongs is! List ||
          (rawFeaturedSongs != null && rawFeaturedSongs is! List) ||
          (rawVideos != null && rawVideos is! List) ||
          rawSections is! List ||
          rawRelated is! List) {
        throw const FormatException('Missing artist catalog');
      }
      final artist = _artistFromJson(rawArtist);
      if (artist.id.isEmpty ||
          artist.name.isEmpty ||
          artist.aliasName.toLowerCase() != normalizedAlias.toLowerCase() ||
          !_isTrustedArtistPage(Uri.tryParse(artist.officialExternalUrl))) {
        throw const FormatException('Invalid artist metadata');
      }
      final songs = rawSongs
          .whereType<Map<String, dynamic>>()
          .map(_catalogSongFromJson)
          .where(
            (item) =>
                item.song.id.isNotEmpty && item.song.displayTitle.isNotEmpty,
          )
          .toList(growable: false);
      final parsedFeaturedSongs = (rawFeaturedSongs as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_catalogSongFromJson)
          .where(
            (item) =>
                item.song.id.isNotEmpty && item.song.displayTitle.isNotEmpty,
          )
          .take(6)
          .toList(growable: false);
      final featuredSongs = parsedFeaturedSongs.isNotEmpty
          ? parsedFeaturedSongs
          : songs.take(6).toList(growable: false);
      final sections = rawSections
          .whereType<Map<String, dynamic>>()
          .map((json) {
            final rawCollections = json['collections'];
            final collections = rawCollections is List
                ? rawCollections
                      .whereType<Map<String, dynamic>>()
                      .map(_collectionFromJson)
                      .where(
                        (collection) =>
                            collection.id.isNotEmpty &&
                            collection.title.isNotEmpty,
                      )
                      .toList(growable: false)
                : const <CatalogCollection>[];
            return CatalogArtistCollectionSection(
              id: json['id']?.toString().trim() ?? '',
              title: json['title']?.toString().trim() ?? '',
              collections: collections,
            );
          })
          .where(
            (section) =>
                section.id.isNotEmpty &&
                section.title.isNotEmpty &&
                section.collections.isNotEmpty,
          )
          .toList(growable: false);
      final videos = (rawVideos as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_catalogVideoFromJson)
          .take(50)
          .toList(growable: false);
      if (songs.isEmpty && videos.isEmpty && sections.isEmpty) {
        throw const FormatException('Artist has no usable catalog');
      }
      final relatedArtists = rawRelated
          .whereType<Map<String, dynamic>>()
          .map(_artistFromJson)
          .where(
            (item) =>
                item.id.isNotEmpty &&
                item.name.isNotEmpty &&
                item.aliasName.isNotEmpty &&
                _isTrustedArtistPage(Uri.tryParse(item.officialExternalUrl)) &&
                item.id != artist.id,
          )
          .toList(growable: false);
      return CatalogArtistDetail(
        artist: artist,
        cover: data['cover']?.toString().trim() ?? '',
        biography: data['biography']?.toString().trim() ?? '',
        realName: data['realName']?.toString().trim() ?? '',
        national: data['national']?.toString().trim() ?? '',
        birthday: data['birthday']?.toString().trim() ?? '',
        totalFollow: ((data['totalFollow'] as num?)?.toInt() ?? 0).clamp(
          0,
          2147483647,
        ),
        awardCount: ((data['awardCount'] as num?)?.toInt() ?? 0).clamp(
          0,
          2147483647,
        ),
        songs: songs,
        featuredSongs: featuredSongs,
        videos: videos,
        collectionSections: sections,
        relatedArtists: relatedArtists,
        catalogPlaybackEnabled: data['catalogPlaybackEnabled'] == true,
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi hồ sơ nghệ sĩ không hợp lệ.',
      );
    }
  }

  @override
  Future<CatalogCollectionDetail> getCollection(String id) async {
    final normalizedId = id.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalizedId)) {
      throw const MusicRepositoryException('Mã playlist/album không hợp lệ.');
    }
    try {
      final response = await _dio.get<dynamic>(
        '/v1/collections/${Uri.encodeComponent(normalizedId)}',
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Missing collection payload');
      }
      final rawSongs = data['songs'];
      final rawGenres = data['genres'];
      final rawArtists = data['artists'];
      final rawSections = data['sections'];
      if (rawSongs is! List || rawGenres is! List || rawArtists is! List) {
        throw const FormatException('Missing collection tracks');
      }
      if (rawSections != null && rawSections is! List) {
        throw const FormatException('Invalid collection sections');
      }
      final collection = _collectionFromJson(data);
      if (collection.id.isEmpty || collection.title.isEmpty) {
        throw const FormatException('Invalid collection metadata');
      }
      final songs = rawSongs
          .whereType<Map<String, dynamic>>()
          .map(_catalogSongFromJson)
          .where(
            (item) =>
                item.song.id.isNotEmpty && item.song.displayTitle.isNotEmpty,
          )
          .toList(growable: false);
      if (songs.isEmpty) {
        throw const FormatException('Collection has no songs');
      }
      final likeCount = (data['likeCount'] as num?)?.toInt() ?? -1;
      if (likeCount < 0 || likeCount > 9007199254740991) {
        throw const FormatException('Invalid collection like count');
      }
      final releasedAtMs = (data['releasedAt'] as num?)?.toInt() ?? 0;
      if (releasedAtMs < 0 || releasedAtMs > 32503680000000) {
        throw const FormatException('Invalid collection release date');
      }
      final distributor = data['distributor']?.toString().trim() ?? '';
      if (distributor.length > 200) {
        throw const FormatException('Invalid collection distributor');
      }
      final artistsById = <String, CatalogArtist>{};
      for (final rawArtist in rawArtists.whereType<Map<String, dynamic>>()) {
        final artist = _artistFromJson(rawArtist);
        if (artist.id.isEmpty ||
            artist.name.isEmpty ||
            !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(artist.id) ||
            !RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(artist.aliasName) ||
            !_isTrustedArtistPage(Uri.tryParse(artist.officialExternalUrl))) {
          continue;
        }
        artistsById.putIfAbsent(artist.id, () => artist);
        if (artistsById.length == 8) break;
      }
      return CatalogCollectionDetail(
        collection: collection,
        artists: artistsById.values.toList(growable: false),
        description: data['description']?.toString().trim() ?? '',
        year: data['year']?.toString().trim() ?? '',
        releasedAt: releasedAtMs == 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(releasedAtMs),
        distributor: distributor,
        likeCount: likeCount,
        genres: rawGenres
            .map((genre) => genre.toString().trim())
            .where((genre) => genre.isNotEmpty)
            .toList(growable: false),
        songs: songs,
        sections: _collectionSectionsFromJson(rawSections ?? const []),
        catalogPlaybackEnabled: data['catalogPlaybackEnabled'] == true,
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi playlist/album không hợp lệ.',
      );
    }
  }

  CatalogCollection _collectionFromJson(Map<String, dynamic> json) {
    final kind = json['kind']?.toString().trim();
    final artists = _catalogArtistsFromJson(json['artists']);
    return CatalogCollection(
      id: json['id']?.toString().trim() ?? '',
      title: json['title']?.toString().trim() ?? '',
      artist: json['artist']?.toString().trim() ?? '',
      artists: artists,
      thumbnail: json['thumbnail']?.toString().trim() ?? '',
      kind: kind == 'album'
          ? CatalogCollectionKind.album
          : CatalogCollectionKind.playlist,
      externalUrl: json['externalUrl']?.toString().trim() ?? '',
    );
  }

  List<CatalogArtist> _catalogArtistsFromJson(Object? value) {
    if (value == null) return const [];
    if (value is! List) throw const FormatException('Invalid artists');
    final byId = <String, CatalogArtist>{};
    for (final raw in value.take(20).whereType<Map<String, dynamic>>()) {
      final artist = _artistFromJson(raw);
      if (artist.id.isEmpty ||
          artist.name.isEmpty ||
          artist.name.length > 300 ||
          !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(artist.id) ||
          !RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(artist.aliasName) ||
          !_isSafeHttpsResource(artist.avatar) ||
          !_isTrustedArtistPage(Uri.tryParse(artist.officialExternalUrl))) {
        continue;
      }
      byId.putIfAbsent(artist.id, () => artist);
      if (byId.length == 8) break;
    }
    return List<CatalogArtist>.unmodifiable(byId.values);
  }

  CatalogArtist _artistFromJson(Map<String, dynamic> json) => CatalogArtist(
    id: json['id']?.toString().trim() ?? '',
    name: json['name']?.toString().trim() ?? '',
    aliasName: json['aliasName']?.toString().trim() ?? '',
    avatar: json['avatar']?.toString().trim() ?? '',
    externalUrl: json['externalUrl']?.toString().trim() ?? '',
    totalFollow: ((json['totalFollow'] as num?)?.toInt() ?? 0)
        .clamp(0, 2147483647)
        .toInt(),
  );

  List<DiscoverySection> _sectionListFromJson(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map((json) {
          final collections = _discoveryCollectionsFromJson(
            json['collections'],
          );
          return DiscoverySection(
            id: json['id']?.toString().trim() ?? '',
            title: json['title']?.toString().trim() ?? '',
            collections: collections,
          );
        })
        .where(
          (section) =>
              section.id.isNotEmpty &&
              section.title.isNotEmpty &&
              section.collections.isNotEmpty,
        )
        .toList(growable: false);
  }

  List<DiscoveryCollection> _discoveryCollectionsFromJson(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => DiscoveryCollection(
            collection: _collectionFromJson(item),
            description: item['description']?.toString().trim() ?? '',
          ),
        )
        .where(
          (item) =>
              item.collection.id.isNotEmpty && item.collection.title.isNotEmpty,
        )
        .toList(growable: false);
  }

  List<CatalogCollectionSection> _collectionSectionsFromJson(Object? value) {
    if (value is! List || value.length > 4) return const [];
    final sectionIds = <String>{};
    final result = <CatalogCollectionSection>[];
    for (final rawSection in value.whereType<Map<String, dynamic>>()) {
      final id = rawSection['id']?.toString().trim() ?? '';
      final title = rawSection['title']?.toString().trim() ?? '';
      final rawCollections = rawSection['collections'];
      if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ||
          title.isEmpty ||
          title.length > 200 ||
          rawCollections is! List ||
          sectionIds.contains(id)) {
        continue;
      }
      final collectionsById = <String, CatalogCollection>{};
      for (final raw in rawCollections.whereType<Map<String, dynamic>>().take(
        20,
      )) {
        final collection = _collectionFromJson(raw);
        if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(collection.id) ||
            collection.title.isEmpty ||
            collection.title.length > 300 ||
            collection.artist.length > 300 ||
            !_isSafeHttpsResource(collection.thumbnail) ||
            !_isTrustedCollectionPage(Uri.tryParse(collection.externalUrl))) {
          continue;
        }
        collectionsById.putIfAbsent(collection.id, () => collection);
        if (collectionsById.length == 12) break;
      }
      if (collectionsById.isEmpty) continue;
      sectionIds.add(id);
      result.add(
        CatalogCollectionSection(
          id: id,
          title: title,
          collections: collectionsById.values.toList(growable: false),
        ),
      );
    }
    return result;
  }

  List<CatalogHub> _hubListFromJson(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(_hubFromJson)
        .where((hub) => hub.id.isNotEmpty && hub.title.isNotEmpty)
        .toList(growable: false);
  }

  CatalogHub _hubFromJson(Map<String, dynamic> json) => CatalogHub(
    id: json['id']?.toString().trim() ?? '',
    title: json['title']?.toString().trim() ?? '',
    description: json['description']?.toString().trim() ?? '',
    image: json['image']?.toString().trim() ?? '',
    externalUrl: json['externalUrl']?.toString().trim() ?? '',
    collections: _discoveryCollectionsFromJson(json['collections']),
  );

  CatalogSong _catalogSongFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    final code = json['code']?.toString().trim() ?? '';
    final idPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    final artists = _catalogArtistsFromJson(json['artists']);
    CatalogCollection? album;
    final rawAlbum = json['album'];
    if (rawAlbum is Map<String, dynamic>) {
      final candidate = _collectionFromJson(rawAlbum);
      if (candidate.kind == CatalogCollectionKind.album &&
          idPattern.hasMatch(candidate.id) &&
          candidate.title.isNotEmpty &&
          candidate.title.length <= 300 &&
          _isSafeHttpsResource(candidate.thumbnail) &&
          _isTrustedCollectionPage(Uri.tryParse(candidate.externalUrl))) {
        album = candidate;
      }
    }
    final rawDurationSeconds = (json['durationSeconds'] as num?)?.toInt() ?? 0;
    return CatalogSong(
      song: Song(
        id: id,
        name: title,
        title: title,
        thumbnail: json['albumCover']?.toString().trim() ?? '',
        artistsNames: json['artist']?.toString().trim() ?? '',
        code: code,
      ),
      duration: Duration(seconds: rawDurationSeconds.clamp(0, 86_400)),
      externalUrl: json['externalUrl']?.toString().trim() ?? '',
      playable: json['playable'] == true && code.isNotEmpty,
      hasLyrics: json['hasLyrics'] == true,
      artists: artists,
      album: album,
    );
  }

  CatalogVideo _catalogVideoFromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final title = json['title']?.toString().trim() ?? '';
    final artist = json['artist']?.toString().trim() ?? '';
    final thumbnail = json['thumbnail']?.toString().trim() ?? '';
    final durationSeconds = (json['durationSeconds'] as num?)?.toInt() ?? -1;
    final externalUrl = json['externalUrl']?.toString().trim() ?? '';
    final artists = _catalogArtistsFromJson(json['artists']);
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ||
        title.isEmpty ||
        title.length > 300 ||
        artist.length > 300 ||
        durationSeconds < 0 ||
        durationSeconds > 24 * 60 * 60 ||
        !_isSafeHttpsResource(thumbnail) ||
        !_isTrustedVideoPage(Uri.tryParse(externalUrl))) {
      throw const FormatException('Invalid catalog video');
    }
    return CatalogVideo(
      id: id,
      title: title,
      artist: artist,
      artists: artists,
      thumbnail: thumbnail,
      duration: Duration(seconds: durationSeconds),
      externalUrl: externalUrl,
    );
  }

  DateTime? _releasedAtFromJson(Map<String, dynamic> json) {
    final seconds = (json['releasedAt'] as num?)?.toInt() ?? 0;
    return seconds <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  @override
  Future<SongDetail> getSongDetail(String songId) async {
    final normalizedSongId = songId.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalizedSongId)) {
      throw const MusicRepositoryException('Mã bài hát không hợp lệ.');
    }
    try {
      final response = await _dio.get<dynamic>(
        '/v1/songs/${Uri.encodeComponent(normalizedSongId)}/detail',
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['song'] is! Map<String, dynamic> ||
          data['artists'] is! List ||
          data['genres'] is! List ||
          data['composers'] is! List) {
        throw const FormatException('Missing song detail');
      }

      final catalogSong = _catalogSongFromJson(
        data['song'] as Map<String, dynamic>,
      );
      final song = catalogSong.song;
      final durationSeconds = catalogSong.duration.inSeconds;
      if (song.id != normalizedSongId ||
          song.code != normalizedSongId ||
          song.displayTitle.isEmpty ||
          song.displayTitle.length > 300 ||
          song.artistsNames.length > 300 ||
          durationSeconds < 0 ||
          durationSeconds > 24 * 60 * 60 ||
          !_isTrustedCatalogPage(Uri.tryParse(catalogSong.externalUrl)) ||
          !_isSafeHttpsResource(song.thumbnail)) {
        throw const FormatException('Invalid song detail metadata');
      }

      List<CatalogArtist> parsePeople(Object? value) {
        if (value is! List || value.length > 8) {
          throw const FormatException('Invalid song contributors');
        }
        return value
            .map((raw) {
              if (raw is! Map<String, dynamic>) {
                throw const FormatException('Invalid song contributor');
              }
              final artist = _artistFromJson(raw);
              if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(artist.id) ||
                  artist.name.isEmpty ||
                  artist.name.length > 200 ||
                  artist.aliasName.isEmpty ||
                  artist.aliasName.length > 200 ||
                  !_isTrustedArtistPage(
                    Uri.tryParse(artist.officialExternalUrl),
                  ) ||
                  !_isSafeHttpsResource(artist.avatar)) {
                throw const FormatException('Invalid song contributor');
              }
              return artist;
            })
            .toList(growable: false);
      }

      CatalogCollection? album;
      final rawAlbum = data['album'];
      if (rawAlbum != null) {
        if (rawAlbum is! Map<String, dynamic>) {
          throw const FormatException('Invalid song album');
        }
        album = _collectionFromJson(rawAlbum);
        if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(album.id) ||
            album.title.isEmpty ||
            album.title.length > 300 ||
            album.kind != CatalogCollectionKind.album ||
            !_isSafeHttpsResource(album.thumbnail) ||
            !_isTrustedCollectionPage(Uri.tryParse(album.externalUrl))) {
          throw const FormatException('Invalid song album');
        }
      }

      final rawGenres = data['genres'] as List;
      if (rawGenres.length > 8) {
        throw const FormatException('Invalid song genres');
      }
      final genres = rawGenres
          .map((raw) => raw.toString().trim())
          .toList(growable: false);
      if (genres.any((genre) => genre.isEmpty || genre.length > 80)) {
        throw const FormatException('Invalid song genre');
      }

      int parseCount(String key) {
        final value = data[key];
        if (value is! num ||
            !value.isFinite ||
            value < 0 ||
            value > 9007199254740991 ||
            value != value.roundToDouble()) {
          throw const FormatException('Invalid song counter');
        }
        return value.toInt();
      }

      final releasedAtMs = (data['releasedAt'] as num?)?.toInt() ?? -1;
      if (releasedAtMs < 0 || releasedAtMs > 32503680000000) {
        throw const FormatException('Invalid song release date');
      }
      final distributor = data['distributor']?.toString().trim() ?? '';
      if (distributor.length > 200) {
        throw const FormatException('Invalid song distributor');
      }

      CatalogVideo? mv;
      final rawMv = data['mv'];
      if (rawMv != null) {
        if (rawMv is! Map<String, dynamic>) {
          throw const FormatException('Invalid song MV');
        }
        final candidate = _catalogVideoFromJson(rawMv);
        if (candidate.id != normalizedSongId) {
          throw const FormatException('Invalid song MV');
        }
        mv = candidate;
      }

      return SongDetail(
        catalogSong: catalogSong,
        artists: parsePeople(data['artists']),
        album: album,
        releasedAt: releasedAtMs == 0
            ? null
            : DateTime.fromMillisecondsSinceEpoch(releasedAtMs),
        distributor: distributor,
        genres: genres,
        composers: parsePeople(data['composers']),
        listenCount: parseCount('listenCount'),
        likeCount: parseCount('likeCount'),
        commentCount: parseCount('commentCount'),
        mv: mv,
        catalogPlaybackEnabled: data['catalogPlaybackEnabled'] == true,
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi thông tin bài hát không hợp lệ.',
      );
    }
  }

  @override
  Future<SongLyrics> getSongLyrics(String code) async {
    final normalizedCode = code.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalizedCode)) {
      throw const MusicRepositoryException('Mã bài hát không hợp lệ.');
    }
    try {
      final response = await _dio.get<dynamic>(
        '/v1/songs/${Uri.encodeComponent(normalizedCode)}/lyrics',
      );
      final data = response.data;
      if (data is! Map<String, dynamic> || data['lines'] is! List) {
        throw const FormatException('Missing lyrics');
      }
      final songId = data['songId']?.toString().trim() ?? '';
      final synced = data['synced'] == true;
      if (songId != normalizedCode) {
        throw const FormatException('Mismatched lyric song');
      }
      final lines = <LyricLine>[];
      var previousStart = -1;
      const maxLyricTimeMs = 24 * 60 * 60 * 1000;
      for (final raw in data['lines'] as List) {
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Invalid lyric line');
        }
        final text = raw['text']?.toString().trim() ?? '';
        final start = (raw['startTimeMs'] as num?)?.toInt() ?? -1;
        final end = (raw['endTimeMs'] as num?)?.toInt() ?? -1;
        final validTiming = synced
            ? start >= 0 &&
                  end > start &&
                  end <= maxLyricTimeMs &&
                  start >= previousStart
            : start == 0 && end == 0;
        if (text.isEmpty || text.length > 500 || !validTiming) {
          throw const FormatException('Invalid lyric line');
        }
        final rawWords = raw['words'];
        if (rawWords != null && rawWords is! List) {
          throw const FormatException('Invalid lyric words');
        }
        final words = <LyricWord>[];
        var previousWordStart = -1;
        for (final rawWord in rawWords is List ? rawWords : const []) {
          if (!synced || rawWord is! Map<String, dynamic>) {
            throw const FormatException('Invalid lyric word');
          }
          final wordText = rawWord['text']?.toString().trim() ?? '';
          final wordStart = (rawWord['startTimeMs'] as num?)?.toInt() ?? -1;
          final wordEnd = (rawWord['endTimeMs'] as num?)?.toInt() ?? -1;
          if (wordText.isEmpty ||
              wordText.length > 80 ||
              wordStart < start ||
              wordEnd <= wordStart ||
              wordEnd > end ||
              wordStart < previousWordStart) {
            throw const FormatException('Invalid lyric word');
          }
          words.add(
            LyricWord(
              start: Duration(milliseconds: wordStart),
              end: Duration(milliseconds: wordEnd),
              text: wordText,
            ),
          );
          previousWordStart = wordStart;
          if (words.length > 100) {
            throw const FormatException('Too many lyric words');
          }
        }
        lines.add(
          LyricLine(
            start: Duration(milliseconds: start),
            end: Duration(milliseconds: end),
            text: text,
            words: List.unmodifiable(words),
          ),
        );
        previousStart = start;
        if (lines.length > 500) {
          throw const FormatException('Too many lyric lines');
        }
      }
      return SongLyrics(
        songId: songId,
        synced: synced && lines.isNotEmpty,
        lines: List.unmodifiable(lines),
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException(
        'Phản hồi lời bài hát không hợp lệ.',
      );
    }
  }

  @override
  Future<SongRadio> getSongRadio(String code) async {
    final normalizedCode = code.trim();
    final codePattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    if (!codePattern.hasMatch(normalizedCode)) {
      throw const MusicRepositoryException('Mã bài hát không hợp lệ.');
    }
    try {
      final response = await _dio.get<dynamic>(
        '/v1/songs/${Uri.encodeComponent(normalizedCode)}/radio',
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['songs'] is! List ||
          data['seedId']?.toString().trim() != normalizedCode ||
          data['catalogPlaybackEnabled'] != true) {
        throw const FormatException('Missing song radio');
      }
      final rawSongs = data['songs'] as List;
      if (rawSongs.length > 30) {
        throw const FormatException('Too many radio songs');
      }
      final seen = <String>{normalizedCode};
      final recommendations = <CatalogSong>[];
      for (final raw in rawSongs) {
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Invalid radio song');
        }
        final id = raw['id']?.toString().trim() ?? '';
        final songCode = raw['code']?.toString().trim() ?? '';
        final title = raw['title']?.toString().trim() ?? '';
        final duration = (raw['durationSeconds'] as num?)?.toInt() ?? -1;
        final externalUrl = raw['externalUrl']?.toString().trim() ?? '';
        final externalUri = externalUrl.isEmpty
            ? null
            : Uri.tryParse(externalUrl);
        if (!codePattern.hasMatch(id) ||
            songCode != id ||
            title.isEmpty ||
            title.length > 300 ||
            raw['playable'] != true ||
            duration < 0 ||
            duration > 24 * 60 * 60 ||
            !seen.add(id) ||
            (externalUri != null &&
                (!externalUri.hasAuthority || externalUri.scheme != 'https'))) {
          throw const FormatException('Invalid radio song');
        }
        recommendations.add(_catalogSongFromJson(raw));
      }
      return SongRadio(
        seedId: normalizedCode,
        recommendations: List.unmodifiable(recommendations),
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException('Phản hồi Song Radio không hợp lệ.');
    }
  }

  @override
  Future<LiveRadioSnapshot> getLiveRadio() async {
    final idPattern = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
    bool safeAsset(String value) {
      if (value.isEmpty) return true;
      final uri = Uri.tryParse(value);
      return uri != null &&
          uri.scheme == 'https' &&
          uri.hasAuthority &&
          uri.userInfo.isEmpty;
    }

    DateTime? timestamp(Object? value) {
      final milliseconds = (value as num?)?.toInt() ?? 0;
      if (milliseconds <= 0 || milliseconds > 4_102_444_800_000) return null;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }

    try {
      final response = await _dio.get<dynamic>('/v1/radio');
      final data = response.data;
      if (data is! Map<String, dynamic> || data['rooms'] is! List) {
        throw const FormatException('Missing live radio');
      }
      final rawRooms = data['rooms'] as List;
      if (rawRooms.isEmpty || rawRooms.length > 18) {
        throw const FormatException('Invalid live radio room count');
      }
      final seen = <String>{};
      final rooms = rawRooms
          .map((raw) {
            if (raw is! Map<String, dynamic> || raw.containsKey('streaming')) {
              throw const FormatException('Invalid live radio room');
            }
            final id = raw['id']?.toString().trim() ?? '';
            final title = raw['title']?.toString().trim() ?? '';
            final description = raw['description']?.toString().trim() ?? '';
            final thumbnail = raw['thumbnail']?.toString().trim() ?? '';
            final hostName = raw['hostName']?.toString().trim() ?? '';
            final hostThumbnail = raw['hostThumbnail']?.toString().trim() ?? '';
            final listeners = (raw['listenerCount'] as num?)?.toInt() ?? -1;
            if (!idPattern.hasMatch(id) ||
                !seen.add(id) ||
                title.isEmpty ||
                title.length > 200 ||
                description.length > 500 ||
                listeners < 0 ||
                listeners > 10_000_000 ||
                hostName.length > 200 ||
                !safeAsset(thumbnail) ||
                !safeAsset(hostThumbnail)) {
              throw const FormatException('Invalid live radio room');
            }
            LiveRadioProgram? program;
            final rawProgram = raw['program'];
            if (rawProgram != null) {
              if (rawProgram is! Map<String, dynamic>) {
                throw const FormatException('Invalid live radio program');
              }
              final programId = rawProgram['id']?.toString().trim() ?? '';
              final programTitle = rawProgram['title']?.toString().trim() ?? '';
              final programThumbnail =
                  rawProgram['thumbnail']?.toString().trim() ?? '';
              final programDescription =
                  rawProgram['description']?.toString().trim() ?? '';
              if (!idPattern.hasMatch(programId) ||
                  programTitle.isEmpty ||
                  programTitle.length > 200 ||
                  programDescription.length > 500 ||
                  !safeAsset(programThumbnail)) {
                throw const FormatException('Invalid live radio program');
              }
              program = LiveRadioProgram(
                id: programId,
                title: programTitle,
                thumbnail: programThumbnail,
                description: programDescription,
                startTime: timestamp(rawProgram['startTime']),
                endTime: timestamp(rawProgram['endTime']),
              );
            }
            return LiveRadioRoom(
              id: id,
              title: title,
              description: description,
              thumbnail: thumbnail,
              listenerCount: listeners,
              hostName: hostName,
              hostThumbnail: hostThumbnail,
              program: program,
            );
          })
          .toList(growable: false);
      return LiveRadioSnapshot(
        updatedAt: timestamp(data['updatedAt']),
        rooms: List.unmodifiable(rooms),
      );
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException('Phản hồi Phòng Nhạc không hợp lệ.');
    }
  }

  @override
  Future<String> getLiveRadioSource(String id) async {
    final normalizedId = id.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalizedId)) {
      throw const MusicRepositoryException('Mã phòng nhạc không hợp lệ.');
    }
    try {
      final response = await _dio.get<dynamic>(
        '/v1/radio/${Uri.encodeComponent(normalizedId)}/source',
      );
      final data = response.data;
      final source = data is Map<String, dynamic>
          ? data['url']?.toString().trim()
          : null;
      final uri = source == null ? null : Uri.tryParse(source);
      if (uri == null || !_isTrustedStreamUri(uri, path: 'live-streams')) {
        throw const MusicRepositoryException(
          'Nguồn Phòng Nhạc do máy chủ trả về không hợp lệ.',
        );
      }
      return uri.toString();
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException('Không thể đọc nguồn Phòng Nhạc.');
    }
  }

  @override
  Future<String> getSongSource(
    String code, {
    StreamingQualityPreference quality = StreamingQualityPreference.automatic,
  }) async {
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      throw const MusicRepositoryException('Bài hát không có mã phát nhạc.');
    }

    try {
      final response = await _dio.get<dynamic>(
        '/v1/songs/${Uri.encodeComponent(normalizedCode)}/source',
        queryParameters: {'quality': quality.apiValue},
      );
      final data = response.data;
      final source = data is Map<String, dynamic>
          ? data['url']?.toString().trim()
          : null;
      final uri = source == null ? null : Uri.tryParse(source);
      if (uri == null || !_isTrustedStreamUri(uri, path: 'streams')) {
        throw const MusicRepositoryException(
          'Nguồn phát do máy chủ trả về không hợp lệ.',
        );
      }
      return uri.toString();
    } on DioException catch (error) {
      throw MusicRepositoryException(_networkMessage(error));
    } on MusicRepositoryException {
      rethrow;
    } catch (_) {
      throw const MusicRepositoryException('Không thể đọc nguồn phát.');
    }
  }

  bool _isTrustedStreamUri(Uri uri, {required String path}) {
    final segments = uri.pathSegments;
    if (!uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        segments.length != 3 ||
        segments[0] != 'v1' ||
        segments[1] != path ||
        segments[2].isEmpty ||
        uri.scheme != _baseUri.scheme ||
        _effectivePort(uri) != _effectivePort(_baseUri)) {
      return false;
    }

    final sourceHost = uri.host.toLowerCase();
    final proxyHost = _baseUri.host.toLowerCase();
    if (sourceHost == proxyHost) return true;

    // Local development commonly mixes localhost and 127.0.0.1 between the
    // Flutter build and PUBLIC_BASE_URL. Both still resolve to the same local
    // proxy; release configuration never enters this HTTP-only exception.
    return uri.scheme == 'http' &&
        _isLoopbackHost(sourceHost) &&
        _isLoopbackHost(proxyHost);
  }

  int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    return uri.scheme == 'https' ? 443 : 80;
  }

  bool _isLoopbackHost(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '::1';

  String _networkMessage(DioException error) {
    final payload = error.response?.data;
    if (payload is Map<String, dynamic>) {
      final details = payload['error'];
      final message = details is Map<String, dynamic>
          ? details['message']?.toString().trim()
          : payload['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Kết nối proxy quá chậm. Vui lòng thử lại.';
    }
    return 'Không thể kết nối máy chủ âm nhạc.';
  }
}

class CachingMusicRepository implements MusicRepository {
  CachingMusicRepository(this._remote, {SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  static const _chartCacheKey = 'chart_cache_v1';
  static const _snapshotCacheKey = 'chart_snapshot_cache_v1';
  final MusicRepository _remote;
  SharedPreferencesAsync? _preferences;
  final Map<String, SongLyrics> _lyricsCache = {};
  final Map<String, Future<SongLyrics>> _pendingLyrics = {};
  final Map<String, SongDetail> _songDetailCache = {};
  final Map<String, Future<SongDetail>> _pendingSongDetail = {};
  final Map<String, SongRadio> _songRadioCache = {};
  final Map<String, Future<SongRadio>> _pendingSongRadio = {};
  Future<LiveRadioSnapshot>? _pendingLiveRadio;

  @override
  Future<ChartSnapshot> getChartSnapshot() async {
    try {
      final snapshot = await _remote.getChartSnapshot();
      final preferences = _preferences ??= SharedPreferencesAsync();
      await preferences.setString(
        _snapshotCacheKey,
        jsonEncode(snapshot.toJson()),
      );
      return snapshot;
    } catch (error) {
      final preferences = _preferences ??= SharedPreferencesAsync();
      final encoded =
          await preferences.getString(_snapshotCacheKey) ??
          await preferences.getString(_chartCacheKey);
      if (encoded == null) rethrow;
      try {
        final json = jsonDecode(encoded);
        final snapshot = json is Map<String, dynamic>
            ? ChartSnapshot.fromJson(json)
            : json is List
            ? ChartSnapshot(
                songs: json
                    .whereType<Map<String, dynamic>>()
                    .map(Song.fromJson)
                    .where((song) => song.id.isNotEmpty)
                    .toList(growable: false),
              )
            : const ChartSnapshot(songs: []);
        if (snapshot.songs.isEmpty) rethrow;
        return snapshot;
      } catch (_) {
        throw error;
      }
    }
  }

  @override
  Future<List<Song>> getChartSongs() async => (await getChartSnapshot()).songs;

  @override
  Future<NewReleaseChart> getNewReleaseChart() => _remote.getNewReleaseChart();

  @override
  Future<WeeklyChart> getWeeklyChart(
    WeeklyChartRegion region, {
    int? week,
    int? year,
  }) => _remote.getWeeklyChart(region, week: week, year: year);

  @override
  Future<DiscoveryCategories> getDiscoveryCategories() =>
      _remote.getDiscoveryCategories();

  @override
  Future<DiscoveryRecommendations> getDiscoveryRecommendations() =>
      _remote.getDiscoveryRecommendations();

  @override
  Future<DiscoveryHome> getDiscoveryHome({String categoryId = '-1'}) =>
      _remote.getDiscoveryHome(categoryId: categoryId);

  @override
  Future<CatalogHubHome> getHubHome() => _remote.getHubHome();

  @override
  Future<CatalogHubDetail> getHubDetail(String id) => _remote.getHubDetail(id);

  @override
  Future<Top100Catalog> getTop100() => _remote.getTop100();

  @override
  Future<ReleaseCatalog> getReleaseCatalog() => _remote.getReleaseCatalog();

  @override
  Future<CatalogArtistDetail> getArtistDetail(String alias) =>
      _remote.getArtistDetail(alias);

  @override
  Future<CatalogSearchResult> searchCatalog(String query) =>
      _remote.searchCatalog(query);

  @override
  Future<SearchSuggestionSnapshot> getSearchSuggestions(String query) =>
      _remote.getSearchSuggestions(query);

  @override
  Future<CatalogCollectionDetail> getCollection(String id) =>
      _remote.getCollection(id);

  @override
  Future<SongDetail> getSongDetail(String songId) {
    final normalizedSongId = songId.trim();
    final cached = _songDetailCache[normalizedSongId];
    if (cached != null) return Future.value(cached);
    return _pendingSongDetail.putIfAbsent(normalizedSongId, () async {
      try {
        final detail = await _remote.getSongDetail(normalizedSongId);
        _songDetailCache[normalizedSongId] = detail;
        while (_songDetailCache.length > 100) {
          _songDetailCache.remove(_songDetailCache.keys.first);
        }
        return detail;
      } finally {
        _pendingSongDetail.remove(normalizedSongId);
      }
    });
  }

  @override
  Future<SongLyrics> getSongLyrics(String code) {
    final normalizedCode = code.trim();
    final cached = _lyricsCache[normalizedCode];
    if (cached != null) return Future.value(cached);
    return _pendingLyrics.putIfAbsent(normalizedCode, () async {
      try {
        final lyrics = await _remote.getSongLyrics(normalizedCode);
        if (!lyrics.isEmpty) {
          _lyricsCache[normalizedCode] = lyrics;
          while (_lyricsCache.length > 100) {
            _lyricsCache.remove(_lyricsCache.keys.first);
          }
        }
        return lyrics;
      } finally {
        _pendingLyrics.remove(normalizedCode);
      }
    });
  }

  @override
  Future<SongRadio> getSongRadio(String code) {
    final normalizedCode = code.trim();
    final cached = _songRadioCache[normalizedCode];
    if (cached != null) return Future.value(cached);
    return _pendingSongRadio.putIfAbsent(normalizedCode, () async {
      try {
        final radio = await _remote.getSongRadio(normalizedCode);
        if (!radio.isEmpty) {
          _songRadioCache[normalizedCode] = radio;
          while (_songRadioCache.length > 100) {
            _songRadioCache.remove(_songRadioCache.keys.first);
          }
        }
        return radio;
      } finally {
        _pendingSongRadio.remove(normalizedCode);
      }
    });
  }

  @override
  Future<LiveRadioSnapshot> getLiveRadio() {
    final pending = _pendingLiveRadio;
    if (pending != null) return pending;
    late final Future<LiveRadioSnapshot> operation;
    operation = _remote.getLiveRadio().whenComplete(() {
      if (identical(_pendingLiveRadio, operation)) _pendingLiveRadio = null;
    });
    _pendingLiveRadio = operation;
    return operation;
  }

  @override
  Future<String> getLiveRadioSource(String id) =>
      _remote.getLiveRadioSource(id);

  @override
  Future<String> getSongSource(
    String code, {
    StreamingQualityPreference quality = StreamingQualityPreference.automatic,
  }) => _remote.getSongSource(code, quality: quality);
}

class MusicRepositoryException implements Exception {
  const MusicRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
