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
    final liked = data['liked'] as Map<String, dynamic>? ?? {};
    final tracks = <TrackModel>[];
    for (final item in liked.values) {
      try {
        tracks.add(TrackModel.fromMap(item as Map<String, dynamic>));
      } catch (e) {
        debugPrint('[LocalLibraryService] lagu rusak dilewati: $e');
      }
    }
    return tracks;
  }

  /// Simpan daftar lagu disukai (id -> track).
  Future<void> saveLiked(Map<String, TrackModel> liked) async {
    final data = await _read();
    data['liked'] = liked.map((key, value) => MapEntry(key, value.toMap()));
    await _write(data);
  }

  /// Muat playlist beserta lagunya.
  Future<List<Map<String, dynamic>>> loadPlaylists() async {
    final data = await _read();
    final playlists = data['playlists'] as Map<String, dynamic>? ?? {};
    return playlists.entries
        .map((entry) {
      final value = entry.value as Map<String, dynamic>;
      return {
        'id': entry.key,
        'name': value['name']?.toString() ?? 'Playlist',
        'tracks': ((value['tracks'] as List<dynamic>?) ?? [])
            .map((t) => t as Map<String, dynamic>)
            .toList(),
      };
    }).toList();
  }

  /// Simpan playlist (id -> {name, tracks}).
  Future<void> savePlaylists(Map<String, Map<String, dynamic>> playlists) async {
    final data = await _read();
    data['playlists'] = playlists;
    await _write(data);
  }

  /// Hapus seluruh koleksi lokal.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
