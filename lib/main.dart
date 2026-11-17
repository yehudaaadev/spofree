import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/library_provider.dart';
import 'providers/player_provider.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'com.david.spotify_pribadi.channel.audio',
        androidNotificationChannelName: 'Pemutaran Musik',
        androidNotificationOngoing: true,
      );
    } catch (e) {
      debugPrint('[main] JustAudioBackground init dilewati: $e');
    }
  }

  // Sesi audio "musik": pemutar mengambil fokus audio, meredam suara aplikasi
  // lain (mis. navigasi), dan berhenti saat headphone dicabut.
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e) {
    debugPrint('[main] konfigurasi audio session gagal: $e');
  }

  final prefs = await SharedPreferences.getInstance();
  final hasAcceptedTerms = prefs.getBool('has_accepted_terms_v1') ?? false;

  runApp(SpotifyCloneApp(
    initialHome: hasAcceptedTerms ? const MainScreen() : const OnboardingScreen(),
  ));
}

class SpotifyCloneApp extends StatelessWidget {
  final Widget initialHome;

  const SpotifyCloneApp({
    super.key,
    this.initialHome = const MainScreen(),
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: MaterialApp(
        title: 'Wave Music',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: initialHome,
      ),
    );
  }
}
