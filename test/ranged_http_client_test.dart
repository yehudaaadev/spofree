import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/services/music_service.dart';
import 'package:spotify_pribadi/services/ranged_http_client.dart';

void main() {
  group('RangedHttpClient.parseTotalBytes', () {
    test('mengambil total ukuran dari header Content-Range', () {
      expect(
        RangedHttpClient.parseTotalBytes('bytes 0-65535/3867712'),
        3867712,
      );
    });

    test('header tanpa total menghasilkan null', () {
      expect(RangedHttpClient.parseTotalBytes('bytes 0-65535/*'), isNull);
      expect(RangedHttpClient.parseTotalBytes('bytes 0-65535'), isNull);
      expect(RangedHttpClient.parseTotalBytes(null), isNull);
    });
  });

  group('RangedHttpClient.parseRangeStart', () {
    test('mengambil posisi awal dari Content-Range', () {
      expect(
        RangedHttpClient.parseRangeStart('bytes 65536-131071/3867712'),
        65536,
      );
      expect(RangedHttpClient.parseRangeStart('bytes 0-0/100'), 0);
    });

    test('header tidak valid menghasilkan null', () {
      expect(RangedHttpClient.parseRangeStart(null), isNull);
      expect(RangedHttpClient.parseRangeStart('bytes */100'), isNull);
      expect(RangedHttpClient.parseRangeStart('not-a-range'), isNull);
    });
  });

  group('RangedHttpClient.parseContentType', () {
    test('memisahkan tipe konten dari parameter tambahan', () {
      expect(
        RangedHttpClient.parseContentType('audio/webm; codecs="opus"'),
        'audio/webm',
      );
      expect(
        RangedHttpClient.parseContentType('audio/mp4'),
        'audio/mp4',
      );
    });

    test('nilai kosong menghasilkan null', () {
      expect(RangedHttpClient.parseContentType(''), isNull);
      expect(RangedHttpClient.parseContentType(null), isNull);
    });
  });

  group('RangedHttpClient batas potongan', () {
    test('ukuran potongan tetap di bawah batas aman CDN', () {
      expect(RangedHttpClient.defaultChunkSize, lessThanOrEqualTo(256 * 1024));
      expect(RangedHttpClient.defaultChunkSize,
          lessThanOrEqualTo(RangedHttpClient.maxChunkSize));
    });
  });

  group('RangedHttpClient.fetchRange (server lokal)', () {
    late HttpServer server;
    late RangedHttpClient client;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      client = RangedHttpClient();
      server.listen((request) async {
        final path = request.uri.path;
        final range = request.headers.value(HttpHeaders.rangeHeader);

        if (path == '/ignore-range') {
          // Server yang mengabaikan Range dan selalu mengirim seluruh berkas.
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType('audio', 'mpeg');
          request.response.contentLength = 1024;
          request.response.add(List.generate(1024, (i) => i % 256));
        } else if (path == '/wrong-range') {
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 10-19/100',
          );
          request.response.headers.contentType = ContentType('audio', 'mpeg');
          request.response.add(List.generate(10, (i) => i));
        } else if (path == '/empty') {
          request.response.statusCode =
              HttpStatus.requestedRangeNotSatisfiable;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */100',
          );
        } else {
          final match =
              RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range ?? '');
          final start = int.parse(match!.group(1)!);
          final end = int.parse(match.group(2)!);
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/1024',
          );
          request.response.headers.contentType = ContentType('audio', 'mpeg');
          request.response.add(
            List.generate(end - start + 1, (i) => (start + i) % 256),
          );
        }

        await request.response.close();
      });
    });

    tearDown(() async {
      client.close();
      await server.close(force: true);
    });

    test('rentang valid mengembalikan byte dan total yang tepat', () async {
      final res = await client.fetchRange(
        Uri.parse('http://127.0.0.1:${server.port}/range'),
        start: 32,
        end: 63,
      );

      expect(res.bytes.length, 32);
      expect(res.bytes.first, 32);
      expect(res.totalBytes, 1024);
      expect(res.contentType, 'audio/mpeg');
    });

    test('HTTP 200 untuk offset > 0 ditolak agar berkas tidak rusak', () async {
      expect(
        () => client.fetchRange(
          Uri.parse('http://127.0.0.1:${server.port}/ignore-range'),
          start: 64,
          end: 127,
        ),
        throwsA(isA<RangedRequestException>()),
      );
    });

    test('HTTP 200 untuk offset 0 dibatasi sesuai rentang yang diminta',
        () async {
      final res = await client.fetchRange(
        Uri.parse('http://127.0.0.1:${server.port}/ignore-range'),
        start: 0,
        end: 99,
      );

      expect(res.bytes.length, 100);
      expect(res.totalBytes, 1024);
    });

    test('Content-Range yang tidak sesuai offset ditolak', () async {
      expect(
        () => client.fetchRange(
          Uri.parse('http://127.0.0.1:${server.port}/wrong-range'),
          start: 0,
          end: 9,
        ),
        throwsA(isA<RangedRequestException>()),
      );
    });

    test('HTTP 416 menghasilkan respons kosong', () async {
      final res = await client.fetchRange(
        Uri.parse('http://127.0.0.1:${server.port}/empty'),
        start: 0,
        end: 9,
      );

      expect(res.bytes, isEmpty);
    });
  });

  group('ResolvedAudioStream.parseTotalBytesFromUrl', () {
    test('mengambil ukuran berkas dari parameter clen', () {
      const url =
          'https://rr3---sn-2uuxa3vh-ngbee.googlevideo.com/videoplayback'
          '?expire=1794813836&itag=251&clen=3867712&mime=audio%2Fwebm';
      expect(ResolvedAudioStream.parseTotalBytesFromUrl(url), 3867712);
    });

    test('URL tanpa parameter clen menghasilkan null', () {
      expect(
        ResolvedAudioStream.parseTotalBytesFromUrl(
          'https://example.com/audio',
        ),
        isNull,
      );
    });
  });
}
