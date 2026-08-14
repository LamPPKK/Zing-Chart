// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Song _$SongFromJson(Map<String, dynamic> json) => Song(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  title: json['title'] as String? ?? '',
  thumbnail: json['thumbnail'] as String? ?? '',
  artistsNames: json['artists_names'] as String? ?? '',
  code: json['code'] as String? ?? '',
);

Map<String, dynamic> _$SongToJson(Song instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'title': instance.title,
  'thumbnail': instance.thumbnail,
  'artists_names': instance.artistsNames,
  'code': instance.code,
};
