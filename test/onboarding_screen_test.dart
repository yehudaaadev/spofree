import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_pribadi/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingScreen Walkthrough Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('menampilkan slide pertama dengan elemen visual dan teks yang benar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      expect(find.text('WAVE MUSIC'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);
      expect(find.text('Bebas Iklan.\nTanpa Perlu Akun.'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);
    });

    testWidgets('berpindah antar slide hingga slide ke-3 dan menekan Mulai Mendengarkan menyimpan preferensi', (tester) async {
      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            onComplete: () => completed = true,
          ),
        ),
      );

      // Slide 1 -> Slide 2
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Suara Jernih &\nFitur Profesional.'), findsOneWidget);

      // Slide 2 -> Slide 3
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Lisensi Nonkomersial &\nPenafian Hak Cipta.'), findsOneWidget);
      expect(find.text('David Yehuda Surbakti'), findsOneWidget);
      expect(find.text('Mulai Mendengarkan'), findsOneWidget);

      // Tekan Mulai Mendengarkan
      await tester.tap(find.text('Mulai Mendengarkan'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(OnboardingScreen.prefKey), isTrue);
    });

    testWidgets('tombol Lewati langsung menandai selesai', (tester) async {
      bool completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            onComplete: () => completed = true,
          ),
        ),
      );

      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(OnboardingScreen.prefKey), isTrue);
    });
  });
}
