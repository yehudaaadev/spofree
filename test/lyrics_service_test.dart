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

  group('LyricsLine serialization', () {
    test('bolak-balik map mempertahankan waktu dan teks', () {
      const line = LyricsLine(
        timestamp: Duration(minutes: 1, seconds: 2, milliseconds: 345),
        text: 'Baris lirik',
      );

      final restored = LyricsLine.fromMap(line.toMap());
      expect(restored.timestamp, line.timestamp);
      expect(restored.text, line.text);
    });

    test('map tanpa field memakai nilai aman', () {
      final restored = LyricsLine.fromMap(const {});
      expect(restored.timestamp, Duration.zero);
      expect(restored.text, isEmpty);
    });
  });

  group('LyricsService.sanitizeQueryTitle', () {
    test('mempertahankan kata dengan tanda hubung', () {
      expect(LyricsService.sanitizeQueryTitle('Spider-Man'), 'Spider-Man');
      expect(LyricsService.sanitizeQueryTitle('Anti-Hero'), 'Anti-Hero');
      expect(LyricsService.sanitizeQueryTitle('Semi-Charmed Life'), 'Semi-Charmed Life');
    });

    test('membuang metadata dalam kurung dan siku', () {
      expect(
        LyricsService.sanitizeQueryTitle('Wonderwall (Official Video)'),
        'Wonderwall',
      );
      expect(
        LyricsService.sanitizeQueryTitle('Song Title [Remastered 2020]'),
        'Song Title',
      );
    });

    test('memotong embel-embel judul yang dipisahkan spasi tanda-hubung', () {
      expect(
        LyricsService.sanitizeQueryTitle('Champagne Supernova - Remastered'),
        'Champagne Supernova',
      );
    });
  });
}
