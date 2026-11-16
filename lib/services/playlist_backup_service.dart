import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track_model.dart';

/// Kontainer data hasil impor atau ekspor backup koleksi.
class BackupPayload {
  final int version;
  final DateTime exportedAt;
  final List<TrackModel> likedTracks;
  final Map<String, List<TrackModel>> playlists;

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
      'playlists': playlists.map(
        (key, list) => MapEntry(key, list.map((t) => t.toMap()).toList()),
      ),
    };
  }

  factory BackupPayload.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    final dateStr = json['exportedAt'] as String?;
    final exportedAt = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();

    final rawLiked = json['likedTracks'] as List<dynamic>? ?? [];
    final liked = rawLiked
        .whereType<Map<String, dynamic>>()
        .map((m) => TrackModel.fromMap(m))
        .toList();

    final rawPlaylists = json['playlists'] as Map<String, dynamic>? ?? {};
    final playlists = <String, List<TrackModel>>{};

    rawPlaylists.forEach((key, val) {
      if (val is List) {
        playlists[key] = val
            .whereType<Map<String, dynamic>>()
            .map((m) => TrackModel.fromMap(m))
            .toList();
      }
    });

    return BackupPayload(
      version: version,
      exportedAt: exportedAt,
      likedTracks: liked,
      playlists: playlists,
    );
  }
}

/// Layanan ekspor dan impor backup koleksi musik (JSON dan M3U universal).
class PlaylistBackupService {
  static const int currentVersion = 1;

  /// Menghasilkan format JSON lengkap dari seluruh pustaka pengguna.
  static String exportToJsonString({
    required List<TrackModel> likedTracks,
    required Map<String, List<TrackModel>> playlists,
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

  /// Mengekspor daftar lagu ke format playlist standar M3U (#EXTM3U).
  static String exportToM3u({
    required String playlistName,
    required List<TrackModel> tracks,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('#EXTM3U');
    buffer.writeln('#PLAYLIST:$playlistName');

    for (final track in tracks) {
      final seconds = (track.durationMs / 1000).round();
      buffer.writeln('#EXTINF:$seconds,${track.artist} - ${track.title}');
      buffer.writeln(track.youtubeId ?? track.id);
    }

    return buffer.toString();
  }

  /// Mengimpor string M3U menjadi daftar track model sederhana.
  static List<TrackModel> importFromM3u(String content) {
    final lines = content.split(RegExp(r'\r?\n'));
    final tracks = <TrackModel>[];

    String? currentTitle;
    String? currentArtist;
    int currentDurationSec = 0;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#EXTM3U') || line.startsWith('#PLAYLIST:')) {
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
      } else if (!line.startsWith('#')) {
        // Baris URL atau identifier
        final id = line;
        if (currentTitle != null) {
          tracks.add(
            TrackModel(
              id: id,
              title: currentTitle,
              artist: currentArtist ?? 'Artis Tidak Diketahui',
              album: 'Impor M3U',
              artworkUrl: '',
              durationMs: currentDurationSec * 1000,
              youtubeId: id.length == 11 ? id : null,
            ),
          );
          currentTitle = null;
          currentArtist = null;
          currentDurationSec = 0;
        }
      }
    }

    return tracks;
  }

  /// Menyimpan berkas backup JSON ke folder dokumen aplikasi.
  static Future<File> saveBackupToFile({
    required List<TrackModel> likedTracks,
    required Map<String, List<TrackModel>> playlists,
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
