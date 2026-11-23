import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track_model.dart';
import '../services/download_service.dart';
import '../services/local_library_service.dart';
import '../services/music_service.dart';
import '../services/network_status_service.dart';
import '../services/playlist_backup_service.dart';
import '../services/stable_hash.dart';

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
  String _audioQuality = 'Otomatis (paling lancar, ~96-128 kbps)';

  LibraryProvider() {
    refreshLibrary();
    refreshDownloaded();
    _loadAudioQuality();
    _loadDownloadPreferences();
  }

  Future<void> _loadAudioQuality() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('spotube_audio_quality');
      if (stored == null) return;
      if (stored.toLowerCase().contains('maksimal')) {
        _audioQuality = 'Otomatis (paling lancar, ~96-128 kbps)';
        await prefs.setString('spotube_audio_quality', _audioQuality);
      } else {
        _audioQuality = stored;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Library] gagal memuat kualitas audio: $e');
    }
  }

  Map<String, TrackModel> get likedTracks => _likedTracks;
  List<TrackModel> get likedList {
    final list = _likedTracks.values.toList();
    list.sort((a, b) {
      final aTime = a.likedAt ?? 0;
      final bTime = b.likedAt ?? 0;
      if (aTime != bTime) {
        return bTime.compareTo(aTime);
      }
      return 0;
    });
    return list;
  }
  List<PlaylistModel> get playlists => _playlists;
  List<TrackModel> get downloadedTracks => _downloadedTracks;

  String get audioQuality => _audioQuality;

  bool _wifiOnlyDownloads = false;
  String? _lastDownloadError;

  /// True bila unduhan offline hanya boleh berjalan di Wi-Fi/Ethernet.
  bool get wifiOnlyDownloads => _wifiOnlyDownloads;

  /// Alasan terakhir unduhan ditolak, mis. karena mode Wi-Fi saja.
  String? get lastDownloadError => _lastDownloadError;

  Future<void> _loadDownloadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _wifiOnlyDownloads =
          prefs.getBool('wave_wifi_only_downloads') ?? _wifiOnlyDownloads;
      notifyListeners();
    } catch (e) {
      debugPrint('[Library] gagal memuat preferensi unduhan: $e');
    }
  }

  Future<void> setWifiOnlyDownloads(bool value) async {
    if (_wifiOnlyDownloads == value) return;
    _wifiOnlyDownloads = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('wave_wifi_only_downloads', value);
    } catch (e) {
      debugPrint('[Library] gagal menyimpan preferensi Wi-Fi: $e');
    }
  }

  /// Menolak unduhan bila mode "Hanya Wi-Fi" aktif dan perangkat memakai
  /// jaringan seluler. Mengembalikan pesan alasan, atau null bila boleh lanjut.
  Future<String?> _checkDownloadNetwork() async {
    _lastDownloadError = null;
    if (!_wifiOnlyDownloads) return null;
    if (await NetworkStatusService.isOnWifi()) return null;
    _lastDownloadError =
        'Unduhan dibatalkan: mode "Hanya Wi-Fi" aktif. Sambungkan ke Wi-Fi atau matikan mode tersebut.';
    notifyListeners();
    return _lastDownloadError;
  }

  Future<void> setAudioQuality(String quality) async {
    if (_audioQuality == quality) return;
    _audioQuality = quality;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('spotube_audio_quality', quality);
    } catch (e) {
      debugPrint('[Library] gagal menyimpan kualitas audio: $e');
    }
  }

  /// ID lokal lama memakai `String.hashCode` yang tidak stabil antar-run.
  /// Hitung ulang dari `localPath` agar like/playlist lama tetap valid.
  TrackModel _withStableLocalId(TrackModel track) {
    final path = track.localPath;
    if (path == null || path.isEmpty || !track.id.startsWith('local_')) {
      return track;
    }
    var normalized = path.replaceAll('\\', '/');
    normalized = normalized.replaceFirst(
      RegExp(r'^/sdcard/'),
      '/storage/emulated/0/',
    );
    final id = 'local_${stableHash(normalized.toLowerCase())}';
    return id == track.id ? track : track.copyWith(id: id);
  }

  /// Muat koleksi tersimpan (lagu disukai + playlist) dari penyimpanan lokal.
  Future<void> refreshLibrary() async {
    try {
      var migratedAnyId = false;
      final liked = await _store.loadLiked();
      final baseTime = DateTime.now().millisecondsSinceEpoch - (liked.length * 1000);
      final migratedLiked = <TrackModel>[];
      for (int i = 0; i < liked.length; i++) {
        final original = liked[i];
        var t = _withStableLocalId(original);
        if (t.id != original.id) migratedAnyId = true;
        if (t.likedAt == null) {
          t = t.copyWith(likedAt: baseTime + (i * 1000));
        }
        migratedLiked.add(t);
      }
      _likedTracks
        ..clear()
        ..addEntries(migratedLiked.map((t) => MapEntry(t.id, t)));

      final rawPlaylists = await _store.loadPlaylists();
      _playlists = rawPlaylists.map((item) {
        final tracks = ((item['tracks'] as List<dynamic>?) ?? [])
            .map((t) => TrackModel.fromMap(t as Map<String, dynamic>))
            .map((t) {
              final migrated = _withStableLocalId(t);
              if (migrated.id != t.id) migratedAnyId = true;
              return migrated;
            })
            .toList();
        return PlaylistModel(
          id: item['id']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Playlist',
          tracks: tracks,
        );
      }).toList();

      if (migratedAnyId) {
        await _store.saveLiked(_likedTracks);
        await _store.savePlaylists({
          for (final p in _playlists)
            p.id: {
              'name': p.name,
              'tracks': p.tracks.map((t) => t.toMap()).toList(),
            },
        });
      }
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
      final likedTrack = track.copyWith(
        likedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _likedTracks[track.id] = likedTrack;
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
  ///
  /// Secara default playlist dengan ID yang sama akan digabung (dedupe per
  /// lagu), bukan diduplikasi. Set [replaceExisting] untuk menimpa isinya.
  Future<void> restoreBackup(
    BackupPayload payload, {
    bool replaceExisting = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    int offset = 0;
    for (final raw in payload.likedTracks) {
      final track = _withStableLocalId(raw);
      final likedTrack = track.likedAt != null
          ? track
          : track.copyWith(likedAt: now + (offset++ * 100));
      _likedTracks[likedTrack.id] = likedTrack;
    }
    await _store.saveLiked(_likedTracks);

    final playlists = await _currentPlaylistMap();
    for (final backup in payload.playlists) {
      final id = backup.id.isNotEmpty
          ? backup.id
          : 'pl_${stableHash(backup.name)}';
      final existing = playlists[id];
      final normalizedTracks = backup.tracks.map(_withStableLocalId).toList();
      final backupTracks = normalizedTracks.map((t) => t.toMap()).toList();

      if (existing == null) {
        playlists[id] = {'name': backup.name, 'tracks': backupTracks};
      } else if (replaceExisting) {
        existing['name'] = backup.name;
        existing['tracks'] = backupTracks;
      } else {
        final merged = <String, Map<String, dynamic>>{};
        for (final raw in (existing['tracks'] as List<dynamic>? ?? [])) {
          if (raw is Map<String, dynamic>) {
            merged[raw['id'].toString()] = raw;
          }
        }
        for (final track in normalizedTracks) {
          merged[track.id] = track.toMap();
        }
        existing['tracks'] = merged.values.toList();
      }
    }

    await _store.savePlaylists(playlists);
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

  final Set<String> _downloadingTrackIds = {};
  bool isDownloadingTrack(String trackId) => _downloadingTrackIds.contains(trackId);

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

  /// Judul lagu yang gagal diunduh pada proses unduhan massal terakhir.
  List<String> _lastBulkDownloadFailures = const [];
  List<String> get lastBulkDownloadFailures => _lastBulkDownloadFailures;

  Future<void> bulkDownloadTracks(List<TrackModel> tracks) async {
    // Bersihkan status lama agar UI tidak menampilkan alasan blokir atau
    // kegagalan dari percobaan sebelumnya.
    _lastDownloadError = null;
    _lastBulkDownloadFailures = const [];

    final toDownload = tracks.where((t) => !isDownloaded(t.id)).toList();
    if (toDownload.isEmpty || _isBulkDownloading) return;

    if (await _checkDownloadNetwork() != null) {
      _lastBulkDownloadFailures = const [];
      return;
    }

    _isBulkDownloading = true;
    _bulkTotalCount = toDownload.length;
    _bulkCurrentIndex = 0;
    _bulkDownloadProgress = 0.0;
    _lastBulkDownloadFailures = const [];
    notifyListeners();

    final failures = <String>[];

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
        failures.add(track.title);
      }
    }

    _lastBulkDownloadFailures = List.unmodifiable(failures);
    _isBulkDownloading = false;
    _bulkDownloadProgress = 0.0;
    await refreshDownloaded();
    notifyListeners();
  }

  /// Unduh 1 lagu langsung ke penyimpanan offline lokal.
  Future<bool> downloadSingleTrack(TrackModel track) async {
    _lastDownloadError = null;
    if (isDownloaded(track.id)) return true;
    if (_downloadingTrackIds.contains(track.id)) return false;

    if (await _checkDownloadNetwork() != null) return false;

    _downloadingTrackIds.add(track.id);
    notifyListeners();

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
      );
      await refreshDownloaded();
      return true;
    } catch (e) {
      debugPrint('[Library] unduhan single track gagal untuk "${track.title}": $e');
      return false;
    } finally {
      _downloadingTrackIds.remove(track.id);
      notifyListeners();
    }
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
