import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SoundwaveDPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  SoundwaveDPainter({
    this.primaryColor = AppTheme.primaryRose,
    this.secondaryColor = AppTheme.primaryRoseLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Linear gradient for soundwaves
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, secondaryColor],
    );
    final shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h));

    // 1. Left Vertical Spine of 'D'
    final spinePaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;

    final spineWidth = w * 0.14;
    final spineX = w * 0.16;
    final spineYTop = h * 0.16;
    final spineYBottom = h * 0.84;
    final spineHeight = spineYBottom - spineYTop;

    final spineRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(spineX, spineYTop, spineWidth, spineHeight),
      Radius.circular(spineWidth / 2),
    );
    canvas.drawRRect(spineRRect, spinePaint);

    // 2. Three Concentric Soundwave Arcs forming the curved lobe of 'D'
    final strokeWidth = w * 0.11;
    final arcPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startX = spineX + spineWidth + (strokeWidth * 0.4);

    // Outer Arc
    final outerPath = Path();
    outerPath.moveTo(startX, spineYTop + (strokeWidth * 0.5));
    outerPath.cubicTo(
      w * 0.92, spineYTop,
      w * 0.92, spineYBottom,
      startX, spineYBottom - (strokeWidth * 0.5),
    );
    canvas.drawPath(outerPath, arcPaint);

    // Middle Arc
    final midPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.88
      ..strokeCap = StrokeCap.round;

    final midOffsetY = spineHeight * 0.16;
    final midPath = Path();
    midPath.moveTo(startX, spineYTop + midOffsetY);
    midPath.cubicTo(
      w * 0.74, spineYTop + (midOffsetY * 0.8),
      w * 0.74, spineYBottom - (midOffsetY * 0.8),
      startX, spineYBottom - midOffsetY,
    );
    canvas.drawPath(midPath, midPaint);

    // Inner Arc
    final innerPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.76
      ..strokeCap = StrokeCap.round;

    final innerOffsetY = spineHeight * 0.30;
    final innerPath = Path();
    innerPath.moveTo(startX, spineYTop + innerOffsetY);
    innerPath.cubicTo(
      w * 0.58, spineYTop + (innerOffsetY * 0.9),
      w * 0.58, spineYBottom - (innerOffsetY * 0.9),
      startX, spineYBottom - innerOffsetY,
    );
    canvas.drawPath(innerPath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final double textSize;
  final bool isVertical;

  const AppLogo({
    super.key,
    this.size = 64,
    this.showText = true,
    this.textSize = 22,
    this.isVertical = true,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.25),
            blurRadius: size * 0.35,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.18),
        child: CustomPaint(
          size: Size(size * 0.64, size * 0.64),
          painter: SoundwaveDPainter(),
        ),
      ),
    );

    if (!showText) {
      return iconWidget;
    }

    final textWidget = RichText(
      textAlign: isVertical ? TextAlign.center : TextAlign.start,
      text: TextSpan(
        style: GoogleFonts.plusJakartaSans(
          fontSize: textSize,
          letterSpacing: 1.5,
        ),
        children: const [
          TextSpan(
            text: 'WAVE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          TextSpan(
            text: ' MUSIC',
            style: TextStyle(
              fontWeight: FontWeight.w300,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
    );

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          SizedBox(height: size * 0.2),
          textWidget,
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 14),
          textWidget,
        ],
      );
    }
  }
}
