import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track_model.dart';

class MusicService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  final YoutubeExplode _yt = YoutubeExplode();

  final Map<String, String> _videoIdCache = {};
  final Map<String, String> _streamUrlCache = {};

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
      } catch (_) {}
    }

    final fallbackQuery = '${track.artist} Radio Mix';
    return searchDeezer(fallbackQuery);
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
    } catch (_) {}
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
    } catch (_) {}

    return _searchYouTubeFallback(query);
  }

  Future<List<TrackModel>> _searchYouTubeFallback(String query) async {
    try {
      final searchList = await _yt.search.search(query);
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
    } catch (_) {
      return [];
    }
  }

  Future<String> resolveAudioStream(TrackModel track, {String quality = 'Maksimal'}) async {
    final cacheKey = '${track.id}_$quality';
    if (_streamUrlCache.containsKey(cacheKey)) {
      return _streamUrlCache[cacheKey]!;
    }

    String? videoId = track.youtubeId ?? _videoIdCache[track.id];

    if (videoId == null) {
      final query = '${track.artist} - ${track.title} Official Audio';
      final searchResults = await _yt.search.search(query);

      if (searchResults.isEmpty) {
        final broadQuery = '${track.artist} - ${track.title}';
        final secondSearch = await _yt.search.search(broadQuery);
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

    final manifest = await _yt.videos.streamsClient.getManifest(VideoId(videoId));
    final sorted = manifest.audioOnly.sortByBitrate().toList();
    AudioStreamInfo selectedStream;

    if (sorted.isEmpty) {
      selectedStream = manifest.audioOnly.withHighestBitrate();
    } else if (quality.contains('64') || quality.toLowerCase().contains('hemat')) {
      selectedStream = sorted.first;
    } else if (quality.contains('128') || quality.toLowerCase().contains('standar')) {
      selectedStream = sorted.first;
      int minDiff = 999999;
      for (final s in sorted) {
        final diff = (s.bitrate.kiloBitsPerSecond - 128).abs().toInt();
        if (diff < minDiff) {
          minDiff = diff;
          selectedStream = s;
        }
      }
    } else {
      selectedStream = manifest.audioOnly.withHighestBitrate();
    }

    final streamUrl = selectedStream.url.toString();
    _streamUrlCache[cacheKey] = streamUrl;
    return streamUrl;
  }

  void dispose() {
    _yt.close();
  }
}
