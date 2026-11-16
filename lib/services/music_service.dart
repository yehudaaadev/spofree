import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/track_model.dart';
import 'youtube_client.dart';

/// Entri cache URL stream beserta waktu penyimpanannya.
class _StreamCacheEntry {
  final String url;
  final DateTime storedAt;

  const _StreamCacheEntry(this.url, this.storedAt);
}

/// Metadata stream audio yang sudah di-resolve dari YouTube.
///
/// Menyimpan bukan hanya URL (yang cepat kedaluwarsa), tetapi juga tipe
/// konten, codec, dan ukuran total berkas agar pemutar bisa menarik data
/// dengan rentang byte yang tepat.
class ResolvedAudioStream {
  const ResolvedAudioStream({
    required this.url,
    required this.contentType,
    required this.videoId,
    this.totalBytes,
    this.codec,
    this.container,
  });

  /// URL stream sementara dari CDN YouTube.
  final String url;

  /// Tipe konten, mis. `audio/webm` atau `audio/mp4`.
  final String contentType;

  /// Id video YouTube sumber stream.
  final String videoId;

  /// Ukuran total berkas audio dalam byte, bila diketahui.
  final int? totalBytes;

  /// Codec audio, mis. `opus` atau `mp4a.40.2`.
  final String? codec;

  /// Kontainer berkas, mis. `webm` atau `mp4`.
  final String? container;

  /// Menentukan ukuran total dari parameter `clen` pada URL.
  ///
  /// Fungsi murni agar dapat diuji tanpa jaringan.
  static int? parseTotalBytesFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    return int.tryParse(uri.queryParameters['clen'] ?? '');
  }

  /// Menentukan kontainer dari tipe konten.
  ///
  /// `audio/webm` menjadi `webm`, `audio/mp4` menjadi `mp4`.
  static String? containerFromContentType(String? contentType) {
    if (contentType == null || contentType.isEmpty) return null;
    if (contentType.contains('webm')) return 'webm';
    if (contentType.contains('mp4')) return 'mp4';
    return null;
  }
}

