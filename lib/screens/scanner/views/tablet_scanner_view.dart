import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/app_colors.dart';
import '../../../models/attendance_record.dart';
import '../../../services/attendance_service.dart';
import '../../../widgets/attendance_tile.dart';
import '../../../widgets/biometric_viewfinder.dart';
import '../../../widgets/kiosk_mode_switcher.dart';

/// 📟 TABLET KIOSK VIEW (>= 600px - Wall-Mounted Dual Pane Terminal)
/// 65% Left: Live Camera Viewport with Cyber Tech-Box Guide & Floating HUD
/// 35% Right: Real-time Digital Clock, Today's Metric Counters & Live Punch Feed
class TabletScannerView extends StatelessWidget {
  final CameraController? cameraController;
  final bool isCamReady;
  final Animation<double> scannerAnimation;
  final DateTime currentKioskTime;
  final String checkType;
  final bool isVerifying;
  final AttendanceRecord? lastPunchResult;
  final bool lastPunchIsAlreadyCheckedIn;
  final bool lastPunchIsAlreadyCheckedOut;
  final bool lastPunchNoCheckIn;
  final String? lastPunchCandidateName;
  final bool blinkDetected;
  final Color statusColor;
  final String statusText;
  final AttendanceService attendanceService;
  final bool canSwitchCamera;
  final VoidCallback onExit;
  final VoidCallback onToggleCamera;
  final ValueChanged<String> onSwitchCheckType;

