import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class QueueSheet extends StatelessWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final queue = player.queue;
    final currentTrack = player.currentTrack;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Antrean Lagu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    if (queue.length > 1)
                      TextButton(
                        onPressed: () => player.clearQueue(),
                        child: const Text(
                          'Kosongkan',
                          style: TextStyle(color: AppTheme.primaryGreen, fontSize: 13),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: AppTheme.divider, height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                // Now Playing Section
                if (currentTrack != null) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 6),
                    child: Text(
                      'SEDANG DIPUTAR',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: currentTrack.artworkUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: currentTrack.artworkUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => Container(color: AppTheme.card),
                              errorWidget: (_, _, _) => Container(
                                color: AppTheme.card,
                                child: const Icon(Icons.music_note, size: 20, color: AppTheme.textSecondary),
                              ),
                            )
                          : Container(width: 44, height: 44, color: AppTheme.card),
                    ),
                    title: Text(
                      currentTrack.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    subtitle: Text(
                      currentTrack.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    trailing: const Icon(Icons.volume_up, color: AppTheme.primaryGreen, size: 20),
                  ),
                  const SizedBox(height: 12),
                ],

                // Upcoming Section
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 6),
                  child: Text(
                    'BERIKUTNYA DALAM ANTREAN',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                if (queue.isEmpty || (queue.length == 1 && currentTrack != null))
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Antrean kosong. Putar lagu atau album untuk mengisi antrean.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  Builder(
                    builder: (context) {
                      // Tampilkan hanya lagu setelah lagu aktif. Lagu aktif
                      // sudah punya bagian "SEDANG DIPUTAR" sendiri.
                      final rawStart =
                          player.currentIndex >= 0 ? player.currentIndex + 1 : 0;
                      final startIndex =
                          rawStart > queue.length ? queue.length : rawStart;
                      final upcoming = [
                        for (var i = startIndex; i < queue.length; i++)
                          MapEntry(i, queue[i]),
                      ];

                      if (upcoming.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'Tidak ada lagu berikutnya di antrean.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }

                      // Kunci unik dan stabil per entri. `identityHashCode`
                      // saja tidak cukup bila objek lagu yang sama ditambahkan
                      // dua kali ke antrean.
                      final itemKeys = <Key>[];
                      final occurrences = <String, int>{};
                      for (final entry in upcoming) {
                        final track = entry.value;
                        final base =
                            '${track.id}_${identityHashCode(track)}';
                        final occurrence = occurrences.update(
                          base,
                          (value) => value + 1,
                          ifAbsent: () => 0,
                        );
                        itemKeys.add(ValueKey('${base}_$occurrence'));
                      }

                      return ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: upcoming.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIdx, newIdx) {
                          final from = upcoming[oldIdx].key;
                          // newIdx == upcoming.length berarti dipindah ke
                          // posisi paling akhir antrean.
                          final to = newIdx >= upcoming.length
                              ? queue.length
                              : upcoming[newIdx].key;
                          player.reorderQueue(from, to);
                        },
                        itemBuilder: (context, index) {
                          final entry = upcoming[index];
                          final track = entry.value;
                          final fullIndex = entry.key;
                          final isCurrent = currentTrack?.id == track.id;

                          return ListTile(
                            key: itemKeys[index],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: track.artworkUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: track.artworkUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      placeholder: (_, _) => Container(color: AppTheme.card),
                                      errorWidget: (_, _, _) => Container(
                                        color: AppTheme.card,
                                        child: const Icon(Icons.music_note, size: 18, color: AppTheme.textSecondary),
                                      ),
                                    )
                                  : Container(width: 40, height: 40, color: AppTheme.card),
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isCurrent ? AppTheme.primaryGreen : Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                                  onPressed: () => player.removeFromQueue(fullIndex),
                                ),
                                const Icon(Icons.drag_handle, color: AppTheme.textSecondary, size: 20),
                              ],
                            ),
                            onTap: () => player.playTrack(track, queue: queue, explicitIndex: fullIndex),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
