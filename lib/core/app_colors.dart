import 'package:flutter/material.dart';

class AppColors {
  // Brand Backgrounds
  static const Color background = Color(0xFF0A0E1A);
  static const Color surface = Color(0xFF131B2E);
  static const Color surfaceCard = Color(0xFF1A233A);
  static const Color surfaceCardLight = Color(0xFF222E4C);

  // Brand Accents
  static const Color primary = Color(0xFF4F46E5); // Indigo Royal
  static const Color primaryLight = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF3730A3);

  // Modern Neon Accents for Biometric Radar / Scanners
  static const Color cyanAccent = Color(0xFF00E5FF);
  static const Color cyanGlow = Color(0x3300E5FF);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color roseError = Color(0xFFEF4444);

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Borders & Dividers
  static const Color border = Color(0xFF263352);
  static const Color borderLight = Color(0xFF334155);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient scannerGradient = LinearGradient(
    colors: [Colors.transparent, Color(0x8000E5FF), Color(0xFF00E5FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF192238), Color(0xFF121829)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Reusable Elevation Shadows for Cards
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.50),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}
