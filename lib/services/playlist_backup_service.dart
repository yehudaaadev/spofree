import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track_model.dart';
import 'stable_hash.dart';

/// Satu playlist di dalam backup.
///
/// Memakai ID playlist (bukan nama) agar dua playlist bernama sama tidak
/// saling menimpa saat ekspor/impor.
class BackupPlaylist {
  final String id;
  final String name;
  final List<TrackModel> tracks;

  const BackupPlaylist({
    required this.id,
    required this.name,
    required this.tracks,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tracks': tracks.map((t) => t.toMap()).toList(),
    };
  }

  factory BackupPlaylist.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? 'Playlist';
    final rawId = json['id']?.toString();
    final id = (rawId == null || rawId.isEmpty)
        ? 'pl_${stableHash(name)}'
        : rawId;
    final tracks = ((json['tracks'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(TrackModel.fromMap)
        .toList();
    return BackupPlaylist(id: id, name: name, tracks: tracks);
  }
}

/// Kontainer data hasil impor atau ekspor backup koleksi.
class BackupPayload {
  final int version;
  final DateTime exportedAt;
  final List<TrackModel> likedTracks;
  final List<BackupPlaylist> playlists;

  const BackupPayload({
    required this.version,
    required this.exportedAt,
    required this.likedTracks,
    required this.playlists,
  });

  Map<String, dynamic> toJson() {
    return {
      'format': 'WaveMusicBackup',
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'likedTracks': likedTracks.map((t) => t.toMap()).toList(),
      'playlists': playlists.map((p) => p.toJson()).toList(),
    };
  }

  factory BackupPayload.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    final dateStr = json['exportedAt'] as String?;
    final exportedAt = dateStr != null
        ? DateTime.tryParse(dateStr) ?? DateTime.now()
        : DateTime.now();

    final rawLiked = json['likedTracks'] as List<dynamic>? ?? [];
    final liked = rawLiked
        .whereType<Map<String, dynamic>>()
        .map((m) => TrackModel.fromMap(m))
        .toList();

    final playlists = <BackupPlaylist>[];
    final rawPlaylists = json['playlists'];

    if (rawPlaylists is List) {
      // Format v2: daftar playlist dengan id + name.
      for (final item in rawPlaylists.whereType<Map<String, dynamic>>()) {
        playlists.add(BackupPlaylist.fromJson(item));
      }
    } else if (rawPlaylists is Map<String, dynamic>) {
      // Format v1: nama playlist sebagai key. ID diturunkan dari nama agar
      // restore berulang tidak menduplikasi playlist yang sama.
      rawPlaylists.forEach((name, value) {
        if (value is List) {
          playlists.add(
            BackupPlaylist(
              id: 'pl_${stableHash(name)}',
              name: name,
              tracks: value
                  .whereType<Map<String, dynamic>>()
                  .map(TrackModel.fromMap)
                  .toList(),
            ),
          );
        }
      });
    }

    return BackupPayload(
      version: version,
      exportedAt: exportedAt,
      likedTracks: liked,
      playlists: playlists,
    );
  }
}

/// Layanan ekspor dan impor backup koleksi musik (JSON dan M3U).
class PlaylistBackupService {
  static const int currentVersion = 2;

  /// Menghasilkan format JSON lengkap dari seluruh pustaka pengguna.
  static String exportToJsonString({
    required List<TrackModel> likedTracks,
    required List<BackupPlaylist> playlists,
  }) {
    final payload = BackupPayload(
      version: currentVersion,
      exportedAt: DateTime.now(),
      likedTracks: likedTracks,
      playlists: playlists,
    );
    return const JsonEncoder.withIndent('  ').convert(payload.toJson());
  }

