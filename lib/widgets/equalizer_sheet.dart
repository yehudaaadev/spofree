import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';

class EqualizerSheet extends StatelessWidget {
  const EqualizerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Equalizer & Efek Audio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: player.equalizerEnabled,
                  activeThumbColor: const Color(0xFF1DB954),
                  activeTrackColor: const Color(0xFF1DB954).withValues(alpha: 0.4),
                  onChanged: (val) => player.setEqualizerEnabled(val),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Preset Suara',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PlayerProvider.equalizerPresets.keys.map((preset) {
                final isSelected = player.equalizerPreset == preset;
                return ChoiceChip(
                  label: Text(preset),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1DB954),
                  backgroundColor: const Color(0xFF282828),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: player.equalizerEnabled
                      ? (_) => player.setEqualizerPreset(preset)
                      : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bass Boost',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(player.bassBoostGain * 100).round()}%',
                  style: const TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: player.bassBoostGain,
              min: 0.0,
              max: 1.0,
              activeColor: const Color(0xFF1DB954),
              inactiveColor: Colors.white12,
              onChanged: player.equalizerEnabled
                  ? (val) => player.setBassBoost(val)
                  : null,
            ),
            const Divider(color: Colors.white10, height: 32),
            const Text(
              'Pitch Shift & Mode Vokal',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transpose Nada Kunci',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  player.pitchSemitones == 0
                      ? 'Standar (0)'
                      : '${player.pitchSemitones > 0 ? "+" : ""}${player.pitchSemitones} Semitone',
                  style: const TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: player.pitchSemitones.toDouble(),
              min: -6.0,
              max: 6.0,
              divisions: 12,
              activeColor: const Color(0xFF1DB954),
              inactiveColor: Colors.white12,
              onChanged: (val) => player.setPitchSemitones(val.round()),
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
                  backgroundColor: isSelected ? const Color(0xFF1DB954) : const Color(0xFF282828),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                  onPressed: () => player.applyAudioPreset(p),
                );
              }).toList(),
            ),
            const Divider(color: Colors.white10, height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Crossfade (Transisi Antar-Lagu)',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  player.crossfadeSeconds == 0
                      ? 'Mati'
                      : '${player.crossfadeSeconds} detik',
                  style: const TextStyle(color: Color(0xFF1DB954), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Menghilangkan jeda sunyi antar lagu dengan transisi mulus seperti DJ.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Slider(
              value: player.crossfadeSeconds.toDouble(),
              min: 0.0,
              max: 12.0,
              divisions: 6,
              activeColor: const Color(0xFF1DB954),
              inactiveColor: Colors.white12,
              onChanged: (val) => player.setCrossfadeSeconds(val.round()),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
