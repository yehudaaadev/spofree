import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import 'player_sheet.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  void _openFullPlayer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlayerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final track = player.currentTrack;

    if (track == null) {
      return const SizedBox.shrink();
    }

    final isLiked = library.isLiked(track.id);

    final currentSeconds = player.position.inSeconds.toDouble();
    final maxSeconds = player.duration.inSeconds > 0
        ? player.duration.inSeconds.toDouble()
        : (track.durationMs / 1000).toDouble();

    final progress = (maxSeconds > 0)
        ? (currentSeconds / maxSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: GestureDetector(
        onTap: () => _openFullPlayer(context),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      // Album Cover Art
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: track.artworkUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: track.artworkUrl,
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Container(
                                  width: 42,
                                  height: 42,
                                  color: AppTheme.surface,
                                  child: const Icon(LucideIcons.music, size: 20),
                                ),
                              )
                            : Container(
                                width: 42,
                                height: 42,
                                color: AppTheme.surface,
                                child: const Icon(LucideIcons.music, size: 20),
                              ),
                      ),

                      const SizedBox(width: 12),

                      // Title & Artist
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Like Button
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? AppTheme.primaryGreen : AppTheme.textSecondary,
                          size: 22,
                        ),
                        onPressed: () => library.toggleLike(track),
                      ),

                      // Play / Pause or Loading Indicator
                      player.isLoadingAudio
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                player.isPlaying ? LucideIcons.pause : LucideIcons.play,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () => player.togglePlayPause(),
                            ),
                    ],
                  ),
                ),
              ),

              // Thin bottom progress bar
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 2.5,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
