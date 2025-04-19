import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart' hide Playlist;
import 'package:zmp3chart/position_seek_widget.dart';
import 'package:zmp3chart/models/song_detail.dart';
import 'package:zmp3chart/models/song.dart';
import 'package:zmp3chart/models/playlist.dart';
import 'package:zmp3chart/search_results/widgets/search_songs_result.dart';
import 'package:zmp3chart/services/playlist_service.dart';
import 'package:zmp3chart/zing_mp3_api.dart';
import 'package:zmp3chart/widgets/playback_controls.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;

  final zingApi = ZingMP3API();
  final TextEditingController _searchController = TextEditingController();
  List<Song> _searchSongs = [];

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}


class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late Playlist _playlist;
  final ValueNotifier<String?> _currentSongId = ValueNotifier<String?>(null);

  
  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
  }

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    widget._searchController.dispose();
    _currentSongId.dispose();
    super.dispose();
  }

  Future<List<SongDetail>> _fetchSongDetails(List<String> songIds) async {
    final songDetails = <SongDetail>[];
    for (final songId in songIds) {
      final detail = await widget.zingApi.getDetailPlaylist(songId);
      if (detail != null && detail.song != null) {
        songDetails.add(detail.song!);
      }
    }
    return songDetails;
  }

  Future<void> _searchSongsMethod(String query) async {
    if (query.isNotEmpty) {
      final searchResult = await widget.zingApi.search(query);
      if (searchResult != null) {
        setState(() {
          widget._searchSongs = searchResult.songs;
        });
      } else {
        //Handle search error.
      }
    } else {
      setState(() {
        widget._searchSongs = [];
      });
    }
    } else {
        widget._searchSongs = [];
      });
    }
  }

  Widget _buildSearchDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Songs'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
                await PlaylistService().addSongToPlaylist(_playlist.id, song.encodeId);
                setState(() {
                  _playlist.songs.add(song.encodeId);
                });
                Navigator.of(context).pop();
              } catch (e) {
                FlutterToast(msg: 'Error adding song to playlist.');
              }
            },
          ),
          const SizedBox(height: 10),
              height: 200, // Adjust as needed
              width: double.maxFinite,
              child: SearchSongsResult(songs: widget._searchSongs, onTap: (song) async {
                try {
                  await PlaylistService().addSongToPlaylist(_playlist.id, song.encodeId);
                  setState(() {
                    _playlist.songs.add(song.encodeId);
                  });
                      SnackBar(content: Text('${song.title} added to playlist.')));
                  Navigator.of(context).pop(); // Close the dialog
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding song to playlist.')));
                }
              },),
            ),
          else if (widget._searchController.text.isNotEmpty)

  Widget _buildPlaybackControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous, size: 32),
            onPressed: _playPreviousSong,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _isCurrentSongPlaying,
            builder: (context, isPlaying, child) => IconButton(
                  if (isPlaying) _pause(); else _resume();
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.skip_next, size: 32),
            onPressed: _playNextSong,
          );
        ],
      ),
    );
    return Container(padding: const EdgeInsets.symmetric(horizontal: 24), child: PositionSeekWidget());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirmDelete = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Playlist?'),
                  content: const Text('Are you sure you want to delete this playlist?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmDelete == true) await _deletePlaylist(context);
            },
          ),
        ],
      ),
      body: _playlist.songs.isEmpty
          ? const Center(child: Text('No songs in this playlist yet.', style: TextStyle(fontSize: 18)))
          : FutureBuilder<List<SongDetail>>(
        future: _fetchSongDetails(_playlist.songs),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(fontSize: 18, color: Colors.red)));
          } else if (snapshot.hasData) {
            final songDetails = snapshot.data!;
            return ListView.builder(
              itemCount: songDetails.length,
              itemBuilder: (context, index) {
                final song = songDetails[index];
                final isNowPlaying = _currentSongId.value == song.encodeId;
                final playPauseIcon =
                    isNowPlaying ? Icons.pause : Icons.play_arrow;
                return Container(
                  color: isNowPlaying ? Colors.blue.withOpacity(0.1) : null,
                  child: Dismissible(
                    key: Key(song.encodeId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) async {
                      try{
                        await PlaylistService().removeSongFromPlaylist(_playlist.id, song.encodeId);
                        setState(() {
                          _playlist.songs.remove(song.encodeId);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${song.title} removed from playlist')));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error removing song from playlist')));
                      }
                    },
                    child: ListTile(
                      leading: song.thumbnailM.isNotEmpty
                          ? Image.network(song.thumbnailM)
                          : const Icon(Icons.music_note),
                      title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(song.artistsNames),
                      trailing: ValueListenableBuilder<String?>(
                        valueListenable: _currentSongId,
                        builder: (context, currentSongId, _) => IconButton(
                          icon: Icon(playPauseIcon, color: Colors.blue),
                          onPressed: () => _playSong(song.encodeId),
                      ),
                      onTap: (){
                        //Todo: Add song detail screen.
                      },
                    },
                  ),
                );
              },
            );
          } else {
            return const Center(child: Text('No songs found.', style: TextStyle(fontSize: 18)));
          }
        },
      ),
      bottomNavigationBar: _currentSong != null ? _buildPlaybackControls() : null,
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
            context: context,
            builder: (context) => _buildSearchDialog(context),
              ),
        child: const Icon(Icons.add, color: Colors.white),
      backgroundColor: Colors.blue,
      ),
    );
  }


  Future<void> _deletePlaylist(BuildContext context) async {
    try{
      await PlaylistService().deletePlaylist(_playlist.id);
      if(mounted) Navigator.of(context).pop();
    } catch (e) {
      FlutterToast(msg: 'Error deleting playlist.');
    }
  }

}