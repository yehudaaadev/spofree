import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track_model.dart';

class DownloadService {
  final Dio _dio = Dio();
  static const String _downloadKey = 'spotube_downloaded_tracks';

  Future<String> _getDownloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${appDir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  Future<List<TrackModel>> getDownloadedTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_downloadKey) ?? [];

    final List<TrackModel> verified = [];
    final List<String> updatedRaw = [];

    for (final item in rawList) {
      try {
        final track = TrackModel.fromJson(item);
        if (track.localPath != null && await File(track.localPath!).exists()) {
          verified.add(track);
          updatedRaw.add(item);
        }
      } catch (_) {
        // Skip malformed entries
      }
    }

    if (updatedRaw.length != rawList.length) {
      await prefs.setStringList(_downloadKey, updatedRaw);
    }

    return verified;
  }

  Future<TrackModel> downloadTrack({
    required TrackModel track,
    required String audioStreamUrl,
    void Function(double progress)? onProgress,
  }) async {
    final dirPath = await _getDownloadDirectory();
    final safeFileName = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filePath = '$dirPath/$safeFileName.m4a';

    await _dio.download(
      audioStreamUrl,
      filePath,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          final progress = received / total;
          onProgress(progress.clamp(0.0, 1.0));
        }
      },
    );

    final updatedTrack = track.copyWith(localPath: filePath);

    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_downloadKey) ?? [];
    list.removeWhere((item) {
      try {
        return TrackModel.fromJson(item).id == track.id;
      } catch (_) {
        return false;
      }
    });
    list.insert(0, updatedTrack.toJson());
    await prefs.setStringList(_downloadKey, list);

    return updatedTrack;
  }

  Future<void> removeDownload(String trackId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_downloadKey) ?? [];
    final remaining = <String>[];

    for (final item in list) {
      try {
        final track = TrackModel.fromJson(item);
        if (track.id == trackId) {
          if (track.localPath != null) {
            final file = File(track.localPath!);
            if (await file.exists()) {
              await file.delete();
            }
          }
        } else {
          remaining.add(item);
        }
      } catch (_) {}
    }

    await prefs.setStringList(_downloadKey, remaining);
  }
}
