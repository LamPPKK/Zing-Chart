import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/artist.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/search_results/widgets/search_artists_result.dart';
import 'package:zmp3chart/search_results/widgets/search_songs_result.dart';
import 'package:zmp3chart/widgets/album_art.dart';

void main() {
  testWidgets('legacy artist search keeps the absolute avatar URL intact', (
    tester,
  ) async {
    const avatar =
        'https://photo-resize-zmp3.zmdcdn.me/w240_r1x1_jpeg/avatar.jpg';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchArtistsResult(
            artists: [
              Artist(
                aliasName: 'Son-Tung-M-TP',
                thumb: avatar,
                name: 'Sơn Tùng M-TP',
                block: 'false',
                id: 'artist-one',
              ),
            ],
          ),
        ),
      ),
    );

    final artwork = tester.widget<AlbumArt>(find.byType(AlbumArt));
    expect(artwork.imageUrl, avatar);
    expect(artwork.imageUrl.split('https://').length - 1, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy song search uses the shared fail-safe artwork widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SearchSongsResult(
            songs: [
              Song(
                id: 'song-one',
                name: 'Nơi Này Có Anh',
                title: 'Nơi Này Có Anh',
                thumbnail: '',
                artistsNames: 'Sơn Tùng M-TP',
                code: 'song-one',
              ),
            ],
          ),
        ),
      ),
    );

    final artwork = tester.widget<AlbumArt>(find.byType(AlbumArt));
    expect(artwork.imageUrl, isEmpty);
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
