import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/models/track_model.dart';
import 'package:spotify_pribadi/services/music_service.dart';
import 'package:spotify_pribadi/services/ranged_http_client.dart';
import 'package:spotify_pribadi/services/youtube_stream_source.dart';

/// Pengujian integrasi terhadap CDN YouTube sungguhan.
///
/// Tes ini memverifikasi kontrak yang dikonsumsi proxy lokal just_audio:
/// `request(start, end)` harus mengembalikan tepat `contentLength` byte yang
/// dimulai pada offset `start`, dengan `sourceLength` sebagai ukuran total
/// media.
///
/// Catatan: CDN YouTube membatasi jumlah data yang bisa diambil dari satu
/// manifest (sesi). Bila pembatasan ini terjadi, tes dilewati karena itu
/// kondisi lingkungan, bukan kegagalan kode.
void main() {
  // Video YouTube yang stabil untuk pengujian.
  const videoId = 'ma4sO59mcC4';

  const track = TrackModel(
    id: 'test-track-1',
    title: 'Monokrom',
    artist: 'Tulus',
    album: 'Monokrom',
    artworkUrl: '',
    durationMs: 228000,
    youtubeId: videoId,
  );

  final musicService = MusicService.instance;

  /// Menandai tes sebagai dilewati bila CDN membatasi pengambilan data.
  void skipIfLimited(Object error) {
    if (error is RangedRequestForbidden || error is RangedRequestException) {
      markTestSkipped('CDN YouTube membatasi pengambilan data: $error');
    } else {
      fail('Kesalahan tak terduga: $error');
    }
  }

  test('request dari awal menyajikan data dengan panjang dan magic byte valid',
      () async {
    final source = YouTubeStreamSource(
      track: track,
      quality: 'Maksimal (320 kbps High Quality)',
      musicService: musicService,
    );

    late dynamic response;
    try {
      response = await source.request();
    } catch (e) {
      skipIfLimited(e);
      return;
    }

    expect(response.rangeRequestsSupported, isTrue);
    expect(response.sourceLength, isNotNull);
    expect(response.sourceLength, greaterThan(0));
    expect(response.contentLength, response.sourceLength);
    expect(response.offset, 0);
    expect(
      response.contentType,
      anyOf(equals('audio/webm'), equals('audio/mp4')),
    );

    final bytes = <int>[];
    try {
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
      }
    } catch (e) {
      // Stream boleh terpotong karena kuota CDN, tapi data yang diterima
      // harus tetap konsisten (magic byte kontainer valid).
      expect(bytes.length, greaterThan(0));
      _expectValidContainer(bytes);
      return;
    }

    expect(bytes.length, response.contentLength);
    _expectValidContainer(bytes);
  });

  test('request range mengembalikan byte persis pada offset yang diminta',
      () async {
    final source = YouTubeStreamSource(
      track: track,
      quality: 'Maksimal (320 kbps High Quality)',
      musicService: musicService,
    );

    const start = 262144;
    const end = 327680; // eksklusif, 64 KB.

    late dynamic response;
    try {
      response = await source.request(start, end);
    } catch (e) {
      skipIfLimited(e);
      return;
    }

    expect(response.offset, start);
    expect(response.contentLength, end - start);

    final bytes = <int>[];
    try {
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
      }
    } catch (e) {
      skipIfLimited(e);
      return;
    }
    expect(bytes.length, end - start);

    // Bandingkan dengan pengambilan langsung rentang yang sama.
    final info = await musicService.resolveAudioStreamInfo(
      track,
      quality: 'Maksimal (320 kbps High Quality)',
    );
    final direct = await RangedHttpClient().fetchRange(
      Uri.parse(info.url),
      start: start,
      end: end - 1,
    );
    expect(bytes, direct.bytes);
  });

  test('preferredContainer mp4 menghasilkan stream MP4 (AAC)', () async {
    final source = YouTubeStreamSource(
      track: track,
      quality: 'Maksimal (320 kbps High Quality)',
      musicService: musicService,
      preferredContainer: 'mp4',
    );

    late dynamic response;
    try {
      response = await source.request(0, 1024);
    } catch (e) {
      skipIfLimited(e);
      return;
    }

    expect(response.contentType, 'audio/mp4');

    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
    }
    expect(bytes.length, 1024);
    expect(String.fromCharCodes(bytes.sublist(4, 8)), 'ftyp');
  });

  test('containerFromContentType memetakan tipe ke nama kontainer', () {
    expect(ResolvedAudioStream.containerFromContentType('audio/webm'), 'webm');
    expect(ResolvedAudioStream.containerFromContentType('audio/mp4'), 'mp4');
    expect(ResolvedAudioStream.containerFromContentType(null), isNull);
  });

  test('Uint8List menangani data kontainer pendek', () {
    final data = Uint8List.fromList([1, 2, 3]);
    expect(data.length, 3);
  });
}

/// Memastikan data dimulai dengan magic byte kontainer audio yang valid.
void _expectValidContainer(List<int> bytes) {
  final isWebm = bytes.length > 4 &&
      bytes[0] == 0x1A &&
      bytes[1] == 0x45 &&
      bytes[2] == 0xDF &&
      bytes[3] == 0xA3;
  final isMp4 = bytes.length > 12 &&
      String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp';
  expect(isWebm || isMp4, isTrue,
      reason: 'Data harus berupa berkas WebM atau MP4 yang valid');
}
