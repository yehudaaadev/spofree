import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_format.dart';
import 'ranged_http_client.dart';
import 'stable_hash.dart';

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

  /// Ukuran minimum agar berkas dianggap audio utuh (bukan potongan/HTML).
  static const int minValidBytes = 1024;

  final Set<String> _cachingKeys = {};

  Future<Directory> _getCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/wave_audio_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Kunci cache yang aman untuk semua sistem berkas (tanpa `:`/`/`).
  ///
  /// Kualitas ikut diperhitungkan agar berkas 64 kbps tidak dipakai untuk
  /// pemutaran 160 kbps.
  static String cacheKeyFor(String trackId, {String quality = ''}) {
    return stableHash('$trackId|$quality');
  }

  Future<File?> _findCacheFile(Directory dir, String key) async {
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.startsWith('$key.')) continue;
      if (name.endsWith('.part') || name.endsWith('.tmp')) continue;
      return entity;
    }
    return null;
  }

  Future<Uint8List> _readHeader(File file) async {
    final handle = await file.open();
    try {
      final bytes = await handle.read(64);
      return Uint8List.fromList(bytes);
    } finally {
      await handle.close();
    }
  }

  /// Memeriksa apakah berkas audio lagu sudah ada di cache lokal.
  Future<File?> getCachedAudioFile(
    String trackId, {
    String quality = '',
  }) async {
    try {
      final cacheDir = await _getCacheDir();
      final key = cacheKeyFor(trackId, quality: quality);
      final file = await _findCacheFile(cacheDir, key);
      if (file == null) return null;

      if (await file.length() < minValidBytes) {
        await file.delete();
        return null;
      }

      // Jangan pernah memutar berkas yang isinya bukan audio (mis. HTML 403).
      final header = await _readHeader(file);
      if (AudioFormat.detect(header) == AudioFormat.unknown) {
        await file.delete();
        return null;
      }

      // Perbarui timestamp modifikasi untuk pelacakan LRU.
      await file.setLastModified(DateTime.now());
      return file;
    } catch (e) {
      debugPrint('[AudioCacheService] gagal membaca cache: $e');
    }
    return null;
  }

  /// Mengunduh audio ke cache disk secara asinkron di latar belakang.
  Future<void> cacheTrackFromUrl(
    String trackId,
    String url, {
    String quality = '',
  }) async {
    final key = cacheKeyFor(trackId, quality: quality);
    if (_cachingKeys.contains(key)) return;
    _cachingKeys.add(key);

    // Cache harus memakai permintaan Range: CDN YouTube menolak GET biasa
    // tanpa header Range dengan HTTP 403.
    final client = RangedHttpClient();
    File? tempFile;
    try {
      final existing = await getCachedAudioFile(trackId, quality: quality);
      if (existing != null) return;

      final cacheDir = await _getCacheDir();
      tempFile = File('${cacheDir.path}/$key.part');

      const chunkSize = RangedHttpClient.defaultChunkSize;
      var total = 0;
      var written = 0;
      var position = 0;

      final sink = tempFile.openWrite();
      try {
        while (true) {
          final chunk = await client.fetchRange(
            Uri.parse(url),
            start: position,
            end: position + chunkSize - 1,
          );

          if (chunk.bytes.isEmpty) break;
          total = chunk.totalBytes ?? total;

          if (written + chunk.bytes.length > maxCacheSizeBytes) {
            throw const RangedRequestException(
              'Berkas audio melebihi batas ukuran cache.',
            );
          }

          sink.add(chunk.bytes);
          written += chunk.bytes.length;
          position += chunk.bytes.length;

          if (total > 0 && position >= total) break;
          if (chunk.bytes.length < chunkSize) break;
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      // Tanpa total, panjang data tidak bisa diverifikasi; jangan simpan
      // berkas yang mungkin terpotong sebagai cache yang akan diputar.
      if (total <= 0) {
        throw const RangedRequestException(
          'Ukuran total audio tidak diketahui; cache dilewati.',
        );
      }
      if (written != total) {
        throw RangedRequestException(
          'Unduhan cache tidak lengkap ($written/$total byte).',
        );
      }
      if (written < minValidBytes) {
        throw RangedRequestException(
          'Data cache terlalu kecil ($written byte).',
        );
      }

      final header = await _readHeader(tempFile);
      final format = AudioFormat.detect(header);
      if (format == AudioFormat.unknown) {
        throw const RangedRequestException(
          'Isi cache bukan audio yang dikenali.',
        );
      }

      // Hapus varian lama dengan ekstensi berbeda agar `_findCacheFile` tidak
      // memilih kontainer basi saat format stream berubah (mis. MP4 -> WebM).
      await for (final entity in cacheDir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('$key.') || name.endsWith('.part')) continue;
        try {
          await entity.delete();
        } catch (_) {
          // Abaikan: berkas mungkin sedang dipakai pemutar.
        }
      }

      final target = File('${cacheDir.path}/$key${format.extension}');
      if (await target.exists()) {
        await target.delete();
      }
      await tempFile.rename(target.path);
      tempFile = null;
      await _enforceLruLimit();
    } catch (e) {
      debugPrint('[AudioCacheService] unduh cache dilewati: $e');
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {
          // Abaikan: pembersihan terbaik yang bisa dilakukan.
        }
      }
      client.close();
      _cachingKeys.remove(key);
    }
  }

  /// Menghapus berkas yang paling lama tidak diakses jika ukuran cache melebihi batas.
  Future<void> _enforceLruLimit() async {
    try {
      final cacheDir = await _getCacheDir();
      final files = await cacheDir
          .list()
          .where(
            (e) =>
                e is File &&
                !e.path.endsWith('.part') &&
                !e.path.endsWith('.tmp'),
          )
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
          try {
            await f.delete();
            totalSize -= size;
          } catch (e) {
            // Berkas mungkin sedang diputar di Windows; lewati saja.
            debugPrint('[AudioCacheService] gagal menghapus cache: $e');
          }
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

  /// Ukuran total dan jumlah berkas cache audio saat ini.
  Future<({int bytes, int files})> getCacheStats() async {
    var bytes = 0;
    var files = 0;
    try {
      final cacheDir = await _getCacheDir();
      await for (final entity in cacheDir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.endsWith('.part') || name.endsWith('.tmp')) continue;
        try {
          bytes += await entity.length();
          files++;
        } catch (_) {
          // Berkas bisa terhapus saat sedang dihitung; abaikan.
        }
      }
    } catch (e) {
      debugPrint('[AudioCacheService] gagal menghitung ukuran cache: $e');
    }
    return (bytes: bytes, files: files);
  }
}
