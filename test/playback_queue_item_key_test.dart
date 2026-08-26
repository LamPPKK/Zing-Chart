import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/widgets/playback_queue_item_key.dart';

void main() {
  test('keeps repeated Repeat All visits uniquely keyed', () {
    const repeated = [_song, _other, _song, _song];

    final keys = List.generate(
      repeated.length,
      (index) => playbackQueueItemKey('queue', repeated, index),
    );

    expect(keys[0], const ValueKey('queue-song'));
    expect(keys[1], const ValueKey('queue-other'));
    expect(keys.toSet(), hasLength(repeated.length));
  });

  test('does not collide with a real ID that looks like a repeat suffix', () {
    const suffixLikeSong = Song(
      id: 'song-1',
      name: 'song-1',
      title: 'Bài có ID dạng hậu tố',
      thumbnail: '',
      artistsNames: 'Nghệ sĩ',
      code: 'song-1-code',
    );
    const collidingNames = [_song, _song, suffixLikeSong];
    final keys = List.generate(
      collidingNames.length,
      (index) => playbackQueueItemKey('queue', collidingNames, index),
    );

    expect(keys[0], const ValueKey('queue-song'));
    expect(keys[2], const ValueKey('queue-song-1'));
    expect(keys.toSet(), hasLength(collidingNames.length));
  });
}

const _song = Song(
  id: 'song',
  name: 'song',
  title: 'Bài hát',
  thumbnail: '',
  artistsNames: 'Nghệ sĩ',
  code: 'song-code',
);

const _other = Song(
  id: 'other',
  name: 'other',
  title: 'Bài khác',
  thumbnail: '',
  artistsNames: 'Nghệ sĩ khác',
  code: 'other-code',
);
