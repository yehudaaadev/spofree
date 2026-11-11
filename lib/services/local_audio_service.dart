import 'dart:io';
import '../models/track_model.dart';

class LocalAudioService {
  static const List<String> supportedExtensions = [
    '.mp3',
    '.m4a',
    '.wav',
    '.flac',
    '.aac',
    '.ogg',
  ];

  static Future<List<TrackModel>> scanLocalAudioFiles() async {
    final List<TrackModel> foundTracks = [];
    final Set<String> seenPaths = {};

    final List<String> searchDirectories = [
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Documents',
      '/storage/emulated/0/Audio',
      '/sdcard/Music',
      '/sdcard/Download',
    ];

    for (final dirPath in searchDirectories) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) continue;

      try {
        final List<FileSystemEntity> entities = dir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is! File) continue;

          final path = entity.path;
          final lower = path.toLowerCase();
          final matches = supportedExtensions.any((ext) => lower.endsWith(ext));

          if (matches && !seenPaths.contains(path)) {
            seenPaths.add(path);
            final track = _createTrackFromFile(entity);
            if (track != null) {
              foundTracks.add(track);
            }
          }
        }
      } catch (_) {
        // Permission or path traversal skipped silently
      }
    }

    return foundTracks;
  }

  static TrackModel? _createTrackFromFile(File file) {
    try {
      final fileName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : file.path.split(Platform.pathSeparator).last;

      final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      String artist = 'Penyimpanan Lokal';
      String title = nameWithoutExt;

      if (nameWithoutExt.contains(' - ')) {
        final parts = nameWithoutExt.split(' - ');
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      } else if (nameWithoutExt.contains('-')) {
        final parts = nameWithoutExt.split('-');
        artist = parts[0].trim();
        title = parts.sublist(1).join('-').trim();
      }

      final stat = file.statSync();
      final approxDurationMs = (stat.size / 16000).clamp(60000, 600000).toInt();

      return TrackModel(
        id: 'local_${file.path.hashCode}',
        title: title.isNotEmpty ? title : 'Lagu Lokal',
        artist: artist.isNotEmpty ? artist : 'Artis Tidak Diketahui',
        album: 'File Internal',
        artworkUrl: '',
        durationMs: approxDurationMs,
        localPath: file.path,
      );
    } catch (_) {
      return null;
    }
  }
}
