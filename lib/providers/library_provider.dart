import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/track_model.dart';
import '../services/download_service.dart';

class PlaylistModel {
  final String id;
  final String name;
  final List<TrackModel> tracks;

  const PlaylistModel({
    required this.id,
    required this.name,
    required this.tracks,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tracks': tracks.map((t) => t.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PlaylistModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final rawTracks = data['tracks'] as List<dynamic>? ?? [];
    return PlaylistModel(
      id: doc.id,
      name: data['name']?.toString() ?? 'Playlist',
      tracks: rawTracks
          .map((item) => TrackModel.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LibraryProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DownloadService _downloadService = DownloadService();

  String? _userId;
  StreamSubscription? _likedSub;
  StreamSubscription? _playlistsSub;

  final Map<String, TrackModel> _likedTracks = {};
  List<PlaylistModel> _playlists = [];
  List<TrackModel> _downloadedTracks = [];

  LibraryProvider() {
    refreshDownloaded();
  }

  Map<String, TrackModel> get likedTracks => _likedTracks;
  List<TrackModel> get likedList => _likedTracks.values.toList();
  List<PlaylistModel> get playlists => _playlists;
  List<TrackModel> get downloadedTracks => _downloadedTracks;

  void updateUser(String? uid) {
    if (_userId == uid) return;
    _userId = uid;
    _likedSub?.cancel();
    _playlistsSub?.cancel();
    _likedTracks.clear();
    _playlists.clear();

    if (uid != null) {
      _listenLiked(uid);
      _listenPlaylists(uid);
    }
    notifyListeners();
  }

  void _listenLiked(String uid) {
    _likedSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('liked_songs')
        .snapshots()
        .listen((snapshot) {
      _likedTracks.clear();
      for (final doc in snapshot.docs) {
        try {
          final track = TrackModel.fromMap(doc.data());
          _likedTracks[track.id] = track;
        } catch (_) {}
      }
      notifyListeners();
    });
  }

  void _listenPlaylists(String uid) {
    _playlistsSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('playlists')
        .snapshots()
        .listen((snapshot) {
      _playlists = snapshot.docs.map((doc) => PlaylistModel.fromDoc(doc)).toList();
      notifyListeners();
    });
  }

  bool isLiked(String trackId) {
    return _likedTracks.containsKey(trackId);
  }

  Future<void> toggleLike(TrackModel track) async {
    if (_userId == null) return;
    final docRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('liked_songs')
        .doc(track.id);

    if (isLiked(track.id)) {
      _likedTracks.remove(track.id);
      notifyListeners();
      await docRef.delete();
    } else {
      _likedTracks[track.id] = track;
      notifyListeners();
      await docRef.set(track.toMap(), SetOptions(merge: true));
    }
  }

  Future<void> createPlaylist(String name) async {
    if (_userId == null || name.trim().isEmpty) return;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('playlists')
        .add({
      'name': name.trim(),
      'tracks': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addTrackToPlaylist(String playlistId, TrackModel track) async {
    if (_userId == null) return;
    final docRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('playlists')
        .doc(playlistId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final tracks = (data['tracks'] as List<dynamic>? ?? [])
        .map((t) => TrackModel.fromMap(t as Map<String, dynamic>))
        .toList();

    if (!tracks.any((t) => t.id == track.id)) {
      tracks.add(track);
      await docRef.update({
        'tracks': tracks.map((t) => t.toMap()).toList(),
      });
    }
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    if (_userId == null) return;
    final docRef = _firestore
        .collection('users')
        .doc(_userId)
        .collection('playlists')
        .doc(playlistId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final tracks = (data['tracks'] as List<dynamic>? ?? [])
        .map((t) => TrackModel.fromMap(t as Map<String, dynamic>))
        .where((t) => t.id != trackId)
        .toList();

    await docRef.update({
      'tracks': tracks.map((t) => t.toMap()).toList(),
    });
  }

  Future<void> deletePlaylist(String playlistId) async {
    if (_userId == null) return;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('playlists')
        .doc(playlistId)
        .delete();
  }

  Future<void> refreshDownloaded() async {
    _downloadedTracks = await _downloadService.getDownloadedTracks();
    notifyListeners();
  }

  bool isDownloaded(String trackId) {
    return _downloadedTracks.any((t) => t.id == trackId);
  }

  TrackModel? getDownloadedTrack(String trackId) {
    try {
      return _downloadedTracks.firstWhere((t) => t.id == trackId);
    } catch (_) {
      return null;
    }
  }

  Future<void> removeDownloadedTrack(String trackId) async {
    await _downloadService.removeDownload(trackId);
    await refreshDownloaded();
  }

  @override
  void dispose() {
    _likedSub?.cancel();
    _playlistsSub?.cancel();
    super.dispose();
  }
}
