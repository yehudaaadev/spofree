import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/track_model.dart';
import 'stable_hash.dart';

/// Jenis koleksi yang dibawa oleh sebuah kode berbagi.
enum SharedCollectionKind {
  /// Satu playlist dengan nama dan daftar lagu.
  playlist,

  /// Seluruh lagu yang disukai pengguna.
  liked,
}

/// Koleksi yang berhasil diurai dari kode berbagi Wave Music.
class SharedCollection {
  final SharedCollectionKind kind;
  final String name;
  final List<TrackModel> tracks;

  const SharedCollection({
    required this.kind,
    required this.name,
    required this.tracks,
  });

  bool get isLiked => kind == SharedCollectionKind.liked;
}

/// Hasil penggabungan koleksi ke pustaka lokal.
class SharedCollectionImportResult {
  final SharedCollectionKind kind;
  final String name;

  /// Jumlah lagu di dalam kode.
  final int totalTracks;

  /// Jumlah lagu yang benar-benar baru ditambahkan.
  final int addedTracks;

  /// True bila playlist baru dibuat (bukan digabung dengan nama yang sama).
  final bool createdPlaylist;

  const SharedCollectionImportResult({
    required this.kind,
    required this.name,
    required this.totalTracks,
    required this.addedTracks,
    required this.createdPlaylist,
  });

  bool get isLiked => kind == SharedCollectionKind.liked;
}

/// Kesalahan yang pesannya aman ditampilkan langsung ke pengguna.
class ShareCodeException implements Exception {
  final String message;

  const ShareCodeException(this.message);

  @override
  String toString() => message;
}

/// Membuat dan membaca kode berbagi playlist/lagu disukai tanpa server.
///
/// Kode berisi data lagu yang dipadatkan (gzip) lalu diubah ke base64url.
/// Karena seluruh data ikut di dalam kode, kode ini bisa dipindai sebagai QR
/// atau ditempel lewat aplikasi chat tanpa memerlukan koneksi ke server Wave.
class PlaylistShareService {
  /// Awalan kode. Angka menandai versi format.
  static const String codePrefix = 'WAVE1.';

  static const int currentVersion = 1;

  /// Batas aman panjang teks kode yang diterima dari pengguna.
  static const int maxCodeLength = 200000;

  /// Batas hasil dekompresi untuk mencegah kode berbahaya menghabiskan RAM.
  static const int maxDecodedBytes = 4 * 1024 * 1024;

  static const int maxTracks = 1000;

  /// Di atas batas ini QR menjadi terlalu rapat untuk dipindai dengan nyaman.
  /// Kode tetap bisa dibagikan sebagai teks.
  static const int qrRecommendedMaxLength = 2400;

  static const int _maxTitleLength = 300;
  static const int _maxArtistLength = 300;
  static const int _maxAlbumLength = 300;
  static const int _maxIdLength = 120;
  static const int _maxYouTubeIdLength = 64;
  static const int _maxNameLength = 120;

  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');
  static final RegExp _shareCodePattern = RegExp(
    r'^WAVE\d+\.',
    caseSensitive: false,
  );
  static final RegExp _anyShareCodePattern = RegExp(
    r'WAVE\d+\.',
    caseSensitive: false,
  );

  /// Membuat kode untuk satu playlist.
  static String encodePlaylist({
    required String name,
    required List<TrackModel> tracks,
  }) {
    return _encode(
      kind: SharedCollectionKind.playlist,
      name: name.trim().isEmpty ? 'Playlist Dibagikan' : name.trim(),
      tracks: tracks,
    );
  }

  /// Membuat kode untuk seluruh lagu disukai.
  static String encodeLikedTracks(List<TrackModel> tracks) {
    return _encode(
      kind: SharedCollectionKind.liked,
      name: 'Lagu Disukai',
      tracks: tracks,
    );
  }

  static String _encode({
    required SharedCollectionKind kind,
    required String name,
    required List<TrackModel> tracks,
  }) {
    final payload = <String, Object?>{
      'v': currentVersion,
      'k': kind == SharedCollectionKind.liked ? 'l' : 'p',
      'n': _cleanText(name, _maxNameLength) ?? 'Koleksi Wave Music',
      't': tracks
          .take(maxTracks)
          .map(_encodeTrack)
          .whereType<List<Object?>>()
          .toList(),
    };

    final compressed = gzip.encode(utf8.encode(jsonEncode(payload)));
    final body = base64Url.encode(compressed).replaceAll('=', '');
    return '$codePrefix$body';
  }

