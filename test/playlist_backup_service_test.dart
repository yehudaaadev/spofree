import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/models/track_model.dart';
import 'package:spotify_pribadi/services/playlist_backup_service.dart';

void main() {
  group('PlaylistBackupService Tests', () {
    final sampleTrack1 = TrackModel(
      id: 'track-1',
      title: 'Hati-Hati di Jalan',
      artist: 'Tulus',
      album: 'Manusia',
      artworkUrl: 'https://example.com/cover1.jpg',
      durationMs: 242000,
      youtubeId: 'abc12345678',
    );

    final sampleTrack2 = TrackModel(
      id: 'track-2',
      title: 'Monokrom',
      artist: 'Tulus',
      album: 'Monokrom',
      artworkUrl: 'https://example.com/cover2.jpg',
      durationMs: 215000,
    );

    test('exportToJsonString dan importFromJsonString round-trip valid', () {
      final liked = [sampleTrack1];
      final playlists = [
        BackupPlaylist(
          id: 'pl_favorit',
          name: 'Favorit Santai',
          tracks: [sampleTrack1, sampleTrack2],
        ),
      ];

      final jsonStr = PlaylistBackupService.exportToJsonString(
        likedTracks: liked,
        playlists: playlists,
      );

      final payload = PlaylistBackupService.importFromJsonString(jsonStr);
      expect(payload, isNotNull);
      expect(payload!.version, equals(2));
      expect(payload.likedTracks.length, equals(1));
      expect(payload.likedTracks.first.title, equals('Hati-Hati di Jalan'));
      expect(payload.playlists.length, equals(1));
      expect(payload.playlists.first.id, equals('pl_favorit'));
      expect(payload.playlists.first.name, equals('Favorit Santai'));
      expect(payload.playlists.first.tracks.length, equals(2));
    });

    test('backup v1 dengan nama sebagai key tetap bisa dibaca', () {
      const legacyJson = '''
{
  "format": "WaveMusicBackup",
  "version": 1,
  "likedTracks": [],
  "playlists": {
    "Favorit Santai": []
  }
}
''';
      final payload = PlaylistBackupService.importFromJsonString(legacyJson);
      expect(payload, isNotNull);
      expect(payload!.playlists.length, equals(1));
      expect(payload.playlists.first.name, equals('Favorit Santai'));
      expect(payload.playlists.first.id, startsWith('pl_'));
    });

    test('exportToM3u menghasilkan format #EXTM3U yang benar', () {
      final m3uStr = PlaylistBackupService.exportToM3u(
        playlistName: 'Daftar Lagu',
        tracks: [sampleTrack1, sampleTrack2],
      );

      expect(m3uStr, contains('#EXTM3U'));
      expect(m3uStr, contains('#PLAYLIST:Daftar Lagu'));
      expect(m3uStr, contains('#EXTINF:242,Tulus - Hati-Hati di Jalan'));
      expect(
        m3uStr,
        contains('https://www.youtube.com/watch?v=abc12345678'),
      );
      // Track tanpa localPath/youtubeId tidak ditulis sebagai ID internal.
      expect(m3uStr, isNot(contains('track-2')));
    });

    test('importFromM3u berhasil mengurai track dari baris #EXTINF', () {
      const rawM3u = '''
#EXTM3U
#PLAYLIST:Kompilasi
#EXTINF:242,Tulus - Hati-Hati di Jalan
abc12345678
#EXTINF:180,Pamungkas - To the Bone
def87654321
''';

      final tracks = PlaylistBackupService.importFromM3u(rawM3u);
      expect(tracks.length, equals(2));
      expect(tracks[0].title, equals('Hati-Hati di Jalan'));
      expect(tracks[0].artist, equals('Tulus'));
      expect(tracks[0].durationMs, equals(242000));
      expect(tracks[0].youtubeId, equals('abc12345678'));
      expect(tracks[1].title, equals('To the Bone'));
      expect(tracks[1].artist, equals('Pamungkas'));
    });

    test('importFromM3u tidak memakai metadata #EXTINF yang rusak', () {
      const rawM3u = '''
#EXTM3U
#EXTINF:100,Artis - Lagu Pertama
https://example.com/satu.mp3
#EXTINF:rusak
https://example.com/dua.mp3
''';

      final tracks = PlaylistBackupService.importFromM3u(rawM3u);
      expect(tracks.length, equals(2));
      expect(tracks[1].title, equals('dua'));
      expect(tracks[1].artist, equals('Artis Tidak Diketahui'));
      expect(tracks[1].durationMs, equals(0));
    });

    test('importFromM3u mengabaikan durasi negatif (siaran langsung)', () {
      const rawM3u = '''
#EXTM3U
#EXTINF:-1,Artis - Siaran Langsung
https://example.com/live.mp3
''';

      final tracks = PlaylistBackupService.importFromM3u(rawM3u);
      expect(tracks.single.durationMs, equals(0));
    });

    test('importFromM3u hanya mengenali host YouTube yang benar', () {
      const rawM3u = '''
#EXTM3U
https://notyoutube.com/watch?v=abc12345678
https://music.youtube.com/watch?v=def87654321
''';

      final tracks = PlaylistBackupService.importFromM3u(rawM3u);
      expect(tracks[0].youtubeId, isNull);
      expect(tracks[0].id, startsWith('url_'));
      expect(tracks[1].youtubeId, equals('def87654321'));
      expect(tracks[1].id, equals('yt_def87654321'));
    });

    test('importFromM3u mengambil judul dari path Windows', () {
      const rawM3u = '''
#EXTM3U
C:\\Musik\\lagu_saya.mp3
''';

      final tracks = PlaylistBackupService.importFromM3u(rawM3u);
      expect(tracks.single.title, equals('lagu saya'));
      expect(tracks.single.localPath, equals('C:\\Musik\\lagu_saya.mp3'));
    });
  });
}
