import 'package:flutter/material.dart';

import '../../models/artist.dart';
import '../search_artists_result_screen.dart';

class SearchArtistsResult extends StatelessWidget {
  const SearchArtistsResult({
    Key? key,
    required this.artists,
    this.isViewAll = true,
  }) : super(key: key);

  final List<Artist> artists;
  final bool isViewAll;

  int _getLengthSingers() {
    if (isViewAll || artists.length < 10) return artists.length;

    return 10;
  }

  @override
  Widget build(BuildContext context) {
    final bodyText1 = Theme.of(context).textTheme.bodyLarge;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isViewAll)
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchArtistsResultScreen(
                          artists: artists,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    'View All',
                    style: bodyText1!.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 1),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey,
                  size: 14,
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        Flexible(
          child: ListView.builder(
            shrinkWrap: !isViewAll,
            primary: false,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: artists.sublist(0, _getLengthSingers()).length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(
                        'https://photo-resize-zmp3.zmdcdn.me/w165_r1x1_webp/' + artists[index].thumb,
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                title: Text(
                  artists[index].name,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  artists[index].aliasName,
                  style: TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  // Add any action you want to perform when tapping on the list tile
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
