import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import 'mini_visualizer.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: GestureDetector(
        onTap: () => _openFullPlayer(context),
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0.0;
          if (velocity < -250) {
            HapticFeedback.lightImpact();
            player.next();
          } else if (velocity > 250) {
            HapticFeedback.lightImpact();
            player.previous();
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: AppTheme.card.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
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
                            borderRadius: BorderRadius.circular(6),
                            child: track.artworkUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: track.artworkUrl,
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => Container(
                                      width: 44,
                                      height: 44,
                                      color: AppTheme.surface,
                                      child: const Icon(Icons.music_note, size: 20),
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      width: 44,
                                      height: 44,
                                      color: AppTheme.surface,
                                      child: const Icon(Icons.music_note, size: 20),
                                    ),
                                  )
                                : Container(
                                    width: 44,
                                    height: 44,
                                    color: AppTheme.surface,
                                    child: const Icon(Icons.music_note, size: 20),
                                  ),
                          ),

                          const SizedBox(width: 12),

                          // Title & Artist with Live Equalizer
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (player.isPlaying) ...[
                                      const MiniVisualizer(
                                        isPlaying: true,
                                        height: 12.0,
                                        color: AppTheme.primaryGreen,
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Expanded(
                                      child: Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
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
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              library.toggleLike(track);
                            },
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
                                    player.isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    player.togglePlayPause();
                                  },
                                ),
                        ],
                      ),
                    ),
                  ),

                  // Thin bottom progress bar
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.5,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
