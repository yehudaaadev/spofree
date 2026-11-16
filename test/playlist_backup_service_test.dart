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
      final playlists = {
        'Favorit Santai': [sampleTrack1, sampleTrack2],
      };

      final jsonStr = PlaylistBackupService.exportToJsonString(
        likedTracks: liked,
        playlists: playlists,
      );

      final payload = PlaylistBackupService.importFromJsonString(jsonStr);
      expect(payload, isNotNull);
      expect(payload!.version, equals(1));
      expect(payload.likedTracks.length, equals(1));
      expect(payload.likedTracks.first.title, equals('Hati-Hati di Jalan'));
      expect(payload.playlists.containsKey('Favorit Santai'), isTrue);
      expect(payload.playlists['Favorit Santai']!.length, equals(2));
    });

    test('exportToM3u menghasilkan format #EXTM3U yang benar', () {
      final m3uStr = PlaylistBackupService.exportToM3u(
        playlistName: 'Daftar Lagu',
        tracks: [sampleTrack1, sampleTrack2],
      );

      expect(m3uStr, contains('#EXTM3U'));
      expect(m3uStr, contains('#PLAYLIST:Daftar Lagu'));
      expect(m3uStr, contains('#EXTINF:242,Tulus - Hati-Hati di Jalan'));
      expect(m3uStr, contains('abc12345678'));
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
  });
}
