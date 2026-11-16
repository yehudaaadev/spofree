import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/services/audio_format.dart';

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

void main() {
  group('AudioFormat.detect', () {
    test('mengenali MP3 dari header ID3', () {
      final header = _bytes([0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00]);
      expect(AudioFormat.detect(header).container, AudioContainer.mp3);
    });

    test('mengenali MP3 dari frame sync MPEG', () {
      final header = _bytes([0xFF, 0xFB, 0x90, 0x64]);
      expect(AudioFormat.detect(header).container, AudioContainer.mp3);
    });

    test('mengenali M4A dari brand ftyp', () {
      final header = _bytes([
        0x00, 0x00, 0x00, 0x20, //
        0x66, 0x74, 0x79, 0x70, //
        0x4D, 0x34, 0x41, 0x20, // "M4A "
        0x00, 0x00, 0x00, 0x00,
      ]);
      final format = AudioFormat.detect(header);
      expect(format.container, AudioContainer.m4a);
      expect(format.extension, '.m4a');
      expect(format.mimeType, 'audio/mp4');
    });

    test('mengenali MP4 bila brand bukan M4A', () {
      final header = _bytes([
        0x00, 0x00, 0x00, 0x20, //
        0x66, 0x74, 0x79, 0x70, //
        0x69, 0x73, 0x6F, 0x6D, // "isom"
        0x00, 0x00, 0x00, 0x00,
      ]);
      expect(AudioFormat.detect(header).container, AudioContainer.mp4);
    });

    test('mengenali WebM dari magic bytes EBML', () {
      final header = _bytes([
        0x1A, 0x45, 0xDF, 0xA3, //
        ...List<int>.filled(60, 0x00),
      ]);
      expect(AudioFormat.detect(header).container, AudioContainer.webm);
    });

    test('mengenali FLAC', () {
      final header = _bytes([0x66, 0x4C, 0x61, 0x43, 0x00, 0x00, 0x00, 0x22]);
      expect(AudioFormat.detect(header).container, AudioContainer.flac);
    });

    test('mengenali WAV', () {
      final header = _bytes([
        0x52, 0x49, 0x46, 0x46, //
        0x24, 0x08, 0x00, 0x00, //
        0x57, 0x41, 0x56, 0x45, // "WAVE"
      ]);
      expect(AudioFormat.detect(header).container, AudioContainer.wav);
    });

    test('mengenali Ogg', () {
      final header = _bytes([0x4F, 0x67, 0x67, 0x53, ...List<int>.filled(24, 0x00)]);
      expect(AudioFormat.detect(header).container, AudioContainer.ogg);
    });

    test('mengenali Opus di dalam kontainer Ogg', () {
      final header = _bytes([
        0x4F, 0x67, 0x67, 0x53, ...List<int>.filled(24, 0x00),
        0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64, // "OpusHead"
      ]);
      expect(AudioFormat.detect(header).container, AudioContainer.opus);
    });

    test('header tidak dikenal menghasilkan format unknown', () {
      final header = _bytes([0x01, 0x02, 0x03, 0x04]);
      final format = AudioFormat.detect(header);
      expect(format.container, AudioContainer.unknown);
      expect(format.supportsId3, isFalse);
    });

    test('hanya MP3 yang mendukung ID3', () {
      expect(AudioFormat.mp3.supportsId3, isTrue);
      expect(AudioFormat.m4a.supportsId3, isFalse);
      expect(AudioFormat.webm.supportsId3, isFalse);
      expect(AudioFormat.flac.supportsId3, isFalse);
    });
  });

  group('AudioFormat.fromMime', () {
    test('memetakan MIME ke format yang sesuai', () {
      expect(AudioFormat.fromMime('audio/mpeg').container, AudioContainer.mp3);
      expect(AudioFormat.fromMime('audio/mp4').container, AudioContainer.m4a);
      expect(AudioFormat.fromMime('audio/flac').container, AudioContainer.flac);
      expect(AudioFormat.fromMime('audio/unknown').container, AudioContainer.unknown);
      expect(AudioFormat.fromMime(null).container, AudioContainer.unknown);
    });
  });
}
