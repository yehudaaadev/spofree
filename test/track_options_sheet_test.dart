import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_pribadi/models/track_model.dart';
import 'package:spotify_pribadi/providers/library_provider.dart';
import 'package:spotify_pribadi/providers/player_provider.dart';
import 'package:spotify_pribadi/widgets/track_options_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTrack = TrackModel(
    id: 'test_123',
    title: 'Magnolia',
    artist: 'Playboi Carti',
    album: 'Playboi Carti',
    artworkUrl: '',
    durationMs: 181000,
  );

  group('TrackOptionsSheet Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('menampilkan opsi lengkap: Like, Download, Playlist, Play Next, dan Antrean', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LibraryProvider()),
            ChangeNotifierProvider(create: (_) => PlayerProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TrackOptionsSheet(track: testTrack),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memverifikasi header lagu
      expect(find.text('Magnolia'), findsOneWidget);
      expect(find.text('Playboi Carti'), findsOneWidget);

      // Memverifikasi kelima opsi pintasan
      expect(find.text('Sukai Lagu Ini'), findsOneWidget);
      expect(find.text('Download Lagu (Offline)'), findsOneWidget);
      expect(find.text('Tambah ke Playlist'), findsOneWidget);
      expect(find.text('Putar Berikutnya (Play Next)'), findsOneWidget);
      expect(find.text('Tambah ke Antrean'), findsOneWidget);
    });

    testWidgets('mengetuk Sukai Lagu Ini menambahkan lagu ke daftar liked', (tester) async {
      final library = LibraryProvider();
      final player = PlayerProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: library),
            ChangeNotifierProvider.value(value: player),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TrackOptionsSheet(track: testTrack),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(library.isLiked(testTrack.id), isFalse);

      await tester.tap(find.text('Sukai Lagu Ini'));
      await tester.pumpAndSettle();

      expect(library.isLiked(testTrack.id), isTrue);
    });
  });
}
