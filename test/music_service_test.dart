import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/services/music_service.dart';

void main() {
  group('MusicService.targetBitrateForQuality', () {
    test('memetakan label kualitas ke target bitrate', () {
      expect(
        MusicService.targetBitrateForQuality('Hemat (64 kbps - Sangat Hemat Kuota)'),
        64,
      );
      expect(
        MusicService.targetBitrateForQuality('Standar (128 kbps - Standar Spotify)'),
        128,
      );
      expect(
        MusicService.targetBitrateForQuality('Tinggi (HQ 160-256 kbps - Kualitas Seimbang)'),
        192,
      );
      expect(
        MusicService.targetBitrateForQuality('Maksimal (320 kbps - Kualitas Tertinggi HQ)'),
        320,
      );
    });

    test('nilai tak dikenal jatuh ke kualitas maksimum', () {
      expect(MusicService.targetBitrateForQuality('Apapun'), 320);
    });
  });

  group('MusicService.selectStreamIndex', () {
    final bitrates = <double>[32, 64, 128, 160, 192, 256, 320];

    test('kualitas hemat memilih stream terdekat dari 64 kbps', () {
      expect(MusicService.selectStreamIndex(bitrates, 'Hemat'), 1);
    });

    test('kualitas standar memilih stream terdekat dari 128 kbps', () {
      expect(MusicService.selectStreamIndex(bitrates, 'Standar'), 2);
    });

    test('kualitas tinggi memilih stream terdekat dari 192 kbps', () {
      expect(MusicService.selectStreamIndex(bitrates, 'Tinggi'), 4);
    });

    test('kualitas maksimal memilih bitrate tertinggi', () {
      expect(MusicService.selectStreamIndex(bitrates, 'Maksimal'), 6);
    });

    test('daftar kosong menghasilkan indeks -1', () {
      expect(MusicService.selectStreamIndex(const <double>[], 'Maksimal'), -1);
    });

    test('daftar tidak terurut tetap menghasilkan stream optimal', () {
      const unordered = <double>[320, 64, 128];
      // Setelah diurutkan: [64, 128, 320]
      expect(MusicService.selectStreamIndex(unordered, 'Standar'), 1);
      expect(MusicService.selectStreamIndex(unordered, 'Maksimal'), 2);
    });
  });
}