  /// Format lagu sengaja memakai array agar kode tetap pendek:
  /// `[id, judul, artis, album, durasiMs, youtubeId]`.
  static List<Object?>? _encodeTrack(TrackModel track) {
    final title = _cleanText(track.title, _maxTitleLength);
    if (title == null) return null;

    final artist =
        _cleanText(track.artist, _maxArtistLength) ?? 'Unknown Artist';
    final album = _cleanText(track.album, _maxAlbumLength) ?? '';
    final youtubeId = _cleanText(track.youtubeId, _maxYouTubeIdLength);
    final id = _portableTrackId(track, youtubeId);

    return <Object?>[
      id,
      title,
      artist,
      album,
      track.durationMs.clamp(0, 86400000),
      ?youtubeId,
    ];
  }

  /// ID lokal tidak boleh dibawa ke perangkat lain karena menunjuk berkas
  /// yang tidak ada di sana. ID lagu daring tetap dipertahankan agar impor
  /// berulang tidak membuat duplikat.
  static String _portableTrackId(TrackModel track, String? youtubeId) {
    final original = _cleanText(track.id, _maxIdLength);
    if (original != null && !original.startsWith('local_')) {
      return original;
    }
    if (youtubeId != null) return 'yt_$youtubeId';
    return 'shared_${stableHash('${track.title}|${track.artist}|${track.album}|${track.durationMs}')}';
  }

  /// True bila teks terlihat seperti kode Wave Music (termasuk kode versi baru).
  static bool looksLikeCode(String raw) {
    return _anyShareCodePattern.hasMatch(raw);
  }

  /// Teks siap kirim untuk aplikasi chat/email.
  static String buildShareMessage({
    required String code,
    required bool isLiked,
    required String name,
  }) {
    final title = isLiked
        ? 'Lagu disukai saya di Wave Music'
        : 'Playlist "$name" dari Wave Music';
    return '$title\n\n$code\n\n'
        'Cara impor: buka Wave Music → Koleksi → ikon info (Status & Bantuan) → '
        '"Terima Kode Playlist", lalu tempel kode atau scan QR.';
  }

  /// Mengurai kode berbagi menjadi metadata dan daftar lagu.
  ///
  /// Melempar [ShareCodeException] dengan pesan Bahasa Indonesia bila kode
  /// tidak valid, rusak, atau dibuat oleh versi format yang lebih baru.
  static SharedCollection decode(String raw) {
    final code = _normalizeCode(raw);
    if (code.isEmpty) {
      throw const ShareCodeException(
        'Kode masih kosong. Tempel kode atau scan QR terlebih dahulu.',
      );
    }
    if (!_shareCodePattern.hasMatch(code)) {
      throw const ShareCodeException(
        'Kode tidak dikenali. Pastikan kode disalin lengkap dan diawali WAVE1.',
      );
    }
    if (!code.toLowerCase().startsWith(codePrefix.toLowerCase())) {
      throw const ShareCodeException(
        'Kode ini dibuat oleh versi Wave Music yang lebih baru. Perbarui aplikasi terlebih dahulu.',
      );
    }
    if (code.length > maxCodeLength) {
      throw const ShareCodeException('Kode terlalu panjang untuk diproses.');
    }

    final body = code.substring(codePrefix.length);
    final compressed = _decodeBase64(body);
    final decodedBytes = _gunzipLimited(compressed);

    Object? parsed;
    try {
      parsed = jsonDecode(utf8.decode(decodedBytes));
    } catch (_) {
      throw const ShareCodeException('Isi kode rusak atau tidak lengkap.');
    }

    if (parsed is! Map) {
      throw const ShareCodeException('Format kode tidak valid.');
    }

    final version = parsed['v'];
    if (version != currentVersion) {
      throw const ShareCodeException(
        'Versi kode tidak didukung. Perbarui Wave Music lalu coba lagi.',
      );
    }

    final kind = switch (parsed['k']) {
      'p' => SharedCollectionKind.playlist,
      'l' => SharedCollectionKind.liked,
      _ => throw const ShareCodeException(
        'Jenis koleksi di dalam kode tidak dikenali.',
      ),
    };

    final name =
        _cleanText(parsed['n'], _maxNameLength) ??
        (kind == SharedCollectionKind.liked
            ? 'Lagu Disukai'
            : 'Playlist Dibagikan');

    final rawTracks = parsed['t'];
    if (rawTracks is! List) {
      throw const ShareCodeException('Kode tidak berisi daftar lagu.');
    }
    if (rawTracks.length > maxTracks) {
      throw const ShareCodeException(
        'Jumlah lagu di dalam kode terlalu banyak.',
      );
    }

    final tracks = <TrackModel>[];
    final seenIds = <String>{};
    for (final rawTrack in rawTracks) {
      final track = _decodeTrack(rawTrack);
      if (track == null || !seenIds.add(track.id)) continue;
      tracks.add(track);
    }

    if (tracks.isEmpty) {
      throw const ShareCodeException(
        'Tidak ada lagu yang bisa dibaca dari kode ini.',
      );
    }

    return SharedCollection(kind: kind, name: name, tracks: tracks);
  }

