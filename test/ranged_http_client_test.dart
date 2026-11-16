import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/services/music_service.dart';
import 'package:spotify_pribadi/services/ranged_http_client.dart';

void main() {
  group('RangedHttpClient.parseTotalBytes', () {
    test('mengambil total ukuran dari header Content-Range', () {
      expect(
        RangedHttpClient.parseTotalBytes('bytes 0-65535/3867712'),
        3867712,
      );
    });

    test('header tanpa total menghasilkan null', () {
      expect(RangedHttpClient.parseTotalBytes('bytes 0-65535/*'), isNull);
      expect(RangedHttpClient.parseTotalBytes('bytes 0-65535'), isNull);
      expect(RangedHttpClient.parseTotalBytes(null), isNull);
    });
  });

  group('RangedHttpClient.parseContentType', () {
    test('memisahkan tipe konten dari parameter tambahan', () {
      expect(
        RangedHttpClient.parseContentType('audio/webm; codecs="opus"'),
        'audio/webm',
      );
      expect(
        RangedHttpClient.parseContentType('audio/mp4'),
        'audio/mp4',
      );
    });

    test('nilai kosong menghasilkan null', () {
      expect(RangedHttpClient.parseContentType(''), isNull);
      expect(RangedHttpClient.parseContentType(null), isNull);
    });
  });

  group('RangedHttpClient batas potongan', () {
    test('ukuran potongan tetap di bawah batas aman CDN', () {
      expect(RangedHttpClient.defaultChunkSize, lessThanOrEqualTo(256 * 1024));
      expect(RangedHttpClient.defaultChunkSize,
          lessThanOrEqualTo(RangedHttpClient.maxChunkSize));
    });
  });

  group('ResolvedAudioStream.parseTotalBytesFromUrl', () {
    test('mengambil ukuran berkas dari parameter clen', () {
      const url =
          'https://rr3---sn-2uuxa3vh-ngbee.googlevideo.com/videoplayback'
          '?expire=1794813836&itag=251&clen=3867712&mime=audio%2Fwebm';
      expect(ResolvedAudioStream.parseTotalBytesFromUrl(url), 3867712);
    });

    test('URL tanpa parameter clen menghasilkan null', () {
      expect(
        ResolvedAudioStream.parseTotalBytesFromUrl(
          'https://example.com/audio',
        ),
        isNull,
      );
    });
  });
}
