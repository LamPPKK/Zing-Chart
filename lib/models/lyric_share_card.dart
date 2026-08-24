import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'song.dart';

@immutable
class LyricShareCardData {
  LyricShareCardData({required this.song, required Iterable<String> lines})
    : lines = List<String>.unmodifiable(
        lines
            .map(_normalizeLine)
            .where((line) => line.isNotEmpty)
            .take(maxLines),
      ) {
    if (this.lines.isEmpty) {
      throw ArgumentError.value(lines, 'lines', 'Cần chọn ít nhất một câu.');
    }
  }

  static const int maxLines = 4;
  static const int maxLineCharacters = 220;

  final Song song;
  final List<String> lines;

  String get excerpt => lines.join('\n');

  LyricSharePayload get payload => LyricSharePayload(
    title: song.displayTitle,
    artist: song.artistsNames,
    lines: lines,
  );

  static String _normalizeLine(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= maxLineCharacters) return normalized;
    return '${normalized.substring(0, maxLineCharacters - 1).trimRight()}…';
  }
}

@immutable
class LyricSharePayload {
  const LyricSharePayload({
    required this.title,
    required this.artist,
    required this.lines,
  });

  final String title;
  final String artist;
  final List<String> lines;

  String encode() => jsonEncode({
    'v': 1,
    'type': 'zingchart-lyrics',
    'title': title,
    'artist': artist,
    'lines': lines,
  });
}
