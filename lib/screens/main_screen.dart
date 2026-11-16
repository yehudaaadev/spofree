import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import 'home_tab.dart';
import 'library_tab.dart';
import 'search_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  /// Error yang sudah pernah ditampilkan, agar tidak muncul dua kali.
  String? _shownError;

  final List<Widget> _tabs = const [
    HomeTab(),
    SearchTab(),
    LibraryTab(),
  ];

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;
    final info = await UpdateService.instance.checkForUpdate();
    if (info.hasUpdate && mounted) {
      _showUpdateBanner(info);
    }
  }

  void _showUpdateBanner(AppUpdateInfo info) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF282828),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versi baru ${info.latestVersionName} tersedia',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            if (info.releaseNotes.isNotEmpty)
              Text(
                info.releaseNotes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
          ],
        ),
        action: SnackBarAction(
          label: 'Unduh',
          textColor: AppTheme.primaryGreen,
          onPressed: () => UpdateService.instance.openDownloadUrl(info.downloadUrl),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Koleksi dimuat ulang saat tab Koleksi dibuka agar data lokal yang
    // baru saja berubah (disukai/playlist) selalu tampil akurat.
    context.read<LibraryProvider>();

    final player = context.watch<PlayerProvider>();
    final error = player.errorMessage;

    // Error playback harus terlihat dari mana pun lagu diputar, bukan hanya
    // saat panel pemutar penuh sedang dibuka.
    if (error != null && error != _shownError) {
      _shownError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.surface,
            duration: const Duration(seconds: 6),
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Coba Lagi',
              textColor: AppTheme.primaryGreen,
              onPressed: () => player.retryCurrentTrack(),
            ),
          ),
        );
        player.clearError();
      });
    } else if (error == null) {
      _shownError = null;
    }

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (_currentIndex != index) {
            HapticFeedback.selectionClick();
          }
          setState(() => _currentIndex = index);
          if (index == 2) {
            context.read<LibraryProvider>().refreshLibrary();
          }
        },
        backgroundColor: AppTheme.background,
        selectedItemColor: Colors.white,
        unselectedItemColor: AppTheme.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Cari',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music),
            label: 'Koleksi',
          ),
        ],
      ),
    );
  }
}
