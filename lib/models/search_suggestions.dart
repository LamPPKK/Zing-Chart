class SearchSuggestionSong {
  const SearchSuggestionSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnail,
    required this.duration,
    required this.externalUrl,
  });

  final String id;
  final String title;
  final String artist;
  final String thumbnail;
  final Duration duration;
  final String externalUrl;
}

class SearchSuggestionSnapshot {
  const SearchSuggestionSnapshot({
    required this.query,
    required this.keywords,
    required this.songs,
  });

  const SearchSuggestionSnapshot.empty([String query = ''])
    : this(query: query, keywords: const [], songs: const []);

  final String query;
  final List<String> keywords;
  final List<SearchSuggestionSong> songs;

  bool get isEmpty => keywords.isEmpty && songs.isEmpty;
}
