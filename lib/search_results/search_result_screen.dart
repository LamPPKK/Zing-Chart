import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zmp3chart/models/artist.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/search_results/widgets/search_artists_result.dart';
import 'package:zmp3chart/search_results/widgets/search_result_app_bar.dart';
import 'package:zmp3chart/search_results/widgets/search_songs_result.dart';
import 'package:zmp3chart/zing_mp3_api.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({Key? key}) : super(key: key);

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  Timer? _debounce;
  bool isLoading = false;
  final List<Song> songs = [];
  final List<Artist> artists = [];

  void search(String? searchQuery) async {
    try {
      if (searchQuery == null || searchQuery.trim().isEmpty) {
        return;
      }

      if (_debounce?.isActive ?? false) _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 1000), () async {
        setState(() {
          isLoading = true;
        });
        await Future.delayed(const Duration(seconds: 1));
        final (searchedSongs, searchedArtists) = await ZingMP3API.search(searchQuery);

        setState(() {
          isLoading = false;
          songs.clear();
          artists.clear();
          songs.addAll(searchedSongs);
          artists.addAll(searchedArtists);
        });
      });
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    // Set the status bar color to match the app bar color
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.deepPurple, // Set your desired color here
    ));

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: SearchResultAppBar(
          onChanged: search,
        ),
      ),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurpleAccent,
              ),
            );
          }

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  color: Colors.deepPurple,
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.white,
                    tabs: [
                      Tab(text: "Song"),
                      Tab(text: "Artist"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SearchSongsResult(
                        isViewAll: false,
                        songs: songs,
                      ),
                      SearchArtistsResult(
                        isViewAll: false,
                        artists: artists,
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
