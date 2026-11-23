import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';
import '../models/track_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../screens/artist_screen.dart';
import '../theme/app_theme.dart';
import 'equalizer_sheet.dart';
import 'export_audio_dialog.dart';
import 'lyric_share_dialog.dart';
import 'playback_options_sheet.dart';
import 'queue_sheet.dart';
import 'sleep_timer_dialog.dart';
import 'vinyl_disc_widget.dart';

class PlayerSheet extends StatefulWidget {
  const PlayerSheet({super.key});

  @override
  State<PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<PlayerSheet> {
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastLyricsIndex = -1;
  bool _showLyricsView = false;
  bool _isVinylMode = false;
  Color _ambientColor = const Color(0xFF1E3A2F);
  Color _ambientSecondaryColor = const Color(0xFF12231C);
  String? _lastArtworkUrl;
  bool _isPlayPressed = false;

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _extractPalette();
  }

  Future<void> _extractPalette() async {
    final track = context.read<PlayerProvider>().currentTrack;
    if (track == null || track.artworkUrl.isEmpty || track.artworkUrl == _lastArtworkUrl) return;
    _lastArtworkUrl = track.artworkUrl;

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(track.artworkUrl),
        size: const Size(60, 60),
      );
      if (!mounted) return;
      // Abaikan hasil palette lagu lama yang datang terlambat.
      if (context.read<PlayerProvider>().currentTrack?.artworkUrl !=
          track.artworkUrl) {
        return;
      }
      setState(() {
        _ambientColor = palette.vibrantColor?.color ??
            palette.dominantColor?.color ??
            const Color(0xFF1E3A2F);
        _ambientSecondaryColor = palette.darkVibrantColor?.color ??
            palette.mutedColor?.color ??
            const Color(0xFF12231C);
      });
    } catch (_) {}
  }

  void _scrollToCurrentLyric(int index) {
    if (!_lyricsScrollController.hasClients || index == _lastLyricsIndex || index < 0) return;
    _lastLyricsIndex = index;
    final viewport = _lyricsScrollController.position.viewportDimension;
    final targetOffset = (index * 56.0) - (viewport * 0.35);
    _lyricsScrollController.animateTo(
      targetOffset.clamp(0.0, _lyricsScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
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

    if (track.artworkUrl != _lastArtworkUrl) {
      _extractPalette();
    }

    final isLiked = library.isLiked(track.id);
    final isDownloaded = library.isDownloaded(track.id);
    final currentLyricIdx = player.currentLyricsIndex;

    // Pesan error runtime ditampilkan di level utama (MainScreen) supaya
    // tetap terlihat ketika panel pemutar penuh tidak sedang dibuka.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showLyricsView && currentLyricIdx >= 0) {
        _scrollToCurrentLyric(currentLyricIdx);
      }
    });

    final currentPosSec = player.position.inSeconds.toDouble();
    final maxDurSec = player.duration.inSeconds > 0
        ? player.duration.inSeconds.toDouble()
        : (track.durationMs / 1000).toDouble();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _ambientColor.withValues(alpha: 0.92),
            _ambientSecondaryColor.withValues(alpha: 0.50),
            AppTheme.background,
            AppTheme.background,
          ],
          stops: const [0.0, 0.32, 0.70, 1.0],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textPrimary, size: 28),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isVinylMode ? Icons.album : Icons.album_outlined,
                          color: _isVinylMode ? AppTheme.primaryRose : AppTheme.textPrimary,
                          size: 22,
                        ),
                        tooltip: _isVinylMode ? 'Mode Cover Standar' : 'Mode Piringan Hitam (Vinyl)',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _isVinylMode = !_isVinylMode);
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          player.hasActiveSleepTimer ? Icons.timer : Icons.timer_outlined,
                          color: player.hasActiveSleepTimer ? AppTheme.primaryRose : AppTheme.textPrimary,
                          size: 22,
                        ),
                        tooltip: 'Sleep Timer',
                        onPressed: () => SleepTimerDialog.show(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.tune, color: AppTheme.textPrimary, size: 22),
                        tooltip: 'Kecepatan & Kualitas',
                        onPressed: () => PlaybackOptionsSheet.show(context),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.equalizer,
                          color: player.equalizerEnabled ? AppTheme.primaryRose : AppTheme.textPrimary,
                          size: 22,
                        ),
                        tooltip: 'Equalizer & Efek',
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => const EqualizerSheet(),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Main Display: Artwork, Vinyl Disc, or Synced Lyrics View
              Expanded(
                child: _showLyricsView
                    ? _buildLyricsView(player, currentLyricIdx, track)
                    : _isVinylMode
                        ? VinylDiscWidget(
                            artworkUrl: track.artworkUrl,
                            isPlaying: player.isPlaying,
                          )
                        : _buildArtworkView(track, player.isPlaying),
              ),

              const SizedBox(height: 14),

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
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArtistScreen(artistName: track.artist),
                              ),
                            );
                          },
                          child: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? AppTheme.primaryRose : AppTheme.textSecondary,
                      size: 28,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      library.toggleLike(track);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (player.skippedSegmentNotice != null)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryRose.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fast_forward, color: AppTheme.primaryRose, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          player.skippedSegmentNotice!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

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

              const SizedBox(height: 8),

              // Media Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      size: 24,
                      color: player.isShuffle ? AppTheme.primaryRose : AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      player.toggleShuffle();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 36, color: AppTheme.textPrimary),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      player.previous();
                    },
                  ),
                  GestureDetector(
                    onTapDown: (_) => setState(() => _isPlayPressed = true),
                    onTapUp: (_) {
                      setState(() => _isPlayPressed = false);
                      HapticFeedback.selectionClick();
                      player.togglePlayPause();
                    },
                    onTapCancel: () => setState(() => _isPlayPressed = false),
                    child: AnimatedScale(
                      scale: _isPlayPressed ? 0.90 : 1.0,
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.28),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
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
                                player.isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 38,
                                color: Colors.black,
                              ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 36, color: AppTheme.textPrimary),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      player.next();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      player.loopMode == LoopMode.one
                          ? Icons.repeat_one
                          : Icons.repeat,
                      size: 24,
                      color: player.loopMode != LoopMode.off
                          ? AppTheme.primaryRose
                          : AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      player.toggleRepeat();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Bottom Actions: Download, Lyrics, and Queue
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
                            color: AppTheme.primaryRose,
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
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppTheme.primaryRose, size: 20),
                        const SizedBox(width: 6),
                        const Text(
                          'Offline',
                          style: TextStyle(fontSize: 12, color: AppTheme.primaryRose, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.drive_file_move_outlined, color: Colors.white, size: 20),
                          tooltip: 'Simpan ke Folder HP',
                          onPressed: () => ExportAudioDialog.show(context, track),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined, color: AppTheme.textSecondary),
                      tooltip: 'Download Offline',
                      onPressed: () async {
                        final downloaded = await player.downloadCurrentTrack();
                        if (downloaded != null) {
                          await library.refreshDownloaded();
                        }
                      },
                    ),

                  Row(
                    children: [
                      TextButton.icon(
                        icon: Icon(
                          _showLyricsView ? Icons.image : Icons.lyrics,
                          size: 16,
                          color: _showLyricsView ? AppTheme.primaryRose : AppTheme.textSecondary,
                        ),
                        label: Text(
                          _showLyricsView ? 'Tutup Lirik' : 'Lirik',
                          style: TextStyle(
                            color: _showLyricsView ? AppTheme.primaryRose : AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _showLyricsView = !_showLyricsView;
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.queue_music, color: AppTheme.textSecondary, size: 22),
                        tooltip: 'Antrean Lagu',
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => const QueueSheet(),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtworkView(TrackModel track, bool isPlaying) {
    return Center(
      child: AnimatedScale(
        scale: isPlaying ? 1.0 : 0.88,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dynamic ambient radial glow
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _ambientColor.withValues(alpha: isPlaying ? 0.6 : 0.2),
                    blurRadius: 65,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: track.artworkUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: track.artworkUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppTheme.card,
                            child: const Center(
                              child: Icon(Icons.music_note, size: 60, color: AppTheme.textSecondary),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: AppTheme.card,
                            child: const Center(
                              child: Icon(Icons.music_note, size: 60, color: AppTheme.textSecondary),
                            ),
                          ),
                        )
                      : Container(
                          color: AppTheme.card,
                          child: const Center(
                            child: Icon(Icons.music_note, size: 60, color: AppTheme.textSecondary),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffsetButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.divider, width: 0.8),
          ),
          child: Icon(icon, size: 14, color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildLyricsView(PlayerProvider player, int currentLyricIdx, TrackModel track) {
    if (player.isLoadingLyrics) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryRose),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider, width: 0.8),
      ),
      child: Column(
        children: [
          // Header Petunjuk Tap-to-Seek
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 13,
                      color: AppTheme.primaryRose.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Ketuk lirik untuk melompat',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRose.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Lirik Sinkron',
                    style: TextStyle(
                      color: AppTheme.primaryRoseLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Kontrol offset sinkronisasi lirik (per lagu, tersimpan).
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              children: [
                const Text(
                  'Sinkron',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                _buildOffsetButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Lirik lebih lambat 0,5 detik',
                  onPressed: () => player.setLyricsOffset(-500),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${player.lyricsOffsetMs >= 0 ? '+' : ''}'
                    '${(player.lyricsOffsetMs / 1000).toStringAsFixed(1)} dtk',
                    style: const TextStyle(
                      color: AppTheme.primaryRoseLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildOffsetButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Lirik lebih cepat 0,5 detik',
                  onPressed: () => player.setLyricsOffset(500),
                ),
                if (player.lyricsOffsetMs != 0) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: player.resetLyricsOffset,
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 4),

          // Daftar Lirik Interaktif
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.06, 0.94, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: _lyricsScrollController,
                itemCount: player.lyrics.length,
                itemBuilder: (context, index) {
                  final line = player.lyrics[index];
                  final isCurrent = index == currentLyricIdx;

                  final minutes = line.timestamp.inMinutes.remainder(60).toString().padLeft(2, '0');
                  final seconds = line.timestamp.inSeconds.remainder(60).toString().padLeft(2, '0');
                  final timeFormatted = '$minutes:$seconds';

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      player.seek(player.lyricSeekPosition(line.timestamp));
                      if (!player.isPlaying) {
                        player.resume();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: isCurrent
                            ? _ambientColor.withValues(alpha: 0.28)
                            : Colors.transparent,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Timestamp badge
                          if (isCurrent)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryRose.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                timeFormatted,
                                style: const TextStyle(
                                  color: AppTheme.primaryRoseLight,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                timeFormatted,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  fontSize: 10,
                                ),
                              ),
                            ),

                          // Lyric text
                          Expanded(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
                                fontSize: isCurrent ? 21 : 15,
                                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                color: isCurrent
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.35),
                                height: 1.35,
                                shadows: isCurrent
                                    ? [
                                        Shadow(
                                          color: _ambientColor.withValues(alpha: 0.8),
                                          blurRadius: 20,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(line.text),
                            ),
                          ),
                          if (isCurrent)
                            IconButton(
                              icon: const Icon(Icons.share_outlined, size: 18, color: AppTheme.primaryRose),
                              tooltip: 'Bagikan Kutipan Lirik',
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                LyricShareDialog.show(
                                  context,
                                  track: track,
                                  lyricText: line.text,
                                  ambientColor: _ambientColor,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
