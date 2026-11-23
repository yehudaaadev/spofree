import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Kategori segmen yang dideteksi oleh komunitas SponsorBlock.
enum SponsorCategory {
  musicOfftopic,
  sponsor,
  intro,
  outro,
  preview,
  other;

  static SponsorCategory fromString(String category) {
    switch (category) {
      case 'music_offtopic':
        return SponsorCategory.musicOfftopic;
      case 'sponsor':
        return SponsorCategory.sponsor;
      case 'intro':
      case 'intermission':
        return SponsorCategory.intro;
      case 'outro':
        return SponsorCategory.outro;
      case 'preview':
        return SponsorCategory.preview;
      default:
        return SponsorCategory.other;
    }
  }

  String get label {
    switch (this) {
      case SponsorCategory.musicOfftopic:
        return 'Bagian Non-Musik / Skit';
      case SponsorCategory.sponsor:
        return 'Sponsor';
      case SponsorCategory.intro:
        return 'Intro Hening';
      case SponsorCategory.outro:
        return 'Outro Panjang';
      case SponsorCategory.preview:
        return 'Cuplikan';
      case SponsorCategory.other:
        return 'Segmen Tambahan';
    }
  }
}

/// Representasi rentang waktu segmen yang perlu dilewati.
class SponsorSegment {
  final SponsorCategory category;
  final Duration start;
  final Duration end;
  final String uuid;

  /// `skip`, `mute`, `full`, atau `poi`. Hanya `skip`/`full` yang boleh
  /// di-seek otomatis; `mute` butuh penanganan volume terpisah dan `poi`
  /// hanyalah penanda, bukan segmen yang harus dilewati.
  final String actionType;

  const SponsorSegment({
    required this.category,
    required this.start,
    required this.end,
    required this.uuid,
    this.actionType = 'skip',
  });

  bool get shouldAutoSkip => actionType == 'skip' || actionType == 'full';

  Duration get duration => end - start;

  String get durationString {
    final seconds = duration.inSeconds;
    if (seconds < 60) {
      return '$seconds detik';
    }
    final mins = seconds ~/ 60;
    final remSecs = seconds % 60;
    return '$mins m ${remSecs}s';
  }

  bool contains(Duration position) {
    return position >= start && position < end;
  }
}

/// Layanan penghubung ke SponsorBlock API (sponsor.ajay.app).
///
/// Mengambil data segmen video YouTube untuk otomatis melewati bagian hening,
/// intro/outro, sponsor, atau percakapan video klip yang bukan bagian dari lagu.
class SponsorBlockService {
  SponsorBlockService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://sponsor.ajay.app',
                connectTimeout: const Duration(seconds: 4),
                receiveTimeout: const Duration(seconds: 4),
              ),
            );

  final Dio _dio;
  final Map<String, _CachedSegments> _cache = {};

  static const Duration _cacheTtl = Duration(hours: 6);
  static const Duration _emptyCacheTtl = Duration(hours: 1);
  static const int _maxCacheEntries = 200;

  static const List<String> defaultCategories = [
    'music_offtopic',
    'sponsor',
    'intro',
    'outro',
  ];

  /// Mengambil daftar segmen untuk satu video YouTube.
  ///
  /// Mengembalikan list kosong bila video tidak memiliki segmen terdaftar
  /// (status HTTP 404) atau terjadi gangguan jaringan.
  Future<List<SponsorSegment>> getSegments(
    String videoId, {
    List<String> categories = defaultCategories,
  }) async {
    final cleanId = videoId.trim();
    if (cleanId.isEmpty) return [];

    final cached = _cache[cleanId];
    if (cached != null) {
      final ttl = cached.segments.isEmpty ? _emptyCacheTtl : _cacheTtl;
      if (DateTime.now().difference(cached.storedAt) < ttl) {
        return cached.segments;
      }
      _cache.remove(cleanId);
    }

    void store(List<SponsorSegment> segments) {
      if (_cache.length >= _maxCacheEntries) {
        String? oldestKey;
        DateTime? oldestAt;
        _cache.forEach((key, value) {
          if (oldestAt == null || value.storedAt.isBefore(oldestAt!)) {
            oldestAt = value.storedAt;
            oldestKey = key;
          }
        });
        if (oldestKey != null) _cache.remove(oldestKey);
      }
      _cache[cleanId] = _CachedSegments(segments, DateTime.now());
    }

    try {
      final response = await _dio.get(
        '/api/skipSegments',
        queryParameters: {
          'videoID': cleanId,
          'categories': json.encode(categories),
        },
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List<dynamic>;
        final segments = <SponsorSegment>[];

        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final categoryStr = item['category'] as String? ?? '';
            final segmentArr = item['segment'] as List<dynamic>?;
            final uuid = item['UUID'] as String? ?? '';
            final actionType = item['actionType'] as String? ?? 'skip';

            if (segmentArr != null && segmentArr.length >= 2) {
              final startSec = (segmentArr[0] as num).toDouble();
              final endSec = (segmentArr[1] as num).toDouble();

              if (endSec > startSec) {
                segments.add(
                  SponsorSegment(
                    category: SponsorCategory.fromString(categoryStr),
                    start: Duration(milliseconds: (startSec * 1000).round()),
                    end: Duration(milliseconds: (endSec * 1000).round()),
                    uuid: uuid,
                    actionType: actionType,
                  ),
                );
              }
            }
          }
        }

        // Urutkan berdasarkan waktu mulai
        segments.sort((a, b) => a.start.compareTo(b.start));
        store(segments);
        return segments;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // 404 artinya tidak ada segmen untuk video ini di database SponsorBlock
        store(const []);
        return [];
      }
      debugPrint('[SponsorBlock] getSegments gagal untuk $cleanId: ${e.message}');
    } catch (e) {
      debugPrint('[SponsorBlock] error tak terduga: $e');
    }

    return [];
  }

  void clearCache() => _cache.clear();
}

class _CachedSegments {
  final List<SponsorSegment> segments;
  final DateTime storedAt;

  const _CachedSegments(this.segments, this.storedAt);
}
