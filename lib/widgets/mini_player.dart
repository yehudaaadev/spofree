import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import 'mini_visualizer.dart';
import 'player_sheet.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  double _dragOffset = 0.0;
  late AnimationController _animController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animController.addListener(() {
      setState(() {
        _dragOffset = _resetAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _openFullPlayer(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlayerSheet(),
    );
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.primaryDelta!).clamp(-90.0, 90.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, PlayerProvider player) {
    final velocity = details.primaryVelocity ?? 0.0;
    const threshold = 35.0;

    if (_dragOffset < -threshold || velocity < -220) {
      HapticFeedback.lightImpact();
      player.next();
    } else if (_dragOffset > threshold || velocity > 220) {
      HapticFeedback.lightImpact();
      player.previous();
    }

    _resetAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0.0);
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
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          if (_dragOffset.abs() < 10) {
            _openFullPlayer(context);
          }
        },
        onTapCancel: () => setState(() => _isPressed = false),
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: (details) => _onHorizontalDragEnd(details, player),
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            height: 60,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.divider,
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Indikator cue gestur di latar belakang kartu
                if (_dragOffset < -15)
                  Positioned(
                    right: 14,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Icon(
                        Icons.skip_next_rounded,
                        color: AppTheme.primaryRose.withValues(
                          alpha: ((_dragOffset.abs() - 15) / 50).clamp(0.0, 1.0),
                        ),
                        size: 26,
                      ),
                    ),
                  ),
                if (_dragOffset > 15)
                  Positioned(
                    left: 14,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Icon(
                        Icons.skip_previous_rounded,
                        color: AppTheme.primaryRose.withValues(
                          alpha: ((_dragOffset - 15) / 50).clamp(0.0, 1.0),
                        ),
                        size: 26,
                      ),
                    ),
                  ),

                // Konten utama yang bergeser mengikuti sentuhan jari
                Transform.translate(
                  offset: Offset(_dragOffset, 0),
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
                                            color: AppTheme.primaryRose,
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
                                  color: isLiked
                                      ? AppTheme.primaryRose
                                      : AppTheme.textSecondary,
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
                                        player.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
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

                      // Progress bar tipis di bawah
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8),
                        ),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 2.0,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
