import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

/// 📱 MOBILE REGISTER VIEW (< 600px - Handheld Vertical Step-by-Step UI)
class MobileRegisterView extends StatelessWidget {
  final bool hasCaptured;
  final bool isReadyToCapture;
  final bool isTablet;
  final Widget? modeToggle;
  final Widget guidanceBanner;
  final Widget viewportContent;
  final Widget actionButtons;

  const MobileRegisterView({
    super.key,
    required this.hasCaptured,
    required this.isReadyToCapture,
    required this.isTablet,
    this.modeToggle,
    required this.guidanceBanner,
    required this.viewportContent,
    required this.actionButtons,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isTablet ? 24.0 : 16.0;

    return Column(
      children: [
        // 1. Sliding Mode Switcher: Quick Blink vs 360° Face ID
        if (modeToggle != null && !hasCaptured)
          Padding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 2, horizontalPadding, 8),
            child: modeToggle!,
          ),

        // 2. Centered Real-time Guidance Banner
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 8),
          child: guidanceBanner,
        ),

        // 3. Center Camera Viewport with Biometric Viewfinder
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: Colors.black,
              border: Border.all(
                color: isReadyToCapture || hasCaptured
                    ? AppColors.emeraldGreen
                    : AppColors.border,
                width: 2.0,
              ),
              boxShadow: AppColors.softShadow,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: viewportContent,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // 4. Bottom Shutter / Action Controls
        Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 12),
          child: actionButtons,
        ),
      ],
    );
  }
}
