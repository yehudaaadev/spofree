import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Informasi status pembaruan aplikasi.
class AppUpdateInfo {
  final bool hasUpdate;
  final int latestVersionCode;
  final String latestVersionName;
  final String releaseNotes;
  final String downloadUrl;

  /// Tautan berkas checksum SHA-256 untuk APK rilis (opsional).
  final String checksumUrl;

  const AppUpdateInfo({
    required this.hasUpdate,
    this.latestVersionCode = 0,
    this.latestVersionName = '',
    this.releaseNotes = '',
    this.downloadUrl = '',
    this.checksumUrl = '',
  });

  const AppUpdateInfo.noUpdate()
      : hasUpdate = false,
        latestVersionCode = 0,
        latestVersionName = '',
        releaseNotes = '',
        downloadUrl = '',
        checksumUrl = '';
}

/// Layanan pengecekan pembaruan aplikasi via GitHub Releases.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Nilai cadangan; diperbarui dari package info saat aplikasi berjalan.
  static int currentVersionCode = 7;
  static String currentVersionName = '1.2.0';
  static bool _versionLoaded = false;

  /// Membaca versi dari package info agar tidak melenceng dari pubspec.
  static Future<void> loadVersionInfo() async {
    if (_versionLoaded) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final code = int.tryParse(info.buildNumber);
      if (code != null && code > 0) currentVersionCode = code;
      if (info.version.isNotEmpty) currentVersionName = info.version;
      _versionLoaded = true;
    } catch (e) {
      debugPrint('[UpdateService] gagal membaca versi aplikasi: $e');
    }
  }

  static const MethodChannel _channel =
      MethodChannel('com.david.spotify_pribadi/storage');

  static const String _versionUrl =
      'https://raw.githubusercontent.com/yehudaaadev/spofree/main/version.json';

  /// Halaman rilis utama, dipakai sebagai cadangan bila metadata tidak memuat
  /// tautan unduhan yang sah.
  static const String releasePageUrl =
      'https://github.com/yehudaaadev/spofree/releases/latest';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {'Cache-Control': 'no-cache'},
    ),
  );

  /// Memeriksa apakah ada versi yang lebih baru di GitHub Releases.
  Future<AppUpdateInfo> checkForUpdate() async {
    try {
      final response = await _dio.get(_versionUrl);
      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> data = response.data is String
            ? json.decode(response.data as String) as Map<String, dynamic>
            : (response.data as Map<String, dynamic>);

        final latestCode = (data['versionCode'] as num?)?.toInt() ?? 0;
        final latestName = data['versionName'] as String? ?? '';
        final notes = data['releaseNotes'] as String? ?? '';
        final rawDownloadUrl = data['downloadUrl'] as String? ?? '';
        final rawChecksumUrl = data['checksumUrl'] as String? ?? '';
        await loadVersionInfo();

        // Hanya tautan HTTPS dari repositori resmi yang boleh dibuka. Ini
        // mencegah pengalihan ke domain lain bila version.json disalahgunakan.
        final downloadUrl = isTrustedReleaseUrl(rawDownloadUrl)
            ? rawDownloadUrl
            : releasePageUrl;
        final checksumUrl = isTrustedReleaseUrl(rawChecksumUrl)
            ? rawChecksumUrl
            : '';

        if (latestCode > currentVersionCode) {
          return AppUpdateInfo(
            hasUpdate: true,
            latestVersionCode: latestCode,
            latestVersionName: latestName,
            releaseNotes: notes,
            downloadUrl: downloadUrl,
            checksumUrl: checksumUrl,
          );
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] periksa pembaruan gagal: $e');
    }
    return const AppUpdateInfo.noUpdate();
  }

  /// Hanya izinkan HTTPS ke repositori rilis resmi.
  ///
  /// Menerima halaman rilis, aset rilis, berkas mentah di branch `main`, dan
  /// endpoint API untuk repo [githubRepo]. Domain dan awalan path harus persis
  /// milik repo ini agar metadata yang disalahgunakan tidak bisa mengalihkan
  /// pengguna ke situs lain.
  static const String githubOwner = 'yehudaaadev';
  static const String githubRepo = 'spofree';

  static bool isTrustedReleaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;

    final ownerRepo = '/$githubOwner/$githubRepo/';
    switch (uri.host) {
      case 'github.com':
        return uri.path.startsWith(ownerRepo);
      case 'raw.githubusercontent.com':
        return uri.path.startsWith('/$githubOwner/$githubRepo/');
      case 'api.github.com':
        return uri.path.startsWith('/repos/$githubOwner/$githubRepo/');
      default:
        return false;
    }
  }

  /// Membuka halaman rilis di browser default pengguna.
  Future<bool> openReleasePage(String url) async {
    if (!isTrustedReleaseUrl(url)) return false;
    try {
      final result = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return result ?? false;
    } catch (e) {
      debugPrint('[UpdateService] openReleasePage gagal: $e');
      return false;
    }
  }

  /// Membuka halaman pengaturan optimasi baterai (Doze mode) perangkat.
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatterySettings');
    } catch (e) {
      debugPrint('[UpdateService] openBatteryOptimizationSettings gagal: $e');
    }
  }
}
