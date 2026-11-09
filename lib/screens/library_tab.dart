import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/track_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  int _selectedFilter = 0; // 0: Liked, 1: Downloaded, 2: Playlists

  void _showCreatePlaylistDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Buat Playlist Baru', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nama Playlist',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<LibraryProvider>().createPlaylist(name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final player = context.read<PlayerProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Koleksi Kamu',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (_selectedFilter == 2)
                    IconButton(
                      icon: const Icon(LucideIcons.plus, color: AppTheme.textPrimary),
                      onPressed: () => _showCreatePlaylistDialog(context),
                    ),
                ],
              ),
            ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildChip('Lagu Disukai (${library.likedList.length})', 0),
                  const SizedBox(width: 8),
                  _buildChip('Offline (${library.downloadedTracks.length})', 1),
                  const SizedBox(width: 8),
                  _buildChip('Playlist (${library.playlists.length})', 2),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Content Area
            Expanded(
              child: _selectedFilter == 0
                  ? _buildTrackList(library.likedList, player, library, isOffline: false)
                  : _selectedFilter == 1
                      ? _buildTrackList(library.downloadedTracks, player, library, isOffline: true)
                      : _buildPlaylists(library, player),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTrackList(
    List<TrackModel> tracks,
    PlayerProvider player,
    LibraryProvider library, {
    required bool isOffline,
  }) {
    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOffline ? LucideIcons.downloadCloud : LucideIcons.heart,
              size: 54,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              isOffline
                  ? 'Belum ada lagu yang di-download'
                  : 'Belum ada lagu yang disukai',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: track.artworkUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: track.artworkUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: AppTheme.card),
                    errorWidget: (_, _, _) => Container(
                      color: AppTheme.card,
                      child: const Icon(LucideIcons.music, size: 24),
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: AppTheme.card,
                    child: const Icon(LucideIcons.music, size: 24),
                  ),
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Text(
            '${track.artist} • ${track.formattedDuration}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          trailing: isOffline
              ? IconButton(
                  icon: const Icon(LucideIcons.trash2, color: AppTheme.textSecondary, size: 20),
                  onPressed: () => library.removeDownloadedTrack(track.id),
                )
              : IconButton(
                  icon: const Icon(Icons.favorite, color: AppTheme.primaryGreen, size: 22),
                  onPressed: () => library.toggleLike(track),
                ),
          onTap: () => player.playTrack(track, queue: tracks),
        );
      },
    );
  }

  Widget _buildPlaylists(LibraryProvider library, PlayerProvider player) {
    if (library.playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.listMusic, size: 54, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text(
              'Belum ada playlist',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              onPressed: () => _showCreatePlaylistDialog(context),
              child: const Text('Buat Playlist Pertama', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: library.playlists.length,
      itemBuilder: (context, index) {
        final playlist = library.playlists[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(LucideIcons.listMusic, color: AppTheme.textSecondary),
          ),
          title: Text(
            playlist.name,
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          subtitle: Text(
            '${playlist.tracks.length} lagu',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(LucideIcons.trash2, color: AppTheme.textSecondary, size: 20),
            onPressed: () => library.deletePlaylist(playlist.id),
          ),
          onTap: () {
            if (playlist.tracks.isNotEmpty) {
              player.playTrack(playlist.tracks.first, queue: playlist.tracks);
            }
          },
        );
      },
    );
  }
}
