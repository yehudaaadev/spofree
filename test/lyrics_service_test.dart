import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/services/lyrics_service.dart';

void main() {
  group('LyricsService.parseLrc', () {
    test('mengurai lirik tersinkron dan mengurutkan berdasarkan waktu', () {
      const lrc = '''
[00:20.00] Baris kedua
[00:10.00] Baris pertama
[00:05.50] Baris paling awal
''';

      final lines = LyricsService.parseLrc(lrc);

      expect(lines.length, 3);
      expect(lines[0].text, 'Baris paling awal');
      expect(lines[0].timestamp, const Duration(milliseconds: 5500));
      expect(lines[1].text, 'Baris pertama');
      expect(lines[2].text, 'Baris kedua');
      expect(lines[2].timestamp, const Duration(seconds: 20));
    });

    test('mengabaikan baris tanpa timestamp', () {
      const lrc = '''
[tiode]
[00:12.34] Teks
''';
      final lines = LyricsService.parseLrc(lrc);
      expect(lines.length, 1);
      expect(lines.single.text, 'Teks');
    });

    test('milidetik dua digit dipadatkan menjadi tiga digit', () {
      final lines = LyricsService.parseLrc('[00:01.05] Teks');
      expect(lines.single.timestamp, const Duration(seconds: 1, milliseconds: 50));
    });
  });

  group('LyricsService.parsePlain', () {
    test('menghasilkan timestamp perkiraan dan mengabaikan baris kosong', () {
      const plain = '''
Baris satu

Baris dua
''';
      final lines = LyricsService.parsePlain(plain);
      expect(lines.length, 2);
      expect(lines[0].text, 'Baris satu');
      expect(lines[0].timestamp, Duration.zero);
      expect(lines[1].text, 'Baris dua');
      expect(lines[1].timestamp, const Duration(seconds: 4));
    });
  });
}
