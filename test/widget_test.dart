import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_pribadi/models/track_model.dart';

void main() {
  test('TrackModel formatting and serialization test', () {
    const track = TrackModel(
      id: '123',
      title: 'Test Song',
      artist: 'Test Artist',
      album: 'Test Album',
      artworkUrl: 'https://example.com/cover.jpg',
      durationMs: 185000,
    );

    expect(track.formattedDuration, '3:05');
    final map = track.toMap();
    final reconstructed = TrackModel.fromMap(map);
    expect(reconstructed.id, '123');
    expect(reconstructed.title, 'Test Song');
    expect(reconstructed.artist, 'Test Artist');
  });
}
