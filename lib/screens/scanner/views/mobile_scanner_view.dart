import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../models/attendance_record.dart';
import '../../../services/attendance_service.dart';
import '../../../widgets/biometric_viewfinder.dart';
import '../../../widgets/kiosk_mode_switcher.dart';

/// 📱 MOBILE SCANNER VIEW (< 600px - Handheld Portrait Terminal)
/// Full-height camera viewport, Cyber Tech-Box Guide, Notch-Safe Top Bar & Floating Guidance HUD
class MobileScannerView extends StatelessWidget {
  final CameraController? cameraController;
  final bool isCamReady;
  final Animation<double> scannerAnimation;
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

  const MobileScannerView({
    super.key,
    required this.cameraController,
    required this.isCamReady,
    required this.scannerAnimation,
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
    final safePadding = MediaQuery.of(context).padding;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Full-Screen Seamless Live Camera Viewport
        if (isCamReady && cameraController != null)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: cameraController!.value.previewSize?.height ?? 720,
                height: cameraController!.value.previewSize?.width ?? 1280,
                child: CameraPreview(cameraController!),
              ),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: AppColors.cyanAccent),
          ),

        // 2. Full-Screen Spotlight Vignette with Biometric Tech-Box HUD
        if (isCamReady)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: scannerAnimation,
              builder: (context, _) {
                final Color defaultColor = checkType == 'IN'
                    ? AppColors.cyanAccent
                    : const Color(0xFFF59E0B);
                final Color activeColor = checkType == 'IN'
                    ? AppColors.emeraldGreen
                    : const Color(0xFFEA580C);
                final Color boxColor = isVerifying || lastPunchResult != null
                    ? activeColor
                    : (blinkDetected
                        ? activeColor
                        : (statusColor == AppColors.amberWarning
                            ? AppColors.amberWarning
                            : defaultColor));

                final screenWidth = MediaQuery.of(context).size.width;
                final boxWidth = (screenWidth * 0.72).clamp(260.0, 300.0);
                final boxHeight = boxWidth * 1.25;

                return CustomPaint(
                  painter: BiometricTechBoxPainter(
                    borderColor: boxColor,
                    isVerified: blinkDetected || isVerifying,
                    pulseValue: scannerAnimation.value,
                    laserProgress: isVerifying ? 0.5 : scannerAnimation.value,
                    customWidth: boxWidth,
                    customHeight: boxHeight,
                    verticalOffset: -12.0,
                    cornerRadius: 24.0,
                  ),
                );
              },
            ),
          ),

        // 3. Top Floating Glassmorphic Header Bar with Safe Top Inset
        Positioned(
          top: safePadding.top + 8,
          left: 14,
          right: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Admin Mode / Exit Button (Circular, 42px)
              _buildAdminExitButton(context),

              // Sliding Mode Switcher (Check-In / Check-Out)
              KioskModeSwitcher(
                checkType: checkType,
                onSwitch: onSwitchCheckType,
                isTablet: false,
              ),

              // Camera Switch Button (Circular, 42px)
              if (canSwitchCamera)
                ClipOval(
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.50),
                    child: InkWell(
                      onTap: onToggleCamera,
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1.0,
                          ),
                        ),
                        child: const Icon(
                          Icons.flip_camera_ios_outlined,
                          color: Colors.white,
                          size: 17,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 42),
            ],
          ),
        ),

        // 4. Bottom Floating Guidance HUD Card with Safe Bottom Inset
        Positioned(
          bottom: safePadding.bottom + 16,
          left: 16,
          right: 16,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: lastPunchNoCheckIn
                    ? AppColors.roseError
                    : (lastPunchIsAlreadyCheckedOut
                        ? const Color(0xFFEA580C)
                        : statusColor.withValues(alpha: 0.8)),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Pulse or Warning Indicator Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (lastPunchNoCheckIn
                            ? AppColors.roseError
                            : (lastPunchIsAlreadyCheckedOut
                                ? const Color(0xFFEA580C)
                                : statusColor))
                        .withValues(alpha: 0.16),
                    border: Border.all(
                      color: lastPunchNoCheckIn
                          ? AppColors.roseError
                          : (lastPunchIsAlreadyCheckedOut
                              ? const Color(0xFFEA580C)
                              : statusColor),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      lastPunchNoCheckIn
                          ? Icons.warning_amber_rounded
                          : (lastPunchIsAlreadyCheckedOut || lastPunchIsAlreadyCheckedIn
                              ? Icons.info_outline_rounded
                              : (blinkDetected
                                  ? Icons.check_circle_rounded
                                  : Icons.face_rounded)),
                      color: lastPunchNoCheckIn
                          ? AppColors.roseError
                          : (lastPunchIsAlreadyCheckedOut
                              ? const Color(0xFFEA580C)
                              : statusColor),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lastPunchNoCheckIn
                            ? 'NO CHECK-IN FOUND'
                            : (lastPunchIsAlreadyCheckedOut
                                ? 'ALREADY CHECKED OUT'
                                : statusText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.bold,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: lastPunchNoCheckIn
                              ? AppColors.roseError
                              : (lastPunchIsAlreadyCheckedOut
                                  ? const Color(0xFFEA580C)
                                  : Colors.white),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lastPunchNoCheckIn
                            ? 'Check-in first for ${lastPunchCandidateName ?? "employee"}'
                            : (lastPunchIsAlreadyCheckedOut
                                ? 'Shift recorded for ${lastPunchCandidateName ?? "employee"}'
                                : 'Active Staff: ${attendanceService.totalStaffCount} enrolled'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.medium,
                          fontSize: 11.5,
                          color: Color(0xFF94A3B8),
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
    );
  }

  Widget _buildAdminExitButton(BuildContext context) {
    return ClipOval(
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: InkWell(
          onTap: onExit,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1.0,
              ),
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              color: Colors.white,
              size: 17,
            ),
          ),
        ),
      ),
    );
  }
}
