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

  void search(String? searchQuery, {String? searchType}) async {
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
        final (searchedSongs, searchedArtists) = await ZingMP3API.search(searchQuery, type: searchType);

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
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(statusBarColor: Colors.grey[800]),
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: SearchResultAppBar(
            onChanged: (query, type) => search(query, searchType: type),
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

            if (songs.isEmpty && artists.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "No results found",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: <Widget>[
                TabBar(
                  indicatorColor: Colors.deepPurpleAccent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[500],
                  tabs: [
                    Tab(text: "Songs"),
                    Tab(text: "Artists"),
                  ],
                  indicatorSize: TabBarIndicatorSize.label,
                  labelPadding: EdgeInsets.symmetric(horizontal: 20),
                ),
                Expanded(
                  child: TabBarView(children: [
                    SearchSongsResult(songs: songs),
                    SearchArtistsResult(artists: artists),
                  ),
                ),
              ],
            );
          },
        },
      ),
    );
  }
}
