import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:zmp3chart/models/playlist.dart';
import 'package:zmp3chart/zing_mp3_api.dart';
import 'package:zmp3chart/models/song_detail.dart';

import '../position_seek_widget.dart';

class PlaybackControls extends StatelessWidget {
  final bool isPlaying;
  final Duration currentPosition;
  final Duration totalDuration;
  final Playlist playlist;
  final String? currentSongId;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(Duration) onSeek;
  final Function(String) onSongChanged;

  const PlaybackControls({
    Key? key,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.onPlayPause,
    required this.playlist,
    required this.onNext,
    required this.onPrevious,
    this.currentSongId,
    required this.onSeek,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PositionSeekWidget(
          currentPosition: currentPosition,
          duration: totalDuration,
          seekTo: onSeek,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: onPrevious,
            ),
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: onPlayPause,
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: onNext,
            ),
          ],
        ),
      ],
    );
  }
}