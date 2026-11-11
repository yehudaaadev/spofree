import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VinylDiscWidget extends StatefulWidget {
  final String artworkUrl;
  final bool isPlaying;
  final double size;

  const VinylDiscWidget({
    super.key,
    required this.artworkUrl,
    required this.isPlaying,
    this.size = 280.0,
  });

  @override
  State<VinylDiscWidget> createState() => _VinylDiscWidgetState();
}

class _VinylDiscWidgetState extends State<VinylDiscWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VinylDiscWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discSize = widget.size;
    final centerArtSize = discSize * 0.44;

    return Center(
      child: AnimatedBuilder(
        animation: _rotationController,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationController.value * 2 * math.pi,
            child: child,
          );
        },
        child: Container(
          width: discSize,
          height: discSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF101010),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 30,
                spreadRadius: 4,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(discSize, discSize),
                painter: _VinylGroovesPainter(),
              ),
              Container(
                width: centerArtSize,
                height: centerArtSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: ClipOval(
                  child: widget.artworkUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.artworkUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            color: AppTheme.card,
                            child: const Icon(Icons.music_note, color: Colors.white38),
                          ),
                          errorWidget: (_, _, _) => Container(
                            color: AppTheme.card,
                            child: const Icon(Icons.music_note, color: Colors.white38),
                          ),
                        )
                      : Container(
                          color: AppTheme.card,
                          child: const Icon(Icons.music_note, color: Colors.white38),
                        ),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF121212),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final groovePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (double r = maxRadius * 0.52; r < maxRadius - 6; r += 7.0) {
      canvas.drawCircle(center, r, groovePaint);
    }

    canvas.drawCircle(center, maxRadius * 0.65, highlightPaint);
    canvas.drawCircle(center, maxRadius * 0.82, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
