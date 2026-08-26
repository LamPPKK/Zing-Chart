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

  /// Last known catalog playback eligibility for this exact song snapshot.
  ///
  /// New in-memory songs default to playable because chart entries are
  /// already filtered by the proxy. Older persisted JSON did not carry an
  /// authority signal, so [fromJson] deliberately restores it as locked.
  @JsonKey(defaultValue: false)
  final bool playable;

  const Song({
    required this.id,
    required this.name,
    required this.title,
    required this.thumbnail,
    required this.artistsNames,
    required this.code,
    this.playable = true,
  });

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);

  Map<String, dynamic> toJson() => _$SongToJson(this);

  String get displayTitle => title.isNotEmpty ? title : name;

  bool get isPlaybackEligible =>
      playable && id.trim().isNotEmpty && code.trim().isNotEmpty;
}
