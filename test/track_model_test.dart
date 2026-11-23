import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/models/track_model.dart';

void main() {
  group('TrackModel', () {
    test('serialisasi round-trip mempertahankan seluruh field', () {
      const track = TrackModel(
        id: 'sp_1',
        title: 'Hati-Hati di Jalan',
        artist: 'Tulus',
        album: 'Manusia',
        artworkUrl: 'https://example.com/cover.jpg',
        durationMs: 242000,
        youtubeId: 'yt_1',
        mimeType: 'audio/mp4',
      );

      final map = track.toMap();
      final restored = TrackModel.fromMap(map);

      expect(restored.id, track.id);
      expect(restored.title, track.title);
      expect(restored.artist, track.artist);
      expect(restored.album, track.album);
      expect(restored.artworkUrl, track.artworkUrl);
      expect(restored.durationMs, track.durationMs);
      expect(restored.youtubeId, track.youtubeId);
      expect(restored.mimeType, track.mimeType);
      expect(restored.formattedDuration, '4:02');
      expect(restored.hasKnownDuration, isTrue);
    });

    test('durasi tidak diketahui ditampilkan sebagai --:--', () {
      const track = TrackModel(
        id: 'local_1',
        title: 'Berkas Lokal',
        artist: 'Penyimpanan Lokal',
        album: 'File Internal',
        artworkUrl: '',
        durationMs: 0,
      );

      expect(track.hasKnownDuration, isFalse);
      expect(track.formattedDuration, '--:--');
    });

    test('map lama tanpa field mimeType tetap dapat dibaca', () {
      final legacy = json.decode(
        '{"id":"1","title":"Judul","artist":"Artis","album":"Album",'
        '"artworkUrl":"","durationMs":1000,"youtubeId":null,"localPath":null}',
      ) as Map<String, dynamic>;

      final track = TrackModel.fromMap(legacy);
      expect(track.mimeType, isNull);
      expect(track.title, 'Judul');
    });

    test('copyWith dapat menyertakan localPath dan mimeType', () {
      const track = TrackModel(
        id: '1',
        title: 'Judul',
        artist: 'Artis',
        album: 'Album',
        artworkUrl: '',
        durationMs: 1000,
      );

      final downloaded = track.copyWith(
        localPath: '/downloads/lagu.m4a',
        mimeType: 'audio/mp4',
      );

      expect(downloaded.isDownloaded, isTrue);
      expect(downloaded.mimeType, 'audio/mp4');
      expect(downloaded.title, track.title);
    });

    test('fromDeezer memetakan cover art dan durasi', () {
      final track = TrackModel.fromDeezer({
        'id': 42,
        'title': 'Judul',
        'duration': 180,
        'artist': {'name': 'Artis'},
        'album': {'title': 'Album', 'cover_xl': 'https://cover/large.jpg'},
      });

      expect(track.id, '42');
      expect(track.artist, 'Artis');
      expect(track.album, 'Album');
      expect(track.artworkUrl, 'https://cover/large.jpg');
      expect(track.durationMs, 180000);
      expect(track.formattedDuration, '3:00');
    });

    test('likedAt dan formattedLikedDate berfungsi dengan benar', () {
      final now = DateTime(2026, 11, 18, 9, 30).millisecondsSinceEpoch;
      final track = const TrackModel(
        id: 'oasis_1',
        title: 'Wonderwall',
        artist: 'Oasis',
        album: 'Definitive',
        artworkUrl: '',
        durationMs: 258000,
      ).copyWith(likedAt: now);

      expect(track.likedAt, now);
      expect(track.formattedLikedDate, '18/11/2026');

      final map = track.toMap();
      expect(map['likedAt'], now);

      final restored = TrackModel.fromMap(map);
      expect(restored.likedAt, now);
      expect(restored.formattedLikedDate, '18/11/2026');
    });

    test('lagu lama tanpa likedAt menghasilkan format tanggal kosong', () {
      const legacy = TrackModel(
        id: 'old_1',
        title: 'Old Song',
        artist: 'Old Artist',
        album: 'Old Album',
        artworkUrl: '',
        durationMs: 120000,
      );
      expect(legacy.likedAt, isNull);
      expect(legacy.formattedLikedDate, '');
    });
  });
}
