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
    });

    test('AppUpdateInfo holds correct update payload', () {
      const info = AppUpdateInfo(
        hasUpdate: true,
        latestVersionCode: 5,
        latestVersionName: '1.2.0',
        releaseNotes: 'Fitur baru dan perbaikan bug.',
        downloadUrl: 'https://gitlab.com/test.apk',
      );

      expect(info.hasUpdate, isTrue);
      expect(info.latestVersionCode, equals(5));
      expect(info.latestVersionName, equals('1.2.0'));
      expect(info.releaseNotes, equals('Fitur baru dan perbaikan bug.'));
      expect(info.downloadUrl, equals('https://gitlab.com/test.apk'));
    });

    test('UpdateService has valid versioning constants', () {
      expect(UpdateService.currentVersionCode, isPositive);
      expect(UpdateService.currentVersionName, isNotEmpty);
      expect(UpdateService.instance, isNotNull);
    });
  });
}
