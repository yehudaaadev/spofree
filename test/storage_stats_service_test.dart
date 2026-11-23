import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/services/storage_stats_service.dart';

void main() {
  group('StorageStatsService.formatBytes', () {
    test('menampilkan byte tanpa desimal', () {
      expect(StorageStatsService.formatBytes(0), '0 B');
      expect(StorageStatsService.formatBytes(512), '512 B');
      expect(StorageStatsService.formatBytes(1023), '1023 B');
    });

    test('mengonversi ke KB, MB, dan GB', () {
      expect(StorageStatsService.formatBytes(1024), '1.0 KB');
      expect(StorageStatsService.formatBytes(1536), '1.5 KB');
      expect(StorageStatsService.formatBytes(1024 * 1024), '1.0 MB');
      expect(
        StorageStatsService.formatBytes(1024 * 1024 * 1024),
        '1.0 GB',
      );
      expect(
        StorageStatsService.formatBytes(5 * 1024 * 1024 * 1024),
        '5.0 GB',
      );
    });

    test('nilai negatif dianggap kosong', () {
      expect(StorageStatsService.formatBytes(-1), '0 B');
    });
  });

  group('StorageSnapshot.usedFraction', () {
    test('menghitung fraksi ruang terpakai', () {
      const snapshot = StorageSnapshot(
        cacheBytes: 0,
        cacheFiles: 0,
        downloadBytes: 0,
        downloadCount: 0,
        freeBytes: 25,
        totalBytes: 100,
      );
      expect(snapshot.usedFraction, closeTo(0.75, 0.0001));
    });

    test('null bila statistik disk tidak tersedia', () {
      const snapshot = StorageSnapshot(
        cacheBytes: 0,
        cacheFiles: 0,
        downloadBytes: 0,
        downloadCount: 0,
      );
      expect(snapshot.usedFraction, isNull);
    });

    test('nilai total nol tidak menghasilkan pembagian nol', () {
      const snapshot = StorageSnapshot(
        cacheBytes: 0,
        cacheFiles: 0,
        downloadBytes: 0,
        downloadCount: 0,
        freeBytes: 0,
        totalBytes: 0,
      );
      expect(snapshot.usedFraction, isNull);
    });
  });
}
