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

  AttendanceService _resolveAttendanceService(BuildContext context) {
    try {
      return context.read<AttendanceService>();
    } catch (_) {
      return AttendanceService.instance;
    }
  }

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
    final attendanceService = _resolveAttendanceService(context);
    final user = attendanceService.users
        .where((u) => u.id == record.employeeId)
        .firstOrNull;

    final Uint8List? avatarBytes = user?.avatarBytes;
    final photoBytes = record.punchImageBytes ?? avatarBytes;
    final bool isLiveSnapshot = record.punchImageBytes != null;

    final initial = record.employeeName.isNotEmpty
        ? record.employeeName.substring(0, 1).toUpperCase()
        : 'U';

    final Color statusColor = isLate ? AppColors.amberWarning : AppColors.emeraldGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
          width: 1.0,
        ),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => AttendanceDetailSheet.show(context, record),
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar / Profile Photo (Live punch snapshot if available)
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: isLiveSnapshot
                              ? AppColors.emeraldGreen.withValues(alpha: 0.6)
                              : AppColors.border,
                          width: isLiveSnapshot ? 1.5 : 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(2.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: photoBytes != null
                            ? Image.memory(
                                photoBytes,
                                key: ValueKey('tile_avatar_${record.id}'),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              )
                            : Container(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                alignment: Alignment.center,
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surfaceCard, width: 1.8),
                      ),
                      child: isLiveSnapshot
                          ? const Icon(
                              Icons.camera_alt,
                              size: 7,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Name & Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              record.employeeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.cyanAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
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
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              record.role,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$matchPercent% match',
                            style: TextStyle(
                              fontSize: 11,
                              color: matchPercent >= 85
                                  ? AppColors.emeraldGreen
                                  : AppColors.amberWarning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Time & Status Pill (Clean 2-line right alignment)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isToday ? timeStr : '$dateDisplay, $timeStr',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.30),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        isLate ? 'Late' : 'Verified',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
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
    );
  }
}
