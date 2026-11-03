import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';

class AttendanceSuccessDialog extends StatefulWidget {
  final AttendanceRecord record;
  final bool isAlreadyCheckedIn;
  final VoidCallback onDismiss;

  const AttendanceSuccessDialog({
    super.key,
    required this.record,
    this.isAlreadyCheckedIn = false,
    required this.onDismiss,
  });

  @override
  State<AttendanceSuccessDialog> createState() => _AttendanceSuccessDialogState();
}

class _AttendanceSuccessDialogState extends State<AttendanceSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _countdownController;

  @override
  void initState() {
    super.initState();
    // 2.5 second auto-dismiss countdown for zero-touch attendance flow
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
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
    final record = widget.record;
    final timeStr = DateFormat('hh:mm:ss a').format(record.timestamp);
    final matchPercent = (record.confidenceScore * 100).toInt();

    // Color theme
    final Color accentColor = widget.isAlreadyCheckedIn
        ? const Color(0xFF38BDF8) // Neon Sky Blue
        : AppColors.emeraldGreen;

    final Color glowColor = accentColor.withValues(alpha: 0.35);

    // Look up avatar from registered staff
    final attendanceService = context.read<AttendanceService>();
    final user = attendanceService.users
        .where((u) => u.id == record.employeeId)
        .firstOrNull;
    final avatarBase64 = user?.avatarBase64;

    Uint8List? avatarBytes;
    try {
      if (avatarBase64 != null && avatarBase64.isNotEmpty) {
        avatarBytes = base64Decode(avatarBase64);
      }
    } catch (_) {
      avatarBytes = null;
    }

    final initialLetter = record.employeeName.isNotEmpty
        ? record.employeeName.substring(0, 1).toUpperCase()
        : 'U';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
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
              border: Border.all(color: accentColor.withValues(alpha: 0.7), width: 1.8),
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
                  // Animated Avatar with Dynamic Countdown Ring
                  AnimatedBuilder(
                    animation: _countdownController,
                    builder: (context, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Countdown Track
                          SizedBox(
                            width: 96,
                            height: 96,
                            child: CircularProgressIndicator(
                              value: 1.0 - _countdownController.value,
                              strokeWidth: 3.5,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                            ),
                          ),

                          // Avatar / Monogram with checkmark badge
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF1E293B),
                                  border: Border.all(
                                    color: accentColor,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(2.5),
                                child: ClipOval(
                                  child: avatarBytes != null
                                      ? Image.memory(
                                          avatarBytes,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) =>
                                              _buildMonogram(initialLetter, accentColor),
                                        )
                                      : _buildMonogram(initialLetter, accentColor),
                                ),
                              ),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF131D31),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withValues(alpha: 0.5),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  widget.isAlreadyCheckedIn
                                      ? Icons.done_all_rounded
                                      : Icons.check,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // Pill Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isAlreadyCheckedIn
                              ? Icons.verified_user_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 14,
                          color: accentColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.isAlreadyCheckedIn
                              ? 'ALREADY CHECKED IN'
                              : 'TOUCHLESS PUNCH VERIFIED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Staff Name
                  Text(
                    record.employeeName,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 4),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCardLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          record.employeeCode,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.cyanAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        record.role,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  // Notice Box for Already Checked In
                  if (widget.isAlreadyCheckedIn) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Attendance was already recorded at $timeStr today. Have a great day!',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFBAE6FD),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Modern Verification Metrics Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18233C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Punch Time
                        Column(
                          children: [
                            Text(
                              widget.isAlreadyCheckedIn ? 'CHECKED IN' : 'PUNCH TIME',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),

                        Container(height: 26, width: 1, color: AppColors.border),

                        // Accuracy Score
                        Column(
                          children: [
                            const Text(
                              'SIMILARITY',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fingerprint_rounded, size: 14, color: accentColor),
                                const SizedBox(width: 4),
                                Text(
                                  '$matchPercent%',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        Container(height: 26, width: 1, color: AppColors.border),

                        // Status
                        Column(
                          children: [
                            const Text(
                              'DUTY STATUS',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              record.status,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: record.status == 'LATE'
                                    ? AppColors.amberWarning
                                    : AppColors.emeraldGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tactile Next Person / Done Button
                  AnimatedBuilder(
                    animation: _countdownController,
                    builder: (context, _) {
                      final remaining = (2.5 * (1.0 - _countdownController.value)).ceil();
                      return Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: widget.isAlreadyCheckedIn
                              ? const LinearGradient(
                                  colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (widget.isAlreadyCheckedIn
                                      ? const Color(0xFF0EA5E9)
                                      : const Color(0xFF10B981))
                                  .withValues(alpha: 0.40),
                              blurRadius: 18,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onDismiss,
                            borderRadius: BorderRadius.circular(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.isAlreadyCheckedIn
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.done_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.isAlreadyCheckedIn ? 'Got it' : 'Next Person',
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${remaining}s',
                                    style: const TextStyle(
                                      fontSize: 12,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonogram(String letter, Color accent) {
    return Container(
      color: accent.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: accent,
        ),
      ),
    );
  }
}
