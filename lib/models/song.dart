import 'package:json_annotation/json_annotation.dart';

part 'song.g.dart';

@JsonSerializable()
class Song {
  @JsonKey(defaultValue: '')
  final String id;

  @JsonKey(defaultValue: '')
  final String name;

  @JsonKey(defaultValue: '')
  final String title;

  @JsonKey(defaultValue: '')
  final String thumbnail;

  @JsonKey(name: 'artists_names', defaultValue: '')
  final String artistsNames;

  @JsonKey(defaultValue: '')
  final String code;

  const Song({
    required this.id,
    required this.name,
    required this.title,
    required this.thumbnail,
    required this.artistsNames,
    required this.code,
  });

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);

  Map<String, dynamic> toJson() => _$SongToJson(this);

  String get displayTitle => title.isNotEmpty ? title : name;
}
