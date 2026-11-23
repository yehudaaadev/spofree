import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/track_model.dart';
import 'stable_hash.dart';
import 'storage_permission_service.dart';

/// Pemindai berkas audio lokal di penyimpanan perangkat.
///
/// Durasi berkas lokal tidak dapat ditentukan tanpa decoding audio, sehingga
/// `durationMs` sengaja diisi 0 (tidak ditebak dari ukuran berkas). Durasi
/// sebenarnya akan terisi otomatis oleh pemutar setelah berkas dimuat.
class LocalAudioService {
  static const List<String> supportedExtensions = [
    '.mp3',
    '.m4a',
    '.wav',
    '.flac',
    '.aac',
    '.ogg',
    '.opus',
    '.webm',
  ];

  /// Folder yang dipindai pada perangkat Android.
  static const List<String> androidSearchDirectories = [
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Documents',
    '/storage/emulated/0/Audio',
    '/sdcard/Music',
    '/sdcard/Download',
  ];

  /// Folder pemindaian sesuai platform. Desktop memakai folder Music/Downloads
  /// milik pengguna, bukan path Android yang tidak ada.
  static List<String> get searchDirectories {
    if (kIsWeb) return const [];
    if (Platform.isAndroid) return androidSearchDirectories;
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home == null || home.isEmpty) return const [];
    final sep = Platform.pathSeparator;
    return ['$home${sep}Music', '$home${sep}Downloads'];
  }

  /// Menyatukan `/sdcard` dan `/storage/emulated/0` agar berkas tidak ganda.
  static String canonicalPath(String path) {
    var normalized = path.replaceAll('\\', '/');
    normalized = normalized.replaceFirst(
      RegExp(r'^/sdcard/'),
      '/storage/emulated/0/',
    );
    return normalized;
  }

  /// Apakah aplikasi memiliki izin untuk membaca penyimpanan perangkat.
  static Future<bool> hasStoragePermission() async {
    return StoragePermissionService.hasPermission();
  }

  /// Minta izin akses penyimpanan kepada pengguna bila belum tersedia.
  static Future<bool> requestStoragePermission() async {
    return StoragePermissionService.requestPermission();
  }

  static Future<List<TrackModel>> scanLocalAudioFiles() async {
    final List<TrackModel> foundTracks = [];
    final Set<String> seenPaths = {};

    for (final dirPath in searchDirectories) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;

      try {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;

          final path = canonicalPath(entity.path);
          final lower = path.toLowerCase();
          final matches =
              supportedExtensions.any((ext) => lower.endsWith(ext));

          if (matches && seenPaths.add(lower)) {
            final track = _createTrackFromFile(File(path));
            if (track != null) {
              foundTracks.add(track);
            }
          }
        }
      } catch (e) {
        debugPrint('[LocalAudioService] gagal memindai $dirPath: $e');
      }
    }

    return foundTracks;
  }

  static TrackModel? _createTrackFromFile(File file) {
    try {
      final fileName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : file.path.split(Platform.pathSeparator).last;

      final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      String artist = 'Penyimpanan Lokal';
      String title = nameWithoutExt;

      if (nameWithoutExt.contains(' - ')) {
        final parts = nameWithoutExt.split(' - ');
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      } else if (nameWithoutExt.contains('-')) {
        final parts = nameWithoutExt.split('-');
        artist = parts[0].trim();
        title = parts.sublist(1).join('-').trim();
      }

      return TrackModel(
        // Hash stabil: `String.hashCode` berubah antar-run sehingga like dan
        // playlist lokal bisa menunjuk ID yang sudah tidak ada.
        id: 'local_${stableHash(file.path.toLowerCase())}',
        title: title.isNotEmpty ? title : 'Lagu Lokal',
        artist: artist.isNotEmpty ? artist : 'Artis Tidak Diketahui',
        album: 'File Internal',
        artworkUrl: '',
        // Durasi unknown: 0 berarti pemutar mengisi durasi sebenarnya saat memuat.
        durationMs: 0,
        localPath: file.path,
        mimeType: _mimeForExtension(file.path),
      );
    } catch (e) {
      debugPrint('[LocalAudioService] gagal membaca metadata berkas: $e');
      return null;
    }
  }

  static String? _mimeForExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.opus')) return 'audio/ogg';
    if (lower.endsWith('.webm')) return 'audio/webm';
    return null;
  }
}
