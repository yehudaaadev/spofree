import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/track_model.dart';
import '../services/download_service.dart';
import '../services/local_library_service.dart';
import '../services/music_service.dart';
import '../services/playlist_backup_service.dart';

/// Metadata sebuah playlist beserta lagunya.
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
    };
  }
}

/// Kelola koleksi pengguna tanpa login: lagu disukai, playlist, dan berkas
/// offline. Seluruh data disimpan lokal di perangkat (SharedPreferences),
/// sehingga aplikasi tetap berfungsi penuh tanpa layanan cloud.
class LibraryProvider with ChangeNotifier {
  final LocalLibraryService _store = LocalLibraryService();
  final DownloadService _downloadService = DownloadService();
  final MusicService _musicService = MusicService.instance;

  final Map<String, TrackModel> _likedTracks = {};
  List<PlaylistModel> _playlists = [];
  List<TrackModel> _downloadedTracks = [];

  /// Kualitas audio yang dipakai saat unduhan (disinkronkan dengan pilihan
  /// kualitas di panel opsi pemutar).
  String _audioQuality = 'Maksimal (320 kbps High Quality)';

  LibraryProvider() {
    refreshLibrary();
    refreshDownloaded();
  }

  Map<String, TrackModel> get likedTracks => _likedTracks;
  List<TrackModel> get likedList => _likedTracks.values.toList();
  List<PlaylistModel> get playlists => _playlists;
  List<TrackModel> get downloadedTracks => _downloadedTracks;

  String get audioQuality => _audioQuality;

  void setAudioQuality(String quality) {
    _audioQuality = quality;
  }

  /// Muat koleksi tersimpan (lagu disukai + playlist) dari penyimpanan lokal.
  Future<void> refreshLibrary() async {
    try {
      final liked = await _store.loadLiked();
      _likedTracks
        ..clear()
        ..addEntries(liked.map((t) => MapEntry(t.id, t)));

      final rawPlaylists = await _store.loadPlaylists();
      _playlists = rawPlaylists.map((item) {
        final tracks = ((item['tracks'] as List<dynamic>?) ?? [])
            .map((t) => TrackModel.fromMap(t as Map<String, dynamic>))
            .toList();
        return PlaylistModel(
          id: item['id']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Playlist',
          tracks: tracks,
        );
      }).toList();
    } catch (e) {
      debugPrint('[Library] pemuatan koleksi lokal gagal: $e');
    }
    notifyListeners();
  }

  bool isLiked(String trackId) {
    return _likedTracks.containsKey(trackId);
  }

  Future<void> toggleLike(TrackModel track) async {
    if (isLiked(track.id)) {
      _likedTracks.remove(track.id);
    } else {
      _likedTracks[track.id] = track;
    }
    notifyListeners();
    try {
      await _store.saveLiked(_likedTracks);
    } catch (e) {
      debugPrint('[Library] penyimpanan lagu disukai gagal: $e');
    }
  }

  Future<void> createPlaylist(String name) async {
    if (name.trim().isEmpty) return;
    final id = 'pl_${DateTime.now().microsecondsSinceEpoch}';
    final playlists = await _currentPlaylistMap();
    playlists[id] = {
      'name': name.trim(),
      'tracks': <Map<String, dynamic>>[],
    };
    await _store.savePlaylists(playlists);
    await refreshLibrary();
  }

  Future<void> importFullPlaylist(String name, List<TrackModel> tracks) async {
    if (name.trim().isEmpty) return;
    final id = 'pl_${DateTime.now().microsecondsSinceEpoch}';
    final playlists = await _currentPlaylistMap();
    playlists[id] = {
      'name': name.trim(),
      'tracks': tracks.map((t) => t.toMap()).toList(),
    };
    await _store.savePlaylists(playlists);
    await refreshLibrary();
  }

