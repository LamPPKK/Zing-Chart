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

  static Future<(List<Song>, List<Artist>)> search(String q) async {
    try {
      final response = await http.get(Uri.parse(searchUrl + q));
      if (response.statusCode == 200) {
        List<Song>? songs;
        List<Artist>? artists;
        final jsonData = jsonDecode(response.body);
        final data = jsonData['data'] as List<dynamic>;

        if (data.isEmpty) return (<Song>[], <Artist>[]);

        if (data.length > 1) {
          final songsData = data[0]['song'] as List<dynamic>;
          songs = songsData.map((song) => Song.fromJson(song)).toList();
        }

        if (data.length == 2) {
          final artistsData = data[1]['artist'] as List<dynamic>;

          artists =
              artistsData.map((artist) => Artist.fromJson(artist)).toList();
        }

        return (
          songs ?? [],
          artists ?? [],
        );
      } else {
        throw Exception('Failed to load Search');
      }
    } catch (e) {
      throw Exception('Failed to Search: $e');
    }
  }
}
