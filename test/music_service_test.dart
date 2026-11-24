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
      expect(
        MusicService.targetBitrateForQuality(
          'Otomatis (paling lancar, ~96-128 kbps)',
        ),
        128,
      );
    });

    test('nilai tak dikenal jatuh ke kualitas maksimum', () {
      expect(MusicService.targetBitrateForQuality('Apapun'), 320);
    });
  });

  group('MusicService.shouldPreferProgressiveQuality', () {
    test('hanya mode Otomatis yang memakai progressive tag 18', () {
      expect(
        MusicService.shouldPreferProgressiveQuality('Otomatis'),
        isTrue,
      );
      expect(
        MusicService.shouldPreferProgressiveQuality(
          'Hemat (64 kbps - Hemat kuota)',
        ),
        isFalse,
      );
      expect(
        MusicService.shouldPreferProgressiveQuality('Standar (128 kbps)'),
        isFalse,
      );
      expect(
        MusicService.shouldPreferProgressiveQuality('Tinggi (160 kbps)'),
        isFalse,
      );
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

    test('cleanTitle tidak memotong kata yang mengandung ft atau feat', () {
      // Regresi: regex lama menghapus "ft"/"feat" di tengah kata.
      expect(TrackModel.cleanTitle('After Dark'), 'After Dark');
      expect(TrackModel.cleanTitle('Softcore'), 'Softcore');
      expect(TrackModel.cleanTitle('Feather'), 'Feather');
      expect(TrackModel.cleanTitle('Defeat'), 'Defeat');
      expect(
        TrackModel.cleanTitle('After Dark (feat. Someone)'),
        'After Dark',
      );
    });

    test('cleanTitle membersihkan kredit fitur di akhir judul', () {
      expect(TrackModel.cleanTitle('Shape of You (feat. Someone)'), 'Shape of You');
      expect(TrackModel.cleanTitle('Song ft. Artist'), 'Song');
      expect(TrackModel.cleanTitle('Song [ft. Artist]'), 'Song');
      expect(TrackModel.cleanTitle('Song feat. Artist'), 'Song');
      expect(
        TrackModel.cleanTitle('Song (feat. Artist) [Official Video]'),
        'Song',
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

    test('authorityBonus mendongkrak skor lagu resmi / otoritas tertinggi', () {
      const canonical = TrackModel(
        id: '1',
        title: 'Magnolia',
        artist: 'Playboi Carti',
        album: 'YouTube Topic',
        artworkUrl: '',
        durationMs: 181000,
        youtubeId: 'magnolia_official',
      );

      const fanUpload = TrackModel(
        id: '2',
        title: 'Magnolia',
        artist: 'Playboi Carti',
        album: 'Fan Channel',
        artworkUrl: '',
        durationMs: 181000,
        youtubeId: 'magnolia_fan',
      );

      final bonusCanonical = MusicService.calculateAuthorityBonus(
        canonical,
        ytRank: 0,
        deezerRank: 0,
      );
      final bonusFan = MusicService.calculateAuthorityBonus(
        fanUpload,
        ytRank: 8,
      );

      // 85 (YT #0) + 20 (Deezer #0) + 15 (Consensus) + 30 (Topic) = 150
      expect(bonusCanonical, equals(150));
      expect(bonusFan, equals(0));

      final scoreCanonical = MusicService.scoreTrack(
        canonical,
        'magnolia',
        authorityBonus: bonusCanonical,
      );
      final scoreFan = MusicService.scoreTrack(
        fanUpload,
        'magnolia',
        authorityBonus: bonusFan,
      );

      expect(scoreCanonical, greaterThan(scoreFan + 100));
    });
  });

  group('MusicService.calculateAuthorityBonus details (YouTube-First)', () {
    const defaultTrack = TrackModel(
      id: '10',
      title: 'Hey Jude',
      artist: 'The Beatles',
      album: 'Past Masters',
      artworkUrl: '',
      durationMs: 420000,
    );

    test('memberikan bonus sesuai tangga popularitas organik YouTube (bobot tinggi)', () {
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 0), equals(85));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 1), equals(55));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 2), equals(38));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 3), equals(25));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 4), equals(18));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 6), equals(10));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 10), equals(0));
    });

    test('memberikan bonus pelengkap Deezer (bobot rendah)', () {
      expect(MusicService.calculateAuthorityBonus(defaultTrack, deezerRank: 0), equals(20));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, deezerRank: 1), equals(12));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, deezerRank: 2), equals(8));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, deezerRank: 5), equals(4));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, deezerRank: 8), equals(0));
    });

    test('memberikan bonus konsensus ringan saat muncul di top 2 kedua layanan', () {
      // 85 (yt#0) + 20 (deezer#0) + 15 (consensus) = 120
      expect(
        MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 0, deezerRank: 0),
        equals(120),
      );
    });

    test('memberikan bonus artis/album resmi Topic atau VEVO', () {
      const topicTrack = TrackModel(
        id: '11',
        title: 'Hey Jude',
        artist: 'The Beatles - Topic',
        album: 'YouTube Topic',
        artworkUrl: '',
        durationMs: 420000,
      );
      expect(MusicService.calculateAuthorityBonus(topicTrack), equals(30));
    });

    test('YouTube #0 tanpa Deezer tetap mengalahkan Deezer #0 tanpa YouTube', () {
      final ytOnly = MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 0);
      final deezerOnly = MusicService.calculateAuthorityBonus(defaultTrack, deezerRank: 0);
      expect(ytOnly, greaterThan(deezerOnly * 3));
    });
  });

  group('YouTube-First scoring: artis kanonikal naik di atas cover', () {
    test('Oasis Champagne Supernova mengalahkan cover Jillette Johnson', () {
      const oasis = TrackModel(
        id: 'yt_tI-5uv4wryI',
        title: 'Champagne Supernova',
        artist: 'Oasis',
        album: 'YouTube',
        artworkUrl: '',
        durationMs: 449000,
        youtubeId: 'tI-5uv4wryI',
      );
      const jillette = TrackModel(
        id: 'deezer_123',
        title: 'Champagne Supernova (OurVinyl Sessions)',
        artist: 'Jillette Johnson',
        album: 'OurVinyl Sessions',
        artworkUrl: '',
        durationMs: 400000,
      );
      final bonusOasis = MusicService.calculateAuthorityBonus(oasis, ytRank: 0);
      final bonusJillette = MusicService.calculateAuthorityBonus(jillette, deezerRank: 0);
      final scoreOasis = MusicService.scoreTrack(oasis, 'champagne supernova', authorityBonus: bonusOasis);
      final scoreJillette = MusicService.scoreTrack(jillette, 'champagne supernova', authorityBonus: bonusJillette);
      expect(scoreOasis, greaterThan(scoreJillette));
    });

    test('live version mendapat penalti ringan', () {
      const studio = TrackModel(
        id: '1',
        title: 'Champagne Supernova',
        artist: 'Oasis',
        album: 'YouTube',
        artworkUrl: '',
        durationMs: 449000,
        youtubeId: 'tI-5uv4wryI',
      );
      const live = TrackModel(
        id: '2',
        title: 'Champagne Supernova (Live From Knebworth 22)',
        artist: 'Liam Gallagher',
        album: 'YouTube',
        artworkUrl: '',
        durationMs: 443000,
        youtubeId: 'P5AjSVwZ9H0',
      );
      final scoreStudio = MusicService.scoreTrack(studio, 'champagne supernova', authorityBonus: 85);
      final scoreLive = MusicService.scoreTrack(live, 'champagne supernova', authorityBonus: 55);
      expect(scoreStudio, greaterThan(scoreLive));
    });
  });
}
