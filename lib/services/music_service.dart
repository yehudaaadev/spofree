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
    this.isDirectProgressive = false,
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

  /// Apakah stream ini berupa progressive stream langsung (mis. tag 18 MP4)
  /// yang aman diputar langsung oleh ExoPlayer tanpa proxy range lokal.
  final bool isDirectProgressive;

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

    // Fallback: campur lagu radio artis, lagu terkait, dan chart global agar
    // tidak menumpuk lagu dari artis yang sama (diversifikasi musik sejati).
    final mixed = <TrackModel>[];
    mixed.addAll(radio);
    mixed.addAll(await getChartTracks());

    final seen = <String>{track.id};
    final artistCounts = <String, int>{
      track.artist.toLowerCase(): 1,
    };
    final result = <TrackModel>[];

    for (final item in mixed) {
      if (!seen.add(item.id)) continue;
      final artLower = item.artist.toLowerCase();
      final currentCount = artistCounts[artLower] ?? 0;
      // Batasi maksimal 2 lagu untuk artis yang sama agar antrean tidak homogen.
      if (currentCount >= 2) continue;
      artistCounts[artLower] = currentCount + 1;
      result.add(item);
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

  /// Pencarian musik hybrid berkecepatan tinggi yang menggabungkan katalog
  /// resmi Deezer dan YouTube Music / Topics.
  Future<List<TrackModel>> searchMusic(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final deezerFuture = _fetchDeezerSearch(q);
    final ytFuture = _fetchYouTubeSearch(q);

    final results = await Future.wait([deezerFuture, ytFuture]);
    final deezerTracks = results[0];
    final ytTracks = results[1];

    if (deezerTracks.isEmpty && ytTracks.isEmpty) return [];

    // Peta peringkat bawaan untuk menghitung popularitas organik YouTube & Deezer
    final ytRankMap = <String, int>{};
    for (int i = 0; i < ytTracks.length; i++) {
      final key =
          '${TrackModel.cleanArtist(ytTracks[i].artist).toLowerCase()}__${TrackModel.cleanTitle(ytTracks[i].title).toLowerCase()}';
      ytRankMap.putIfAbsent(key, () => i);
    }

    final deezerRankMap = <String, int>{};
    for (int i = 0; i < deezerTracks.length; i++) {
      final key =
          '${TrackModel.cleanArtist(deezerTracks[i].artist).toLowerCase()}__${TrackModel.cleanTitle(deezerTracks[i].title).toLowerCase()}';
      deezerRankMap.putIfAbsent(key, () => i);
    }

    // Tempatkan hasil YouTube teratas berdampingan dengan Deezer agar lagu yang
    // diblokir di Deezer (seperti Oasis Champagne Supernova) langsung terangkat.
    final candidates = <TrackModel>[
      ...ytTracks.take(8),
      ...deezerTracks,
      ...ytTracks.skip(8),
    ];

    final seenKeys = <String>{};
    final merged = <TrackModel>[];

    for (final track in candidates) {
      final key = '${TrackModel.cleanArtist(track.artist).toLowerCase()}__${TrackModel.cleanTitle(track.title).toLowerCase()}';
      if (seenKeys.contains(key)) {
        // Bila track sudah ada dari Deezer tapi belum punya youtubeId, tempelkan
        // youtubeId dari kandidat YouTube agar pemutaran awal menjadi instan.
        final idx = merged.indexWhere((m) =>
            '${TrackModel.cleanArtist(m.artist).toLowerCase()}__${TrackModel.cleanTitle(m.title).toLowerCase()}' == key);
        if (idx != -1 && merged[idx].youtubeId == null && track.youtubeId != null) {
          merged[idx] = merged[idx].copyWith(youtubeId: track.youtubeId);
        }
        continue;
      }
      seenKeys.add(key);
      merged.add(track);
    }

    // Urutkan berdasarkan skor relevansi dan otoritas peringkat kanonikal.
    merged.sort((a, b) {
      final keyA =
          '${TrackModel.cleanArtist(a.artist).toLowerCase()}__${TrackModel.cleanTitle(a.title).toLowerCase()}';
      final keyB =
          '${TrackModel.cleanArtist(b.artist).toLowerCase()}__${TrackModel.cleanTitle(b.title).toLowerCase()}';
      final bonusA = calculateAuthorityBonus(a, ytRank: ytRankMap[keyA], deezerRank: deezerRankMap[keyA]);
      final bonusB = calculateAuthorityBonus(b, ytRank: ytRankMap[keyB], deezerRank: deezerRankMap[keyB]);
      final scoreA = scoreTrack(a, q, authorityBonus: bonusA);
      final scoreB = scoreTrack(b, q, authorityBonus: bonusB);
      return scoreB.compareTo(scoreA);
    });
    return merged;
  }

  /// Menghitung bonus popularitas organik dari YouTube & Deezer.
  static int calculateAuthorityBonus(TrackModel track, {int? ytRank, int? deezerRank}) {
    int bonus = 0;

    // 1. YouTube organic popularity decay (peringkat 0 adalah video views terbanyak/relevan)
    if (ytRank != null) {
      if (ytRank == 0) {
        bonus += 50;
      } else if (ytRank == 1) {
        bonus += 35;
      } else if (ytRank == 2) {
        bonus += 25;
      } else if (ytRank == 3) {
        bonus += 18;
      } else if (ytRank == 4) {
        bonus += 12;
      } else if (ytRank <= 7) {
        bonus += 8;
      }
    }

    // 2. Deezer organic popularity decay
    if (deezerRank != null) {
      if (deezerRank == 0) {
        bonus += 40;
      } else if (deezerRank == 1) {
        bonus += 25;
      } else if (deezerRank == 2) {
        bonus += 15;
      } else if (deezerRank <= 5) {
        bonus += 8;
      }
    }

    // 3. Kesepakatan Kanonikal Ganda (muncul di peringkat atas kedua layanan)
    if (ytRank != null && ytRank <= 3 && deezerRank != null && deezerRank <= 3) {
      bonus += 60;
    }

    // 4. Deteksi artis/album resmi YouTube Topic / VEVO
    final albumLower = track.album.toLowerCase();
    final artistLower = track.artist.toLowerCase();
    if (albumLower.contains('topic') ||
        artistLower.contains('topic') ||
        artistLower.contains('vevo')) {
      bonus += 25;
    }

    return bonus;
  }

  /// Backward-compatibility wrapper untuk pencarian.
  Future<List<TrackModel>> searchDeezer(String query) => searchMusic(query);

  Future<List<TrackModel>> _fetchDeezerSearch(String query) async {
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
      debugPrint('[MusicService] Deezer search gagal: $e');
    }
    return [];
  }

  Future<List<TrackModel>> _fetchYouTubeSearch(String query) async {
    try {
      final qLower = query.toLowerCase();
      final searchList = await YoutubeClient.instance.client.search.search(query);
      final tracks = <TrackModel>[];

      for (final video in searchList.take(20)) {
        final titleLower = video.title.toLowerCase();
        final authorLower = video.author.toLowerCase();
        final durationSec = video.duration?.inSeconds ?? 0;

        // Hindari kompilasi video panjang (> 15 menit)
        if (durationSec > 900) continue;

        // Filter karaoke kecuali diminta secara eksplisit
        if (!qLower.contains('karaoke') &&
            (titleLower.contains('karaoke') || authorLower.contains('karaoke'))) {
          continue;
        }

        // Filter loop / 1 hour
        if (!qLower.contains('1 hour') && !qLower.contains('1 jam') && !qLower.contains('loop') &&
            (titleLower.contains('1 hour') || titleLower.contains('1 jam') || titleLower.contains('loop'))) {
          continue;
        }

        // Filter slowed / sped up
        if (!qLower.contains('slowed') && !qLower.contains('speed up') && !qLower.contains('sped up') &&
            (titleLower.contains('slowed') || titleLower.contains('speed up') || titleLower.contains('sped up'))) {
          continue;
        }

        // Filter video lirik amatir agar tidak mengotori antrean
        if (!qLower.contains('lirik') && !qLower.contains('lyric') && !qLower.contains('letra') &&
            (titleLower.contains('lyrics') || titleLower.contains('lirik') || titleLower.contains('letra'))) {
          continue;
        }

        final meta = TrackModel.parseYouTubeMetadata(video.title, video.author);
        tracks.add(TrackModel(
          id: 'yt_${video.id.value}',
          title: meta.title,
          artist: meta.artist,
          album: video.author.toLowerCase().contains('topic') ? 'YouTube Topic' : 'YouTube',
          artworkUrl: video.thumbnails.highResUrl,
          durationMs: durationSec * 1000,
          youtubeId: video.id.value,
        ));
      }
      return tracks;
    } catch (e) {
      debugPrint('[MusicService] YouTube search gagal: $e');
      return [];
    }
  }

  /// Menilai kecocokan lagu terhadap query pencarian pengguna (fungsi murni).
  static int scoreTrack(TrackModel t, String query, {int authorityBonus = 0}) {
    int score = authorityBonus;
    final q = query.toLowerCase().trim();
    final title = t.title.toLowerCase().trim();
    final artist = t.artist.toLowerCase().trim();
    final tokens = q.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

    // Exact title match
    if (title == q) {
      score += 35;
    } else if (title.startsWith(q)) {
      score += 20;
    } else if (title.contains(q)) {
      score += 15;
    }

    // Exact artist match
    if (artist == q) {
      score += 35;
    } else if (artist.contains(q)) {
      score += 15;
    }

    // Token matches
    for (final tok in tokens) {
      if (title.contains(tok)) score += 8;
      if (artist.contains(tok)) score += 10;
    }

    // Penalti untuk versi cover jika pengguna tidak mencari cover
    if (!q.contains('cover') && (title.contains('cover') || artist.contains('cover'))) {
      score -= 25;
    }
    // Penalti untuk backing track, tribute, instrumental, karaoke
    if (!q.contains('backing') && title.contains('backing track')) score -= 30;
    if (!q.contains('tribute') && title.contains('tribute')) score -= 25;
    if (!q.contains('karaoke') && (title.contains('karaoke') || artist.contains('karaoke'))) score -= 30;

    // Bonus track yang sudah memiliki direct youtubeId (instant playback)
    if (t.youtubeId != null) score += 5;

    return score;
  }

  /// Memuat awal stream URL di background agar transisi lagu berikutnya instan.
  Future<void> preloadTrackStream(TrackModel track, {String quality = 'Maksimal'}) async {
    try {
      await resolveAudioStreamInfo(track, quality: quality);
    } catch (_) {
      // Abaikan kegagalan preload di background.
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
  /// [preferProgressive] memprioritaskan stream progressive (`tag 18` MP4)
  /// yang memiliki `ratebypass=yes` sehingga dapat dimainkan langsung oleh
  /// ExoPlayer tanpa batasan chunk range 403.
  Future<ResolvedAudioStream> resolveAudioStreamInfo(
    TrackModel track, {
    String quality = 'Maksimal',
    bool forceRefresh = false,
    String? preferredContainer,
    bool preferProgressive = true,
  }) async {
    final cacheKey = '${track.id}_$quality'
        '${preferredContainer != null ? '_$preferredContainer' : ''}'
        '${preferProgressive ? '_prog' : ''}';

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

      if (_videoIdCache.length >= 200) {
        _videoIdCache.remove(_videoIdCache.keys.first);
      }
      _videoIdCache[track.id] = videoId;
    }

    // requireWatchPage: false memotong waktu pemuatan manifest dari ~1500ms
    // menjadi ~350ms dan mencegah bot challenge watch-page.
    final manifest = await yt.videos.streamsClient.getManifest(
      VideoId(videoId),
      requireWatchPage: false,
    );

    StreamInfo? selected;
    bool isProgressive = false;

    // Utamakan progressive stream MP4 (tag 18 atau progressive stream muxed lain)
    // untuk pemutaran langsung tanpa drop 403 CDN.
    if (preferProgressive && (preferredContainer == null || preferredContainer == 'mp4')) {
      final tag18 = manifest.muxed.where((s) => s.tag == 18).toList();
      if (tag18.isNotEmpty) {
        selected = tag18.first;
        isProgressive = true;
      } else {
        final muxedMp4 = manifest.muxed
            .where((s) => s.container.name.toLowerCase() == 'mp4')
            .toList();
        if (muxedMp4.isNotEmpty) {
          muxedMp4.sort((a, b) => a.size.totalBytes.compareTo(b.size.totalBytes));
          selected = muxedMp4.first;
          isProgressive = true;
        }
      }
    }

    selected ??= _selectPreferredStream(
      manifest.audioOnly,
      quality,
      preferredContainer,
    );

    if (selected == null) {
      throw Exception('Tidak ada stream audio yang tersedia untuk lagu ini.');
    }

    final streamUrl = selected.url.toString();
    if (_streamUrlCache.length >= 200) {
      _streamUrlCache.remove(_streamUrlCache.keys.first);
    }
    _streamUrlCache[cacheKey] = _StreamCacheEntry(streamUrl, DateTime.now());
    return _describeStream(
      streamUrl,
      videoId: videoId,
      codec: selected is AudioStreamInfo ? selected.audioCodec : 'mp4a.40.2',
      container: selected.container.name,
      totalBytes: selected.size.totalBytes,
      isDirectProgressive: isProgressive,
    );
  }

  /// Memilih stream sesuai kualitas, dengan pilihan kontainer bila diminta.
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
    int? totalBytes,
    bool isDirectProgressive = false,
  }) {
    final uri = Uri.tryParse(url);
    final mime = uri?.queryParameters['mime'] ?? '';
    final contentType = mime.split(';').first.trim();

    return ResolvedAudioStream(
      url: url,
      contentType: contentType.isEmpty
          ? (isDirectProgressive ? 'video/mp4' : 'audio/mpeg')
          : contentType,
      videoId: videoId,
      totalBytes: totalBytes ?? ResolvedAudioStream.parseTotalBytesFromUrl(url),
      codec: codec,
      container: container ??
          ResolvedAudioStream.containerFromContentType(
            contentType.isEmpty ? null : contentType,
          ),
      isDirectProgressive: isDirectProgressive,
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
