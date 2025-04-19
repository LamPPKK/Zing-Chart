class Playlist {
  final String id;
  final String name;
  final List<String> songs;
  final String userId;

  Playlist({
    required this.id,
    required this.name,
    required this.songs,
    required this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'songs': songs,
      'userId': userId,
    };
  }
}