class Song {
  String id;
  String name;
  String title;
  String thumbnail;
  String artistsNames;
  String code;

  Song({
    required this.id,
    required this.name,
    required this.title,
    required this.thumbnail,
    required this.artistsNames,
    required this.code,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'] ?? json['thumb'] ?? '',
      artistsNames: json['artists_names'] ?? json['artist'] ?? '',
      code: json['code'] ?? '',
    );
  }
}
