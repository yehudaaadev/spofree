import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track_model.dart';
import 'youtube_client.dart';

class ImportedPlaylistResult {
  final String title;
  final String source;
  final List<TrackModel> tracks;

  const ImportedPlaylistResult({
    required this.title,
    required this.source,
    required this.tracks,
  });
}

/// Sumber playlist yang didukung untuk impor tautan.
enum PlaylistSource { youtube, spotify }

class PlaylistImportService {
  final YoutubeExplode _yt = YoutubeClient.instance.client;
  final Dio _dio = Dio(
    BaseOptions(
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  /// Sumber playlist yang dikenali dari sebuah tautan.
  static PlaylistSource? detectSource(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;

    if (uri.scheme == 'spotify') return PlaylistSource.spotify;

    // Deteksi berdasarkan host, bukan substring. Dengan begitu tautan seperti
    // "https://contoh.com/?next=youtube.com" tidak salah dikenali.
    final host = uri.host.toLowerCase();
    if (_isHostOrSubdomain(host, 'youtube.com') ||
        _isHostOrSubdomain(host, 'youtube-nocookie.com') ||
        host == 'youtu.be') {
      return PlaylistSource.youtube;
    }
    if (_isHostOrSubdomain(host, 'spotify.com')) {
      return PlaylistSource.spotify;
    }
    return null;
  }

  /// True bila [host] sama dengan [domain] atau merupakan subdomainnya.
  static bool _isHostOrSubdomain(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }

  /// Klien YouTube dipakai bersama, sehingga tidak ada resource per-instance
  /// yang perlu ditutup.
  Future<ImportedPlaylistResult> importFromUrl(String url) async {
    final cleanUrl = url.trim();

    switch (detectSource(cleanUrl)) {
      case PlaylistSource.youtube:
        return _importYouTubePlaylist(cleanUrl);
      case PlaylistSource.spotify:
        return _importSpotifyPlaylist(cleanUrl);
      case null:
        throw Exception(
          'Format URL tidak dikenali. Gunakan tautan Spotify atau YouTube Playlist.',
        );
    }
  }

  Future<ImportedPlaylistResult> _importYouTubePlaylist(String url) async {
    String? playlistId;
    final regExp = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)');
    final match = regExp.firstMatch(url);

    if (match != null) {
      playlistId = match.group(1);
    } else if (url.contains('/playlist/')) {
      final parts = url.split('/playlist/');
      if (parts.length > 1) {
        playlistId = parts[1].split('?').first;
      }
    }

    if (playlistId == null || playlistId.isEmpty) {
      throw Exception('ID Playlist YouTube tidak ditemukan pada tautan.');
    }

    final playlist = await _yt.playlists.get(playlistId);
    final playlistTitle = playlist.title.isNotEmpty ? playlist.title : 'YouTube Playlist';

    final List<TrackModel> tracks = [];
    final stream = _yt.playlists.getVideos(playlistId);

    // Batasi hingga 200 lagu untuk menjaga efisiensi memori dan responsivitas UI.
    await for (final video in stream.take(200)) {
      final cleanMeta = TrackModel.parseYouTubeMetadata(
        video.title,
        video.author,
      );

      tracks.add(
        TrackModel(
          id: 'yt_${video.id.value}',
          title: cleanMeta.title,
          artist: cleanMeta.artist,
          album: playlistTitle,
          artworkUrl: video.thumbnails.highResUrl,
          durationMs: video.duration?.inMilliseconds ?? 0,
          youtubeId: video.id.value,
        ),
      );
    }

    if (tracks.isEmpty) {
      throw Exception('Playlist YouTube kosong atau tidak dapat diakses.');
    }

    return ImportedPlaylistResult(
      title: playlistTitle,
      source: 'YouTube',
      tracks: tracks,
    );
  }

  Future<ImportedPlaylistResult> _importSpotifyPlaylist(String url) async {
    final isAlbum = url.contains('/album/') || url.contains(':album:');
    final type = isAlbum ? 'album' : 'playlist';

    final regExp = RegExp(r'(?:playlist|album)[\/:]([a-zA-Z0-9]+)');
    final match = regExp.firstMatch(url);
    final id = match?.group(1);

    if (id == null || id.isEmpty) {
      throw Exception('ID Spotify tidak valid pada tautan.');
    }

    final embedUrl = 'https://open.spotify.com/embed/$type/$id';
    final Response<dynamic> response;
    try {
      response = await _dio.get(embedUrl);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        throw Exception('Playlist atau album Spotify tidak ditemukan.');
      }
      throw Exception('Gagal menghubungi Spotify. Periksa koneksi internet.');
    } catch (_) {
      throw Exception('Gagal memuat tautan Spotify.');
    }
    final html = response.data.toString();

    final nextDataMatch = RegExp(r'<script id="__NEXT_DATA__" type="application\/json">(.*?)<\/script>').firstMatch(html);
    if (nextDataMatch == null) {
      throw Exception('Gagal membaca data playlist Spotify. Pastikan playlist bersifat publik.');
    }

    final jsonData = jsonDecode(nextDataMatch.group(1)!);
    final pageProps = jsonData['props']?['pageProps'];
    final state = pageProps?['state']?['data'];
    final entity = state?['entity'];

    if (entity == null) {
      throw Exception('Format data Spotify telah berubah atau konten tidak ditemukan.');
    }

    final playlistTitle = entity['title'] ?? entity['name'] ?? 'Spotify Playlist';
    final coverArt = entity['coverArt']?['sources']?[0]?['url'] ?? '';

    final List<TrackModel> tracks = [];
    final trackList = entity['trackList'] as List<dynamic>? ?? [];

    for (int i = 0; i < trackList.length; i++) {
      final item = trackList[i];
      final title = item['title'] ?? '';
      final artist = item['subtitle'] ?? '';
      final durationMs = (item['duration'] is num) ? (item['duration'] as num).toInt() : 0;
      final uri = item['uri'] ?? 'spotify:track:$i';

      if (title.isNotEmpty) {
        tracks.add(
          TrackModel(
            id: 'sp_$uri',
            title: title,
            artist: artist.isNotEmpty ? artist : 'Various Artists',
            album: playlistTitle,
            artworkUrl: coverArt,
            durationMs: durationMs,
          ),
        );
      }
    }

    if (tracks.isEmpty) {
      throw Exception('Tidak ada lagu yang ditemukan di dalam playlist Spotify.');
    }

    return ImportedPlaylistResult(
      title: playlistTitle,
      source: 'Spotify',
      tracks: tracks,
    );
  }
}