  const TabletScannerView({
    super.key,
    required this.cameraController,
    required this.isCamReady,
    required this.scannerAnimation,
    required this.currentKioskTime,
    required this.checkType,
    required this.isVerifying,
    required this.lastPunchResult,
    required this.lastPunchIsAlreadyCheckedIn,
    required this.lastPunchIsAlreadyCheckedOut,
    required this.lastPunchNoCheckIn,
    required this.lastPunchCandidateName,
    required this.blinkDetected,
    required this.statusColor,
    required this.statusText,
    required this.attendanceService,
    required this.canSwitchCamera,
    required this.onExit,
    required this.onToggleCamera,
    required this.onSwitchCheckType,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm:ss a').format(currentKioskTime);
    final dateStr = DateFormat('EEEE, MMMM dd, yyyy').format(currentKioskTime);

    return SafeArea(
      child: Row(
        children: [
          // =================================================================
          // LEFT PANE (65%): Live Camera Stream + Biometric Detection Ring
          // =================================================================
          Expanded(
            flex: 65,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.black,
                border: Border.all(color: AppColors.border, width: 1.5),
                boxShadow: AppColors.softShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22.5),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 1. Live Camera Stream
                    if (isCamReady && cameraController != null)
                      FittedBox(
                        fit: BoxFit.cover,
                        clipBehavior: Clip.hardEdge,
                        child: SizedBox(
                          width: MediaQuery.of(context).orientation == Orientation.landscape
                              ? (cameraController!.value.previewSize?.width ?? 1280)
                              : (cameraController!.value.previewSize?.height ?? 720),
                          height: MediaQuery.of(context).orientation == Orientation.landscape
                              ? (cameraController!.value.previewSize?.height ?? 720)
                              : (cameraController!.value.previewSize?.width ?? 1280),
                          child: CameraPreview(cameraController!),
                        ),
                      )
                    else
                      const Center(
                        child: CircularProgressIndicator(color: AppColors.cyanAccent),
                      ),

                    // 2. Biometric Tech-Box Viewfinder Guide
                    if (isCamReady)
                      AnimatedBuilder(
                        animation: scannerAnimation,
                        builder: (context, _) {
                          final Color defaultColor = checkType == 'IN'
                              ? AppColors.cyanAccent
                              : const Color(0xFFF59E0B);
                          final Color activeColor = checkType == 'IN'
                              ? AppColors.emeraldGreen
                              : const Color(0xFFEA580C);

                          final Color boxColor = isVerifying || lastPunchResult != null
                              ? ((lastPunchIsAlreadyCheckedIn || lastPunchIsAlreadyCheckedOut)
                                  ? AppColors.cyanAccent
                                  : activeColor)
                              : (blinkDetected
                                  ? activeColor
                                  : (statusColor == AppColors.amberWarning
                                      ? AppColors.amberWarning
                                      : defaultColor));

                          return CustomPaint(
                            painter: BiometricTechBoxPainter(
                              borderColor: boxColor,
                              isVerified: blinkDetected || isVerifying,
                              pulseValue: scannerAnimation.value,
                              laserProgress: isVerifying ? 0.5 : scannerAnimation.value,
                              customWidth: 440,
                              customHeight: 480,
                              verticalOffset: 0.0,
                              cornerRadius: 28.0,
                            ),
                          );
                        },
                      ),

                    // 3. Top Pane Bar: Admin Mode / Exit Button, Mode Switcher & Camera Toggle
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildAdminExitButton(context),
                          KioskModeSwitcher(
                            checkType: checkType,
                            onSwitch: onSwitchCheckType,
                            isTablet: true,
                          ),
                          if (canSwitchCamera)
                            ClipOval(
                              child: Material(
                                color: Colors.black.withValues(alpha: 0.55),
                                child: InkWell(
                                  onTap: onToggleCamera,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.flip_camera_ios_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 44),
                        ],
                      ),
                    ),

                    // 4. Bottom Live Guidance Pill OR Floating Verification HUD Card
                    Positioned(
                      bottom: 16,
                      left: 20,
                      right: 20,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: (lastPunchResult != null || lastPunchNoCheckIn)
                            ? _buildFloatingCameraKioskCard(
                                lastPunchResult,
                                isAlreadyCheckedIn: lastPunchIsAlreadyCheckedIn,
                                isAlreadyCheckedOut: lastPunchIsAlreadyCheckedOut,
                                isNoCheckInFound: lastPunchNoCheckIn,
                                candidateName: lastPunchCandidateName,
                              )
                            : Container(
                                key: const ValueKey('idle_pill'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withValues(alpha: 0.90),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.7),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: statusColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        statusText,
                                        style: const TextStyle(
                                          fontFamily: AppFonts.bold,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // =================================================================
          // RIGHT PANE (35%): Permanent Live Kiosk Console
          // =================================================================
          Expanded(
            flex: 35,
            child: Container(
              margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border, width: 1.0),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Office Header & Branding
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.face_retouching_natural_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI FACE',
                              style: TextStyle(
                                fontFamily: AppFonts.bold,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              'Office Attendance Kiosk',
                              style: TextStyle(
                                fontFamily: AppFonts.medium,
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 16),

                  // Real-Time Digital Clock
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontFamily: AppFonts.bold,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontFamily: AppFonts.medium,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Today's Check-in Counter Metric
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PRESENT TODAY',
                                style: TextStyle(
                                  fontFamily: AppFonts.bold,
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${attendanceService.todayCheckInCount}',
                                style: const TextStyle(
                                  fontFamily: AppFonts.bold,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.emeraldGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TOTAL ENROLLED',
                                style: TextStyle(
                                  fontFamily: AppFonts.bold,
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${attendanceService.totalStaffCount}',
                                style: const TextStyle(
                                  fontFamily: AppFonts.bold,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.cyanAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Section Title: Permanent Live Punch Feed
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'LIVE PUNCH FEED',
                        style: TextStyle(
                          fontFamily: AppFonts.bold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        attendanceService.records.isEmpty
                            ? 'Awaiting punches'
                            : '${attendanceService.records.length} Recorded',
                        style: const TextStyle(
                          fontFamily: AppFonts.medium,
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Permanent Live Attendance Feed (Always Visible - Zero Layout Shifts)
                  Expanded(
                    child: attendanceService.records.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sensors_rounded,
                                  size: 36,
                                  color: AppColors.cyanAccent.withValues(alpha: 0.4),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Waiting for Employee Face...',
                                  style: TextStyle(
                                    fontFamily: AppFonts.medium,
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: attendanceService.records.length,
                            itemBuilder: (ctx, idx) {
                              return AttendanceTile(
                                record: attendanceService.records[idx],
                                enableTap: false,
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 12),

                  // Bottom Engine Badge
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.security_rounded,
                          size: 13,
                          color: AppColors.cyanAccent,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'On-Device AI Engine • Secure Biometric Scanner',
                          style: TextStyle(
                            fontFamily: AppFonts.medium,
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminExitButton(BuildContext context) {
    return ClipOval(
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: InkWell(
          onTap: onExit,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.exit_to_app,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCameraKioskCard(
    AttendanceRecord? record, {
    required bool isAlreadyCheckedIn,
    required bool isAlreadyCheckedOut,
    required bool isNoCheckInFound,
    String? candidateName,
  }) {
    // 1. Warning State: Trying to Check-Out without Check-In today
    if (isNoCheckInFound) {
      const Color accentColor = AppColors.amberWarning;
      return Container(
        key: const ValueKey('punch_hud_no_checkin'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: accentColor, width: 1.8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          candidateName ?? 'Employee',
                          style: const TextStyle(
                            fontFamily: AppFonts.bold,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.6),
                            width: 1.0,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 11, color: accentColor),
                            SizedBox(width: 4),
                            Text(
                              'NO CHECK-IN FOUND',
                              style: TextStyle(
                                fontFamily: AppFonts.bold,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'No Check-In found today. Please switch to CHECK-IN mode first!',
                    style: TextStyle(
                      fontFamily: AppFonts.medium,
                      fontSize: 11.5,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (record == null) return const SizedBox.shrink();

    final bool isCheckOut = record.checkType == 'OUT';
    final Color accentColor = isCheckOut
        ? (isAlreadyCheckedOut ? AppColors.cyanAccent : const Color(0xFFEA580C))
        : (isAlreadyCheckedIn ? AppColors.cyanAccent : AppColors.emeraldGreen);

    final String badgeText = isCheckOut
        ? (isAlreadyCheckedOut ? 'ALREADY CHECKED OUT' : 'CHECK-OUT RECORDED')
        : (isAlreadyCheckedIn ? 'ALREADY MARKED' : 'CHECK-IN RECORDED');

    final IconData badgeIcon = isCheckOut
        ? (isAlreadyCheckedOut ? Icons.verified_rounded : Icons.logout_rounded)
        : (isAlreadyCheckedIn ? Icons.verified_rounded : Icons.check_circle_rounded);

    // Compute subtitle & shift duration
    String subtitle;
    if (isCheckOut) {
      if (isAlreadyCheckedOut) {
        subtitle = 'Checked out today at ${DateFormat('hh:mm:ss a').format(record.timestamp)} • Have a safe journey! 🚗';
      } else {
        final inRecord = attendanceService.getTodayCheckIn(record.employeeId);
        if (inRecord != null) {
          final duration = attendanceService.calculateWorkDuration(inRecord.timestamp, record.timestamp);
          subtitle = '${record.employeeCode} • Shift: $duration • Punched Out at ${DateFormat('hh:mm a').format(record.timestamp)}';
        } else {
          subtitle = '${record.employeeCode} • ${record.role} • Punched Out at ${DateFormat('hh:mm:ss a').format(record.timestamp)}';
        }
      }
    } else {
      if (isAlreadyCheckedIn) {
        subtitle = 'Marked today at ${DateFormat('hh:mm:ss a').format(record.timestamp)} • Have a great day! ✨';
      } else {
        subtitle = '${record.employeeCode} • ${record.role} • Punched at ${DateFormat('hh:mm:ss a').format(record.timestamp)}';
      }
    }

    return Container(
      key: ValueKey('punch_hud_${record.id}_${record.checkType}_${isAlreadyCheckedIn}_$isAlreadyCheckedOut'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor,
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Employee Avatar / Punch Snapshot with Status Badge
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: accentColor, width: 1.8),
                ),
                padding: const EdgeInsets.all(1.5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.5),
                  child: record.punchImageBytes != null
                      ? Image.memory(
                          record.punchImageBytes!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : Container(
                          color: accentColor,
                          child: Icon(
                            isCheckOut ? Icons.logout_rounded : Icons.person_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                child: Icon(
                  (isAlreadyCheckedIn || isAlreadyCheckedOut)
                      ? Icons.done_all_rounded
                      : Icons.check,
                  size: 9,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Name, Badge & Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.employeeName,
                        style: const TextStyle(
                          fontFamily: AppFonts.bold,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.6),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            badgeIcon,
                            size: 11,
                            color: accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            badgeText,
                            style: TextStyle(
                              fontFamily: AppFonts.bold,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: AppFonts.medium,
                    fontSize: 11.5,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
