import 'dart:convert';
import 'dart:typed_data';

class Id3Writer {
  static Uint8List buildId3Tag({
    required String title,
    required String artist,
    required String album,
    Uint8List? imageBytes,
  }) {
    final List<int> frames = [];

    if (title.isNotEmpty) {
      frames.addAll(_createTextFrame('TIT2', title));
    }
    if (artist.isNotEmpty) {
      frames.addAll(_createTextFrame('TPE1', artist));
    }
    if (album.isNotEmpty) {
      frames.addAll(_createTextFrame('TALB', album));
    }
    if (imageBytes != null && imageBytes.isNotEmpty) {
      frames.addAll(_createPictureFrame(imageBytes));
    }

    final int framesSize = frames.length;
    final header = [
      0x49, 0x44, 0x33, // 'ID3'
      0x03, 0x00,       // version 2.3.0
      0x00,             // flags
      (framesSize >> 21) & 0x7F, // synchsafe size 4 bytes
      (framesSize >> 14) & 0x7F,
      (framesSize >> 7) & 0x7F,
      framesSize & 0x7F,
    ];

    return Uint8List.fromList([...header, ...frames]);
  }

  static List<int> _createTextFrame(String id, String text) {
    final List<int> payload = [0x01, 0xFF, 0xFE]; // UTF-16LE with BOM
    for (final unit in text.codeUnits) {
      payload.add(unit & 0xFF);
      payload.add((unit >> 8) & 0xFF);
    }

    final len = payload.length;
    return [
      ...ascii.encode(id),
      (len >> 24) & 0xFF,
      (len >> 16) & 0xFF,
      (len >> 8) & 0xFF,
      len & 0xFF,
      0x00, 0x00,
      ...payload,
    ];
  }

  static List<int> _createPictureFrame(Uint8List imageBytes) {
    final mime = ascii.encode('image/jpeg');
    final List<int> payload = [
      0x00, // ISO-8859-1 encoding for MIME
      ...mime,
      0x00, // null delimiter
      0x03, // cover front
      0x00, // empty description
      ...imageBytes,
    ];

    final len = payload.length;
    return [
      ...ascii.encode('APIC'),
      (len >> 24) & 0xFF,
      (len >> 16) & 0xFF,
      (len >> 8) & 0xFF,
      len & 0xFF,
      0x00, 0x00,
      ...payload,
    ];
  }
}
