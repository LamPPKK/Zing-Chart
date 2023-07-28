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
  final bool isViewAll;

  int _getLengthSongs() {
    if (isViewAll || songs.length < 10) return songs.length;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    final bodyText1 = Theme.of(context).textTheme.bodyText1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isViewAll)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchSongsResultScreen(
                          songs: songs,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'View All',
                        style: bodyText1!.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.grey,
                        size: 14,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: !isViewAll,
            primary: false,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _getLengthSongs(),
            itemBuilder: (context, index) {
              final song = songs[index];
              return ListTile(
                leading: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(song.thumbnail),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(
                  song.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  song.artistsNames,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
