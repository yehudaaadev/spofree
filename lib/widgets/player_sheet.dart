import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/track_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class PlayerSheet extends StatefulWidget {
  const PlayerSheet({super.key});

  @override
  State<PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<PlayerSheet> {
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastLyricsIndex = -1;
  bool _showLyricsView = false;

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentLyric(int index) {
    if (!_lyricsScrollController.hasClients || index == _lastLyricsIndex || index < 0) return;
    _lastLyricsIndex = index;
    final targetOffset = (index * 42.0) - 100.0;
    _lyricsScrollController.animateTo(
      targetOffset.clamp(0.0, _lyricsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
    final isDownloaded = library.isDownloaded(track.id);
    final currentLyricIdx = player.currentLyricsIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showLyricsView && currentLyricIdx >= 0) {
        _scrollToCurrentLyric(currentLyricIdx);
      }
    });

    final currentPosSec = player.position.inSeconds.toDouble();
    final maxDurSec = player.duration.inSeconds > 0
        ? player.duration.inSeconds.toDouble()
        : (track.durationMs / 1000).toDouble();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              // Header bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.chevronDown, color: AppTheme.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'MEMUTAR DARI ALBUM',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.album.isNotEmpty ? track.album : 'Single',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showLyricsView ? LucideIcons.music : LucideIcons.fileText,
                      color: _showLyricsView ? AppTheme.primaryGreen : AppTheme.textPrimary,
                    ),
                    onPressed: () {
                      setState(() {
                        _showLyricsView = !_showLyricsView;
                      });
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Main Display: Artwork or Synced Lyrics View
              Expanded(
                child: _showLyricsView
                    ? _buildLyricsView(player, currentLyricIdx)
                    : _buildArtworkView(track),
              ),

              const SizedBox(height: 16),

              // Title, Artist and Like button
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppTheme.primaryGreen : AppTheme.textSecondary,
                      size: 28,
                    ),
                    onPressed: () => library.toggleLike(track),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Seekbar Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white12,
                ),
                child: Slider(
                  value: currentPosSec.clamp(0.0, maxDurSec > 0 ? maxDurSec : 1.0),
                  min: 0.0,
                  max: maxDurSec > 0 ? maxDurSec : 1.0,
                  onChanged: (val) {
                    player.seek(Duration(seconds: val.toInt()));
                  },
                ),
              ),

              // Position & Duration label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(player.position),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    Text(
                      _formatDuration(player.duration),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Media Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      LucideIcons.shuffle,
                      size: 22,
                      color: player.isShuffle ? AppTheme.primaryGreen : AppTheme.textSecondary,
                    ),
                    onPressed: () => player.toggleShuffle(),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.skipBack, size: 30, color: AppTheme.textPrimary),
                    onPressed: () => player.previous(),
                  ),
                  GestureDetector(
                    onTap: () => player.togglePlayPause(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: player.isLoadingAudio
                          ? const Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.black,
                                ),
                              ),
                            )
                          : Icon(
                              player.isPlaying ? LucideIcons.pause : LucideIcons.play,
                              size: 30,
                              color: Colors.black,
                            ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.skipForward, size: 30, color: AppTheme.textPrimary),
                    onPressed: () => player.next(),
                  ),
                  IconButton(
                    icon: Icon(
                      player.loopMode == LoopMode.one
                          ? LucideIcons.repeat1
                          : LucideIcons.repeat,
                      size: 22,
                      color: player.loopMode != LoopMode.off
                          ? AppTheme.primaryGreen
                          : AppTheme.textSecondary,
                    ),
                    onPressed: () => player.toggleRepeat(),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Bottom Actions: Download button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (player.isDownloading)
                    Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: player.downloadProgress > 0 ? player.downloadProgress : null,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mengunduh ${(player.downloadProgress * 100).toInt()}%',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    )
                  else if (isDownloaded)
                    const Row(
                      children: [
                        Icon(LucideIcons.checkCircle2, color: AppTheme.primaryGreen, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'Tersimpan Offline',
                          style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: const Icon(LucideIcons.download, color: AppTheme.textSecondary),
                      tooltip: 'Download Offline',
                      onPressed: () async {
                        final downloaded = await player.downloadCurrentTrack();
                        if (downloaded != null) {
                          await library.refreshDownloaded();
                        }
                      },
                    ),

                  TextButton.icon(
                    icon: Icon(
                      _showLyricsView ? LucideIcons.image : LucideIcons.fileText,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    label: Text(
                      _showLyricsView ? 'Tutup Lirik' : 'Lirik',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    onPressed: () {
                      setState(() {
                        _showLyricsView = !_showLyricsView;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkView(TrackModel track) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: track.artworkUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: track.artworkUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.card,
                      child: const Center(
                        child: Icon(LucideIcons.music, size: 60, color: AppTheme.textSecondary),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.card,
                      child: const Center(
                        child: Icon(LucideIcons.music, size: 60, color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                : Container(
                    color: AppTheme.card,
                    child: const Center(
                      child: Icon(LucideIcons.music, size: 60, color: AppTheme.textSecondary),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsView(PlayerProvider player, int currentLyricIdx) {
    if (player.isLoadingLyrics) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      );
    }

    if (player.lyrics.isEmpty) {
      return const Center(
        child: Text(
          'Lirik tidak tersedia untuk lagu ini',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListView.builder(
        controller: _lyricsScrollController,
        itemCount: player.lyrics.length,
        itemBuilder: (context, index) {
          final line = player.lyrics[index];
          final isCurrent = index == currentLyricIdx;

          return GestureDetector(
            onTap: () => player.seek(line.timestamp),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                line.text,
                style: TextStyle(
                  fontSize: isCurrent ? 20 : 16,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent ? Colors.white : AppTheme.textSecondary.withValues(alpha: 0.5),
                  height: 1.4,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
