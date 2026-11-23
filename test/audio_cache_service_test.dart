import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/services/audio_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioCacheService Tests', () {
    test('memiliki batas maksimal cache 300 MB', () {
      expect(AudioCacheService.maxCacheSizeBytes, equals(300 * 1024 * 1024));
    });

    test('getCachedAudioFile mengembalikan null untuk id lagu yang belum dicache', () async {
      final file = await AudioCacheService.instance.getCachedAudioFile('non_existent_id');
      expect(file, isNull);
    });

    test('instance adalah singleton valid', () {
      final inst1 = AudioCacheService.instance;
      final inst2 = AudioCacheService.instance;
      expect(identical(inst1, inst2), isTrue);
    });

    test('cacheKeyFor stabil dan aman dipakai sebagai nama berkas', () {
      final a = AudioCacheService.cacheKeyFor('sp_spotify:track:123');
      final b = AudioCacheService.cacheKeyFor('sp_spotify:track:123');
      expect(a, equals(b));
      expect(a, matches(RegExp(r'^[a-f0-9]{16}$')));
      expect(a.contains(':'), isFalse);
    });

    test('cacheKeyFor membedakan kualitas audio', () {
      final standard = AudioCacheService.cacheKeyFor(
        'track-1',
        quality: 'Standar',
      );
      final high = AudioCacheService.cacheKeyFor(
        'track-1',
        quality: 'Tinggi',
      );
      expect(standard, isNot(equals(high)));
    });
  });
}
