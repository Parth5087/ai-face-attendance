import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class FaceIdRingPainter extends CustomPainter {
  final Set<int> completedTicks;
  final int totalTicks;
  final double currentAngleRad; // User's active head direction in radians
  final bool hasActivePointer;
  final bool isCompleted;
  final double pulseValue;

  FaceIdRingPainter({
    required this.completedTicks,
    this.totalTicks = 48,
    this.currentAngleRad = 0.0,
    this.hasActivePointer = false,
    this.isCompleted = false,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (min(size.width, size.height) / 2) - 26;

    // 1. Subtle Outer Track Guide Ring
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, baseRadius + 1, trackPaint);

    final outerTrackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, baseRadius + 18, outerTrackPaint);

    // 2. Render all radial Apple Face ID Capsules
    for (int i = 0; i < totalTicks; i++) {
      // Angle starting from top (-pi / 2)
      final theta = (-pi / 2) + (2 * pi * i / totalTicks);
      final isDone = isCompleted || completedTicks.contains(i);

      double innerR = baseRadius;
      double tickLen = 13.0;
      double strokeWidth = 2.2;
      Color tickColor;

      if (isDone) {
        // Completed Apple Face ID Capsule: slightly elongated & emerald glowing
        tickLen = 17.5;
        strokeWidth = 3.6;
        tickColor = AppColors.emeraldGreen;
      } else {
        // Idle/Unfilled Capsule: clean, modern subtle translucent
        tickColor = Colors.white.withValues(alpha: 0.18);
      }

      final paint = Paint()
        ..color = tickColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final p1 = Offset(
        center.dx + innerR * cos(theta),
        center.dy + innerR * sin(theta),
      );
      final p2 = Offset(
        center.dx + (innerR + tickLen) * cos(theta),
        center.dy + (innerR + tickLen) * sin(theta),
      );

      canvas.drawLine(p1, p2, paint);
    }

    // 3. Active Direction Pointer (Gently shows user where their head is aiming)
    if (hasActivePointer && !isCompleted) {
      final pointerP1 = Offset(
        center.dx + (baseRadius - 2) * cos(currentAngleRad),
        center.dy + (baseRadius - 2) * sin(currentAngleRad),
      );
      final pointerP2 = Offset(
        center.dx + (baseRadius + 20) * cos(currentAngleRad),
        center.dy + (baseRadius + 20) * sin(currentAngleRad),
      );

      final pointerPaint = Paint()
        ..color = AppColors.cyanAccent
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

      canvas.drawLine(pointerP1, pointerP2, pointerPaint);
    }

    // 4. Sleek Circular Viewfinder Inner Border with glow
    final borderPaint = Paint()
      ..color = isCompleted
          ? AppColors.emeraldGreen
          : (completedTicks.isNotEmpty
              ? AppColors.cyanAccent.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(center, baseRadius - 6, borderPaint);

    // Subtle ambient glow when completed
    if (isCompleted) {
      final glowPaint = Paint()
        ..color = AppColors.emeraldGreen.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

      canvas.drawCircle(center, baseRadius - 6, glowPaint);
    }
  }

  @override
  bool shouldRepaint(FaceIdRingPainter oldDelegate) {
    return oldDelegate.completedTicks.length != completedTicks.length ||
        oldDelegate.isCompleted != isCompleted ||
        oldDelegate.currentAngleRad != currentAngleRad ||
        oldDelegate.hasActivePointer != hasActivePointer ||
        oldDelegate.pulseValue != pulseValue;
  }
}
