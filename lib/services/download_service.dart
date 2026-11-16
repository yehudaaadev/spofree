import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track_model.dart';
import 'audio_format.dart';
import 'id3_writer.dart';
import 'music_service.dart';
import 'ranged_http_client.dart';
import 'storage_permission_service.dart';

/// Hasil proses ekspor berkas audio ke folder penyimpanan.
class ExportResult {
  final String? path;
  final String? error;
  final AudioFormat format;
  final bool tagged;

  const ExportResult({
    this.path,
    this.error,
    required this.format,
    required this.tagged,
  });

  bool get success => path != null;
}

/// Mengelola unduhan offline dan ekspor berkas audio.
///
/// Berkas unduhan memakai ekstensi yang sesuai dengan kontainer aslinya
/// (hasil deteksi magic bytes), bukan selalu `.m4a`. Ekspor ke folder publik
/// hanya menyisipkan tag ID3 bila sumbernya benar-benar MP3; untuk kontainer
/// lain berkas disalin apa adanya dengan ekstensi yang benar.
class DownloadService {
  final Dio _dio;
  static const String _downloadKey = 'spotube_downloaded_tracks';

  DownloadService({Dio? dio}) : _dio = dio ?? Dio();

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
      } catch (e) {
        debugPrint('[DownloadService] entri unduhan rusak dilewati: $e');
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
    required MusicService musicService,
    required String quality,
    void Function(double progress)? onProgress,
  }) async {
    final dirPath = await _getDownloadDirectory();
    final safeFileName = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final tempPath = '$dirPath/$safeFileName.download';

    await _downloadRanged(
      tempPath: tempPath,
      initialUrl: audioStreamUrl,
      track: track,
      musicService: musicService,
      quality: quality,
      onProgress: onProgress,
    );

    // Deteksi kontainer asli dari magic bytes agar ekstensi dan MIME type
    // sesuai dengan isi berkas.
    final format = await detectFormatOfFile(tempPath);
    final filePath = '$dirPath/$safeFileName${format.extension}';

    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      if (await File(filePath).exists()) {
        await File(filePath).delete();
      }
      await tempFile.rename(filePath);
    }

    final updatedTrack = track.copyWith(localPath: filePath, mimeType: format.mimeType);

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

  /// Mengunduh berkas audio per potongan dengan header `Range` terbatasi.
  ///
  /// CDN YouTube membalas HTTP 403 untuk permintaan tanpa `Range` terbatasi,
  /// sehingga unduhan harus dipecah menjadi potongan kecil. Bila link ditolak
  /// (kedaluwarsa / IP berubah), link baru di-resolve lalu unduhan dilanjutkan.
  Future<void> _downloadRanged({
    required String tempPath,
    required String initialUrl,
    required TrackModel track,
    required MusicService musicService,
    required String quality,
    void Function(double progress)? onProgress,
  }) async {
    const chunkSize = RangedHttpClient.defaultChunkSize;
    final client = RangedHttpClient();
    var url = initialUrl;
    var total = 0;
    var written = 0;

    try {
      final sink = File(tempPath).openWrite();
      try {
        var position = 0;
        while (true) {
          final chunkEnd = position + chunkSize - 1;
          final chunk = await client.fetchRangeResilient(
            Uri.parse(url),
            start: position,
            end: chunkEnd,
            onForbidden: () async {
              // Link ditolak: ambil link baru lalu lanjutkan unduhan.
              url = await musicService.resolveAudioStream(
                track,
                quality: quality,
                forceRefresh: true,
              );
              return Uri.parse(url);
            },
          );

          if (chunk.bytes.isEmpty) break;
          total = chunk.totalBytes ?? total;
          sink.add(chunk.bytes);
          written += chunk.bytes.length;
          position += chunk.bytes.length;

          if (total > 0) {
            onProgress?.call((written / total).clamp(0.0, 1.0));
          }

          // Potongan terakhir lebih pendek dari ukuran permintaan.
          if (chunk.bytes.length < chunkSize) break;
          if (total > 0 && position >= total) break;
        }

        // Berkas yang terpotong tidak boleh disimpan sebagai unduhan utuh.
        if (total > 0 && written < total) {
          throw RangedRequestException(
            'Unduhan terhenti: hanya $written dari $total byte yang bisa '
            'diambil. YouTube membatasi pengunduhan stream untuk lagu ini.',
          );
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  /// Deteksi kontainer berkas dari 64 byte pertama.
  static Future<AudioFormat> detectFormatOfFile(String path) async {
    try {
      final handle = await File(path).open();
      try {
        final header = await handle.read(64);
        return AudioFormat.detect(Uint8List.fromList(header));
      } finally {
        await handle.close();
      }
    } catch (e) {
      debugPrint('[DownloadService] deteksi format gagal: $e');
      return AudioFormat.unknown;
    }
  }

  static String getSanitizedFileName(TrackModel track, String extension) {
    final clean = '${track.artist} - ${track.title}'
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    return '$clean$extension';
  }

  /// Ekspor berkas audio ke folder yang dapat diakses pengguna.
  ///
  /// Mengembalikan [ExportResult] berisi path tujuan, format, dan apakah tag
  /// ID3 berhasil disisipkan.
  Future<ExportResult> exportToDirectory(
    TrackModel track, {
    String folderName = 'Download',
  }) async {
    if (track.localPath == null) {
      return const ExportResult(
        error: 'Lagu ini belum diunduh ke penyimpanan lokal.',
        format: AudioFormat.unknown,
        tagged: false,
      );
    }

    final sourceFile = File(track.localPath!);
    if (!await sourceFile.exists()) {
      return const ExportResult(
        error: 'Berkas unduhan tidak ditemukan di perangkat.',
        format: AudioFormat.unknown,
        tagged: false,
      );
    }

    final hasPermission = await StoragePermissionService.ensurePermission();
    if (!hasPermission) {
      return const ExportResult(
        error:
            'Izin akses penyimpanan ditolak. Aktifkan "Akses semua file" pada pengaturan aplikasi untuk menyimpan ke folder HP.',
        format: AudioFormat.unknown,
        tagged: false,
      );
    }

    final cleanFolder =
        folderName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final folder = cleanFolder.isEmpty ? 'Download' : cleanFolder;

    final format = await detectFormatOfFile(sourceFile.path);
    final fileName = getSanitizedFileName(track, format.extension);

    // Hanya MP3 yang mendukung ID3; kontainer lain disalin apa adanya.
    Uint8List? imageBytes;
    if (format.supportsId3 && track.artworkUrl.isNotEmpty) {
      try {
        final res = await _dio.get<List<int>>(
          track.artworkUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.data != null) {
          imageBytes = Uint8List.fromList(res.data!);
        }
      } catch (e) {
        debugPrint('[DownloadService] cover art gagal diambil: $e');
      }
    }

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
    final audioPayload =
        audioOffset > 0 ? sourceBytes.sublist(audioOffset) : sourceBytes;

    final bool tagged = format.supportsId3;
    final id3Bytes = tagged
        ? Id3Writer.buildId3Tag(
            title: track.title,
            artist: track.artist,
            album: track.album,
            imageBytes: imageBytes,
          )
        : Uint8List(0);

    Future<void> writeTaggedFile(String path) async {
      final target = File(path);
      final sink = target.openWrite();
      if (tagged) {
        sink.add(id3Bytes);
      }
      sink.add(audioPayload);
      await sink.flush();
      await sink.close();
    }

    final candidates = [
      '/storage/emulated/0/$folder',
      '/sdcard/$folder',
    ];

    for (final path in candidates) {
      try {
        final dir = Directory(path);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final targetPath = '${dir.path}/$fileName';
        await writeTaggedFile(targetPath);
        return ExportResult(path: targetPath, format: format, tagged: tagged);
      } catch (e) {
        debugPrint('[DownloadService] gagal menulis ke $path: $e');
      }
    }

    final docDir = await getApplicationDocumentsDirectory();
    final fallbackDir = Directory('${docDir.path}/$folder');
    try {
      if (!await fallbackDir.exists()) await fallbackDir.create(recursive: true);
      final fallbackPath = '${fallbackDir.path}/$fileName';
      await writeTaggedFile(fallbackPath);
      return ExportResult(path: fallbackPath, format: format, tagged: tagged);
    } catch (e) {
      debugPrint('[DownloadService] ekspor gagal: $e');
      return ExportResult(
        error: 'Gagal menyimpan berkas: $e',
        format: format,
        tagged: tagged,
      );
    }
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
      } catch (e) {
        debugPrint('[DownloadService] entri rusak saat hapus: $e');
      }
    }

    await prefs.setStringList(_downloadKey, remaining);
  }
}
