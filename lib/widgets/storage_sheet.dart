import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/library_provider.dart';
import '../services/audio_cache_service.dart';
import '../services/download_service.dart';
import '../services/storage_stats_service.dart';
import '../theme/app_theme.dart';

/// Panel ringkasan dan pembersihan penyimpanan aplikasi.
class StorageSheet extends StatefulWidget {
  const StorageSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const StorageSheet(),
    );
  }

  @override
  State<StorageSheet> createState() => _StorageSheetState();
}

class _StorageSheetState extends State<StorageSheet> {
  StorageSnapshot? _snapshot;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload({bool showError = true}) async {
    if (mounted) setState(() => _loading = true);
    try {
      final snapshot = await StorageStatsService.load();
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[StorageSheet] gagal memuat statistik: $e');
      if (!mounted) return;
      setState(() => _loading = false);
      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat statistik penyimpanan.')),
        );
      }
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(
          message,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _clearCache() async {
    if (_working) return;
    final confirmed = await _confirm(
      'Hapus Cache Audio?',
      'Cache hanya mempercepat pemutaran ulang. Lagu yang sudah diunduh offline '
          'tidak ikut terhapus.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    try {
      await AudioCacheService.instance.clearCache();
      await _reload(showError: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache audio dibersihkan.')),
      );
    } catch (e) {
      debugPrint('[StorageSheet] gagal menghapus cache: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus cache audio.')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _clearDownloads() async {
    if (_working) return;
    final confirmed = await _confirm(
      'Hapus Semua Unduhan?',
      'Seluruh lagu offline akan dihapus dari perangkat. Lagu yang disukai dan '
          'playlist tetap tersimpan.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    try {
      await DownloadService().removeAllDownloads();
      if (mounted) {
        await context.read<LibraryProvider>().refreshDownloaded();
      }
      await _reload(showError: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua unduhan offline dihapus.')),
      );
    } catch (e) {
      debugPrint('[StorageSheet] gagal menghapus unduhan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menghapus unduhan offline.')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final usedFraction = snapshot?.usedFraction;

    return Material(
      color: AppTheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
              const Row(
                children: [
                  Icon(Icons.storage_rounded, color: AppTheme.primaryRose, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Penyimpanan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Kelola cache pemutaran dan lagu offline di perangkat ini.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryRose),
                  ),
                )
              else ...[
                _buildStatCard(
                  icon: Icons.music_note_rounded,
                  title: 'Cache Audio',
                  subtitle:
                      '${snapshot?.cacheFiles ?? 0} berkas · maksimal 300 MB',
                  value: StorageStatsService.formatBytes(snapshot?.cacheBytes ?? 0),
                  actionLabel: 'Hapus Cache',
                  onAction: _working ? null : _clearCache,
                ),
                const SizedBox(height: 10),
                _buildStatCard(
                  icon: Icons.download_for_offline_rounded,
                  title: 'Unduhan Offline',
                  subtitle: '${snapshot?.downloadCount ?? 0} lagu tersimpan',
                  value: StorageStatsService.formatBytes(
                    snapshot?.downloadBytes ?? 0,
                  ),
                  actionLabel: 'Hapus Semua',
                  onAction: (snapshot?.downloadCount ?? 0) == 0 || _working
                      ? null
                      : _clearDownloads,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider, width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.smartphone_rounded,
                            color: AppTheme.primaryRose,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Ruang Perangkat',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            snapshot?.freeBytes != null
                                ? '${StorageStatsService.formatBytes(snapshot!.freeBytes!)} bebas'
                                : 'Tidak tersedia',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (usedFraction != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: usedFraction,
                            minHeight: 7,
                            backgroundColor: AppTheme.divider,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryRose,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${StorageStatsService.formatBytes(snapshot!.totalBytes! - snapshot.freeBytes!)} '
                          'terpakai dari ${StorageStatsService.formatBytes(snapshot.totalBytes!)}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            'Statistik ruang disk hanya tersedia di Android.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF484848)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _working ? null : _reload,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Muat Ulang', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required String actionLabel,
    required VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryRose, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.primaryRoseLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryRose,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
