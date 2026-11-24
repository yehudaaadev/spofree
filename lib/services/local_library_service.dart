import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track_model.dart';

/// Penyimpanan koleksi pengguna (lagu disukai + playlist) di perangkat.
///
/// Aplikasi berjalan tanpa login, sehingga seluruh koleksi disimpan lokal dan
/// tetap tersedia antar-jalankan aplikasi.
class LocalLibraryService {
  static const String _storageKey = 'wave_local_library';

  /// Antrean tulis agar operasi baca-ubah-tulis tidak saling menimpa saat
  /// `saveLiked` dan `savePlaylists` dipanggil bersamaan.
  Future<void> _writeChain = Future<void>.value();

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _writeChain = _writeChain.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, stackTrace) {
        completer.completeError(e, stackTrace);
      }
    });
    return completer.future;
  }

  Future<Map<String, dynamic>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[LocalLibraryService] data koleksi rusak: $e');
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, json.encode(data));
  }

  /// Muat lagu disukai.
  Future<List<TrackModel>> loadLiked() async {
    final data = await _read();
    final rawLiked = data['liked'];
    if (rawLiked is! Map) return [];
    final tracks = <TrackModel>[];
    for (final item in rawLiked.values) {
      try {
        if (item is Map) {
          tracks.add(TrackModel.fromMap(Map<String, dynamic>.from(item)));
        }
      } catch (e) {
        debugPrint('[LocalLibraryService] lagu rusak dilewati: $e');
      }
    }
    return tracks;
  }

  /// Simpan daftar lagu disukai (id -> track).
  Future<void> saveLiked(Map<String, TrackModel> liked) {
    return _synchronized(() async {
      final data = await _read();
      data['liked'] = liked.map((key, value) => MapEntry(key, value.toMap()));
      await _write(data);
    });
  }

  /// Muat playlist beserta lagunya.
  ///
  /// Setiap entri diproses terpisah: satu playlist yang rusak tidak boleh
  /// membuat seluruh koleksi gagal dimuat.
  Future<List<Map<String, dynamic>>> loadPlaylists() async {
    final data = await _read();
    final rawPlaylists = data['playlists'];
    if (rawPlaylists is! Map) return [];

    final result = <Map<String, dynamic>>[];
    for (final entry in rawPlaylists.entries) {
      try {
        final rawValue = entry.value;
        if (rawValue is! Map) {
          debugPrint(
            '[LocalLibraryService] playlist ${entry.key} rusak dilewati',
          );
          continue;
        }
        final value = Map<String, dynamic>.from(rawValue);
        final tracks = <Map<String, dynamic>>[];
        final rawTracks = value['tracks'];
        if (rawTracks is List) {
          for (final rawTrack in rawTracks) {
            if (rawTrack is Map) {
              tracks.add(Map<String, dynamic>.from(rawTrack));
            }
          }
        }
        result.add({
          'id': entry.key.toString(),
          'name': value['name']?.toString() ?? 'Playlist',
          'tracks': tracks,
        });
      } catch (e) {
        debugPrint(
          '[LocalLibraryService] playlist ${entry.key} rusak dilewati: $e',
        );
      }
    }
    return result;
  }

  /// Simpan playlist (id -> {name, tracks}).
  Future<void> savePlaylists(Map<String, Map<String, dynamic>> playlists) {
    return _synchronized(() async {
      final data = await _read();
      data['playlists'] = playlists;
      await _write(data);
    });
  }

  /// Hapus seluruh koleksi lokal.
  Future<void> clear() {
    return _synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    });
  }
}
