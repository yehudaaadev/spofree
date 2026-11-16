import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Hasil satu permintaan HTTP dengan header `Range` terbatasi.
class RangedResponse {
  const RangedResponse({
    required this.bytes,
    this.totalBytes,
    this.contentType,
  });

  /// Data byte yang diterima.
  final List<int> bytes;

  /// Total ukuran media (dari header `Content-Range`), null bila tidak diketahui.
  final int? totalBytes;

  /// Tipe konten dari header `Content-Type` (mis. `audio/webm`).
  final String? contentType;
}

/// Exception ketika server menolak permintaan range dengan HTTP 403.
///
/// Pada CDN YouTube hal ini berarti URL stream sudah kedaluwarsa atau IP
/// perangkat berubah, sehingga URL baru harus di-resolve.
class RangedRequestForbidden implements Exception {
  const RangedRequestForbidden(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'Permintaan range ditolak server (HTTP $statusCode).';
}

/// Exception umum saat pengambilan byte gagal.
class RangedRequestException implements Exception {
  const RangedRequestException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Klien HTTP yang selalu mengambil data memakai header `Range` terbatasi.
///
/// CDN YouTube (`googlevideo.com`) membalas HTTP 403 untuk permintaan tanpa
/// header `Range`, untuk `Range` tanpa batas atas (`bytes=0-`), dan untuk rentang
/// yang terlalu besar. Karena itu semua pembacaan stream audio harus memakai
/// rentang byte eksplisit dan berukuran kecil.
class RangedHttpClient {
  RangedHttpClient({HttpClient? client}) : _client = client ?? HttpClient() {
    _client.userAgent = defaultUserAgent;
    _client.connectionTimeout = const Duration(seconds: 15);
  }

  /// Ukuran potongan default per permintaan.
  static const int defaultChunkSize = 256 * 1024;

  /// Batas aman ukuran satu rentang (jauh di bawah batas CDN YouTube).
  static const int maxChunkSize = 512 * 1024;

  static const String defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  final HttpClient _client;

  /// Mengambil byte `[start]` sampai `[end]` (inklusif) dari [url].
  ///
  /// Melempar [RangedRequestForbidden] bila server menjawab 403 dan
  /// [RangedRequestException] untuk kegagalan lain.
  Future<RangedResponse> fetchRange(
    Uri url, {
    required int start,
    required int end,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    if (end < start) {
      return const RangedResponse(bytes: <int>[]);
    }

    final HttpClientRequest request;
    try {
      request = await _client.getUrl(url).timeout(timeout);
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
      // Tanpa ini server boleh mengompres respons sehingga offset byte bergeser.
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');

      final response = await request.close().timeout(timeout);

      if (response.statusCode == HttpStatus.forbidden) {
        throw const RangedRequestForbidden(403);
      }
      if (response.statusCode != HttpStatus.partialContent &&
          response.statusCode != HttpStatus.ok) {
        throw RangedRequestException(
          'Server streaming menjawab HTTP ${response.statusCode}.',
        );
      }

      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }

      return RangedResponse(
        bytes: builder.takeBytes(),
        totalBytes: parseTotalBytes(
          response.headers.value(HttpHeaders.contentRangeHeader),
        ),
        contentType: parseContentType(
          response.headers.value(HttpHeaders.contentTypeHeader),
        ),
      );
    } on RangedRequestForbidden {
      rethrow;
    } on RangedRequestException {
      rethrow;
    } on TimeoutException {
      throw const RangedRequestException('Server streaming tidak merespons.');
    } catch (e) {
      throw RangedRequestException('Gagal mengambil data stream: $e');
    }
  }

  /// Mengambil range dengan percobaan ulang.
  ///
  /// [onForbidden] dipanggil saat server menolak (403) untuk memperbarui URL,
  /// misalnya mengambil link stream YouTube yang baru. Percobaan berikutnya
  /// memakai link tersebut, sedangkan penolakan lanjutan menunggu jeda singkat
  /// karena 403 kadang hanya bersifat sementara (throttle CDN).
  Future<RangedResponse> fetchRangeResilient(
    Uri url, {
    required int start,
    required int end,
    Future<Uri> Function()? onForbidden,
    int maxAttempts = 4,
    Duration retryDelay = const Duration(milliseconds: 800),
  }) async {
    var current = url;
    RangedRequestForbidden? lastError;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await fetchRange(current, start: start, end: end);
      } on RangedRequestForbidden catch (e) {
        lastError = e;
        if (attempt == maxAttempts - 1) break;

        // Percobaan pertama dan ketiga memakai link baru (link lama mungkin
        // sudah kedaluwarsa), sisanya cukup menunggu jeda karena penolakan
        // berulang biasanya berasal dari throttle sementara CDN.
        if (onForbidden != null && attempt.isEven) {
          current = await onForbidden();
        } else {
          await Future.delayed(retryDelay * (attempt + 1));
        }
      }
    }

    throw lastError ?? const RangedRequestForbidden(403);
  }

  /// Menutup koneksi HTTP.
  void close() => _client.close(force: true);

  /// Mengambil total ukuran media dari header `Content-Range`.
  ///
  /// Format: `bytes 0-65535/3867712`. Fungsi murni agar dapat diuji.
  static int? parseTotalBytes(String? contentRange) {
    if (contentRange == null) return null;
    final slash = contentRange.lastIndexOf('/');
    if (slash == -1 || slash == contentRange.length - 1) return null;
    return int.tryParse(contentRange.substring(slash + 1).trim());
  }

  /// Membersihkan tipe konten dari parameter tambahan.
  ///
  /// `audio/webm; codecs="opus"` menjadi `audio/webm`.
  static String? parseContentType(String? contentType) {
    if (contentType == null || contentType.isEmpty) return null;
    final value = contentType.split(';').first.trim();
    return value.isEmpty ? null : value;
  }
}
