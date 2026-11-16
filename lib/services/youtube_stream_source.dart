// just_audio menandai `StreamAudioSource` sebagai API eksperimental, namun
// API inilah satu-satunya cara menyajikan sumber audio dengan kendali penuh
// atas header `Range` yang dibutuhkan untuk stream YouTube.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:math';

import 'package:just_audio/just_audio.dart';

import '../models/track_model.dart';
import 'music_service.dart';
import 'ranged_http_client.dart';

/// Sumber audio streaming YouTube yang memakai permintaan `Range` terbatasi.
///
/// ExoPlayer (mesin di balik `just_audio`) membuka media progresif tanpa
/// header `Range`, sedangkan CDN YouTube membalas HTTP 403 untuk permintaan
/// semacam itu. Akibatnya pemutar gagal memuat sumber dan posisi playback
/// menggantung di detik 0.
///
/// Solusinya: audio ditarik sendiri lewat [RangedHttpClient] dengan rentang
/// byte eksplisit, lalu disajikan ke ExoPlayer melalui API `StreamAudioSource`
/// milik just_audio (proxy lokal sudah menangani permintaan range & seek).
///
/// Catatan penting tentang CDN YouTube:
///
/// - Setiap URL dari satu manifest disebut "sesi". Sesi hanya bisa dibaca
///   berurutan mulai dari byte 0, dan punya kuota data terbatas.
/// - Ketika kuota sesi habis (HTTP 403), sesi baru harus dibuat lewat
///   manifest baru. Manifest baru membawa sesi baru dengan kuota baru.
/// - Karena itu pembacaan selalu dilakukan berurutan dan posisi sesi
///   dipantau agar tetap sinkron dengan data yang sudah dikirim ke pemutar.
class YouTubeStreamSource extends StreamAudioSource {
  YouTubeStreamSource({
    required this.track,
    required this.quality,
    required this.musicService,
    RangedHttpClient? httpClient,
    this.preferredContainer,
    super.tag,
  }) : _httpClient = httpClient ?? RangedHttpClient();

  final TrackModel track;
  final String quality;
  final MusicService musicService;

  /// Kontainer yang diminta, mis. `mp4` untuk fallback AAC.
  final String? preferredContainer;

  final RangedHttpClient _httpClient;

  /// Ukuran potongan yang diambil per permintaan.
  static const int chunkSize = RangedHttpClient.defaultChunkSize;

  /// Jeda antar permintaan agar CDN tidak menganggap ini pola lalu lintas
  /// tinggi (CDN memblokir request yang datang terlalu cepat).
  static const Duration _requestInterval = Duration(milliseconds: 150);

  ResolvedAudioStream? _resolved;

  /// URL sesi aktif (berasal dari satu manifest).
  Uri? _sessionUrl;

  /// Jumlah byte yang sudah dibaca dari sesi aktif.
  int _sessionPosition = 0;

  DateTime _lastRequestAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    final resolved = await _resolve();

    // Chunk pertama sekaligus untuk mengetahui total ukuran media.
    final first = await _readChunk(from, from + chunkSize - 1);

    // Total ukuran biasanya terbaca dari header `Content-Range`. Parameter
    // `clen` pada URL dipakai sebagai cadangan.
    var total = first.totalBytes ?? resolved.totalBytes ?? 0;
    if (total <= 0) {
      // Tanpa total, pemutar hanya bisa menyajikan potongan yang sudah diambil.
      total = from + first.bytes.length;
    }

    // `end` bersifat eksklusif (konvensi just_audio).
    final limit = (end != null && end < total) ? end : total;

    if (from >= total) {
      return StreamAudioResponse(
        rangeRequestsSupported: true,
        sourceLength: total,
        contentLength: 0,
        offset: from,
        contentType: first.contentType ?? resolved.contentType,
        stream: const Stream<List<int>>.empty(),
      );
    }

