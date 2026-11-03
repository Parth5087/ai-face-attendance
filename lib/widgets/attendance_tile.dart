import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/attendance_record.dart';
import '../services/attendance_service.dart';
import 'attendance_detail_sheet.dart';

class AttendanceTile extends StatelessWidget {
  final AttendanceRecord record;
  final VoidCallback? onTap;

  const AttendanceTile({
    super.key,
    required this.record,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(record.timestamp);
    final isLate = record.status == 'LATE';
    final matchPercent = (record.confidenceScore * 100).toInt();

    // Date formatting
    final now = DateTime.now();
    final isToday = record.timestamp.year == now.year &&
        record.timestamp.month == now.month &&
        record.timestamp.day == now.day;
    final dateDisplay = isToday ? 'Today' : DateFormat('dd MMM').format(record.timestamp);

    // Look up user avatar if available
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

    final initial = record.employeeName.isNotEmpty
        ? record.employeeName.substring(0, 1).toUpperCase()
        : 'U';

    final Color statusColor = isLate ? AppColors.amberWarning : AppColors.emeraldGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF162238),
            const Color(0xFF0F1827).withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLate
              ? AppColors.amberWarning.withValues(alpha: 0.25)
              : AppColors.cyanAccent.withValues(alpha: 0.16),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          if (!isLate)
            BoxShadow(
              color: AppColors.cyanAccent.withValues(alpha: 0.04),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => AttendanceDetailSheet.show(context, record),
          borderRadius: BorderRadius.circular(20),
          splashColor: statusColor.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.03),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                // Avatar with presence / status badge
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withValues(alpha: 0.6),
                            statusColor.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(2.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF0E1726),
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: avatarBytes != null
                            ? Image.memory(
                                avatarBytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                cacheWidth: 96,
                                cacheHeight: 96,
                                errorBuilder: (ctx, err, stack) =>
                                    _buildLetter(initial, statusColor),
                              )
                            : _buildLetter(initial, statusColor),
                      ),
                    ),

                    // Status Micro Badge
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0F1827),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isLate ? Icons.access_time_rounded : Icons.check_rounded,
                        size: 9.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Employee Name, Code & Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              record.employeeName,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  record.status,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceCardLight,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              record.employeeCode,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cyanAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              record.role,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Time, Date & Confidence
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dateDisplay,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$matchPercent%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLetter(String letter, Color color) {
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: color,
          fontSize: 17,
        ),
      ),
    );
  }
}
