import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Status koneksi jaringan untuk kebijakan "unduh hanya via Wi-Fi".
class NetworkStatusService {
  NetworkStatusService._();

  static const MethodChannel _channel =
      MethodChannel('com.david.spotify_pribadi/storage');

  /// True bila perangkat sedang memakai Wi-Fi/Ethernet.
  ///
  /// Di desktop dan web tidak ada batasan kuota seluler, jadi selalu true.
  /// Bila native tidak menjawab, unduhan tidak diblokir (fail-open) agar
  /// pengguna tidak terjebak tanpa bisa mengunduh.
  static Future<bool> isOnWifi() async {
    if (kIsWeb) return true;
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final value = await _channel.invokeMethod<bool>('isOnWifi');
      return value ?? true;
    } catch (e) {
      debugPrint('[NetworkStatusService] cek Wi-Fi gagal: $e');
      return true;
    }
  }
}
