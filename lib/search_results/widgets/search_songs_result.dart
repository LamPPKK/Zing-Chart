import 'package:flutter/material.dart';
import '../../models/song.dart';
import '../../music_player_screen.dart';
import '../search_songs_result_screen.dart';

class SearchSongsResult extends StatelessWidget {
  const SearchSongsResult({
    Key? key,
    required this.songs,
    this.isViewAll = true,
  }) : super(key: key);

  final List<Song> songs;  

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            primary: false,
            padding: const EdgeInsets.all(16),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                leading: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(song.thumbnail),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(
                  song.name,                  
                ),
                subtitle: Text(
                  song.artistsNames,
                  style: TextStyle(color: Colors.grey[600]),
                
                ),
                onTap: () {
                  FocusScope.of(context).unfocus();
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
        )
      ],
    );
  }
}