  /// Membaca dan memvalidasi string JSON backup.
  static BackupPayload? importFromJsonString(String content) {
    try {
      final decoded = json.decode(content);
      if (decoded is Map<String, dynamic>) {
        return BackupPayload.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[PlaylistBackupService] importFromJsonString gagal: $e');
    }
    return null;
  }

  /// URI yang bisa dipakai pemutar lain. ID internal aplikasi tidak ditulis.
  static String? _exportUriFor(TrackModel track) {
    if (track.localPath != null && track.localPath!.isNotEmpty) {
      return track.localPath;
    }
    final yt = track.youtubeId;
    if (yt != null && yt.isNotEmpty) {
      return 'https://www.youtube.com/watch?v=$yt';
    }
    return null;
  }

  /// Mengekspor daftar lagu ke format playlist standar M3U (#EXTM3U).
  static String exportToM3u({
    required String playlistName,
    required List<TrackModel> tracks,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#PLAYLIST:$playlistName');

    for (final track in tracks) {
      final uri = _exportUriFor(track);
      if (uri == null) continue;
      final seconds = (track.durationMs / 1000).round();
      buffer.writeln('#EXTINF:$seconds,${track.artist} - ${track.title}');
      buffer.writeln(uri);
    }

    return buffer.toString();
  }

  static bool _looksLikeLocalPath(String value) {
    if (value.startsWith('/') || value.startsWith('\\\\')) return true;
    return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);
  }

  static String? _youTubeIdFromUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final host = uri.host.toLowerCase();
    if (host.endsWith('youtu.be')) {
      final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      return (id != null && id.length == 11) ? id : null;
    }
    if (host.endsWith('youtube.com') || host.endsWith('youtube-nocookie.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && v.length == 11) return v;
      if (uri.pathSegments.length >= 2 &&
          (uri.pathSegments.first == 'shorts' ||
              uri.pathSegments.first == 'embed' ||
              uri.pathSegments.first == 'live')) {
        final id = uri.pathSegments[1];
        return id.length == 11 ? id : null;
      }
    }
    return null;
  }

  static String _titleFromUri(String value) {
    final uri = Uri.tryParse(value);
    final segment = (uri != null && uri.pathSegments.isNotEmpty)
        ? uri.pathSegments.last
        : value.split(RegExp(r'[\\/]')).last;
    final withoutExt = segment.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    final title = Uri.decodeComponent(withoutExt).replaceAll('_', ' ').trim();
    return title.isEmpty ? 'Lagu Impor' : title;
  }

  /// Mengimpor string M3U menjadi daftar track model sederhana.
  ///
  /// Mendukung entri `#EXTINF` maupun URI tanpa metadata, serta path lokal,
  /// URL YouTube, dan ID YouTube 11 karakter (format lama Wave).
  static List<TrackModel> importFromM3u(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final tracks = <TrackModel>[];

    String? currentTitle;
    String? currentArtist;
    int currentDurationSec = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty ||
          line.startsWith('#EXTM3U') ||
          line.startsWith('#PLAYLIST:')) {
        continue;
      }

      if (line.startsWith('#EXTINF:')) {
        final infoPart = line.substring(8);
        final commaIndex = infoPart.indexOf(',');
        if (commaIndex != -1) {
          final durStr = infoPart.substring(0, commaIndex).trim();
          currentDurationSec = int.tryParse(durStr) ?? 0;
          final titlePart = infoPart.substring(commaIndex + 1).trim();
          final dashIndex = titlePart.indexOf(' - ');
          if (dashIndex != -1) {
            currentArtist = titlePart.substring(0, dashIndex).trim();
            currentTitle = titlePart.substring(dashIndex + 3).trim();
          } else {
            currentArtist = 'Artis Tidak Diketahui';
            currentTitle = titlePart;
          }
        }
        continue;
      }

      if (line.startsWith('#')) continue;

      final isUrl = line.startsWith('http://') || line.startsWith('https://');
      String? youtubeId;
      String? localPath;
      String id;

      if (isUrl) {
        youtubeId = _youTubeIdFromUrl(line);
        if (youtubeId != null) {
          id = 'yt_$youtubeId';
        } else {
          id = 'url_${stableHash(line)}';
        }
      } else if (_looksLikeLocalPath(line)) {
        localPath = line;
        id = 'local_${stableHash(line.toLowerCase())}';
      } else if (line.length == 11) {
        youtubeId = line;
        id = 'yt_$line';
      } else if (line.startsWith('yt_') && line.length == 14) {
        youtubeId = line.substring(3);
        id = line;
      } else {
        id = line;
      }

      final title = currentTitle ?? _titleFromUri(line);
      final artist = currentArtist ?? 'Artis Tidak Diketahui';
      tracks.add(
        TrackModel(
          id: id,
          title: title,
          artist: artist,
          album: 'Impor M3U',
          artworkUrl: '',
          durationMs: currentDurationSec * 1000,
          youtubeId: youtubeId,
          localPath: localPath,
        ),
      );
      currentTitle = null;
      currentArtist = null;
      currentDurationSec = 0;
    }

    return tracks;
  }

  /// Menyimpan berkas backup JSON ke folder dokumen aplikasi.
  static Future<File> saveBackupToFile({
    required List<TrackModel> likedTracks,
    required List<BackupPlaylist> playlists,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${backupDir.path}/wave_music_backup_$dateStr.json');
    final jsonContent = exportToJsonString(
      likedTracks: likedTracks,
      playlists: playlists,
    );

    return await file.writeAsString(jsonContent);
  }
}
