import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

abstract interface class MusicRepository {
  Future<List<Song>> getChartSongs();

  Future<String> getSongSource(String code);
}

class ProxyMusicRepository implements MusicRepository {
  ProxyMusicRepository({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 15),
              headers: const {'Accept': 'application/json'},
            ),
          );

  final Dio _dio;

  @override
  Future<List<Song>> getChartSongs() async {
    try {
      final response = await _dio.get<dynamic>('/v1/chart');
      final data = response.data;
      final rawSongs = data is Map<String, dynamic> ? data['songs'] : null;
      if (rawSongs is! List) {
        throw const FormatException('Missing songs');
      }
      return rawSongs
          .whereType<Map<String, dynamic>>()
          .map(
            (json) => Song(
              id: json['id']?.toString() ?? '',
              name: json['title']?.toString() ?? '',
              title: json['title']?.toString() ?? '',
              thumbnail: json['albumCover']?.toString() ?? '',
              artistsNames: json['artist']?.toString() ?? '',
              code: json['code']?.toString() ?? '',
            ),
          )
          .where((song) => song.id.isNotEmpty && song.displayTitle.isNotEmpty)
          .toList(growable: false);
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
  Future<String> getSongSource(String code) async {
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      throw const MusicRepositoryException('Bài hát không có mã phát nhạc.');
    }

    try {
      final response = await _dio.get<dynamic>(
        '/v1/songs/${Uri.encodeComponent(normalizedCode)}/source',
      );
      final data = response.data;
      final source = data is Map<String, dynamic>
          ? data['url']?.toString().trim()
          : null;
      final uri = source == null ? null : Uri.tryParse(source);
      if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
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
  final MusicRepository _remote;
  SharedPreferencesAsync? _preferences;

  @override
  Future<List<Song>> getChartSongs() async {
    try {
      final songs = await _remote.getChartSongs();
      final preferences = _preferences ??= SharedPreferencesAsync();
      await preferences.setString(
        _chartCacheKey,
        jsonEncode(songs.map((song) => song.toJson()).toList()),
      );
      return songs;
    } catch (error) {
      final preferences = _preferences ??= SharedPreferencesAsync();
      final encoded = await preferences.getString(_chartCacheKey);
      if (encoded == null) rethrow;
      try {
        final json = jsonDecode(encoded);
        if (json is! List) rethrow;
        final songs = json
            .whereType<Map<String, dynamic>>()
            .map(Song.fromJson)
            .where((song) => song.id.isNotEmpty)
            .toList(growable: false);
        if (songs.isEmpty) rethrow;
        return songs;
      } catch (_) {
        throw error;
      }
    }
  }

  @override
  Future<String> getSongSource(String code) => _remote.getSongSource(code);
}

class MusicRepositoryException implements Exception {
  const MusicRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
