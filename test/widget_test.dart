import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/models/track_model.dart';
import 'package:spotify_pribadi/services/auth_service.dart';
import 'package:spotify_pribadi/services/id3_writer.dart';
import 'package:spotify_pribadi/services/local_audio_service.dart';

void main() {
  group('TrackModel Tests', () {
    test('Formatting and serialization test', () {
      const track = TrackModel(
        id: '123',
        title: 'Hati-Hati di Jalan',
        artist: 'Tulus',
        album: 'Manusia',
        artworkUrl: 'https://example.com/cover.jpg',
        durationMs: 242000,
      );

      expect(track.formattedDuration, '4:02');
      final map = track.toMap();
      final reconstructed = TrackModel.fromMap(map);
      expect(reconstructed.id, '123');
      expect(reconstructed.title, 'Hati-Hati di Jalan');
      expect(reconstructed.artist, 'Tulus');
      expect(reconstructed.album, 'Manusia');
      expect(reconstructed.isDownloaded, false);

      final downloaded = reconstructed.copyWith(localPath: '/downloads/tulus.m4a');
      expect(downloaded.isDownloaded, true);
    });
  });

  group('AuthService Tests', () {
    test('extractUsername extracts username correctly from shadow email', () {
      expect(AuthService.extractUsername('budi@spotube.local'), 'budi');
      expect(AuthService.extractUsername('david.surbakti@spotube.local'), 'david.surbakti');
      expect(AuthService.extractUsername(null), 'Pengguna');
      expect(AuthService.extractUsername(''), 'Pengguna');
    });
  });

  group('Id3Writer Tests', () {
    test('buildId3Tag generates valid ID3v2.3 header and frames', () {
      final mockImage = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final tag = Id3Writer.buildId3Tag(
        title: 'Separuh Aku',
        artist: 'NOAH',
        album: 'Seperti Seharusnya',
        imageBytes: mockImage,
      );

      expect(tag.length > 10, true);
      // Check ID3 header 'ID3' (0x49, 0x44, 0x33)
      expect(tag[0], 0x49);
      expect(tag[1], 0x44);
      expect(tag[2], 0x33);
      // Version 2.3
      expect(tag[3], 0x03);
      expect(tag[4], 0x00);
      // Synchsafe size bytes are at indices 6..9 and each <= 0x7F
      for (int i = 6; i <= 9; i++) {
        expect(tag[i] & 0x80, 0);
      }
    });
  });

  group('LocalAudioService Tests', () {
    test('supportedExtensions contains standard audio formats', () {
      expect(LocalAudioService.supportedExtensions.contains('.mp3'), true);
      expect(LocalAudioService.supportedExtensions.contains('.m4a'), true);
      expect(LocalAudioService.supportedExtensions.contains('.flac'), true);
      expect(LocalAudioService.supportedExtensions.contains('.wav'), true);
    });
  });
}
