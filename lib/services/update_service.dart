import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Informasi status pembaruan aplikasi.
class AppUpdateInfo {
  final bool hasUpdate;
  final int latestVersionCode;
  final String latestVersionName;
  final String releaseNotes;
  final String downloadUrl;

  const AppUpdateInfo({
    required this.hasUpdate,
    this.latestVersionCode = 0,
    this.latestVersionName = '',
    this.releaseNotes = '',
    this.downloadUrl = '',
  });

  const AppUpdateInfo.noUpdate()
      : hasUpdate = false,
        latestVersionCode = 0,
        latestVersionName = '',
        releaseNotes = '',
        downloadUrl = '';
}

/// Layanan pengecekan pembaruan APK mandiri via GitLab.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const int currentVersionCode = 3;
  static const String currentVersionName = '1.0.2';

  static const MethodChannel _channel =
      MethodChannel('com.david.spotify_pribadi/storage');

  static const String _versionUrl =
      'https://gitlab.com/davidyehudaaa/spotify-gratis/-/raw/main/version.json';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {'Cache-Control': 'no-cache'},
    ),
  );

  /// Memeriksa apakah ada versi APK yang lebih baru di repository GitLab.
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
        final downloadUrl = data['downloadUrl'] as String? ?? '';

        if (latestCode > currentVersionCode) {
          return AppUpdateInfo(
            hasUpdate: true,
            latestVersionCode: latestCode,
            latestVersionName: latestName,
            releaseNotes: notes,
            downloadUrl: downloadUrl,
          );
        }
      }
    } catch (e) {
      debugPrint('[UpdateService] periksa pembaruan gagal: $e');
    }
    return const AppUpdateInfo.noUpdate();
  }

  /// Membuka tautan unduhan APK di browser default pengguna.
  Future<bool> openDownloadUrl(String url) async {
    if (url.isEmpty) return false;
    try {
      final result = await _channel.invokeMethod<bool>('openUrl', {'url': url});
      return result ?? false;
    } catch (e) {
      debugPrint('[UpdateService] openDownloadUrl gagal: $e');
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
