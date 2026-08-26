import 'package:flutter/foundation.dart';

import '../models/song.dart';

/// Keeps queue row keys unique when Repeat All history contains the same song
/// more than once, while preserving the simple ID key for the first visit.
///
/// Repeated visits use a typed record rather than a string suffix so an actual
/// song ID such as `song-1` cannot collide with the second visit to `song`.
LocalKey playbackQueueItemKey(String prefix, List<Song> songs, int index) {
  final songId = songs[index].id;
  var occurrence = 0;
  for (var previous = 0; previous < index; previous++) {
    if (songs[previous].id == songId) occurrence++;
  }
  if (occurrence == 0) return ValueKey('$prefix-$songId');
  return ValueKey<(String, String, int)>((prefix, songId, occurrence));
}
