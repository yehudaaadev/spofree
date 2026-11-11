import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class SleepTimerDialog extends StatelessWidget {
  const SleepTimerDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SleepTimerDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pengatur Waktu Tidur',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (player.hasActiveSleepTimer)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Aktif',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: AppTheme.divider, height: 1),

            _buildOption(
              context,
              title: '5 menit',
              duration: const Duration(minutes: 5),
              onTap: () {
                player.setSleepTimer(const Duration(minutes: 5));
                Navigator.pop(context);
              },
            ),
            _buildOption(
              context,
              title: '15 menit',
              duration: const Duration(minutes: 15),
              onTap: () {
                player.setSleepTimer(const Duration(minutes: 15));
                Navigator.pop(context);
              },
            ),
            _buildOption(
              context,
              title: '30 menit',
              duration: const Duration(minutes: 30),
              onTap: () {
                player.setSleepTimer(const Duration(minutes: 30));
                Navigator.pop(context);
              },
            ),
            _buildOption(
              context,
              title: '45 menit',
              duration: const Duration(minutes: 45),
              onTap: () {
                player.setSleepTimer(const Duration(minutes: 45));
                Navigator.pop(context);
              },
            ),
            _buildOption(
              context,
              title: '1 jam',
              duration: const Duration(hours: 1),
              onTap: () {
                player.setSleepTimer(const Duration(hours: 1));
                Navigator.pop(context);
              },
            ),
            _buildOption(
              context,
              title: 'Selesai lagu ini',
              duration: null,
              isSelected: player.sleepAtSongEnd,
              onTap: () {
                player.setSleepTimer(null, atSongEnd: true);
                Navigator.pop(context);
              },
            ),

            if (player.hasActiveSleepTimer)
              ListTile(
                title: const Text(
                  'Matikan Timer',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                leading: const Icon(Icons.timer_off, color: Colors.redAccent),
                onTap: () {
                  player.setSleepTimer(null);
                  Navigator.pop(context);
                },
              ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String title,
    required Duration? duration,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryGreen : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppTheme.primaryGreen, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
