import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/services/update_service.dart';

void main() {
  group('UpdateService & AppUpdateInfo Tests', () {
    test('AppUpdateInfo.noUpdate initializes with default empty state', () {
      const info = AppUpdateInfo.noUpdate();
      expect(info.hasUpdate, isFalse);
      expect(info.latestVersionCode, equals(0));
      expect(info.latestVersionName, isEmpty);
      expect(info.releaseNotes, isEmpty);
      expect(info.downloadUrl, isEmpty);
      expect(info.checksumUrl, isEmpty);
    });

    test('AppUpdateInfo holds correct update payload', () {
      const info = AppUpdateInfo(
        hasUpdate: true,
        latestVersionCode: 5,
        latestVersionName: '1.2.0',
        releaseNotes: 'Fitur baru dan perbaikan bug.',
        downloadUrl: 'https://github.com/yehudaaadev/spofree/releases/latest',
        checksumUrl:
            'https://github.com/yehudaaadev/spofree/releases/latest/download/SHA256SUMS.txt',
      );

      expect(info.hasUpdate, isTrue);
      expect(info.latestVersionCode, equals(5));
      expect(info.latestVersionName, equals('1.2.0'));
      expect(info.releaseNotes, equals('Fitur baru dan perbaikan bug.'));
      expect(
        info.downloadUrl,
        equals('https://github.com/yehudaaadev/spofree/releases/latest'),
      );
      expect(info.checksumUrl, contains('SHA256SUMS.txt'));
    });

    test('UpdateService has valid versioning constants', () {
      expect(UpdateService.currentVersionCode, isPositive);
      expect(UpdateService.currentVersionName, isNotEmpty);
      expect(UpdateService.instance, isNotNull);
      expect(UpdateService.releasePageUrl, contains('github.com'));
    });
  });

  group('UpdateService.isTrustedReleaseUrl', () {
    test('menerima halaman rilis, aset, raw, dan API repo resmi', () {
      expect(
        UpdateService.isTrustedReleaseUrl(
          'https://github.com/yehudaaadev/spofree/releases/latest',
        ),
        isTrue,
      );
      expect(
        UpdateService.isTrustedReleaseUrl(
          'https://github.com/yehudaaadev/spofree/releases/download/v1.1.0/WaveMusic-arm64-v8a.apk',
        ),
        isTrue,
      );
      expect(
        UpdateService.isTrustedReleaseUrl(
          'https://github.com/yehudaaadev/spofree/releases/latest/download/SHA256SUMS.txt',
        ),
        isTrue,
      );
      expect(
        UpdateService.isTrustedReleaseUrl(
          'https://raw.githubusercontent.com/yehudaaadev/spofree/main/version.json',
        ),
        isTrue,
      );
      expect(
        UpdateService.isTrustedReleaseUrl(
          'https://api.github.com/repos/yehudaaadev/spofree/releases/latest',
        ),
        isTrue,
      );
    });

    test('menolak domain, skema, dan repo lain', () {
      expect(
        UpdateService.isTrustedReleaseUrl(
          'http://github.com/yehudaaadev/spofree/releases/latest',
        ),
        isFalse,
      );
      expect(
        UpdateService.isTrustedReleaseUrl(
          'https://example.com/yehudaaadev/spofree/releases/latest',
        ),
        isFalse,
      );
      expect(
        UpdateService.isTrustedReleaseUrl(
          'https://gitlab.com/davidyehudaaa/spotify-gratis/-/releases',
        ),
        isFalse,
      );
      expect(
        UpdateService.isTrustedReleaseUrl(
          'https://github.com/orang-lain/spofree/releases/latest',
        ),
        isFalse,
      );
      expect(
        UpdateService.isTrustedReleaseUrl(
          'https://github.com/yehudaaadev/spofree-palsu/releases/latest',
        ),
        isFalse,
      );
      expect(
        UpdateService.isTrustedReleaseUrl(
          'https://raw.githubusercontent.com/orang-lain/spofree/main/version.json',
        ),
        isFalse,
      );
      expect(UpdateService.isTrustedReleaseUrl(''), isFalse);
    });
  });

  group('UpdateService.shouldOfferUpdate', () {
    test('mengabaikan offset versionCode APK per-ABI', () {
      // arm64-v8a v1.2.0 terpasang memakai versionCode 2007, sedangkan
      // version.json memakai versionCode dasar 7.
      expect(
        UpdateService.shouldOfferUpdate(
          latestCode: 7,
          latestName: '1.2.0',
          currentCode: 2007,
          currentName: '1.1.0',
        ),
        isTrue,
      );
      expect(
        UpdateService.shouldOfferUpdate(
          latestCode: 7,
          latestName: '1.2.0',
          currentCode: 2007,
          currentName: '1.2.0',
        ),
        isFalse,
      );
      expect(
        UpdateService.shouldOfferUpdate(
          latestCode: 6,
          latestName: '1.1.0',
          currentCode: 2007,
          currentName: '1.2.0',
        ),
        isFalse,
      );
    });

    test('jatuh ke versionCode bila nama versi tidak valid', () {
      expect(
        UpdateService.shouldOfferUpdate(
          latestCode: 8,
          latestName: '',
          currentCode: 7,
          currentName: '1.2.0',
        ),
        isTrue,
      );
      expect(
        UpdateService.shouldOfferUpdate(
          latestCode: 7,
          latestName: 'abc',
          currentCode: 7,
          currentName: '1.2.0',
        ),
        isFalse,
      );
    });
  });

  group('UpdateService.compareVersionNames', () {
    test('membandingkan inti numerik semver', () {
      expect(
        UpdateService.compareVersionNames('1.2.0', '1.1.0'),
        greaterThan(0),
      );
      expect(
        UpdateService.compareVersionNames('1.1.0', '1.2.0'),
        lessThan(0),
      );
      expect(UpdateService.compareVersionNames('1.2.0', '1.2.0'), 0);
      expect(
        UpdateService.compareVersionNames('1.10.0', '1.9.9'),
        greaterThan(0),
      );
      expect(UpdateService.compareVersionNames('2.0', '1.9.9'), greaterThan(0));
      expect(UpdateService.compareVersionNames('1.2', '1.2.0'), 0);
      expect(UpdateService.compareVersionNames('1.2.0+7', '1.2.0'), 0);
    });

    test('mengembalikan null untuk nama yang tidak bisa diurai', () {
      expect(UpdateService.compareVersionNames('', '1.0.0'), isNull);
      expect(UpdateService.compareVersionNames('1.0.0', 'abc'), isNull);
      expect(UpdateService.compareVersionNames('1..0', '1.0.0'), isNull);
    });
  });
}
