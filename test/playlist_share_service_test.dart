import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/models/track_model.dart';
import 'package:spotify_pribadi/services/playlist_share_service.dart';

void main() {
  const trackWithYouTube = TrackModel(
    id: 'yt_abc12345678',
    title: 'Hati-Hati di Jalan',
    artist: 'Tulus',
    album: 'Manusia',
    artworkUrl: 'https://example.com/cover1.jpg',
    durationMs: 242000,
    youtubeId: 'abc12345678',
  );

  const trackWithoutYouTube = TrackModel(
    id: 'dz_987654',
    title: 'Monokrom',
    artist: 'Tulus',
    album: 'Monokrom',
    artworkUrl: 'https://example.com/cover2.jpg',
    durationMs: 215000,
  );

  const localTrack = TrackModel(
    id: 'local_1234567890abcdef',
    title: 'Lagu Lokal',
    artist: 'Artis Lokal',
    album: 'Album Lokal',
    artworkUrl: '',
    durationMs: 180000,
    localPath: '/storage/emulated/0/Music/lagu.mp3',
  );

  group('PlaylistShareService', () {
    test('round-trip playlist mempertahankan metadata penting', () {
      final code = PlaylistShareService.encodePlaylist(
        name: 'Favorit Santai',
        tracks: [trackWithYouTube, trackWithoutYouTube],
      );

      expect(code.startsWith(PlaylistShareService.codePrefix), isTrue);
      expect(PlaylistShareService.looksLikeCode(code), isTrue);

      final decoded = PlaylistShareService.decode(code);
      expect(decoded.kind, SharedCollectionKind.playlist);
      expect(decoded.isLiked, isFalse);
      expect(decoded.name, 'Favorit Santai');
      expect(decoded.tracks.length, 2);
      expect(decoded.tracks.first.id, trackWithYouTube.id);
      expect(decoded.tracks.first.title, 'Hati-Hati di Jalan');
      expect(decoded.tracks.first.artist, 'Tulus');
      expect(decoded.tracks.first.album, 'Manusia');
      expect(decoded.tracks.first.durationMs, 242000);
      expect(decoded.tracks.first.youtubeId, 'abc12345678');
      expect(
        decoded.tracks.first.artworkUrl,
        'https://i.ytimg.com/vi/abc12345678/hqdefault.jpg',
      );
      expect(decoded.tracks[1].id, 'dz_987654');
      expect(decoded.tracks[1].youtubeId, isNull);
      expect(decoded.tracks[1].artworkUrl, isEmpty);
    });

    test('round-trip lagu disukai memakai jenis liked', () {
      final code = PlaylistShareService.encodeLikedTracks([
        trackWithYouTube,
        trackWithoutYouTube,
      ]);

      final decoded = PlaylistShareService.decode(code);
      expect(decoded.kind, SharedCollectionKind.liked);
      expect(decoded.isLiked, isTrue);
      expect(decoded.name, 'Lagu Disukai');
      expect(decoded.tracks.length, 2);
    });

    test('id lokal diganti dan localPath tidak ikut dibagikan', () {
      final code = PlaylistShareService.encodePlaylist(
        name: 'Lokal',
        tracks: [localTrack],
      );

      final decoded = PlaylistShareService.decode(code);
      expect(decoded.tracks.single.id.startsWith('local_'), isFalse);
      expect(decoded.tracks.single.id, startsWith('shared_'));
      expect(decoded.tracks.single.localPath, isNull);
      expect(decoded.tracks.single.title, 'Lagu Lokal');
    });

    test('spasi dan baris baru di dalam kode diabaikan', () {
      final code = PlaylistShareService.encodePlaylist(
        name: 'Spasi',
        tracks: [trackWithYouTube],
      );
      final wrapped = StringBuffer();
      for (var i = 0; i < code.length; i += 40) {
        final end = (i + 40).clamp(0, code.length).toInt();
        wrapped.writeln(code.substring(i, end));
      }

      final decoded = PlaylistShareService.decode(wrapped.toString());
      expect(decoded.name, 'Spasi');
      expect(decoded.tracks.single.title, trackWithYouTube.title);
    });

    test('seluruh pesan chat yang berisi kode tetap bisa diimpor', () {
      final code = PlaylistShareService.encodePlaylist(
        name: 'Dari Chat',
        tracks: [trackWithYouTube],
      );
      final message = PlaylistShareService.buildShareMessage(
        code: code,
        isLiked: false,
        name: 'Dari Chat',
      );

      expect(PlaylistShareService.looksLikeCode(message), isTrue);
      final decoded = PlaylistShareService.decode(message);
      expect(decoded.name, 'Dari Chat');
      expect(decoded.tracks.single.title, trackWithYouTube.title);
    });

    test('kode tidak dikenal ditolak dengan pesan jelas', () {
      expect(
        () => PlaylistShareService.decode('bukan kode wave'),
        throwsA(
          isA<ShareCodeException>().having(
            (e) => e.message,
            'message',
            contains('tidak dikenali'),
          ),
        ),
      );
    });

    test('kode versi format baru memberi pesan untuk memperbarui aplikasi', () {
      expect(
        () => PlaylistShareService.decode('WAVE2.abcdef'),
        throwsA(
          isA<ShareCodeException>().having(
            (e) => e.message,
            'message',
            contains('lebih baru'),
          ),
        ),
      );
    });

    test('kode rusak atau terpotong ditolak', () {
      final code = PlaylistShareService.encodePlaylist(
        name: 'Rusak',
        tracks: [trackWithYouTube],
      );
      final truncated = code.substring(0, code.length - 20);
      expect(
        () => PlaylistShareService.decode(truncated),
        throwsA(isA<ShareCodeException>()),
      );
    });

    test('kode terlalu panjang ditolak sebelum didekompresi', () {
      final huge =
          'WAVE1.${List.filled(PlaylistShareService.maxCodeLength, 'A').join()}';
      expect(
        () => PlaylistShareService.decode(huge),
        throwsA(
          isA<ShareCodeException>().having(
            (e) => e.message,
            'message',
            contains('terlalu panjang'),
          ),
        ),
      );
    });

    test('hasil dekompresi yang membengkak ditolak', () {
      final bomb = gzip.encode(
        utf8.encode(
          List.filled(PlaylistShareService.maxDecodedBytes + 1, 'A').join(),
        ),
      );
      final code = 'WAVE1.${base64Url.encode(bomb).replaceAll('=', '')}';
      expect(
        () => PlaylistShareService.decode(code),
        throwsA(
          isA<ShareCodeException>().having(
            (e) => e.message,
            'message',
            contains('terlalu besar'),
          ),
        ),
      );
    });

    test('lagu dengan ID duplikat hanya diimpor sekali', () {
      final code = PlaylistShareService.encodePlaylist(
        name: 'Duplikat',
        tracks: [trackWithYouTube, trackWithYouTube],
      );
      final decoded = PlaylistShareService.decode(code);
      expect(decoded.tracks.length, 1);
    });

    test(
      'kode playlist besar tetap lebih kecil dari batas QR yang disarankan',
      () {
        final tracks = List.generate(
          25,
          (i) => TrackModel(
            id: 'yt_video$i',
            title: 'Judul Lagu Yang Cukup Panjang $i',
            artist: 'Nama Artis Yang Juga Panjang',
            album: 'Nama Album Yang Panjang',
            artworkUrl: 'https://example.com/cover$i.jpg',
            durationMs: 180000 + (i * 1000),
            youtubeId: 'video$i',
          ),
        );

        final code = PlaylistShareService.encodePlaylist(
          name: 'Kompilasi 25 Lagu',
          tracks: tracks,
        );
        expect(
          code.length,
          lessThan(PlaylistShareService.qrRecommendedMaxLength),
          reason: 'Kode 25 lagu seharusnya masih nyaman dipindai sebagai QR.',
        );
      },
    );

    test('playlist 1.000 lagu tetap bisa dibaca ulang oleh aplikasi', () {
      final tracks = List.generate(
        PlaylistShareService.maxTracks,
        (i) => TrackModel(
          id: 'yt_video$i',
          title: 'Judul Lagu Nomor $i',
          artist: 'Nama Artis $i',
          album: 'Album $i',
          artworkUrl: '',
          durationMs: 180000 + i,
          youtubeId: 'video$i',
        ),
      );

      final code = PlaylistShareService.encodePlaylist(
        name: 'Koleksi Besar',
        tracks: tracks,
      );

      expect(code.length, lessThan(PlaylistShareService.maxCodeLength));
      final decoded = PlaylistShareService.decode(code);
      expect(decoded.tracks.length, PlaylistShareService.maxTracks);
      expect(decoded.tracks.last.title, 'Judul Lagu Nomor 999');
    });
  });
}
