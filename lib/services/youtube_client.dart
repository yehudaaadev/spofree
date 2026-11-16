import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Klien YouTube tunggal yang dipakai seluruh aplikasi.
///
/// Sebelumnya setiap `MusicService`/`PlaylistImportService` membuat instance
/// `YoutubeExplode` sendiri yang tidak pernah ditutup, sehingga koneksi HTTP
/// menumpuk setiap kali widget dibangun ulang. Sekarang hanya ada satu
/// instance yang dibagikan dan hanya ditutup saat aplikasi keluar.
class YoutubeClient {
  YoutubeClient._();

  static final YoutubeClient instance = YoutubeClient._();

  final YoutubeExplode client = YoutubeExplode();

  void close() {
    client.close();
  }
}
