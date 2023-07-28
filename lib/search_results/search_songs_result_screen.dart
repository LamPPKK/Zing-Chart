import 'package:flutter/material.dart';
import 'package:zmp3chart/search_results/widgets/search_songs_result.dart';

import '../models/song.dart';

class SearchSongsResultScreen extends StatelessWidget {
  const SearchSongsResultScreen({
    Key? key,
    required this.songs,
  }) : super(key: key);

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Songs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: SearchSongsResult(songs: songs),
    );
  }
}
