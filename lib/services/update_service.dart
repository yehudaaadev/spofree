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

  /// Membandingkan dua versi numerik seperti `1.2.0` vs `1.10.0`.
  ///
  /// Mengembalikan nilai > 0 bila [a] lebih baru, < 0 bila lebih lama, 0 bila
  /// sama, dan null bila salah satu nama tidak bisa diurai. Suffix seperti
  /// `-beta` atau `+7` diabaikan karena hanya inti numerik yang dibandingkan.
  static int? compareVersionNames(String a, String b) {
    List<int>? parse(String value) {
      final core = value.split('+').first.split('-').first.trim();
      if (core.isEmpty) return null;
      final numbers = <int>[];
      for (final part in core.split('.')) {
        final number = int.tryParse(part.trim());
        if (number == null) return null;
        numbers.add(number);
      }
      return numbers;
    }

    final av = parse(a);
    final bv = parse(b);
    if (av == null || bv == null) return null;

    final length = av.length > bv.length ? av.length : bv.length;
    for (var i = 0; i < length; i++) {
      final ai = i < av.length ? av[i] : 0;
      final bi = i < bv.length ? bv[i] : 0;
      if (ai != bi) return ai.compareTo(bi);
    }
    return 0;
  }

  /// Menentukan apakah rilis [latestName]/[latestCode] lebih baru.
  ///
  /// APK `--split-per-abi` menambahkan offset ke `versionCode` (1000 untuk
  /// armeabi-v7a, 2000 untuk arm64-v8a, 4000 untuk x86_64). Karena itu
  /// `versionCode` di `version.json` tidak bisa dibandingkan langsung dengan
  /// `versionCode` perangkat. Nama versi dipakai lebih dulu; `versionCode`
  /// hanya cadangan bila nama tidak valid.
  static bool shouldOfferUpdate({
    required int latestCode,
    required String latestName,
    required int currentCode,
    required String currentName,
  }) {
    final comparison = compareVersionNames(latestName, currentName);
    if (comparison == null) return latestCode > currentCode;
    if (comparison != 0) return comparison > 0;
    // Nama sama: hanya tawarkan bila build number memang lebih tinggi.
    return latestCode > currentCode;
  }

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

        if (shouldOfferUpdate(
          latestCode: latestCode,
          latestName: latestName,
          currentCode: currentVersionCode,
          currentName: currentVersionName,
        )) {
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
