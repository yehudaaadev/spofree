import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/library_provider.dart';
import '../screens/share_scanner_screen.dart';
import '../services/playlist_share_service.dart';
import '../theme/app_theme.dart';

/// Dialog untuk menerima playlist/lagu disukai lewat kode atau QR offline.
class ReceiveCollectionDialog extends StatefulWidget {
  const ReceiveCollectionDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ReceiveCollectionDialog(),
    );
  }

  @override
  State<ReceiveCollectionDialog> createState() =>
      _ReceiveCollectionDialogState();
}

class _ReceiveCollectionDialogState extends State<ReceiveCollectionDialog> {
  final TextEditingController _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _canScan {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) {
        if (mounted) {
          setState(() => _error = 'Papan klip tidak berisi teks.');
        }
        return;
      }
      _codeController.text = text;
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal membaca papan klip.');
    }
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ShareCodeScannerScreen()),
    );
    if (!mounted || result == null) return;
    _codeController.text = result;
    await _previewAndImport();
  }

  Future<void> _previewAndImport() async {
    FocusScope.of(context).unfocus();
    final SharedCollection collection;
    try {
      collection = PlaylistShareService.decode(_codeController.text);
    } on ShareCodeException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Kode tidak valid. Pastikan kode disalin lengkap.',
        );
      }
      return;
    }

    if (mounted) setState(() => _error = null);
    final library = context.read<LibraryProvider>();
    final playlistExists =
        !collection.isLiked &&
        library.playlists.any(
          (playlist) =>
              playlist.name.toLowerCase() == collection.name.toLowerCase(),
        );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          collection.isLiked ? 'Impor Lagu Disukai?' : 'Impor Playlist?',
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              collection.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${collection.tracks.length} lagu',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              collection.isLiked
                  ? 'Lagu yang sudah ada di daftar disukai akan dilewati.'
                  : playlistExists
                  ? 'Playlist dengan nama ini sudah ada. Lagu baru akan digabung tanpa duplikat.'
                  : 'Playlist baru akan dibuat di koleksi kamu.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Impor'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _import(collection);
  }

  Future<void> _import(SharedCollection collection) async {
    setState(() => _busy = true);
    try {
      final result = await context
          .read<LibraryProvider>()
          .importSharedCollection(collection);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surface,
          duration: const Duration(seconds: 4),
          content: Text(_resultMessage(result)),
        ),
      );
    } on ShareCodeException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Gagal mengimpor kode: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _resultMessage(SharedCollectionImportResult result) {
    if (!result.isLiked) {
      final name = result.name;
      if (result.createdPlaylist) {
        return 'Playlist "$name" dibuat dengan ${result.addedTracks} lagu.';
      }
      if (result.addedTracks == 0) {
        return 'Semua lagu sudah ada di playlist "$name".';
      }
      return '${result.addedTracks} lagu baru ditambahkan ke playlist "$name".';
    }
    if (result.addedTracks == 0) {
      return 'Semua lagu sudah ada di daftar Lagu Disukai.';
    }
    return '${result.addedTracks} lagu baru ditambahkan ke Lagu Disukai.';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.move_to_inbox_rounded,
                      color: AppTheme.primaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terima Kode Playlist',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tanpa server • playlist & lagu disukai',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Tempel kode WAVE1 dari teman, atau scan QR yang mereka bagikan. '
                'Kode berisi daftar lagu, bukan berkas audio.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (_canScan) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF484852)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        onPressed: _busy ? null : _scanQr,
                        icon: const Icon(Icons.qr_code_scanner, size: 17),
                        label: const Text('Scan QR'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF484852)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      onPressed: _busy ? null : _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste_rounded, size: 17),
                      label: const Text('Tempel'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                minLines: 4,
                maxLines: 7,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'WAVE1.xxxxxxxx...',
                  hintStyle: const TextStyle(
                    color: Colors.white30,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  filled: true,
                  fillColor: const Color(0xFF22222A),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: Color(0xFF34343E)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: Color(0xFF34343E)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  onPressed: _busy ? null : _previewAndImport,
                  icon: _busy
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black87,
                          ),
                        )
                      : const Icon(Icons.download_done_rounded, size: 18),
                  label: Text(
                    _busy ? 'Mengimpor...' : 'Impor Kode',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Playlist dengan nama yang sama akan digabung tanpa duplikat. '
                'Lagu yang sudah ada di koleksi juga dilewati.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
