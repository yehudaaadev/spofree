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
/// Menyediakan pilihan Sukai (Like), Download Offline, Tambah ke Playlist,
/// "Putar Berikutnya" (Play Next), dan "Tambah ke Antrean".
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
      isScrollControlled: true,
      builder: (ctx) => TrackOptionsSheet(track: track, contextQueue: contextQueue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final isLiked = library.isLiked(track.id);
    final isDownloaded = library.isDownloaded(track.id);
    final isDownloading = library.isDownloadingTrack(track.id);

    return Material(
      color: AppTheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
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
                        placeholder: (_, _) => Container(color: AppTheme.card),
                        errorWidget: (_, _, _) => Container(
                          width: 48,
                          height: 48,
                          color: AppTheme.card,
                          child: const Icon(
                            Icons.music_note,
                            color: AppTheme.textSecondary,
                            size: 24,
                          ),
                        ),
                      )
                    : Container(width: 48, height: 48, color: AppTheme.card),
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
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 8),

          // Option: Like / Unlike
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? AppTheme.primaryRose : Colors.white70,
            ),
            title: Text(
              isLiked ? 'Hapus dari Lagu Disukai' : 'Sukai Lagu Ini',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: Text(
              isLiked
                  ? 'Tersimpan di daftar lagu favoritmu'
                  : 'Tambahkan ke koleksi lagu disukai',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              library.toggleLike(track);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.card,
                  content: Text(
                    isLiked
                        ? 'Dihapus dari Lagu Disukai'
                        : 'Ditambahkan ke Lagu Disukai',
                    style: const TextStyle(color: Colors.white),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // Option: Download Offline
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppTheme.primaryRose,
                    ),
                  )
                : Icon(
                    isDownloaded
                        ? Icons.download_done_rounded
                        : Icons.download_for_offline_outlined,
                    color: isDownloaded ? AppTheme.primaryRose : Colors.white70,
                  ),
            title: Text(
              isDownloaded
                  ? 'Tersimpan Offline'
                  : isDownloading
                      ? 'Sedang Mengunduh...'
                      : 'Download Lagu (Offline)',
              style: TextStyle(
                color: isDownloaded ? AppTheme.primaryRoseLight : Colors.white,
                fontSize: 14,
                fontWeight: isDownloaded ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              isDownloaded
                  ? 'Lagu siap diputar tanpa kuota internet'
                  : isDownloading
                      ? 'Mengunduh stream kualitas tinggi...'
                      : 'Simpan file audio lokal ke perangkat',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            onTap: (isDownloaded || isDownloading)
                ? null
                : () async {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.card,
                        content: Text(
                          'Memulai unduhan "${track.title}"...',
                          style: const TextStyle(color: Colors.white),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    final success = await library.downloadSingleTrack(track);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppTheme.card,
                          content: Text(
                            success
                                ? 'Berhasil mengunduh "${track.title}" untuk offline'
                                : 'Gagal mengunduh "${track.title}". Periksa koneksi internet.',
                            style: const TextStyle(color: Colors.white),
                          ),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
          ),

          // Option: Add to Playlist
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.playlist_add, color: Colors.white70),
            title: const Text(
              'Tambah ke Playlist',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: const Text(
              'Simpan ke salah satu daftar putar pribadimu',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
              _showAddToPlaylistSheet(context, library, track);
            },
          ),

          // Option: Play Next
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.playlist_play, color: AppTheme.primaryRose),
            title: const Text(
              'Putar Berikutnya (Play Next)',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: const Text(
              'Disisipkan tepat setelah lagu yang sedang diputar',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              player.playNext(track);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.card,
                  content: Text(
                    '"${track.title}" akan diputar berikutnya',
                    style: const TextStyle(color: Colors.white),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // Option: Add to Queue
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.queue_music, color: Colors.white70),
            title: const Text(
              'Tambah ke Antrean',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: const Text(
              'Ditambahkan ke akhir antrean pemutaran',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            onTap: () {
              HapticFeedback.selectionClick();
              player.addToQueue(track);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppTheme.card,
                  content: Text(
                    '"${track.title}" ditambahkan ke antrean',
                    style: const TextStyle(color: Colors.white),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
  }

  static void _showAddToPlaylistSheet(
    BuildContext context,
    LibraryProvider library,
    TrackModel track,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return Material(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
              const Text(
                'Tambah ke Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider, width: 0.8),
                  ),
                  child: const Icon(Icons.add, color: AppTheme.primaryRose),
                ),
                title: const Text(
                  'Buat Playlist Baru',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Buat playlist dan simpan lagu ini ke dalamnya',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showCreateAndAddDialog(context, library, track);
                },
              ),
              const Divider(color: AppTheme.divider, height: 16),
              if (library.playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Belum ada playlist dibuat',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetCtx).size.height * 0.45,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: library.playlists.length,
                    itemBuilder: (ctx, index) {
                      final p = library.playlists[index];
                      final alreadyIn = p.tracks.any((t) => t.id == track.id);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.queue_music,
                            color: AppTheme.textSecondary,
                            size: 22,
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${p.tracks.length} lagu',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        trailing: alreadyIn
                            ? const Icon(
                                Icons.check,
                                color: AppTheme.primaryRose,
                                size: 20,
                              )
                            : null,
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          Navigator.pop(sheetCtx);
                          if (!alreadyIn) {
                            await library.addTrackToPlaylist(p.id, track);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.card,
                                  content: Text(
                                    '"${track.title}" ditambahkan ke "${p.name}"',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppTheme.card,
                                  content: Text(
                                    '"${track.title}" sudah ada di "${p.name}"',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
  }

  static void _showCreateAndAddDialog(
    BuildContext context,
    LibraryProvider library,
    TrackModel track,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Playlist Baru',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nama playlist',
            hintStyle: const TextStyle(color: AppTheme.textSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryRose),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(dlgCtx);
                await library.createPlaylist(name);
                if (library.playlists.isNotEmpty) {
                  final newPl = library.playlists.firstWhere(
                    (p) => p.name == name,
                    orElse: () => library.playlists.last,
                  );
                  await library.addTrackToPlaylist(newPl.id, track);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppTheme.card,
                        content: Text(
                          'Playlist "$name" dibuat dan lagu ditambahkan',
                          style: const TextStyle(color: Colors.white),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text(
              'Buat & Tambah',
              style: TextStyle(color: AppTheme.primaryRose, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
