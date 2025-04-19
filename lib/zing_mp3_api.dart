import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:zmp3chart/models/song.dart';

import 'models/artist.dart';

class ZingMP3API {
  static const String zingChartURL =
      'https://mp3.zing.vn/xhr/chart-realtime?songId=0&videoId=0&albumId=0&chart=song&time=-1';

  static const String songDetailURL =
      'https://m.zingmp3.vn/xhr/media/get-source?type=audio&key=';
  static const String searchUrl =
      'http://ac.mp3.zing.vn/complete?type=artist,song,key,code&num=20&query=';

  static Future<List<Song>> getZingChartSongs() async {
    try {
      final response = await http.get(Uri.parse(zingChartURL));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final songsData = jsonData['data']['song'] as List<dynamic>;

        List<Song> songs =
            songsData.map((songData) => Song.fromJson(songData)).toList();
        return songs;
      } else {
        throw Exception('Failed to load Zing MP3 chart');
      }
    } catch (e) {
      throw Exception('Failed to load Zing MP3 chart: $e');
    }
  }

  static Future<String> getSongUrlByCode(String code) async {
    try {
      final response = await http.get(Uri.parse(songDetailURL + code));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final src = jsonData['data']['source']['128'] as String;

        return 'https:' + src;
      } else {
        throw Exception('Failed to load MP3 Source');
      }
    } catch (e) {
      throw Exception('Failed to load MP3 Source: $e');
    }
  }

  static Future<Map<String, List<dynamic>>> search(String q, {String? type}) async {
    String url = searchUrl + q;
    if (type != null) {
      url += '&type=$type';
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        print('Failed to load Search: ${response.statusCode}');
        return {'songs': [], 'artists': []};
      }

      final jsonData = jsonDecode(response.body);
      final data = jsonData['data'];

      List<Song> songs = [];
      List<Artist> artists = [];

      if (data is List) {
        if (data.isNotEmpty) {
          if (data.length > 1) {
            final songsData = data[0]['song'] as List<dynamic>?;
            final artistsData = data[1]['artist'] as List<dynamic>?;

            songs = songsData?.map((song) => Song.fromJson(song)).toList() ?? [];
            artists = artistsData?.map((artist) => Artist.fromJson(artist)).toList() ?? [];
          } else if (type == 'song') {
            final songsData = data[0]['song'] as List<dynamic>?;
            songs = songsData?.map((song) => Song.fromJson(song)).toList() ?? [];
          } else if (type == 'artist') {
            final artistsData = data[0]['artist'] as List<dynamic>?;
            artists = artistsData?.map((artist) => Artist.fromJson(artist)).toList() ?? [];
          }
        }
      } else {
        print('Unexpected API response format: $data');
      }

      return {'songs': songs, 'artists': artists};
    } catch (e) {
      throw Exception('Failed to Search: $e');
    }
  }
}
