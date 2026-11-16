import 'dart:typed_data';

/// Format kontainer audio yang dikenali aplikasi.
enum AudioContainer { mp3, m4a, mp4, aac, webm, opus, ogg, flac, wav, unknown }

/// Deskripsi kontainer audio: ekstensi file yang benar dan MIME type untuk decoder.
class AudioFormat {
  final AudioContainer container;
  final String extension;
  final String mimeType;

  const AudioFormat(this.container, this.extension, this.mimeType);

  static const AudioFormat mp3 =
      AudioFormat(AudioContainer.mp3, '.mp3', 'audio/mpeg');
  static const AudioFormat m4a =
      AudioFormat(AudioContainer.m4a, '.m4a', 'audio/mp4');
  static const AudioFormat mp4 =
      AudioFormat(AudioContainer.mp4, '.mp4', 'audio/mp4');
  static const AudioFormat aac =
      AudioFormat(AudioContainer.aac, '.aac', 'audio/aac');
  static const AudioFormat webm =
      AudioFormat(AudioContainer.webm, '.webm', 'audio/webm');
  static const AudioFormat opus =
      AudioFormat(AudioContainer.opus, '.opus', 'audio/ogg');
  static const AudioFormat ogg =
      AudioFormat(AudioContainer.ogg, '.ogg', 'audio/ogg');
  static const AudioFormat flac =
      AudioFormat(AudioContainer.flac, '.flac', 'audio/flac');
  static const AudioFormat wav =
      AudioFormat(AudioContainer.wav, '.wav', 'audio/wav');
  static const AudioFormat unknown =
      AudioFormat(AudioContainer.unknown, '.audio', 'application/octet-stream');

  /// Hanya MP3 yang mendukung penandaan ID3 (TIT2/TPE1/TALB/APIC) secara aman.
  bool get supportsId3 => container == AudioContainer.mp3;

  /// Deteksi kontainer dari magic bytes header file.
  ///
  /// [header] cukup 64 byte pertama file. Bila tidak dikenali, mengembalikan
  /// [AudioFormat.unknown] agar penamaan file tetap konsisten.
  static AudioFormat detect(Uint8List header) {
    if (header.length < 4) return AudioFormat.unknown;

    // ID3v2 tag -> MP3.
    if (header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33) {
      return AudioFormat.mp3;
    }

    // MPEG audio frame sync (FF Ex/Fx).
    if (header[0] == 0xFF && (header[1] & 0xE0) == 0xE0) {
      return AudioFormat.mp3;
    }

    // ADTS AAC frame sync (FFF1/FFF9).
    if (header[0] == 0xFF &&
        (header[1] == 0xF1 || header[1] == 0xF9 || header[1] == 0xF0)) {
      return AudioFormat.aac;
    }

    // ISO Base Media (MP4/M4A) -> 'ftyp' pada offset 4.
    if (header.length >= 12 &&
        header[4] == 0x66 &&
        header[5] == 0x74 &&
        header[6] == 0x79 &&
        header[7] == 0x70) {
      final brand = String.fromCharCodes(header.sublist(8, 12));
      return brand.startsWith('M4A') ? AudioFormat.m4a : AudioFormat.mp4;
    }

    // Matroska / WebM -> EBML magic 1A 45 DF A3.
    if (header[0] == 0x1A &&
        header[1] == 0x45 &&
        header[2] == 0xDF &&
        header[3] == 0xA3) {
      if (header.length >= 68) {
        final doctype = String.fromCharCodes(header.sublist(8, 68)).trim();
        if (doctype.contains('webm')) return AudioFormat.webm;
      }
      return AudioFormat.webm;
    }

    // Ogg container ('OggS'); Opus memakai 'OpusHead' di dalam.
    if (header[0] == 0x4F &&
        header[1] == 0x67 &&
        header[2] == 0x67 &&
        header[3] == 0x53) {
      if (header.length >= 36) {
        final codec = String.fromCharCodes(header.sublist(28, 36));
        if (codec.startsWith('Opus')) return AudioFormat.opus;
      }
      return AudioFormat.ogg;
    }

    // FLAC.
    if (header[0] == 0x66 &&
        header[1] == 0x4C &&
        header[2] == 0x61 &&
        header[3] == 0x43) {
      return AudioFormat.flac;
    }

    // RIFF/WAVE.
    if (header.length >= 12 &&
        header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 &&
        header[8] == 0x57 &&
        header[9] == 0x41 &&
        header[10] == 0x56 &&
        header[11] == 0x45) {
      return AudioFormat.wav;
    }

    return AudioFormat.unknown;
  }

  /// Format dari MIME type yang tersimpan pada metadata lagu.
  static AudioFormat fromMime(String? mime) {
    switch (mime) {
      case 'audio/mpeg':
        return AudioFormat.mp3;
      case 'audio/mp4':
        return AudioFormat.m4a;
      case 'audio/aac':
        return AudioFormat.aac;
      case 'audio/webm':
        return AudioFormat.webm;
      case 'audio/ogg':
        return AudioFormat.opus;
      case 'audio/flac':
        return AudioFormat.flac;
      case 'audio/wav':
        return AudioFormat.wav;
      default:
        return AudioFormat.unknown;
    }
  }

  /// Nama format yang ditampilkan ke pengguna.
  String get displayName {
    switch (container) {
      case AudioContainer.mp3:
        return 'MP3';
      case AudioContainer.m4a:
        return 'M4A (AAC)';
      case AudioContainer.mp4:
        return 'MP4';
      case AudioContainer.aac:
        return 'AAC';
      case AudioContainer.webm:
        return 'WebM';
      case AudioContainer.opus:
        return 'Opus';
      case AudioContainer.ogg:
        return 'OGG';
      case AudioContainer.flac:
        return 'FLAC';
      case AudioContainer.wav:
        return 'WAV';
      case AudioContainer.unknown:
        return 'AUDIO';
    }
  }
}
