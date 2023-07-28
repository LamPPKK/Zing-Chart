import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/position_seek_widget.dart';
import 'package:zmp3chart/zing_mp3_api.dart';

class MusicPlayerScreen extends StatefulWidget {
  final Song song;

  MusicPlayerScreen({required this.song});

  @override
  _MusicPlayerScreenState createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  AudioPlayer audioPlayer = AudioPlayer();
  String songUrl = '';
  bool isPlaying = false; // Set the default state to false

  String get songTitle => widget.song.title;
  String get songArtist => widget.song.artistsNames;
  String get albumCoverUrl => widget.song.thumbnail;

  @override
  void initState() {
    _loadSongSrc();
    super.initState();
  }

  void _loadSongSrc() async {
    try {
      final url = await ZingMP3API.getSongUrlByCode(widget.song.code);
      setState(() {
        songUrl = url;
        // Do not auto-play the song when loaded, let the user control it
      });
    } catch (e) {
      print('Error: $e');
    }
  }

  void _handlePlayOrPause() {
    if (songUrl.isEmpty) return;

    if (isPlaying) {
      audioPlayer.pause(); // If playing, pause the song
    } else {
      audioPlayer.play(UrlSource(songUrl)); // If not playing, play the song
    }

    setState(() {
      isPlaying = !isPlaying; // Toggle the isPlaying state
    });
  }

  void _handleStop() {
    if (audioPlayer.state == PlayerState.stopped) return;

    audioPlayer.stop();
    setState(() {
      isPlaying = false; // Set isPlaying to false when the song stops
    });
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String getRemainingTime(Duration currentPosition, Duration totalDuration) {
    final remainingDuration = totalDuration - currentPosition;
    return formatDuration(remainingDuration);
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (songUrl.isEmpty) return Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Now Playing',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            _handleStop();
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(albumCoverUrl),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Now Playing:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              SizedBox(height: 10),
              Text(
                songTitle,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              SizedBox(height: 10),
              Text(
                songArtist,
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              SizedBox(height: 20),
              StreamBuilder<Duration>(
                stream: audioPlayer.onDurationChanged,
                builder: (context, snapshot1) {
                  if (!snapshot1.hasData) return const SizedBox.shrink();

                  final songDuration = snapshot1.data ?? Duration.zero;

                  return StreamBuilder<Duration>(
                    stream: audioPlayer.onPositionChanged,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();

                      final currentPosition = snapshot.data ?? Duration.zero;
                      final elapsedTime = formatDuration(currentPosition);
                      final remainingTime = getRemainingTime(currentPosition, songDuration);

                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20), // Add horizontal spacing
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  elapsedTime,
                                  style: TextStyle(fontSize: 18),
                                ),
                                Text(
                                  "-$remainingTime",
                                  style: TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          PositionSeekWidget(
                            currentPosition: currentPosition,
                            duration: songDuration,
                            seekTo: (position) => audioPlayer.seek(position),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {}, // Previous song functionality can be added here
                    icon: Icon(
                      Icons.skip_previous,
                      size: 32,
                      color: Colors.deepPurple, // Icon color
                    ),
                  ),
                  SizedBox(width: 30),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _handlePlayOrPause,
                        icon: Icon(
                          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: Colors.deepPurple, // Icon color
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 30),
                  IconButton(
                    onPressed: () {}, // Next song functionality can be added here
                    icon: Icon(
                      Icons.skip_next,
                      size: 32,
                      color: Colors.deepPurple, // Icon color
                    ),
                  ),
                ],
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