  static TrackModel? _decodeTrack(Object? raw) {
    if (raw is! List || raw.length < 2) return null;

    final title = _cleanText(raw[1], _maxTitleLength);
    if (title == null) return null;

    final artist = _cleanText(raw[2], _maxArtistLength) ?? 'Unknown Artist';
    final album = _cleanText(raw[3], _maxAlbumLength) ?? '';
    final duration = raw.length > 4 && raw[4] is num
        ? (raw[4] as num).toInt().clamp(0, 86400000).toInt()
        : 0;
    final youtubeId = raw.length > 5
        ? _cleanText(raw[5], _maxYouTubeIdLength)
        : null;

    var id = _cleanText(raw[0], _maxIdLength);
    if (id == null || id.startsWith('local_')) {
      id = youtubeId != null
          ? 'yt_$youtubeId'
          : 'shared_${stableHash('$title|$artist|$album|$duration')}';
    }

    return TrackModel(
      id: id,
      title: title,
      artist: artist,
      album: album,
      artworkUrl: youtubeId == null
          ? ''
          : 'https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg',
      durationMs: duration,
      youtubeId: youtubeId,
    );
  }

  static String _normalizeCode(String raw) {
    final trimmed = raw.trim();
    final match = _anyShareCodePattern.firstMatch(trimmed);
    if (match == null) return trimmed.replaceAll(_whitespace, '');
    if (match.start > 0) {
      // Pengguna menempel seluruh pesan chat: ambil kode pada baris itu saja.
      final fromCode = trimmed.substring(match.start);
      final firstLine = fromCode.split(RegExp(r'[\r\n]')).first;
      return firstLine.replaceAll(_whitespace, '');
    }
    // Kode yang dibungkus manual boleh memiliki spasi/baris baru di mana saja.
    return trimmed.replaceAll(_whitespace, '');
  }

  static Uint8List _decodeBase64(String body) {
    try {
      final normalized = body.replaceAll('-', '+').replaceAll('_', '/');
      final padding = normalized.length % 4;
      final padded = padding == 0
          ? normalized
          : normalized + ('=' * (4 - padding));
      return base64Decode(padded);
    } catch (_) {
      throw const ShareCodeException('Kode rusak atau tidak lengkap.');
    }
  }

  static Uint8List _gunzipLimited(Uint8List compressed) {
    final sink = _BoundedBytesSink(maxDecodedBytes);
    try {
      final input = gzip.decoder.startChunkedConversion(sink);
      input.add(compressed);
      input.close();
    } catch (_) {
      if (sink.exceeded) {
        throw const ShareCodeException('Kode terlalu besar untuk diproses.');
      }
      throw const ShareCodeException('Kode rusak atau tidak lengkap.');
    }
    if (sink.exceeded) {
      throw const ShareCodeException('Kode terlalu besar untuk diproses.');
    }
    return sink.takeBytes();
  }

  /// Membersihkan teks agar tidak membawa karakter kontrol dan membatasi
  /// panjangnya. Nilai kosong dianggap tidak ada.
  static String? _cleanText(Object? value, int maxLength) {
    if (value == null) return null;
    var text = value.toString().trim();
    if (text.isEmpty) return null;
    text = text
        .replaceAll(_controlCharacters, ' ')
        .replaceAll(_whitespace, ' ');
    if (text.length > maxLength) text = text.substring(0, maxLength);
    return text;
  }
}

/// Sink dengan batas ukuran agar kode gzip yang membengkak tidak menghabiskan
/// memori perangkat.
class _BoundedBytesSink implements Sink<List<int>> {
  _BoundedBytesSink(this.limit);

  final int limit;
  final BytesBuilder _builder = BytesBuilder(copy: false);
  int _length = 0;
  bool exceeded = false;

  @override
  void add(List<int> data) {
    if (exceeded) return;
    if (_length + data.length > limit) {
      exceeded = true;
      throw const FormatException('Ukuran hasil dekompresi melebihi batas.');
    }
    _length += data.length;
    _builder.add(data);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _builder.takeBytes();
}
