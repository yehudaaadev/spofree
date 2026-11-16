import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/track_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../services/local_audio_service.dart';
import '../theme/app_theme.dart';
import '../widgets/export_audio_dialog.dart';
import '../widgets/import_playlist_dialog.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});

  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  int _selectedFilter = 0; // 0: Liked, 1: Downloaded, 2: Playlists, 3: File Lokal
  List<TrackModel> _localFiles = [];
  bool _isLoadingLocal = false;

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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.link, color: AppTheme.textPrimary),
                          tooltip: 'Impor Playlist',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => const ImportPlaylistDialog(),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: AppTheme.textPrimary),
                          onPressed: () => _showCreatePlaylistDialog(context),
                        ),
                      ],
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
                  const SizedBox(width: 8),
                  _buildChip('File Lokal', 3),
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
                      : _selectedFilter == 2
                          ? _buildPlaylists(library, player)
                          : _buildLocalFilesView(player),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGreen : Colors.white12,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.black : Colors.white70,
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
              isOffline ? Icons.cloud_download_outlined : Icons.favorite_border,
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

    return Column(
      children: [
        // Action Controls & Bulk Download
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${tracks.length} lagu',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  if (!isOffline)
                    TextButton.icon(
                      icon: library.isBulkDownloading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                            )
                          : const Icon(Icons.download_for_offline_outlined, size: 18, color: AppTheme.primaryGreen),
                      label: Text(
                        library.isBulkDownloading
                            ? '${library.bulkCurrentIndex}/${library.bulkTotalCount}'
                            : 'Download Semua',
                        style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      onPressed: library.isBulkDownloading
                          ? null
                          : () {
                              library.bulkDownloadTracks(tracks);
                            },
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Putar Semua', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      if (tracks.isNotEmpty) {
                        player.playTrack(tracks.first, queue: tracks);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        if (library.isBulkDownloading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: LinearProgressIndicator(
              value: library.bulkDownloadProgress,
              backgroundColor: AppTheme.card,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
            ),
          ),

        Expanded(
          child: ListView.builder(
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
                            child: const Icon(Icons.music_note, size: 24),
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: AppTheme.card,
                          child: const Icon(Icons.music_note, size: 24),
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
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.drive_file_move_outlined, color: AppTheme.primaryGreen, size: 22),
                            tooltip: 'Salin ke Folder HP',
                            onPressed: () => ExportAudioDialog.show(context, track),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary, size: 20),
                            onPressed: () => library.removeDownloadedTrack(track.id),
                          ),
                        ],
                      )
                    : IconButton(
                        icon: const Icon(Icons.favorite, color: AppTheme.primaryGreen, size: 22),
                        onPressed: () => library.toggleLike(track),
                      ),
                onTap: () => player.playTrack(track, queue: tracks),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylists(LibraryProvider library, PlayerProvider player) {
    if (library.playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music, size: 54, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
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
            child: const Icon(Icons.queue_music, color: AppTheme.textSecondary),
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
            icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary, size: 20),
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

  Future<void> _scanLocalFiles() async {
    setState(() => _isLoadingLocal = true);
    try {
      // Android 11+ memerlukan izin akses penyimpanan penuh untuk memindai
      // folder publik perangkat.
      final granted = await LocalAudioService.requestStoragePermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.surface,
              duration: Duration(seconds: 5),
              content: Text(
                'Izin akses penyimpanan diperlukan untuk memindai file lokal.',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          );
        }
        _localFiles = [];
      } else {
        _localFiles = await LocalAudioService.scanLocalAudioFiles();
      }
    } catch (e) {
      _localFiles = [];
    }
    if (mounted) setState(() => _isLoadingLocal = false);
  }

  Widget _buildLocalFilesView(PlayerProvider player) {
    if (_localFiles.isEmpty && !_isLoadingLocal) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 54,
              color: AppTheme.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pindai file audio (.mp3, .m4a, .flac, .wav)\nyang tersimpan di perangkat',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.search, size: 20),
              label: const Text('Pindai Sekarang', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _scanLocalFiles,
            ),
          ],
        ),
      );
    }

    if (_isLoadingLocal) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            SizedBox(height: 16),
            Text(
              'Memindai file audio...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_localFiles.length} file ditemukan',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.play_circle_fill, size: 18, color: AppTheme.primaryGreen),
                    label: const Text(
                      'Putar Semua',
                      style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: _localFiles.isNotEmpty
                        ? () => player.playTrack(_localFiles.first, queue: _localFiles)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20),
                    tooltip: 'Pindai Ulang',
                    onPressed: _scanLocalFiles,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _localFiles.length,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemBuilder: (ctx, index) {
              final track = _localFiles[index];
              final ext = track.localPath?.split('.').last.toUpperCase() ?? 'AUDIO';
              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      ext,
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  track.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.textSecondary, size: 20),
                  tooltip: 'Tambah ke Antrean',
                  onPressed: () {
                    player.addToQueue(track);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${track.title} ditambahkan ke antrean'),
                        backgroundColor: AppTheme.surface,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                onTap: () => player.playTrack(track, queue: _localFiles),
              );
            },
          ),
        ),
      ],
    );
  }
}