    // Potong chunk pertama bila pemutar hanya meminta sebagian.
    var head = first.bytes;
    if (from + head.length > limit) {
      head = head.sublist(0, max(0, limit - from));
    }

    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: total,
      contentLength: max(0, limit - from),
      offset: from,
      contentType: first.contentType ?? resolved.contentType,
      stream: _streamBytes(from, head, limit),
    );
  }

  /// Mengalirkan byte dari posisi [from] sampai [limit] (eksklusif).
  ///
  /// Setiap potongan diambil dengan rentang terbatasi agar CDN YouTube tidak
  /// menolak permintaan.
  Stream<List<int>> _streamBytes(int from, List<int> head, int limit) async* {
    var position = from;
    if (head.isNotEmpty) {
      yield head;
      position += head.length;
    }

    while (position < limit) {
      final chunkEnd = min(position + chunkSize, limit) - 1;
      final chunk = await _readChunk(position, chunkEnd);
      if (chunk.bytes.isEmpty) break;
      yield chunk.bytes;
      position += chunk.bytes.length;
    }
  }

  /// Membaca satu potongan data dari sesi aktif.
  ///
  /// Bila sesi aktif sudah tidak sinkron dengan posisi yang diminta (mis.
  /// setelah seek atau setelah sesi habis), sesi baru dibuat dan
  /// diproses Maju sampai posisi yang benar.
  Future<RangedResponse> _readChunk(int start, int end) async {
    await _throttle();

    if (_sessionUrl == null || _sessionPosition != start) {
      await _openSession(start);
    }

    try {
      final chunk = await _httpClient.fetchRange(
        _sessionUrl!,
        start: start,
        end: end,
      );
      _sessionPosition = start + chunk.bytes.length;
      return chunk;
    } on RangedRequestForbidden {
      // Kuota sesi habis: buat sesi baru (manifest baru) lalu ulangi.
      await _openSession(start);
      final chunk = await _httpClient.fetchRange(
        _sessionUrl!,
        start: start,
        end: end,
      );
      _sessionPosition = start + chunk.bytes.length;
      return chunk;
    }
  }

  /// Membuat sesi baru dan memajuinya sampai posisi [target].
  ///
  /// Sesi YouTube hanya bisa dibaca berurutan mulai dari byte 0, jadi untuk
  /// mencapai posisi tertentu data sebelumnya harus diunduh ulang (dan
  /// dibuang). Pada kondisi normal sesi pertama sudah berada di posisi yang
  /// benar sehingga jalur ini jarang dipakai.
  Future<void> _openSession(int target) async {
    final resolved = await _resolve(forceRefresh: true);
    _sessionUrl = Uri.parse(resolved.url);
    _sessionPosition = 0;

    while (_sessionPosition < target) {
      await _throttle();
      final end = min(_sessionPosition + chunkSize, target) - 1;
      try {
        final chunk = await _httpClient.fetchRange(
          _sessionUrl!,
          start: _sessionPosition,
          end: end,
        );
        if (chunk.bytes.isEmpty) break;
        _sessionPosition += chunk.bytes.length;
      } on RangedRequestForbidden {
        throw RangedRequestException(
          'YouTube membatasi unduhan stream untuk lagu ini. '
          'Coba putar ulang atau gunakan lagu lain.',
        );
      }
    }
  }

  /// Menunda request bila terlalu berdekatan dengan request sebelumnya.
  Future<void> _throttle() async {
    final elapsed = DateTime.now().difference(_lastRequestAt);
    if (elapsed < _requestInterval) {
      await Future.delayed(_requestInterval - elapsed);
    }
    _lastRequestAt = DateTime.now();
  }

  /// Mengambil (dan menyimpan) metadata stream yang sudah di-resolve.
  Future<ResolvedAudioStream> _resolve({bool forceRefresh = false}) async {
    final cached = _resolved;
    if (cached != null && !forceRefresh) return cached;

    final resolved = await musicService.resolveAudioStreamInfo(
      track,
      quality: quality,
      forceRefresh: forceRefresh,
      preferredContainer: preferredContainer,
    );
    _resolved = resolved;
    return resolved;
  }
}
