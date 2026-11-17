import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/track_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

/// Modal menu tindakan cepat untuk satu lagu.
///
/// Menyediakan pilihan "Putar Berikutnya" (Play Next), "Tambah ke Antrean",
/// dan "Sukai Lagu".
class TrackOptionsSheet extends StatelessWidget {
  final TrackModel track;
  final List<TrackModel>? contextQueue;

  const TrackOptionsSheet({
    super.key,
    required this.track,
    this.contextQueue,
  });

  static void show(
    BuildContext context,
    TrackModel track, {
    List<TrackModel>? contextQueue,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TrackOptionsSheet(track: track, contextQueue: contextQueue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final isLiked = library.isLiked(track.id);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Track Header
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: track.artworkUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: track.artworkUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: const Color(0xFF282828)),
                        errorWidget: (_, _, _) => Container(
                          width: 48,
                          height: 48,
                          color: const Color(0xFF282828),
                          child: const Icon(Icons.music_note, color: Colors.white38, size: 24),
                        ),
                      )
                    : Container(width: 48, height: 48, color: const Color(0xFF282828)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),

          // Option: Play Next
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.playlist_play, color: AppTheme.primaryGreen),
            title: const Text('Putar Berikutnya (Play Next)', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Disisipkan tepat setelah lagu yang sedang diputar', style: TextStyle(color: Colors.white54, fontSize: 11)),
            onTap: () {
              HapticFeedback.selectionClick();
              player.playNext(track);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF282828),
                  content: Text('"${track.title}" akan diputar berikutnya'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // Option: Add to Queue
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.queue_music, color: Colors.white70),
            title: const Text('Tambah ke Antrean', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Ditambahkan ke akhir antrean pemutaran', style: TextStyle(color: Colors.white54, fontSize: 11)),
            onTap: () {
              HapticFeedback.selectionClick();
              player.addToQueue(track);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF282828),
                  content: Text('"${track.title}" ditambahkan ke antrean'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // Option: Like / Unlike
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? AppTheme.primaryGreen : Colors.white70,
            ),
            title: Text(
              isLiked ? 'Hapus dari Lagu Disukai' : 'Sukai Lagu Ini',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              library.toggleLike(track);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
