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

      // 50 (YT #0) + 40 (Deezer #0) + 60 (Consensus) + 25 (Topic) = 175
      expect(bonusCanonical, equals(175));
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

  group('MusicService.calculateAuthorityBonus details', () {
    const defaultTrack = TrackModel(
      id: '10',
      title: 'Hey Jude',
      artist: 'The Beatles',
      album: 'Past Masters',
      artworkUrl: '',
      durationMs: 420000,
    );

    test('memberikan bonus sesuai tangga popularitas organik YouTube', () {
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 0), equals(50));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 1), equals(35));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 2), equals(25));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 3), equals(18));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 4), equals(12));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 6), equals(8));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 10), equals(0));
    });

    test('memberikan bonus sesuai tangga popularitas organik Deezer', () {
      expect(MusicService.calculateAuthorityBonus(defaultTrack, deezerRank: 0), equals(40));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, deezerRank: 1), equals(25));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, deezerRank: 2), equals(15));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, deezerRank: 5), equals(8));
      expect(MusicService.calculateAuthorityBonus(defaultTrack, deezerRank: 8), equals(0));
    });

    test('memberikan bonus kesepakatan kanonikal saat muncul di top 3 kedua layanan', () {
      // 50 (yt#0) + 40 (deezer#0) + 60 (consensus) = 150
      expect(
        MusicService.calculateAuthorityBonus(defaultTrack, ytRank: 0, deezerRank: 0),
        equals(150),
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
      expect(MusicService.calculateAuthorityBonus(topicTrack), equals(25));
    });
  });
}
