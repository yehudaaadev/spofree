import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class PlaybackOptionsSheet extends StatelessWidget {
  const PlaybackOptionsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const PlaybackOptionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final qualities = [
      'Hemat (64 kbps - Sangat Hemat Kuota)',
      'Standar (128 kbps - Standar Spotify)',
      'Tinggi (HQ 160-256 kbps - Kualitas Seimbang)',
      'Maksimal (320 kbps - Kualitas Tertinggi HQ)',
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pengaturan Audio Premium',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AppTheme.divider, height: 16),

              // Autoplay Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'AUTOPLAY LAGU SERUPA',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Lanjutkan memutar musik serupa secara otomatis saat antrean habis',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: player.autoplayEnabled,
                    activeTrackColor: AppTheme.primaryGreen,
                    onChanged: (val) => player.setAutoplay(val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.divider, height: 1),
              const SizedBox(height: 16),

              // Playback Speed
              const Text(
                'KECEPATAN PEMUTARAN',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: speeds.map((speed) {
                  final isSelected = (player.playbackSpeed - speed).abs() < 0.05;
                  return ChoiceChip(
                    label: Text('${speed}x'),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryGreen,
                    backgroundColor: AppTheme.card,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (_) => player.setPlaybackSpeed(speed),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Crossfade
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CROSSFADE TRANSISI',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    player.crossfadeSeconds == 0
                        ? 'Mati'
                        : '${player.crossfadeSeconds} detik',
                    style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Transisi halus antar-lagu tanpa jeda sunyi.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              Slider(
                value: player.crossfadeSeconds.toDouble(),
                min: 0.0,
                max: 12.0,
                divisions: 6,
                activeColor: AppTheme.primaryGreen,
                inactiveColor: Colors.white12,
                onChanged: (val) => player.setCrossfadeSeconds(val.round()),
              ),

              const SizedBox(height: 16),

              // Pitch Shift
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'NADA KUNCI (PITCH SHIFT)',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    player.pitchSemitones == 0
                        ? 'Standar'
                        : '${player.pitchSemitones > 0 ? "+" : ""}${player.pitchSemitones} st',
                    style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Slider(
                value: player.pitchSemitones.toDouble(),
                min: -6.0,
                max: 6.0,
                divisions: 12,
                activeColor: AppTheme.primaryGreen,
                inactiveColor: Colors.white12,
                onChanged: (val) => player.setPitchSemitones(val.round()),
              ),

              const SizedBox(height: 8),

              // Preset mode
              const Text(
                'MODE EFEK INSTAN',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'Normal',
                  'Karaoke Vokal Rendah',
                  'Karaoke Vokal Tinggi',
                  'Slowed + Reverb',
                  'Nightcore / Speed Up',
                ].map((p) {
                  final isSelected = player.audioPreset == p;
                  return ActionChip(
                    label: Text(p),
                    backgroundColor: isSelected ? AppTheme.primaryGreen : AppTheme.card,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 11,
                    ),
                    onPressed: () => player.applyAudioPreset(p),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Audio Quality
              const Text(
                'KUALITAS STREAMING AUDIO',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...qualities.map((q) {
                final isSelected = player.audioQuality.startsWith(q.split(' ').first);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    q,
                    style: TextStyle(
                      color: isSelected ? AppTheme.primaryGreen : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: AppTheme.primaryGreen, size: 18)
                      : null,
                  onTap: () => player.setAudioQuality(q),
                );
              }),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
