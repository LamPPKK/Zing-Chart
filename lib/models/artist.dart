
import 'package:json_annotation/json_annotation.dart';

part 'artist.g.dart';

@JsonSerializable()
class Artist {
  String aliasName;
  String thumb;
  String name;
  String block;
  String id;

  Artist({
    required this.aliasName,
    required this.thumb,
    required this.name,
    required this.block,
    required this.id,
  });

  factory Artist.fromJson(Map<String, dynamic> json) => _$ArtistFromJson(json);

  Map<String, dynamic> toJson() => _$ArtistToJson(this);
}
