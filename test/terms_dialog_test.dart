import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spotify_pribadi/widgets/terms_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TermsDisclaimerDialog Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('menampilkan dialog jika belum pernah disetujui', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => TermsDisclaimerDialog.checkAndShow(context),
                  child: const Text('Buka'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Ketentuan & Penafian'), findsOneWidget);
      expect(find.text('Wave Music oleh David Yehuda Surbakti'), findsOneWidget);
      expect(find.text('Pengembang & Tujuan Aplikasi'), findsOneWidget);
      expect(find.text('Lisensi Perangkat Lunak (MIT License)'), findsOneWidget);
      expect(find.text('Sumber Aliran Konten'), findsOneWidget);
      expect(find.text('Saya Mengerti & Setuju'), findsOneWidget);

      await tester.tap(find.text('Saya Mengerti & Setuju'));
      await tester.pumpAndSettle();

      expect(find.text('Ketentuan & Penafian'), findsNothing);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(TermsDisclaimerDialog.prefKey), isTrue);
    });

    testWidgets('tidak menampilkan dialog jika sudah pernah disetujui sebelumnya', (tester) async {
      SharedPreferences.setMockInitialValues({
        TermsDisclaimerDialog.prefKey: true,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => TermsDisclaimerDialog.checkAndShow(context),
                  child: const Text('Buka'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();

      expect(find.text('Ketentuan & Penafian'), findsNothing);
    });
  });
}
