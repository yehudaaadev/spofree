import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_pribadi/models/track_model.dart';
import 'package:spotify_pribadi/providers/library_provider.dart';
import 'package:spotify_pribadi/services/local_library_service.dart';
import 'package:spotify_pribadi/services/playlist_backup_service.dart';
import 'package:spotify_pribadi/services/playlist_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LibraryProvider Liked Tracks Chronological Sorting', () {
    test('lagu yang baru disukai selalu berada di urutan teratas (index 0)', () async {
      final provider = LibraryProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      const track1 = TrackModel(
        id: 'oasis_1',
        title: 'Wonderwall',
        artist: 'Oasis',
        album: 'Morning Glory',
        artworkUrl: '',
        durationMs: 258000,
      );

      const track2 = TrackModel(
        id: 'oasis_2',
        title: 'Champagne Supernova',
        artist: 'Oasis',
        album: 'Morning Glory',
        artworkUrl: '',
        durationMs: 449000,
      );

      // Suka lagu oasis_1 pertama
      await provider.toggleLike(track1);
      expect(provider.isLiked(track1.id), isTrue);
      expect(provider.likedList.length, equals(1));
      expect(provider.likedList.first.id, equals('oasis_1'));

      // Beri sedikit jeda waktu sebelum menyukai oasis_2
      await Future<void>.delayed(const Duration(milliseconds: 15));

      // Suka lagu oasis_2 kedua
      await provider.toggleLike(track2);
      expect(provider.isLiked(track2.id), isTrue);
      expect(provider.likedList.length, equals(2));

      // oasis_2 HARUS berada di urutan paling atas (index 0)
      expect(provider.likedList.first.id, equals('oasis_2'));
      expect(provider.likedList[1].id, equals('oasis_1'));

      // Verifikasi likedAt terekam
      expect(provider.likedList.first.likedAt, isNotNull);
      expect(provider.likedList.first.likedAt!, greaterThan(provider.likedList[1].likedAt!));
    });

    test('menyukai ulang lagu lama memindahkannya ke posisi teratas', () async {
      final provider = LibraryProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      const track1 = TrackModel(
        id: 'lagu_a',
        title: 'Lagu A',
        artist: 'Artis A',
        album: 'Album A',
        artworkUrl: '',
        durationMs: 200000,
      );

      const track2 = TrackModel(
        id: 'lagu_b',
        title: 'Lagu B',
        artist: 'Artis B',
        album: 'Album B',
        artworkUrl: '',
        durationMs: 210000,
      );

      await provider.toggleLike(track1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await provider.toggleLike(track2);

      expect(provider.likedList.first.id, equals('lagu_b'));

      // Batal like lagu_a lalu like lagi
      await provider.toggleLike(track1); // un-like
      expect(provider.isLiked('lagu_a'), isFalse);
      expect(provider.likedList.length, equals(1));

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await provider.toggleLike(track1); // re-like

      // Sekarang lagu_a harus kembali menjadi yang paling atas
      expect(provider.likedList.first.id, equals('lagu_a'));
      expect(provider.likedList[1].id, equals('lagu_b'));
    });
  });

  group('LibraryProvider.createPlaylist', () {
    test('mengembalikan ID unik meskipun nama playlist sama', () async {
      final provider = LibraryProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final firstId = await provider.createPlaylist('Favorit');
      final secondId = await provider.createPlaylist('Favorit');

      expect(firstId, isNotNull);
      expect(secondId, isNotNull);
      expect(firstId, isNot(equals(secondId)));
      expect(
        provider.playlists.where((p) => p.name == 'Favorit').length,
        2,
      );
    });
  });

  group('LocalLibraryService robustness', () {
    const track = TrackModel(
      id: 'local_track',
      title: 'Lagu Lokal',
      artist: 'Artis',
      album: 'Album',
      artworkUrl: '',
      durationMs: 100000,
    );

    test('playlist rusak dilewati tanpa menggagalkan playlist lain', () async {
      SharedPreferences.setMockInitialValues({
        'wave_local_library': jsonEncode({
          'playlists': {
            'good': {'name': 'Bagus', 'tracks': []},
            'bad': 'bukan map',
            'badTracks': {'name': 'Track Rusak', 'tracks': 'bukan list'},
          },
        }),
      });

      final service = LocalLibraryService();
      final playlists = await service.loadPlaylists();

      expect(playlists, hasLength(2));
      expect(playlists.any((p) => p['name'] == 'Bagus'), isTrue);
      expect(playlists.any((p) => p['name'] == 'Track Rusak'), isTrue);
    });

    test('saveLiked dan savePlaylists tidak saling menimpa', () async {
      SharedPreferences.setMockInitialValues({});
      final service = LocalLibraryService();

      await Future.wait([
        service.saveLiked({'local_track': track}),
        service.savePlaylists({
          'pl': {'name': 'Playlist', 'tracks': <Map<String, dynamic>>[]},
        }),
      ]);

      final liked = await service.loadLiked();
      final playlists = await service.loadPlaylists();
      expect(liked, hasLength(1));
      expect(playlists, hasLength(1));
    });
  });

  group('LibraryProvider.restoreBackup', () {
    const track1 = TrackModel(
      id: 'track_1',
      title: 'Lagu Satu',
      artist: 'Artis',
      album: 'Album',
      artworkUrl: '',
      durationMs: 100000,
    );
    const track2 = TrackModel(
      id: 'track_2',
      title: 'Lagu Dua',
      artist: 'Artis',
      album: 'Album',
      artworkUrl: '',
      durationMs: 120000,
    );

    test('menggabungkan playlist dan tidak menduplikasi lagu yang sama',
        () async {
      SharedPreferences.setMockInitialValues({
        'wave_local_library': jsonEncode({
          'playlists': {
            'pl_1': {
              'name': 'Favorit',
              'tracks': [track1.toMap()],
            },
          },
        }),
      });

      final provider = LibraryProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await provider.restoreBackup(
        BackupPayload(
          version: 2,
          exportedAt: DateTime.now(),
          likedTracks: const [],
          playlists: const [
            BackupPlaylist(
              id: 'pl_1',
              name: 'Favorit',
              tracks: [track1, track2],
            ),
          ],
        ),
      );

      final playlist =
          provider.playlists.firstWhere((p) => p.id == 'pl_1');
      expect(playlist.tracks.length, 2);
      expect(
        playlist.tracks.map((t) => t.id),
        containsAll(<String>['track_1', 'track_2']),
      );
    });
  });

  group('LibraryProvider.importSharedCollection', () {
    const sharedTrack1 = TrackModel(
      id: 'yt_share00001',
      title: 'Lagu Bagian Satu',
      artist: 'Artis Berbagi',
      album: 'Album Berbagi',
      artworkUrl: 'https://i.ytimg.com/vi/share00001/hqdefault.jpg',
      durationMs: 200000,
      youtubeId: 'share00001',
    );
    const sharedTrack2 = TrackModel(
      id: 'yt_share00002',
      title: 'Lagu Bagian Dua',
      artist: 'Artis Berbagi',
      album: 'Album Berbagi',
      artworkUrl: 'https://i.ytimg.com/vi/share00002/hqdefault.jpg',
      durationMs: 210000,
      youtubeId: 'share00002',
    );

    test('playlist baru dibuat sekali dan impor ulang tidak menduplikasi',
        () async {
      final provider = LibraryProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      const collection = SharedCollection(
        kind: SharedCollectionKind.playlist,
        name: 'Dari Teman',
        tracks: [sharedTrack1, sharedTrack2],
      );

      final first = await provider.importSharedCollection(collection);
      expect(first.createdPlaylist, isTrue);
      expect(first.addedTracks, 2);
      expect(provider.playlists.length, 1);
      expect(provider.playlists.single.name, 'Dari Teman');
      expect(provider.playlists.single.tracks.length, 2);

      final second = await provider.importSharedCollection(collection);
      expect(second.createdPlaylist, isFalse);
      expect(second.addedTracks, 0);
      expect(provider.playlists.length, 1);
      expect(provider.playlists.single.tracks.length, 2);
    });

    test('playlist bernama sama digabung dan hanya lagu baru ditambahkan',
        () async {
      final provider = LibraryProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await provider.importSharedCollection(
        const SharedCollection(
          kind: SharedCollectionKind.playlist,
          name: 'Gabungan',
          tracks: [sharedTrack1],
        ),
      );

      final result = await provider.importSharedCollection(
        const SharedCollection(
          kind: SharedCollectionKind.playlist,
          name: 'gabungan',
          tracks: [sharedTrack1, sharedTrack2],
        ),
      );

      expect(result.createdPlaylist, isFalse);
      expect(result.addedTracks, 1);
      expect(provider.playlists.length, 1);
      expect(provider.playlists.single.tracks.length, 2);
    });

    test('lagu disukai dari kode tidak terduplikasi dan likedAt terisi',
        () async {
      final provider = LibraryProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      const collection = SharedCollection(
        kind: SharedCollectionKind.liked,
        name: 'Lagu Disukai',
        tracks: [sharedTrack1, sharedTrack2],
      );

      final first = await provider.importSharedCollection(collection);
      expect(first.isLiked, isTrue);
      expect(first.addedTracks, 2);
      expect(provider.likedList.length, 2);
      expect(provider.likedList.every((t) => t.likedAt != null), isTrue);

      final second = await provider.importSharedCollection(collection);
      expect(second.addedTracks, 0);
      expect(provider.likedList.length, 2);
    });
  });

  group('LibraryProvider download preferences', () {
    test('mode hanya Wi-Fi nonaktif secara default dan tersimpan', () async {
      final provider = LibraryProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(provider.wifiOnlyDownloads, isFalse);
      await provider.setWifiOnlyDownloads(true);
      expect(provider.wifiOnlyDownloads, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('wave_wifi_only_downloads'), isTrue);

      await provider.setWifiOnlyDownloads(false);
      expect(provider.wifiOnlyDownloads, isFalse);
      expect(prefs.getBool('wave_wifi_only_downloads'), isFalse);
    });

    test('preferensi tersimpan dimuat saat provider dibuat', () async {
      SharedPreferences.setMockInitialValues({
        'wave_wifi_only_downloads': true,
      });
      final provider = LibraryProvider();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(provider.wifiOnlyDownloads, isTrue);
    });
  });
}
