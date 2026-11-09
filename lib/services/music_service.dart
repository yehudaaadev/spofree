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

  Future<String> resolveAudioStream(TrackModel track) async {
    if (_streamUrlCache.containsKey(track.id)) {
      return _streamUrlCache[track.id]!;
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
    final audioStream = manifest.audioOnly.withHighestBitrate();
    final streamUrl = audioStream.url.toString();

    _streamUrlCache[track.id] = streamUrl;
    return streamUrl;
  }

  void dispose() {
    _yt.close();
  }
}
