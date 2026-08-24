import 'package:flutter/foundation.dart';

@immutable
class LyricWord {
  const LyricWord({required this.start, required this.end, required this.text});

  final Duration start;
  final Duration end;
  final String text;
}

@immutable
class LyricLine {
  const LyricLine({
    required this.start,
    required this.end,
    required this.text,
    this.words = const [],
  });

  final Duration start;
  final Duration end;
  final String text;
  final List<LyricWord> words;

  int activeWordIndex(Duration position) {
    if (words.isEmpty) return -1;
    var low = 0;
    var high = words.length - 1;
    var result = -1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (words[middle].start <= position) {
        result = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    if (result < 0) return -1;
    final candidate = words[result];
    return position < candidate.end ? result : -1;
  }
}

@immutable
class SongLyrics {
  const SongLyrics({
    required this.songId,
    required this.synced,
    required this.lines,
  });

  const SongLyrics.empty(String songId)
    : this(songId: songId, synced: false, lines: const []);

  final String songId;
  final bool synced;
  final List<LyricLine> lines;

  bool get isEmpty => lines.isEmpty;
  bool get wordSynced => lines.any((line) => line.words.isNotEmpty);

  int activeLineIndex(Duration position) {
    if (!synced || lines.isEmpty) return -1;
    var low = 0;
    var high = lines.length - 1;
    var result = -1;
    while (low <= high) {
      final middle = low + ((high - low) >> 1);
      if (lines[middle].start <= position) {
        result = middle;
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    if (result < 0) return -1;
    final candidate = lines[result];
    return position < candidate.end ? result : -1;
  }
}
