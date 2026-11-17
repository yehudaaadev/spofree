import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/models/track_model.dart';
import 'package:spotify_pribadi/services/music_service.dart';

void main() {
  group('ArtistProfile & Model Tests', () {
    test('ArtistProfile menginisialisasi properti profil artis dengan benar', () {
      const topTrack = TrackModel(
        id: '123',
        title: 'Hati-Hati di Jalan',
        artist: 'Tulus',
        album: 'Manusia',
        artworkUrl: 'https://example.com/cover.jpg',
        durationMs: 242000,
      );

      const profile = ArtistProfile(
        id: 456,
        name: 'Tulus',
        pictureUrl: 'https://example.com/artist.jpg',
        fansCount: 4500000,
        topTracks: [topTrack],
      );

      expect(profile.id, equals(456));
      expect(profile.name, equals('Tulus'));
      expect(profile.pictureUrl, equals('https://example.com/artist.jpg'));
      expect(profile.fansCount, equals(4500000));
      expect(profile.topTracks.length, equals(1));
      expect(profile.topTracks.first.title, equals('Hati-Hati di Jalan'));
    });
  });
}
