import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/services/playlist_import_service.dart';

void main() {
  group('PlaylistImportService.detectSource', () {
    test('menolak host yang hanya menyebut youtube.com di query', () {
      expect(
        PlaylistImportService.detectSource(
          'https://contoh.com/?next=youtube.com',
        ),
        isNull,
      );
    });

    test('menolak domain yang berakhiran youtube.com tanpa titik', () {
      expect(
        PlaylistImportService.detectSource(
          'https://notyoutube.com/watch?v=abc12345678',
        ),
        isNull,
      );
    });

    test('menolak subdomain palsu seperti youtube.com.evil.test', () {
      expect(
        PlaylistImportService.detectSource(
          'https://youtube.com.evil.test/watch?v=abc12345678',
        ),
        isNull,
      );
    });

    test('menerima host YouTube yang sah beserta subdomainnya', () {
      expect(
        PlaylistImportService.detectSource(
          'https://www.youtube.com/playlist?list=PL123',
        ),
        PlaylistSource.youtube,
      );
      expect(
        PlaylistImportService.detectSource(
          'https://music.youtube.com/watch?v=abc12345678',
        ),
        PlaylistSource.youtube,
      );
      expect(
        PlaylistImportService.detectSource('https://youtu.be/abc12345678'),
        PlaylistSource.youtube,
      );
    });

    test('menerima tautan Spotify dan skema spotify:', () {
      expect(
        PlaylistImportService.detectSource(
          'https://open.spotify.com/playlist/abc123',
        ),
        PlaylistSource.spotify,
      );
      expect(
        PlaylistImportService.detectSource('spotify:track:abc'),
        PlaylistSource.spotify,
      );
    });

    test('menolak teks yang bukan tautan', () {
      expect(PlaylistImportService.detectSource('bukan tautan'), isNull);
    });
  });
}
