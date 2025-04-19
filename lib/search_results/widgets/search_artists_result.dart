import 'package:flutter/material.dart';
import '../../models/artist.dart';

class SearchArtistsResult extends StatelessWidget {
  const SearchArtistsResult({
    Key? key,
    required this.artists,
  }) : super(key: key);

  final List<Artist> artists;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8, // Adjust as needed
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: artists.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              // Handle artist tap (e.g., navigate to artist details)
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[900], // Example background color
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(
                          'https://photo-resize-zmp3.zmdcdn.me/w320_r1x1_webp/' +
                              artists[index].thumb,
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    artists[index].name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    artists[index].aliasName,
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        },
      ),
    );
  }
}
