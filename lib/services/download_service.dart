import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track_model.dart';
import 'id3_writer.dart';

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

  static String getSanitizedMp3FileName(TrackModel track) {
    final clean = '${track.artist} - ${track.title}'
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    return '$clean.mp3';
  }

  Future<String?> exportToDirectory(TrackModel track, {String folderName = 'Download'}) async {
    if (track.localPath == null) return null;
    final sourceFile = File(track.localPath!);
    if (!await sourceFile.exists()) return null;

    final fileName = getSanitizedMp3FileName(track);
    final cleanFolder = folderName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    Uint8List? imageBytes;
    if (track.artworkUrl.isNotEmpty) {
      try {
        final res = await _dio.get<List<int>>(
          track.artworkUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.data != null) {
          imageBytes = Uint8List.fromList(res.data!);
        }
      } catch (_) {}
    }

    final id3Bytes = Id3Writer.buildId3Tag(
      title: track.title,
      artist: track.artist,
      album: track.album,
      imageBytes: imageBytes,
    );

    final sourceBytes = await sourceFile.readAsBytes();
    int audioOffset = 0;
    if (sourceBytes.length >= 10 &&
        sourceBytes[0] == 0x49 &&
        sourceBytes[1] == 0x44 &&
        sourceBytes[2] == 0x33) {
      final synchsafeSize = (sourceBytes[6] << 21) |
          (sourceBytes[7] << 14) |
          (sourceBytes[8] << 7) |
          sourceBytes[9];
      audioOffset = 10 + synchsafeSize;
      if (audioOffset > sourceBytes.length) audioOffset = 0;
    }
    final audioPayload = audioOffset > 0 ? sourceBytes.sublist(audioOffset) : sourceBytes;

    Future<void> writeTaggedFile(String path) async {
      final target = File(path);
      final sink = target.openWrite();
      sink.add(id3Bytes);
      sink.add(audioPayload);
      await sink.flush();
      await sink.close();
    }

    final candidates = [
      '/storage/emulated/0/$cleanFolder',
      '/sdcard/$cleanFolder',
    ];

    for (final path in candidates) {
      try {
        final dir = Directory(path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final targetPath = '${dir.path}/$fileName';
        await writeTaggedFile(targetPath);
        return targetPath;
      } catch (_) {}
    }

    final docDir = await getApplicationDocumentsDirectory();
    final fallbackDir = Directory('${docDir.path}/$cleanFolder');
    if (!await fallbackDir.exists()) await fallbackDir.create(recursive: true);
    final fallbackPath = '${fallbackDir.path}/$fileName';
    await writeTaggedFile(fallbackPath);
    return fallbackPath;
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
