import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/services/sponsorblock_service.dart';

void main() {
  group('SponsorBlock Tests', () {
    test('SponsorCategory memetakan string kategori dengan tepat', () {
      expect(
        SponsorCategory.fromString('music_offtopic'),
        equals(SponsorCategory.musicOfftopic),
      );
      expect(
        SponsorCategory.fromString('sponsor'),
        equals(SponsorCategory.sponsor),
      );
      expect(
        SponsorCategory.fromString('intro'),
        equals(SponsorCategory.intro),
      );
      expect(
        SponsorCategory.fromString('outro'),
        equals(SponsorCategory.outro),
      );
      expect(
        SponsorCategory.fromString('unknown_category'),
        equals(SponsorCategory.other),
      );
    });

    test('SponsorSegment mendeteksi posisi waktu yang dicakup', () {
      const segment = SponsorSegment(
        category: SponsorCategory.musicOfftopic,
        start: Duration(seconds: 10),
        end: Duration(seconds: 35),
        uuid: 'test-uuid-1',
      );

      expect(segment.duration, equals(const Duration(seconds: 25)));
      expect(segment.durationString, equals('25 detik'));
      expect(segment.contains(const Duration(seconds: 9)), isFalse);
      expect(segment.contains(const Duration(seconds: 10)), isTrue);
      expect(segment.contains(const Duration(seconds: 20)), isTrue);
      expect(segment.contains(const Duration(seconds: 35)), isFalse);
    });

    test('SponsorSegment format durasi lebih dari 1 menit', () {
      const segment = SponsorSegment(
        category: SponsorCategory.intro,
        start: Duration(seconds: 0),
        end: Duration(seconds: 75),
        uuid: 'test-uuid-2',
      );

      expect(segment.durationString, equals('1 m 15s'));
    });
  });
}
