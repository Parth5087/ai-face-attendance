import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../screens/registration/register_staff_screen.dart';

class AttendanceUnrecognizedDialog extends StatefulWidget {
  final double? closestSimilarity;
  final String? closestCandidateName;
  final VoidCallback onDismiss;

  const AttendanceUnrecognizedDialog({
    super.key,
    this.closestSimilarity,
    this.closestCandidateName,
    required this.onDismiss,
  });

  @override
  State<AttendanceUnrecognizedDialog> createState() =>
      _AttendanceUnrecognizedDialogState();
}

class _AttendanceUnrecognizedDialogState
    extends State<AttendanceUnrecognizedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _countdownController;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();

    // 3.0-second zero-touch auto-dismiss
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();

    _countdownController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _countdownController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFEF4444); // Crimson Rose
    final glowColor = const Color(0xFFEF4444).withValues(alpha: 0.35);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 390),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            decoration: BoxDecoration(
              color: const Color(0xFF131D31).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: accentColor.withValues(alpha: 0.65), width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 36,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.75),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Biometric Alert Icon with Countdown Ring
                  AnimatedBuilder(
                    animation: _countdownController,
                    builder: (context, child) {
                      return SizedBox(
                        width: 82,
                        height: 82,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: CircularProgressIndicator(
                                value: 1.0 - _countdownController.value,
                                strokeWidth: 3.5,
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  accentColor,
                                ),
                              ),
                            ),
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor.withValues(alpha: 0.16),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.6),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.face_retouching_off_rounded,
                                color: accentColor,
                                size: 32,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Pill Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 13, color: accentColor),
                        SizedBox(width: 5),
                        Text(
                          'UNREGISTERED FACE',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Main Title
                  const Text(
                    'Face Not Recognized',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Explanation Description
                  Text(
                    'No matching employee profile was detected in the local directory. Please align your face inside the oval guide or register as a new employee.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),

                  if (widget.closestSimilarity != null &&
                      widget.closestSimilarity! > 0.40) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Highest similarity: ${(widget.closestSimilarity! * 100).toStringAsFixed(1)}% (Need ≥ 68%)',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Action Buttons Row
                  Row(
                    children: [
                      // Direct Enroll Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            widget.onDismiss();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterStaffScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: AppColors.cyanAccent.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Enroll Face',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.cyanAccent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Dismiss / Got It Button
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _countdownController,
                          builder: (context, _) {
                            final remaining =
                                (3.0 * (1.0 - _countdownController.value)).ceil().clamp(1, 3);

                            return Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: widget.onDismiss,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Dismiss',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${remaining}s',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
