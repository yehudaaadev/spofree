import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_cache_service.dart';
import 'download_service.dart';

/// Ringkasan pemakaian penyimpanan aplikasi.
class StorageSnapshot {
  final int cacheBytes;
  final int cacheFiles;
  final int downloadBytes;
  final int downloadCount;
  final int? freeBytes;
  final int? totalBytes;

  const StorageSnapshot({
    required this.cacheBytes,
    required this.cacheFiles,
    required this.downloadBytes,
    required this.downloadCount,
    this.freeBytes,
    this.totalBytes,
  });

  /// Bagian ruang terpakai dari total partisi (0.0 - 1.0), bila diketahui.
  double? get usedFraction {
    final free = freeBytes;
    final total = totalBytes;
    if (free == null || total == null || total <= 0) return null;
    return ((total - free) / total).clamp(0.0, 1.0);
  }
}

/// Membaca ukuran cache, unduhan offline, dan ruang disk perangkat.
class StorageStatsService {
  StorageStatsService._();

  static const MethodChannel _channel =
      MethodChannel('com.david.spotify_pribadi/storage');

  static Future<StorageSnapshot> load() async {
    final cache = await AudioCacheService.instance.getCacheStats();
    final downloads = await DownloadService().getDownloadedTracks();
    final downloadBytes = await DownloadService().getDownloadsSizeBytes();

    int? freeBytes;
    int? totalBytes;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final stats = await _channel.invokeMapMethod<String, dynamic>(
          'getStorageStats',
        );
        freeBytes = (stats?['freeBytes'] as num?)?.toInt();
        totalBytes = (stats?['totalBytes'] as num?)?.toInt();
      } catch (e) {
        debugPrint('[StorageStatsService] statistik disk gagal: $e');
      }
    }

    return StorageSnapshot(
      cacheBytes: cache.bytes,
      cacheFiles: cache.files,
      downloadBytes: downloadBytes,
      downloadCount: downloads.length,
      freeBytes: freeBytes,
      totalBytes: totalBytes,
    );
  }

  /// Format ukuran byte menjadi teks yang mudah dibaca.
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = value >= 100 || unit == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
  }
}
