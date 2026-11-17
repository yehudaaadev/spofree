import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../services/music_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_options_sheet.dart';

class ArtistScreen extends StatefulWidget {
  final String artistName;

  const ArtistScreen({
    super.key,
    required this.artistName,
  });

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  ArtistProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await MusicService.instance.getArtistProfile(widget.artistName);
    if (mounted) {
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    }
  }

  String _formatFans(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M pendengar bulanan';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K pendengar bulanan';
    } else {
      return '$count pendengar bulanan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: const SafeArea(
        child: MiniPlayer(),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryRose),
            )
          : _profile == null
              ? _buildNotFound()
              : _buildArtistContent(player, _profile!),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off_outlined, size: 56, color: AppTheme.textSecondary),
          const SizedBox(height: 14),
          Text(
            'Profil "${widget.artistName}" tidak ditemukan',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Kembali'),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistContent(PlayerProvider player, ArtistProfile profile) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: AppTheme.surface,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              profile.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 10),
                ],
              ),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (profile.pictureUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: profile.pictureUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: AppTheme.card),
                    errorWidget: (_, _, _) => Container(color: AppTheme.card),
                  )
                else
                  Container(color: AppTheme.card),
                // Shading gradien bawah
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        AppTheme.background.withValues(alpha: 0.8),
                        AppTheme.background,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Info Artis & Tombol Aksi
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRose.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Artis Terverifikasi',
                        style: TextStyle(
                          color: AppTheme.primaryRoseLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatFans(profile.fansCount),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (profile.topTracks.isNotEmpty) {
                      player.playTrack(profile.topTracks.first, queue: profile.topTracks);
                    }
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryRose,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryRose.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Section Title: Lagu Populer
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Text(
              'Lagu Populer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Daftar Top Lagu
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final track = profile.topTracks[index];
              final isCurrent = player.currentTrack?.id == track.id;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isCurrent ? AppTheme.primaryRoseLight : AppTheme.textSecondary,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: track.artworkUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(color: AppTheme.card),
                        errorWidget: (_, _, _) => Container(
                          color: AppTheme.card,
                          child: const Icon(Icons.music_note, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isCurrent ? AppTheme.primaryRoseLight : AppTheme.textPrimary,
                  ),
                ),
                subtitle: Text(
                  track.formattedDuration,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
                  tooltip: 'Opsi Lagu',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    TrackOptionsSheet.show(context, track, contextQueue: profile.topTracks);
                  },
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  player.playTrack(track, queue: profile.topTracks);
                },
              );
            },
            childCount: profile.topTracks.length,
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );
  }
}
