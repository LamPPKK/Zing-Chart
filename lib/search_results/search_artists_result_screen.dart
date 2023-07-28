import 'package:flutter/material.dart';
import 'package:zmp3chart/search_results/widgets/search_artists_result.dart';

import '../models/artist.dart';

class SearchArtistsResultScreen extends StatelessWidget {
  const SearchArtistsResultScreen({
    Key? key,
    required this.artists,
  }) : super(key: key);

  final List<Artist> artists;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Artists',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
      ),
      body: SearchArtistsResult(artists: artists),
      backgroundColor: Colors.white,
    );
  }
}
