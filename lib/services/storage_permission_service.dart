import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Jembatan ke native Android untuk izin "Akses semua file"
/// (`MANAGE_EXTERNAL_STORAGE`).
///
/// Android 11+ menghapus perilaku `requestLegacyExternalStorage`, sehingga
/// penulisan ke folder publik (`/storage/emulated/0/...`) hanya berhasil bila
/// pengguna memberi izin tersebut. Channel ini dipakai untuk memeriksa dan
/// meminta izin tersebut, sekaligus tetap aman di platform lain.
class StoragePermissionService {
  StoragePermissionService._();

  static const MethodChannel _channel =
      MethodChannel('com.david.spotify_pribadi/storage');

  /// true bila platform tidak memerlukan izin tambahan (iOS, web, Android < 11).
  static bool get isPermissionSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Periksa apakah aplikasi sudah memiliki izin akses penyimpanan penuh.
  static Future<bool> hasPermission() async {
    if (!isPermissionSupported) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('hasPermission');
      // Jangan menganggap izin diberikan saat native tidak menjawab: ekspor
      // akan gagal tanpa pesan yang jelas.
      return granted ?? false;
    } catch (e) {
      debugPrint('[StoragePermissionService] hasPermission gagal: $e');
      return false;
    }
  }

  /// Minta izin akses penyimpanan penuh ke pengguna.
  ///
  /// Mengembalikan true bila izin diberikan (atau tidak diperlukan).
  static Future<bool> requestPermission() async {
    if (!isPermissionSupported) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } catch (e) {
      debugPrint('[StoragePermissionService] requestPermission gagal: $e');
      return false;
    }
  }

  /// Periksa lalu minta izin bila belum ada.
  static Future<bool> ensurePermission() async {
    if (await hasPermission()) return true;
    return requestPermission();
  }

  /// Minta izin notifikasi Android 13+ agar notifikasi pemutaran tampil.
  ///
  /// Notifikasi media tetap diizinkan sistem meski izin ini ditolak, tetapi
  /// kontrol pemutaran di laci notifikasi bisa tidak terlihat.
  static Future<bool> requestNotificationPermission() async {
    if (!isPermissionSupported) return true;
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return granted ?? false;
    } catch (e) {
      debugPrint(
        '[StoragePermissionService] requestNotificationPermission gagal: $e',
      );
      return false;
    }
  }
}