  /// Memulihkan koleksi lagu disukai dan playlist dari berkas backup.
  Future<void> restoreBackup(BackupPayload payload) async {
    for (final track in payload.likedTracks) {
      _likedTracks[track.id] = track;
    }
    await _store.saveLiked(_likedTracks);

    for (final entry in payload.playlists.entries) {
      await importFullPlaylist(entry.key, entry.value);
    }
    await refreshLibrary();
  }

  Future<void> addTrackToPlaylist(String playlistId, TrackModel track) async {
    final playlists = await _currentPlaylistMap();
    final entry = playlists[playlistId];
    if (entry == null) return;

    final tracks = ((entry['tracks'] as List<dynamic>?) ?? [])
        .map((t) => t as Map<String, dynamic>)
        .toList();
    if (tracks.any((t) => t['id'] == track.id)) return;

    tracks.add(track.toMap());
    entry['tracks'] = tracks;
    await _store.savePlaylists(playlists);
    await refreshLibrary();
  }

  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final playlists = await _currentPlaylistMap();
    final entry = playlists[playlistId];
    if (entry == null) return;

    final tracks = ((entry['tracks'] as List<dynamic>?) ?? [])
        .map((t) => t as Map<String, dynamic>)
        .where((t) => t['id'] != trackId)
        .toList();
    entry['tracks'] = tracks;
    await _store.savePlaylists(playlists);
    await refreshLibrary();
  }

  Future<void> deletePlaylist(String playlistId) async {
    final playlists = await _currentPlaylistMap();
    if (playlists.remove(playlistId) == null) return;
    await _store.savePlaylists(playlists);
    await refreshLibrary();
  }

  /// Bentuk map playlist mentah untuk ditulis ke penyimpanan.
  Future<Map<String, Map<String, dynamic>>> _currentPlaylistMap() async {
    final raw = await _store.loadPlaylists();
    return {
      for (final item in raw)
        item['id'].toString(): {
          'name': item['name'],
          'tracks': item['tracks'],
        },
    };
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

  bool _isBulkDownloading = false;
  double _bulkDownloadProgress = 0.0;
  int _bulkCurrentIndex = 0;
  int _bulkTotalCount = 0;

  bool get isBulkDownloading => _isBulkDownloading;
  double get bulkDownloadProgress => _bulkDownloadProgress;
  int get bulkCurrentIndex => _bulkCurrentIndex;
  int get bulkTotalCount => _bulkTotalCount;

  Future<void> bulkDownloadTracks(List<TrackModel> tracks) async {
    final toDownload = tracks.where((t) => !isDownloaded(t.id)).toList();
    if (toDownload.isEmpty || _isBulkDownloading) return;

    _isBulkDownloading = true;
    _bulkTotalCount = toDownload.length;
    _bulkCurrentIndex = 0;
    _bulkDownloadProgress = 0.0;
    notifyListeners();

    for (int i = 0; i < toDownload.length; i++) {
      _bulkCurrentIndex = i + 1;
      final track = toDownload[i];
      try {
        final streamUrl = await _musicService.resolveAudioStream(
          track,
          quality: _audioQuality,
        );
        await _downloadService.downloadTrack(
          track: track,
          audioStreamUrl: streamUrl,
          musicService: _musicService,
          quality: _audioQuality,
          onProgress: (p) {
            _bulkDownloadProgress = ((i + p) / _bulkTotalCount).clamp(0.0, 1.0);
            notifyListeners();
          },
        );
      } catch (e) {
        debugPrint('[Library] unduhan massal gagal untuk "${track.title}": $e');
      }
    }

    _isBulkDownloading = false;
    _bulkDownloadProgress = 0.0;
    await refreshDownloaded();
  }

  /// Ekspor berkas audio ke folder yang dapat diakses pengguna.
  Future<ExportResult> exportTrack(
    TrackModel track, {
    String folderName = 'Download',
  }) async {
    return _downloadService.exportToDirectory(track, folderName: folderName);
  }

  Future<void> removeDownloadedTrack(String trackId) async {
    await _downloadService.removeDownload(trackId);
    await refreshDownloaded();
  }
}
