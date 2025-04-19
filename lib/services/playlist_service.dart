import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/playlist.dart';

class PlaylistService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createPlaylist(String name, String userId) async {
    final playlist = Playlist(
      id: '', // Firestore will generate an ID
      name: name,
      songs: [],
      userId: userId,
    );

    final docRef = await _firestore.collection('playlists').add(playlist.toJson());
    await docRef.update({'id': docRef.id}); // Update the document with the generated ID

    return docRef.id;
  }

  Stream<List<Playlist>> getPlaylists(String userId) {
    return _firestore
        .collection('playlists')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Playlist(
          id: data['id'] as String,
          name: data['name'] as String,
          songs: List<String>.from(data['songs'] as List),
          userId: data['userId'] as String,
        );
      }).toList();
    });
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final playlistRef = _firestore.collection('playlists').doc(playlistId);
    await playlistRef.update({
      'songs': FieldValue.arrayUnion([songId]),
    });
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlistRef = _firestore.collection('playlists').doc(playlistId);
    await playlistRef.update({
      'songs': FieldValue.arrayRemove([songId]),
    });
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _firestore.collection('playlists').doc(playlistId).delete();
  }
}