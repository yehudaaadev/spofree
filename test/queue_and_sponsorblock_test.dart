import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_pribadi/models/track_model.dart';
import 'package:spotify_pribadi/providers/player_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerProvider Play Next & Features', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    final trackA = TrackModel(
      id: 'a',
      title: 'Lagu A',
      artist: 'Artis 1',
      album: 'Album 1',
      artworkUrl: '',
      durationMs: 180000,
    );
    final trackB = TrackModel(
      id: 'b',
      title: 'Lagu B',
      artist: 'Artis 2',
      album: 'Album 2',
      artworkUrl: '',
      durationMs: 200000,
    );
    final trackNext1 = TrackModel(
      id: 'next1',
      title: 'Lagu Next 1',
      artist: 'Artis 3',
      album: 'Album 3',
      artworkUrl: '',
      durationMs: 210000,
    );
    final trackNext2 = TrackModel(
      id: 'next2',
      title: 'Lagu Next 2',
      artist: 'Artis 4',
      album: 'Album 4',
      artworkUrl: '',
      durationMs: 190000,
    );

    test('playNext menyisipkan track persis setelah track saat ini', () {
      final provider = PlayerProvider();

      // Inisialisasi antrean awal [trackA, trackB]
      provider.addTracksToQueue([trackA, trackB]);
      expect(provider.queue.length, equals(2));

      // Putar Berikutnya trackNext1 lalu trackNext2
      provider.playNext(trackNext1);
      provider.playNext(trackNext2);

      expect(provider.queue.length, equals(4));
      expect(provider.userQueueCount, equals(2));
      expect(provider.queue[0].id, equals('next1'));
      expect(provider.queue[1].id, equals('next2'));
    });

    test('setBalance membatasi nilai antara -1.0 dan 1.0', () async {
      final provider = PlayerProvider();

      await provider.setBalance(0.5);
      expect(provider.balance, equals(0.5));

      await provider.setBalance(2.0);
      expect(provider.balance, equals(1.0));

      await provider.setBalance(-3.5);
      expect(provider.balance, equals(-1.0));
    });

    test('toggleSponsorBlock berganti status aktif/non-aktif', () async {
      final provider = PlayerProvider();
      expect(provider.sponsorBlockEnabled, isTrue);

      await provider.toggleSponsorBlock();
      expect(provider.sponsorBlockEnabled, isFalse);

      await provider.toggleSponsorBlock();
      expect(provider.sponsorBlockEnabled, isTrue);
    });
  });
}
