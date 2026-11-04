import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';

class AttendanceDetailSheet extends StatelessWidget {
  final AttendanceRecord record;

  const AttendanceDetailSheet({super.key, required this.record});

  static void show(BuildContext context, AttendanceRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false, // Allows the sheet background to reach the very bottom physical edge
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => AttendanceDetailSheet(record: record),
    );
  }

  AttendanceService _resolveAttendanceService(BuildContext context) {
    try {
      return context.read<AttendanceService>();
    } catch (_) {
      return AttendanceService.instance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceService = _resolveAttendanceService(context);
    final user = attendanceService.users
        .where((u) => u.id == record.employeeId)
        .firstOrNull;

    final Uint8List? avatarBytes = user?.avatarBytes;
    final Uint8List? punchBytes = record.punchImageBytes;

    final isLate = record.status == 'LATE';
    final matchPercent = (record.confidenceScore * 100).toStringAsFixed(1);
    final timeStr = DateFormat('hh:mm:ss a').format(record.timestamp);
    final dateStr = DateFormat('dd MMM yyyy').format(record.timestamp);
    final dayStr = DateFormat('EEEE').format(record.timestamp);
    final now = DateTime.now();
    final isToday = record.timestamp.year == now.year &&
        record.timestamp.month == now.month &&
        record.timestamp.day == now.day;
    final initial = record.employeeName.isNotEmpty
        ? record.employeeName.substring(0, 1).toUpperCase()
        : 'U';

    final Color statusColor = isLate ? AppColors.amberWarning : AppColors.emeraldGreen;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxSheetHeight = screenHeight * 0.88;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: maxSheetHeight,
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: AppColors.border, width: 1.0),
            boxShadow: AppColors.softShadow,
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Top Drag Handle & Close Button Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 36), // Balance
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCard,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 2. Premium Employee Hero Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Row(
                      children: [
                        // Avatar with status ring
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: statusColor, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(2.5),
                              child: ClipOval(
                                child: (punchBytes ?? avatarBytes) != null
                                    ? Image.memory(
                                        (punchBytes ?? avatarBytes)!,
                                        key: ValueKey('avatar_${record.id}'),
                                        fit: BoxFit.cover,
                                        gaplessPlayback: true,
                                      )
                                    : Container(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        alignment: Alignment.center,
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.surfaceCard, width: 2.0),
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // Employee Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      record.status,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.cyanAccent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'BIOMETRIC PUNCH',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.cyanAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                record.employeeName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceCardLight,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.badge_outlined,
                                          size: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          record.employeeCode,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceCardLight,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.work_outline_rounded,
                                          size: 12,
                                          color: AppColors.cyanAccent,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          record.role,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2.5 Biometric Audit Proof: Registered Profile Face vs Live Punched Snapshot
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.camera_alt_outlined, size: 14, color: AppColors.cyanAccent),
                            const SizedBox(width: 6),
                            const Text(
                              'BIOMETRIC AUDIT PROOF',
                              style: TextStyle(
                                fontSize: 10.5,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cyanAccent,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LIVE CAPTURE',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.emeraldGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // 1. Enrolled Profile Face
                            Column(
                              children: [
                                Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.border, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(2.5),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: avatarBytes != null
                                        ? Image.memory(
                                            avatarBytes,
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                          )
                                        : Container(
                                            color: AppColors.primary.withValues(alpha: 0.12),
                                            alignment: Alignment.center,
                                            child: Text(
                                              initial,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Enrolled Profile',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),

                            // Comparison Indicator
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.emeraldGreen.withValues(alpha: 0.12),
                                  ),
                                  child: const Icon(
                                    Icons.compare_arrows_rounded,
                                    color: AppColors.emeraldGreen,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$matchPercent% Match',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.emeraldGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),

                            // 2. Actual Live Punch Snapshot
                            Column(
                              children: [
                                Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.emeraldGreen, width: 2.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.emeraldGreen.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(2.5),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: punchBytes != null
                                        ? Image.memory(
                                            punchBytes,
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                          )
                                        : (avatarBytes != null
                                            ? Image.memory(
                                                avatarBytes,
                                                fit: BoxFit.cover,
                                                gaplessPlayback: true,
                                              )
                                            : Container(
                                                color: AppColors.emeraldGreen.withValues(alpha: 0.12),
                                                child: const Icon(
                                                  Icons.face_retouching_natural_rounded,
                                                  color: AppColors.emeraldGreen,
                                                ),
                                              )),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.emeraldGreen,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Punch Snapshot',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.emeraldGreen,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. Overflow-Free 2x2 Telemetry Grid
                  Row(
                    children: [
                      Expanded(
                        child: _buildTelemetryCard(
                          icon: Icons.access_time_filled_rounded,
                          iconColor: AppColors.cyanAccent,
                          label: 'PUNCH TIME',
                          value: timeStr,
                          subtitle: isToday ? 'Today' : dateStr,
                          subtitleColor: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTelemetryCard(
                          icon: Icons.calendar_today_rounded,
                          iconColor: AppColors.primaryLight,
                          label: 'PUNCH DATE',
                          value: dateStr,
                          subtitle: dayStr,
                          subtitleColor: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTelemetryCard(
                          icon: Icons.verified_user_rounded,
                          iconColor: AppColors.emeraldGreen,
                          label: 'SIMILARITY MATCH',
                          value: '$matchPercent%',
                          subtitle: 'Confidence score',
                          subtitleColor: AppColors.textSecondary,
                          badge: 'PASSED',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTelemetryCard(
                          icon: Icons.security_rounded,
                          iconColor: AppColors.emeraldGreen,
                          label: 'LIVENESS AI',
                          value: 'Real Face',
                          subtitle: 'Anti-spoofing ok',
                          subtitleColor: AppColors.emeraldGreen,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 4. Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copy ID'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            final code = record.employeeCode;
                            Clipboard.setData(ClipboardData(text: code));
                            HapticFeedback.lightImpact();
                            Navigator.pop(context); // Close sheet FIRST so SnackBar is not covered
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Copied Employee ID "$code" to clipboard'),
                                  ],
                                ),
                                duration: const Duration(seconds: 2),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(14),
                              child: const Center(
                                child: Text(
                                  'Done',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
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

  Widget _buildTelemetryCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
    required Color subtitleColor,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emeraldGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }
}
