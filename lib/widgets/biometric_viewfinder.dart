import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// 🎯 Mathematically Smooth Biometric Oval HUD Painter
/// Eliminates straight/chopped borders by rendering a true Skia Ellipse with
/// spotlight vignette mask and futuristic HUD corner brackets.
class BiometricOvalPainter extends CustomPainter {
  final Color borderColor;
  final bool isVerified;
  final double pulseValue;
  final double? laserProgress;
  final double? customWidth;
  final double? customHeight;

  BiometricOvalPainter({
    required this.borderColor,
    required this.isVerified,
    this.pulseValue = 0.0,
    this.laserProgress,
    this.customWidth,
    this.customHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Dynamic oval sizing: True golden ratio face ellipse
    // Respects container bounds with ample breathing room
    final ovalWidth = customWidth ?? min(size.width * 0.60, 215.0);
    final ovalHeight = customHeight ?? min(size.height * 0.63, 275.0);
    final ovalRect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // 1. Spotlight Vignette: Dim the outside area so the face pops out
    final vignettePath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect);
    vignettePath.fillType = PathFillType.evenOdd;

    final vignettePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.62)
      ..style = PaintingStyle.fill;
    canvas.drawPath(vignettePath, vignettePaint);

    // 2. Neon Ambient Glow behind the primary stroke
    if (isVerified) {
      final glowWidth = 8.0 + (pulseValue * 4.0);
      final glowPaint = Paint()
        ..color = borderColor.withValues(alpha: 0.35 + (pulseValue * 0.15))
        ..style = PaintingStyle.stroke
        ..strokeWidth = glowWidth
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawOval(ovalRect, glowPaint);
    }

    // 3. Crisp Primary Ellipse Stroke (Zero flat edges)
    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isVerified ? 3.0 : 2.2;
    canvas.drawOval(ovalRect, strokePaint);

    // 4. Subtle Outer Track Ring
    final trackRect = Rect.fromCenter(
      center: center,
      width: ovalWidth + 18,
      height: ovalHeight + 18,
    );
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawOval(trackRect, trackPaint);

    // 5. Four Modern HUD Corner Brackets
    _drawCornerBrackets(
      canvas,
      center,
      (ovalWidth / 2) + 12,
      (ovalHeight / 2) + 12,
      borderColor,
    );

    // 6. Holographic Laser Scanning Line (Strictly clipped inside the oval)
    if (laserProgress != null) {
      final ovalPath = Path()..addOval(ovalRect);
      canvas.save();
      canvas.clipPath(ovalPath);

      final laserY = ovalRect.top + (ovalRect.height * laserProgress!.clamp(0.0, 1.0));
      final laserRect = Rect.fromLTWH(ovalRect.left, laserY - 3, ovalRect.width, 6);

      // Glow behind laser
      final laserGlowPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            borderColor.withValues(alpha: 0.5),
            borderColor,
            borderColor.withValues(alpha: 0.5),
            Colors.transparent,
          ],
        ).createShader(laserRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawLine(Offset(ovalRect.left, laserY), Offset(ovalRect.right, laserY), laserGlowPaint);

      // Sharp laser line
      final laserLinePaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.8),
            Colors.white,
            Colors.white.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ).createShader(laserRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(ovalRect.left, laserY), Offset(ovalRect.right, laserY), laserLinePaint);

      canvas.restore();
    }
  }

  void _drawCornerBrackets(
    Canvas canvas,
    Offset center,
    double rx,
    double ry,
    Color color,
  ) {
    final bracketPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    const arm = 14.0;

    // Top-Left
    canvas.drawLine(
      Offset(center.dx - rx, center.dy - ry + arm),
      Offset(center.dx - rx, center.dy - ry),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(center.dx - rx, center.dy - ry),
      Offset(center.dx - rx + arm, center.dy - ry),
      bracketPaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(center.dx + rx - arm, center.dy - ry),
      Offset(center.dx + rx, center.dy - ry),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(center.dx + rx, center.dy - ry),
      Offset(center.dx + rx, center.dy - ry + arm),
      bracketPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(center.dx - rx, center.dy + ry - arm),
      Offset(center.dx - rx, center.dy + ry),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(center.dx - rx, center.dy + ry),
      Offset(center.dx - rx + arm, center.dy + ry),
      bracketPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(center.dx + rx - arm, center.dy + ry),
      Offset(center.dx + rx, center.dy + ry),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(center.dx + rx, center.dy + ry),
      Offset(center.dx + rx, center.dy + ry - arm),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(BiometricOvalPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.isVerified != isVerified ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.laserProgress != laserProgress ||
        oldDelegate.customWidth != customWidth ||
        oldDelegate.customHeight != customHeight;
  }
}

/// 🌐 Futuristic Radar Concentric Rings for Biometric Review Card
class BiometricRadarBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.40);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final r in [65.0, 115.0, 168.0, 225.0, 285.0]) {
      canvas.drawCircle(center, r, linePaint);
    }

    // Subtle crosshairs
    final crossPaint = Paint()
      ..color = AppColors.cyanAccent.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(center.dx - 180, center.dy),
      Offset(center.dx + 180, center.dy),
      crossPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 180),
      Offset(center.dx, center.dy + 180),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
