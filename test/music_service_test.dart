import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/models/track_model.dart';
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

  group('TrackModel YouTube metadata helpers', () {
    test('cleanTitle membersihkan tag noise YouTube', () {
      expect(
        TrackModel.cleanTitle('Champagne Supernova (Official Video)'),
        'Champagne Supernova',
      );
      expect(
        TrackModel.cleanTitle('Hati-Hati di Jalan (Official Music Video)'),
        'Hati-Hati di Jalan',
      );
      expect(
        TrackModel.cleanTitle('Monokrom (Lyrics)'),
        'Monokrom',
      );
      expect(
        TrackModel.cleanTitle('Wonderwall [Official 4K Video]'),
        'Wonderwall',
      );
    });

    test('cleanArtist membersihkan suffix - Topic dan Vevo', () {
      expect(TrackModel.cleanArtist('Oasis - Topic'), 'Oasis');
      expect(TrackModel.cleanArtist('TulusVEVO'), 'Tulus');
    });

    test('parseYouTubeMetadata membedah artist dan title dengan tepat', () {
      final parsed1 = TrackModel.parseYouTubeMetadata(
        'Oasis - Champagne Supernova (Official Video)',
        'Oasis',
      );
      expect(parsed1.artist, 'Oasis');
      expect(parsed1.title, 'Champagne Supernova');

      final parsed2 = TrackModel.parseYouTubeMetadata(
        'Hati-Hati di Jalan',
        'Tulus - Topic',
      );
      expect(parsed2.artist, 'Tulus');
      expect(parsed2.title, 'Hati-Hati di Jalan');
    });
  });

  group('MusicService.scoreTrack relevance ranking', () {
    test('memberikan skor tertinggi untuk artist dan title yang persis sama', () {
      const exact = TrackModel(
        id: '1',
        title: 'Champagne Supernova',
        artist: 'Oasis',
        album: 'YouTube',
        artworkUrl: '',
        durationMs: 449000,
        youtubeId: 'tI-5uv4wryI',
      );

      const cover = TrackModel(
        id: '2',
        title: 'Champagne Supernova (Oasis Cover)',
        artist: 'Noel Gallagher',
        album: 'Live',
        artworkUrl: '',
        durationMs: 400000,
      );

      final scoreExact = MusicService.scoreTrack(exact, 'champagne supernova');
      final scoreCover = MusicService.scoreTrack(cover, 'champagne supernova');

      expect(scoreExact, greaterThan(scoreCover));
    });

    test('penalti terhadap lagu karaoke, backing track, dan cover saat tidak diminta', () {
      const normal = TrackModel(
        id: '1',
        title: 'Monokrom',
        artist: 'Tulus',
        album: 'Album',
        artworkUrl: '',
        durationMs: 200000,
      );

      const karaoke = TrackModel(
        id: '2',
        title: 'Monokrom (Karaoke Version)',
        artist: 'Karaoke Channel',
        album: 'Karaoke',
        artworkUrl: '',
        durationMs: 200000,
      );

      final scoreNormal = MusicService.scoreTrack(normal, 'monokrom');
      final scoreKaraoke = MusicService.scoreTrack(karaoke, 'monokrom');

      expect(scoreNormal, greaterThan(scoreKaraoke));
    });
  });
}
