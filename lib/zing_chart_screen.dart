import 'package:flutter/material.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/search_results/search_result_screen.dart';

import 'music_player_screen.dart';
import 'zing_mp3_api.dart';

class ZingChartScreen extends StatefulWidget {
  @override
  _ZingChartScreenState createState() => _ZingChartScreenState();
}

class _ZingChartScreenState extends State<ZingChartScreen> {
  List<Song> _songs = [];

  @override
  void initState() {
    super.initState();
    _loadZingChartSongs();
  }

  Future<void> _loadZingChartSongs() async {
    try {
      List<Song> songs = await ZingMP3API.getZingChartSongs();
      setState(() {
        _songs = songs;
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '#ZingChart',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white, // Text color is white
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchResultsScreen(),
              ),
            ),
            icon: Icon(Icons.search),
          ),
        ],
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple, // Primary color is deepPurple
      ),
      backgroundColor: Colors.white, // Background color is white
      body: RefreshIndicator(
        onRefresh: _loadZingChartSongs,
        child: ListView.builder(
          itemCount: _songs.length,
          itemBuilder: (context, index) {
            final song = _songs[index];
            final title = song.title;
            final artist = song.artistsNames;
            final thumbnailUrl = song.thumbnail;
            final rank = (index + 1).toString(); // Adding 1 to index since ranking starts from 1

            return ListTile(
              leading: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(thumbnailUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          rank,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Rank text color is white
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black, // Song title text color is black
                ),
              ),
              subtitle: Text(
                artist,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54, // Artist name text color is black54
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: Colors.black, // Trailing icon color is black
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MusicPlayerScreen(
                      song: song,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
