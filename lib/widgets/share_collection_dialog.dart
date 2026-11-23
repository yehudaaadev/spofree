import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/track_model.dart';
import '../services/playlist_share_service.dart';
import '../theme/app_theme.dart';

/// Dialog untuk membagikan playlist atau lagu disukai sebagai kode/QR offline.
class ShareCollectionDialog extends StatefulWidget {
  final String name;
  final List<TrackModel> tracks;
  final bool isLiked;

  const ShareCollectionDialog({
    super.key,
    required this.name,
    required this.tracks,
    required this.isLiked,
  });

  static Future<void> show(
    BuildContext context, {
    required String name,
    required List<TrackModel> tracks,
    bool isLiked = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          ShareCollectionDialog(name: name, tracks: tracks, isLiked: isLiked),
    );
  }

  @override
  State<ShareCollectionDialog> createState() => _ShareCollectionDialogState();
}

class _ShareCollectionDialogState extends State<ShareCollectionDialog> {
  late final String _code;
  bool _copied = false;
  bool _sharing = false;

  bool get _fitsQr =>
      _code.length <= PlaylistShareService.qrRecommendedMaxLength;

  @override
  void initState() {
    super.initState();
    _code = widget.isLiked
        ? PlaylistShareService.encodeLikedTracks(widget.tracks)
        : PlaylistShareService.encodePlaylist(
            name: widget.name,
            tracks: widget.tracks,
          );
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.surface,
        duration: Duration(seconds: 2),
        content: Text('Kode berbagi disalin ke papan klip.'),
      ),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  Future<void> _shareCode() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: PlaylistShareService.buildShareMessage(
            code: _code,
            isLiked: widget.isLiked,
            name: widget.name,
          ),
          subject: widget.isLiked
              ? 'Wave Music - Lagu Disukai'
              : 'Wave Music - ${widget.name}',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      // Jika share sheet tidak tersedia (mis. desktop), salin kode saja.
      await _copyCode();
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isLiked ? 'Bagikan Lagu Disukai' : 'Bagikan Playlist';
    final subtitle = widget.isLiked
        ? '${widget.tracks.length} lagu disukai'
        : '"${widget.name}" • ${widget.tracks.length} lagu';

    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
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
                      Icons.qr_code_2_rounded,
                      color: AppTheme.primaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
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
              if (_fitsQr) Center(child: _buildQr()) else _buildQrTooLarge(),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF22222A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF34343E)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    _code.length > 160
                        ? '${_code.substring(0, 160)}...'
                        : _code,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Kode ini berisi daftar lagu, bukan berkas audio. Tanpa server: '
                'siapa pun yang punya kode bisa mengimpornya. Lagu akan diputar '
                'dari YouTube seperti biasa.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      onPressed: _copyCode,
                      icon: Icon(
                        _copied ? Icons.check : Icons.copy_rounded,
                        size: 17,
                      ),
                      label: Text(
                        _copied ? 'Tersalin' : 'Salin Kode',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF484852)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      onPressed: _sharing ? null : _shareCode,
                      icon: _sharing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            )
                          : const Icon(Icons.ios_share, size: 17),
                      label: const Text('Bagikan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQr() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: QrImageView(
        data: _code,
        size: 240,
        padding: EdgeInsets.zero,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
        errorStateBuilder: (context, error) => const SizedBox(
          width: 240,
          height: 240,
          child: Center(
            child: Text(
              'QR gagal dibuat. Gunakan Salin atau Bagikan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrTooLarge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF34343E)),
      ),
      child: Column(
        children: [
          const Icon(Icons.qr_code_2_rounded, color: Colors.white38, size: 46),
          const SizedBox(height: 10),
          const Text(
            'Playlist ini terlalu besar untuk QR',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kode berisi ${_code.length} karakter. Gunakan tombol Salin Kode '
            'atau Bagikan, lalu tempel di aplikasi chat.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
