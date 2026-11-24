import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/models/track_model.dart';
import 'package:spotify_pribadi/services/download_service.dart';
import 'package:spotify_pribadi/services/id3_writer.dart';
import 'package:spotify_pribadi/services/local_audio_service.dart';

void main() {
  group('Id3Writer', () {
    test('menghasilkan header ID3v2.3 yang valid', () {
      final mockImage = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final tag = Id3Writer.buildId3Tag(
        title: 'Separuh Aku',
        artist: 'NOAH',
        album: 'Seperti Seharusnya',
        imageBytes: mockImage,
      );

      expect(tag.length > 10, isTrue);
      expect(tag[0], 0x49); // 'I'
      expect(tag[1], 0x44); // 'D'
      expect(tag[2], 0x33); // '3'
      expect(tag[3], 0x03); // versi 2.3
      expect(tag[4], 0x00);
      for (int i = 6; i <= 9; i++) {
        expect(tag[i] & 0x80, 0); // ukuran synchsafe
      }
    });

    test('frame teks memuat judul dalam UTF-16LE', () {
      final tag = Id3Writer.buildId3Tag(
        title: 'Halo',
        artist: '',
        album: '',
      );
      final content = String.fromCharCodes(tag);
      expect(content.contains('TIT2'), isTrue);
    });
  });

  group('LocalAudioService', () {
    test('mendukung format audio standar', () {
      expect(LocalAudioService.supportedExtensions.contains('.mp3'), isTrue);
      expect(LocalAudioService.supportedExtensions.contains('.m4a'), isTrue);
      expect(LocalAudioService.supportedExtensions.contains('.flac'), isTrue);
      expect(LocalAudioService.supportedExtensions.contains('.wav'), isTrue);
      expect(LocalAudioService.supportedExtensions.contains('.opus'), isTrue);
    });
  });

  group('DownloadService', () {
    test('nama berkas mengekspor dibersihkan dari karakter ilegal', () {
      const track = TrackModel(
        id: '1',
        title: 'Lagu: Umum?',
        artist: 'Artis/Contoh',
        album: '',
        artworkUrl: '',
        durationMs: 1000,
      );

      final name = DownloadService.getSanitizedFileName(track, '.mp3');
      expect(name, startsWith('Artis_Contoh - Lagu_ Umum_ ['));
      expect(name, endsWith('.mp3'));
      expect(name.contains('/'), isFalse);
      expect(name.contains(':'), isFalse);
    });

    test('nama folder ekspor tidak bisa keluar dari direktori tujuan', () {
      expect(DownloadService.sanitizeFolderName('..'), 'Download');
      expect(DownloadService.sanitizeFolderName('.'), 'Download');
      expect(DownloadService.sanitizeFolderName('...'), 'Download');
      expect(DownloadService.sanitizeFolderName('  '), 'Download');
      expect(DownloadService.sanitizeFolderName('Musik'), 'Musik');
      expect(DownloadService.sanitizeFolderName('Musik/..'), 'Musik_');
      expect(DownloadService.sanitizeFolderName('Musik.'), 'Musik');
    });
  });
}
