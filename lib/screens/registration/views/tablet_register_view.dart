import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';

/// 📟 TABLET REGISTER VIEW (>= 600px Landscape - Split-Screen 60:40 UI)
/// 60% Left: Live Viewfinder, Mode Switcher & Capture Controls
/// 40% Right: Staff Biometric Profile & Enrollment Form
class TabletRegisterView extends StatelessWidget {
  final bool hasCaptured;
  final bool isReadyToCapture;
  final Widget? modeToggle;
  final Widget guidanceBanner;
  final Widget viewportContent;
  final Widget actionButtons;
  final Widget formContent;

  const TabletRegisterView({
    super.key,
    required this.hasCaptured,
    required this.isReadyToCapture,
    this.modeToggle,
    required this.guidanceBanner,
    required this.viewportContent,
    required this.actionButtons,
    required this.formContent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // =================================================================
          // 📷 LEFT PANE (60%): Large Prominent Viewfinder & Controls
          // =================================================================
          Expanded(
            flex: 60,
            child: Column(
              children: [
                if (modeToggle != null && !hasCaptured) ...[
                  modeToggle!,
                  const SizedBox(height: 6),
                ],
                guidanceBanner,
                const SizedBox(height: 6),
                Expanded(
                  child: Container(
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
                actionButtons,
              ],
            ),
          ),

          const SizedBox(width: 18),

          // =================================================================
          // 📝 RIGHT PANE (40%): Compact & Elegant Staff Details Form
          // =================================================================
          Expanded(
            flex: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.cardShadow,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: formContent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