/// Sumber katalog dan pemutar audio.
///
/// Katalog (judul, cover art, durasi) diambil dari Deezer API, sedangkan audio
/// dialirkan dari YouTube. URL stream YouTube bersifat sementara dan biasanya
/// kedaluwarsa dalam beberapa jam, sehingga cache dibatasi usianya dan dapat
/// dipaksasegarkan ketika playback gagal.
class MusicService {
  MusicService({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  /// Instance bersama. Memakai instance tunggal memastikan cache URL stream
  /// tidak terduplikasi antar widget.
  static final MusicService instance = MusicService();

  final Dio _dio;

  /// Masa berlaku cache URL stream. YouTube menganggap URL lama tidak valid
  /// setelah +/- 6 jam; ambang 3 jam dipilih sebagai margin aman.
  static const Duration streamCacheTtl = Duration(hours: 3);

  static final Map<String, _StreamCacheEntry> _streamUrlCache = {};
  static final Map<String, String> _videoIdCache = {};

  /// Mengambil videoId YouTube yang sudah pernah di-resolve untuk track tertentu.
  static String? getCachedVideoId(String trackId) => _videoIdCache[trackId];

  /// Target bitrate (kbps) untuk setiap pilihan kualitas pengguna.
  ///
  /// Fungsi murni agar dapat diuji tanpa jaringan.
  static int targetBitrateForQuality(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('hemat') || q.contains('64')) return 64;
    if (q.contains('standar') || q.contains('128')) return 128;
    if (q.contains('maksimal') || q.contains('320')) return 320;
    if (q.contains('tinggi') || q.contains('hq') || q.contains('160')) return 192;
    return 320;
  }

  /// Buang cache URL stream untuk satu lagu (dipakai saat playback gagal).
  void invalidateStreamCache(String trackId) {
    _streamUrlCache.removeWhere((key, _) => key.startsWith('${trackId}_'));
  }

  /// Buang seluruh cache URL stream.
  void invalidateAllStreamCache() {
    _streamUrlCache.clear();
  }

  Future<List<TrackModel>> getRelatedTracks(TrackModel track) async {
    if (track.artist.isNotEmpty && track.artist.toLowerCase() != 'unknown artist') {
      try {
        final response = await _dio.get(
          'https://api.deezer.com/search',
          queryParameters: {'q': track.artist, 'limit': 15},
        );
        if (response.statusCode == 200) {
          final data = response.data is String ? json.decode(response.data) : response.data;
          final tracksData = data['data'] as List<dynamic>? ?? [];
          final tracks = tracksData
              .map((item) => TrackModel.fromDeezer(item as Map<String, dynamic>))
              .where((t) => t.id != track.id && t.title.toLowerCase() != track.title.toLowerCase())
              .toList();
          if (tracks.isNotEmpty) {
            return tracks;
          }
        }
      } catch (e) {
        debugPrint('[MusicService] getRelatedTracks gagal: $e');
      }
    }

    final fallbackQuery = '${track.artist} Radio Mix';
    return searchDeezer(fallbackQuery);
  }

  /// Track Radio: daftar lagu yang benar-benar berputar seperti radio.
  ///
  /// Memakai endpoint `artist/{id}/radio` milik Deezer yang membangun daftar
  /// berdasarkan karakter lagu (genre/era), bukan sekadar nama artis. Bila
  /// endpoint tidak tersedia, fallback ke campuran pencarian artis + chart.
  Future<List<TrackModel>> getRadioTracks(
    TrackModel track, {
    int limit = 15,
  }) async {
    final radio = await _fetchDeezerArtistRadio(track.artist);

    if (radio.length >= 3) {
      return radio
          .where((t) => t.id != track.id)
          .take(limit)
          .toList();
    }

    // Fallback: campur pencarian artis dengan chart global agar tidak
    // menumpuk lagu dari artis yang sama.
    final mixed = <TrackModel>[];
    mixed.addAll(radio);
    mixed.addAll(await searchDeezer(track.artist));
    mixed.addAll(await getChartTracks());

    final seen = <String>{track.id};
    final result = <TrackModel>[];
    for (final item in mixed) {
      if (seen.add(item.id)) result.add(item);
    }
    return result.take(limit).toList();
  }

  Future<List<TrackModel>> _fetchDeezerArtistRadio(String artistName) async {
    if (artistName.trim().isEmpty) return [];

    try {
      final searchResponse = await _dio.get(
        'https://api.deezer.com/search',
        queryParameters: {'q': artistName, 'limit': 5},
      );
      final searchData = searchResponse.data is String
          ? json.decode(searchResponse.data)
          : searchResponse.data;
      final items = searchData['data'] as List<dynamic>? ?? [];

      for (final item in items) {
        final artistMap = (item as Map<String, dynamic>)['artist'];
        final artistId = artistMap is Map<String, dynamic> ? artistMap['id'] : null;
        if (artistId == null) continue;

        final radioResponse = await _dio.get(
          'https://api.deezer.com/artist/$artistId/radio',
        );
        final radioData = radioResponse.data is String
            ? json.decode(radioResponse.data)
            : radioResponse.data;
        final list = radioData['data'] as List<dynamic>? ?? [];
        if (list.isEmpty) continue;

        return list
            .map((e) => TrackModel.fromDeezer(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[MusicService] radio artis gagal: $e');
    }

    return [];
  }

  Future<List<TrackModel>> getChartTracks() async {
    try {
      final response = await _dio.get('https://api.deezer.com/chart');
      if (response.statusCode == 200) {
        final data = response.data is String ? json.decode(response.data) : response.data;
        final tracksData = data['tracks']?['data'] as List<dynamic>? ?? [];
        return tracksData
            .map((item) => TrackModel.fromDeezer(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[MusicService] getChartTracks gagal: $e');
    }
    return [];
  }

  Future<List<TrackModel>> searchDeezer(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _dio.get(
        'https://api.deezer.com/search',
        queryParameters: {'q': query.trim()},
      );
      if (response.statusCode == 200) {
        final data = response.data is String ? json.decode(response.data) : response.data;
        final tracksData = data['data'] as List<dynamic>? ?? [];
        return tracksData
            .map((item) => TrackModel.fromDeezer(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('[MusicService] searchDeezer gagal, beralih ke YouTube: $e');
    }

    return _searchYouTubeFallback(query);
  }

  Future<List<TrackModel>> _searchYouTubeFallback(String query) async {
    try {
      final searchList = await YoutubeClient.instance.client.search.search(query);
      return searchList.take(20).map((video) {
        final durationSec = video.duration?.inSeconds ?? 0;
        return TrackModel(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          album: 'YouTube',
          artworkUrl: video.thumbnails.highResUrl,
          durationMs: durationSec * 1000,
          youtubeId: video.id.value,
        );
      }).toList();
    } catch (e) {
      debugPrint('[MusicService] pencarian YouTube gagal: $e');
      return [];
    }
  }

  /// Resolusi URL stream audio untuk satu lagu.
  ///
  /// [forceRefresh] mengabaikan cache sehingga URL baru diambil dari YouTube.
  Future<String> resolveAudioStream(
    TrackModel track, {
    String quality = 'Maksimal',
    bool forceRefresh = false,
  }) async {
    final resolved = await resolveAudioStreamInfo(
      track,
      quality: quality,
      forceRefresh: forceRefresh,
    );
    return resolved.url;
  }

  /// Resolusi stream audio lengkap dengan metadata-nya.
  ///
  /// Berbeda dengan [resolveAudioStream] yang hanya mengembalikan URL, hasil
  /// sini juga memuat tipe konten dan ukuran berkas agar pemutar dapat
  /// menarik data dengan rentang byte yang tepat.
  Future<ResolvedAudioStream> resolveAudioStreamInfo(
    TrackModel track, {
    String quality = 'Maksimal',
    bool forceRefresh = false,
    String? preferredContainer,
  }) async {
    final cacheKey = '${track.id}_$quality'
        '${preferredContainer != null ? '_$preferredContainer' : ''}';

    if (!forceRefresh) {
      final cached = _streamUrlCache[cacheKey];
      if (cached != null) {
        final age = DateTime.now().difference(cached.storedAt);
        if (age < streamCacheTtl) {
          return _describeStream(
            cached.url,
            videoId: track.youtubeId ?? _videoIdCache[track.id] ?? '',
          );
        }
        _streamUrlCache.remove(cacheKey);
      }
    }

    final yt = YoutubeClient.instance.client;
    String? videoId = track.youtubeId ?? _videoIdCache[track.id];

    if (videoId == null) {
      final query = '${track.artist} - ${track.title} Official Audio';
      final searchResults = await yt.search.search(query);

      if (searchResults.isEmpty) {
        final broadQuery = '${track.artist} - ${track.title}';
        final secondSearch = await yt.search.search(broadQuery);
        if (secondSearch.isEmpty) {
          throw Exception('Lagu tidak ditemukan di YouTube.');
        }
        videoId = secondSearch.first.id.value;
      } else {
        final targetDurationSec = (track.durationMs / 1000).round();
        Video? bestMatch;
        int minDiff = 999999;

        for (final video in searchResults.take(6)) {
          final vidSec = video.duration?.inSeconds ?? 0;
          final diff = (vidSec - targetDurationSec).abs();
          if (diff < minDiff) {
            minDiff = diff;
            bestMatch = video;
          }
        }

        videoId = (bestMatch ?? searchResults.first).id.value;
      }

      _videoIdCache[track.id] = videoId;
    }

    final manifest = await yt.videos.streamsClient.getManifest(VideoId(videoId));
    final selected = _selectPreferredStream(
      manifest.audioOnly,
      quality,
      preferredContainer,
    );
    if (selected == null) {
      throw Exception('Tidak ada stream audio yang tersedia untuk lagu ini.');
    }

    final streamUrl = selected.url.toString();
    _streamUrlCache[cacheKey] = _StreamCacheEntry(streamUrl, DateTime.now());
    return _describeStream(
      streamUrl,
      videoId: videoId,
      codec: selected.audioCodec,
      container: selected.container.name,
    );
  }

  /// Memilih stream sesuai kualitas, dengan pilihan kontainer bila diminta.
  ///
  /// Kontainer `mp4` (AAC) dipakai sebagai cadangan ketika perangkat gagal
  /// mendekode Opus/WebM. Bila kontainer yang diminta tidak tersedia, stream
  /// terbaik apa pun dipakai sebagai gantinya.
  static AudioStreamInfo? _selectPreferredStream(
    List<AudioStreamInfo> audioOnly,
    String quality,
    String? preferredContainer,
  ) {
    if (preferredContainer != null) {
      final matching = audioOnly
          .where((s) => s.container.name == preferredContainer)
          .toList();
      if (matching.isNotEmpty) {
        return selectStream(matching, quality);
      }
    }
    return selectStream(audioOnly, quality);
  }

  /// Menyusun metadata stream dari URL yang sudah di-resolve.
  static ResolvedAudioStream _describeStream(
    String url, {
    required String videoId,
    String? codec,
    String? container,
  }) {
    final uri = Uri.tryParse(url);
    final mime = uri?.queryParameters['mime'] ?? '';
    final contentType = mime.split(';').first.trim();

    return ResolvedAudioStream(
      url: url,
      contentType: contentType.isEmpty ? 'audio/mpeg' : contentType,
      videoId: videoId,
      totalBytes: ResolvedAudioStream.parseTotalBytesFromUrl(url),
      codec: codec,
      container: container ??
          ResolvedAudioStream.containerFromContentType(
            contentType.isEmpty ? null : contentType,
          ),
    );
  }

  /// Pilih stream audio paling sesuai dengan tingkat kualitas yang diminta.
  ///
  /// Logika murni (tanpa jaringan) sehingga dapat diuji secara unit.
  static AudioStreamInfo? selectStream(
    List<AudioStreamInfo> audioOnly,
    String quality,
  ) {
    if (audioOnly.isEmpty) return null;

    final sorted = List<AudioStreamInfo>.from(audioOnly)
      ..sort((a, b) => a.bitrate.kiloBitsPerSecond
          .compareTo(b.bitrate.kiloBitsPerSecond));

    final bitrates =
        sorted.map((s) => s.bitrate.kiloBitsPerSecond).toList();
    final index = selectStreamIndex(bitrates, quality);
    return index < 0 ? null : sorted[index];
  }

  /// Menentukan indeks stream terbaik pada daftar bitrate (kbps) yang sudah
  /// terurut menaik.
  ///
  /// Fungsi murni agar dapat diuji tanpa memerlukan objek stream YouTube.
  static int selectStreamIndex(List<double> bitratesKbps, String quality) {
    if (bitratesKbps.isEmpty) return -1;

    final sorted = List<double>.from(bitratesKbps)..sort();
    final target = targetBitrateForQuality(quality);

    // Kualitas tertinggi: ambil bitrate terbesar yang tersedia.
    if (target >= 320) {
      return sorted.length - 1;
    }

    int bestIndex = 0;
    int bestDiff = (sorted.first - target).abs().toInt();
    for (int i = 1; i < sorted.length; i++) {
      final diff = (sorted[i] - target).abs().toInt();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
      }
    }
    return bestIndex;
  }
}
