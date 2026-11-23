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
import 'stable_hash.dart';
import 'storage_permission_service.dart';

/// Sinyal internal untuk mengulang unduhan dari byte 0 setelah URL berubah.
class _RestartDownload implements Exception {
  const _RestartDownload();
}

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
    // ID yang berbeda bisa menghasilkan nama sanitasi yang sama (mis. `:` dan
    // `_`), jadi tambahkan hash stabil agar berkas tidak saling menimpa.
    final idPart = track.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeFileName =
        '${idPart.length > 40 ? idPart.substring(0, 40) : idPart}'
        '_${stableHash(track.id).substring(0, 8)}';
    final tempPath = '$dirPath/$safeFileName.download';

    try {
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
      if (format == AudioFormat.unknown) {
        throw const RangedRequestException(
          'Berkas hasil unduhan bukan audio yang dikenali.',
        );
      }

      final filePath = '$dirPath/$safeFileName${format.extension}';
      final tempFile = File(tempPath);
      if (!await tempFile.exists()) {
        throw const RangedRequestException(
          'Berkas unduhan hilang sebelum disimpan.',
        );
      }
      // Hapus versi lama dengan ekstensi berbeda agar tidak ada berkas yatim
      // saat format hasil deteksi berubah (mis. .m4a -> .webm).
      await for (final entity in Directory(dirPath).list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name == '$safeFileName.download') continue;
        if (name.startsWith('$safeFileName.')) {
          try {
            await entity.delete();
          } catch (_) {
            // Abaikan: berkas mungkin sedang dipakai pemutar.
          }
        }
      }
      await tempFile.rename(filePath);

      final updatedTrack =
          track.copyWith(localPath: filePath, mimeType: format.mimeType);

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
    } catch (e) {
      // Jangan tinggalkan berkas .download setengah jadi.
      final temp = File(tempPath);
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {
          // Abaikan: pembersihan terbaik yang bisa dilakukan.
        }
      }
      rethrow;
    }
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
    // 256 KB per potongan untuk akselerasi unduhan tanpa membebani CDN.
    const chunkSize = 256 * 1024;
    const maxRestarts = 2;
    final client = RangedHttpClient();
    var url = initialUrl;
    var restarts = 0;

    try {
      while (true) {
        var total = 0;
        var written = 0;
        var needsRestart = false;
        var reachedEnd = false;

        final sink = File(tempPath).openWrite();
        try {
          Future<RangedResponse> fetchChunk(int start, int end) {
            return client.fetchRangeResilient(
              Uri.parse(url),
              start: start,
              end: end,
              onForbidden: () async {
                // Link lama bisa menunjuk kontainer berbeda (WebM -> MP4).
                // Melanjutkan offset lama berisiko mencampur dua kontainer,
                // jadi mulai ulang dari byte 0 dengan URL baru.
                url = await musicService.resolveAudioStream(
                  track,
                  quality: quality,
                  forceRefresh: true,
                );
                needsRestart = true;
                throw const _RestartDownload();
              },
            );
          }

          var position = 0;
          while (true) {
            final chunkEnd = position + chunkSize - 1;
            final chunk = await fetchChunk(position, chunkEnd);

            if (chunk.bytes.isEmpty) {
              // 416/akhir berkas hanya sah bila sudah ada data sebelumnya.
              reachedEnd = position > 0;
              if (!reachedEnd) {
                throw const RangedRequestException(
                  'Server tidak mengirim data audio apa pun.',
                );
              }
              break;
            }

            total = chunk.totalBytes ?? total;
            sink.add(chunk.bytes);
            written += chunk.bytes.length;
            position += chunk.bytes.length;

            if (total > 0) {
              onProgress?.call((written / total).clamp(0.0, 1.0));
            }

            if (total > 0 && position >= total) {
              reachedEnd = true;
              break;
            }

            // Potongan lebih pendek dari permintaan bisa berarti EOF, tetapi
            // juga bisa throttle CDN. Bila total belum diketahui, probe satu
            // byte untuk memastikan berkas benar-benar habis.
            if (chunk.bytes.length < chunkSize) {
              if (total > 0) {
                reachedEnd = true;
                break;
              }
              final probe = await fetchChunk(position, position);
              if (probe.bytes.isEmpty) {
                reachedEnd = true;
                break;
              }
              sink.add(probe.bytes);
              written += probe.bytes.length;
              position += probe.bytes.length;
              total = probe.totalBytes ?? total;
              if (total > 0) {
                onProgress?.call((written / total).clamp(0.0, 1.0));
              }
              if (total > 0 && position >= total) {
                reachedEnd = true;
                break;
              }
            }
          }
        } on _RestartDownload {
          // Ditangani setelah sink ditutup.
        } finally {
          await sink.flush();
          await sink.close();
        }

        if (needsRestart) {
          if (restarts >= maxRestarts) {
            throw const RangedRequestException(
              'Unduhan gagal: server terus menolak link stream.',
            );
          }
          restarts++;
          onProgress?.call(0);
          final temp = File(tempPath);
          if (await temp.exists()) {
            await temp.delete();
          }
          continue;
        }

        if (!reachedEnd) {
          throw const RangedRequestException(
            'Unduhan berhenti sebelum selesai.',
          );
        }

        // Berkas yang terpotong tidak boleh disimpan sebagai unduhan utuh.
        if (total > 0 && written != total) {
          throw RangedRequestException(
            'Unduhan tidak utuh: hanya $written dari $total byte yang bisa '
            'diambil. YouTube membatasi pengunduhan stream untuk lagu ini.',
          );
        }
        break;
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
    var clean = '${track.artist} - ${track.title}'
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim();
    // Titik/spasi di akhir tidak valid pada Windows.
    clean = clean.replaceAll(RegExp(r'[. ]+$'), '');
    if (clean.isEmpty) clean = 'audio';

    // Batasi panjang agar aman di semua sistem berkas.
    final runes = clean.runes.toList();
    if (runes.length > 50) {
      clean = String.fromCharCodes(runes.take(50));
    }

    // Sufiks hash mencegah dua lagu dengan judul/artis sama saling menimpa.
    final suffix = stableHash(track.id).substring(0, 8);
    return '$clean [$suffix]$extension';
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

    // Hanya baca header ID3 (10 byte) agar tidak memuat seluruh lagu ke RAM.
    int audioOffset = 0;
    final sourceHandle = await sourceFile.open();
    try {
      final header = await sourceHandle.read(10);
      if (header.length >= 10 &&
          header[0] == 0x49 &&
          header[1] == 0x44 &&
          header[2] == 0x33) {
        final synchsafeSize = (header[6] << 21) |
            (header[7] << 14) |
            (header[8] << 7) |
            header[9];
        audioOffset = 10 + synchsafeSize;
        if (audioOffset > await sourceFile.length()) audioOffset = 0;
      }
    } finally {
      await sourceHandle.close();
    }

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
      // Tulis ke berkas sementara lalu rename agar ekspor yang gagal di tengah
      // jalan tidak meninggalkan berkas tujuan yang rusak.
      final part = File('$path.part');
      try {
        final sink = part.openWrite();
        try {
          if (tagged) {
            sink.add(id3Bytes);
          }
          await sink.addStream(sourceFile.openRead(audioOffset));
          await sink.flush();
        } finally {
          await sink.close();
        }
        final target = File(path);
        if (await target.exists()) {
          await target.delete();
        }
        await part.rename(path);
      } catch (e) {
        if (await part.exists()) {
          try {
            await part.delete();
          } catch (_) {
            // Abaikan: pembersihan terbaik yang bisa dilakukan.
          }
        }
        rethrow;
      }
    }

    final candidates = <String>[];
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final external = await getExternalStorageDirectory();
        if (external != null) {
          const marker = '/Android/';
          final root = external.path.split(marker).first;
          candidates.add('$root/$folder');
        }
      } catch (e) {
        debugPrint('[DownloadService] folder eksternal tidak tersedia: $e');
      }
      candidates.add('/storage/emulated/0/$folder');
      candidates.add('/sdcard/$folder');
    } else {
      try {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          candidates.add('${downloads.path}/$folder');
        }
      } catch (e) {
        debugPrint('[DownloadService] folder Downloads tidak tersedia: $e');
      }
    }

    final uniqueCandidates = <String>[];
    for (final candidate in candidates) {
      if (!uniqueCandidates.contains(candidate)) {
        uniqueCandidates.add(candidate);
      }
    }

    for (final path in uniqueCandidates) {
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

  /// Ukuran total berkas audio offline yang tersimpan.
  Future<int> getDownloadsSizeBytes() async {
    var total = 0;
    try {
      final tracks = await getDownloadedTracks();
      for (final track in tracks) {
        try {
          total += await File(track.localPath!).length();
        } catch (_) {
          // Berkas bisa terhapus di antara verifikasi dan penghitungan.
        }
      }
    } catch (e) {
      debugPrint('[DownloadService] gagal menghitung ukuran unduhan: $e');
    }
    return total;
  }

  /// Menghapus semua unduhan offline beserta berkasnya.
  Future<void> removeAllDownloads() async {
    try {
      final tracks = await getDownloadedTracks();
      for (final track in tracks) {
        final path = track.localPath;
        if (path == null || path.isEmpty) continue;
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (e) {
          debugPrint('[DownloadService] gagal menghapus ${track.title}: $e');
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_downloadKey);
    } catch (e) {
      debugPrint('[DownloadService] gagal menghapus semua unduhan: $e');
    }
  }
}
