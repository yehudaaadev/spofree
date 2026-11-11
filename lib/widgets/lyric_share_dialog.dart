import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/track_model.dart';
import '../theme/app_theme.dart';

class LyricShareDialog extends StatelessWidget {
  final TrackModel track;
  final String lyricText;
  final Color ambientColor;

  const LyricShareDialog({
    super.key,
    required this.track,
    required this.lyricText,
    required this.ambientColor,
  });

  static void show(BuildContext context, {
    required TrackModel track,
    required String lyricText,
    required Color ambientColor,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => LyricShareDialog(
        track: track,
        lyricText: lyricText,
        ambientColor: ambientColor,
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final textToCopy = '"$lyricText"\n\n— ${track.title} oleh ${track.artist} (Wave Music)';
    Clipboard.setData(ClipboardData(text: textToCopy));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kutipan lirik disalin ke papan klip!'),
        backgroundColor: AppTheme.primaryGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ambientColor.withValues(alpha: 0.95),
                  const Color(0xFF181818),
                  Colors.black,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: track.artworkUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: track.artworkUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                width: 48,
                                height: 48,
                                color: AppTheme.card,
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              color: AppTheme.card,
                              child: const Icon(Icons.music_note, color: Colors.white54),
                            ),
                    ),
                    const SizedBox(width: 12),
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
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  '“',
                  style: TextStyle(
                    fontSize: 36,
                    height: 0.8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38,
                  ),
                ),
                Text(
                  lyricText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.35,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.graphic_eq, color: AppTheme.primaryGreen, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Wave Music',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Kutipan Lirik',
                      style: TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Batal', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Salin Kutipan', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _copyToClipboard(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
