// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'artist.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Artist _$ArtistFromJson(Map<String, dynamic> json) => Artist(
      aliasName: json['aliasName'] as String,
      thumb: json['thumb'] as String,
      name: json['name'] as String,
      block: json['block'] as String,
      id: json['id'] as String,
    );

Map<String, dynamic> _$ArtistToJson(Artist instance) => <String, dynamic>{
      'aliasName': instance.aliasName,
      'thumb': instance.thumb,
      'name': instance.name,
      'block': instance.block,
      'id': instance.id,
    };
