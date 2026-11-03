import 'dart:convert';
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => AttendanceDetailSheet(record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceService = context.read<AttendanceService>();
    final user = attendanceService.users
        .where((u) => u.id == record.employeeId)
        .firstOrNull;

    Uint8List? avatarBytes;
    try {
      if (user?.avatarBase64 != null && user!.avatarBase64!.isNotEmpty) {
        avatarBytes = base64Decode(user.avatarBase64!);
      }
    } catch (_) {
      avatarBytes = null;
    }

    final isLate = record.status == 'LATE';
    final matchPercent = (record.confidenceScore * 100).toStringAsFixed(1);
    final timeStr = DateFormat('hh:mm:ss a').format(record.timestamp);
    final dateStr = DateFormat('EEEE, dd MMMM yyyy').format(record.timestamp);
    final initial = record.employeeName.isNotEmpty
        ? record.employeeName.substring(0, 1).toUpperCase()
        : 'U';

    final Color statusColor = isLate ? AppColors.amberWarning : AppColors.emeraldGreen;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),

              // Employee Profile Section
              Row(
                children: [
                  // Avatar with status ring
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          statusColor,
                          statusColor.withValues(alpha: 0.3),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.25),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: avatarBytes != null
                          ? Image.memory(avatarBytes, fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                initial,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Name & Code
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.employeeName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cyanAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.cyanAccent.withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                record.employeeCode,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.cyanAccent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                record.role,
                                style: const TextStyle(
                                  fontSize: 13,
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

                  // Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          record.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 20),

              // Verification Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF18233C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      icon: Icons.access_time_rounded,
                      iconColor: AppColors.cyanAccent,
                      label: 'Punch Time',
                      value: timeStr,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Color(0xFF263352), height: 1),
                    ),
                    _buildDetailRow(
                      icon: Icons.calendar_today_rounded,
                      iconColor: const Color(0xFF818CF8),
                      label: 'Date',
                      value: dateStr,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Color(0xFF263352), height: 1),
                    ),
                    _buildDetailRow(
                      icon: Icons.fingerprint_rounded,
                      iconColor: AppColors.emeraldGreen,
                      label: 'Biometric Match',
                      value: '$matchPercent% Similarity',
                      trailingWidget: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PASSED',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.emeraldGreen,
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Color(0xFF263352), height: 1),
                    ),
                    _buildDetailRow(
                      icon: Icons.security_rounded,
                      iconColor: const Color(0xFF38BDF8),
                      label: 'Liveness & Anti-Spoof',
                      value: 'Active Blink Verified',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Action Buttons
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
                        Clipboard.setData(ClipboardData(text: record.employeeCode));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${record.employeeCode} to clipboard'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Widget? trailingWidget,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (trailingWidget != null) ...[
          const SizedBox(width: 6),
          trailingWidget,
        ],
      ],
    );
  }
}
