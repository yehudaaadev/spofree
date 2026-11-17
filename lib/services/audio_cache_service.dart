import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Layanan cache disk transparan (LRU) untuk audio pemutaran.
///
/// Menyimpan berkas audio yang baru saja didengarkan ke direktori temporer
/// perangkat dengan batas kuota maksimal (300 MB). Pemutaran ulang lagu yang
/// sama akan langsung memuat berkas lokal tanpa menggunakan kuota internet.
class AudioCacheService {
  AudioCacheService._();
  static final AudioCacheService instance = AudioCacheService._();

  /// Batas maksimal cache audio: 300 MB.
  static const int maxCacheSizeBytes = 300 * 1024 * 1024;

  final Set<String> _cachingTrackIds = {};

  Future<Directory> _getCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/wave_audio_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Memeriksa apakah berkas audio lagu sudah ada di cache lokal.
  Future<File?> getCachedAudioFile(String trackId) async {
    try {
      final cacheDir = await _getCacheDir();
      final file = File('${cacheDir.path}/$trackId.bin');
      if (await file.exists() && await file.length() > 10000) {
        // Perbarui timestamp modifikasi untuk pelacakan LRU
        await file.setLastModified(DateTime.now());
        return file;
      }
    } catch (e) {
      debugPrint('[AudioCacheService] gagal membaca cache: $e');
    }
    return null;
  }

  /// Mengunduh audio ke cache disk secara asinkron di latar belakang.
  Future<void> cacheTrackFromUrl(String trackId, String url) async {
    if (_cachingTrackIds.contains(trackId)) return;
    _cachingTrackIds.add(trackId);

    try {
      final existing = await getCachedAudioFile(trackId);
      if (existing != null) return;

      final cacheDir = await _getCacheDir();
      final tempFile = File('${cacheDir.path}/$trackId.tmp');
      final targetFile = File('${cacheDir.path}/$trackId.bin');

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 12);
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      );
      final response = await request.close();

      if (response.statusCode == 200) {
        final sink = tempFile.openWrite();
        await response.pipe(sink);
        await sink.close();

        if (await tempFile.exists() && await tempFile.length() > 10000) {
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          await tempFile.rename(targetFile.path);
          await _enforceLruLimit();
        } else {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioCacheService] unduh cache dilewati: $e');
    } finally {
      _cachingTrackIds.remove(trackId);
    }
  }

  /// Menghapus berkas yang paling lama tidak diakses jika ukuran cache melebihi batas.
  Future<void> _enforceLruLimit() async {
    try {
      final cacheDir = await _getCacheDir();
      final files = await cacheDir
          .list()
          .where((e) => e is File && e.path.endsWith('.bin'))
          .cast<File>()
          .toList();

      int totalSize = 0;
      final fileStats = <File, FileStat>{};
      for (final f in files) {
        final stat = await f.stat();
        fileStats[f] = stat;
        totalSize += stat.size;
      }

      if (totalSize > maxCacheSizeBytes) {
        // Urutkan dari yang paling lama tidak diakses
        files.sort((a, b) => fileStats[a]!.modified.compareTo(fileStats[b]!.modified));

        for (final f in files) {
          if (totalSize <= (maxCacheSizeBytes * 0.75)) break; // Sisakan ruang 25%
          final size = fileStats[f]!.size;
          await f.delete();
          totalSize -= size;
        }
      }
    } catch (e) {
      debugPrint('[AudioCacheService] penegakan batas LRU gagal: $e');
    }
  }

  /// Menghapus seluruh berkas audio di direktori cache.
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('[AudioCacheService] pembersihan cache gagal: $e');
    }
  }
}
