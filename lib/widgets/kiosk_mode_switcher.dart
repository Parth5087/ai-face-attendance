import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_fonts.dart';

/// Reusable Apple/iOS-Style Segmented Sliding Pill Mode Switcher
/// Seamlessly slides between [CHECK-IN] and [CHECK-OUT]
class KioskModeSwitcher extends StatelessWidget {
  final String checkType;
  final ValueChanged<String> onSwitch;
  final bool isTablet;

  const KioskModeSwitcher({
    super.key,
    required this.checkType,
    required this.onSwitch,
    this.isTablet = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCheckIn = checkType == 'IN';
    final double switcherWidth = isTablet ? 260.0 : 215.0;
    final double switcherHeight = isTablet ? 42.0 : 38.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 100 && checkType != 'OUT') {
            HapticFeedback.selectionClick();
            onSwitch('OUT');
          } else if (details.primaryVelocity! < -100 && checkType != 'IN') {
            HapticFeedback.selectionClick();
            onSwitch('IN');
          }
        }
      },
      child: Container(
        width: switcherWidth,
        height: switcherHeight,
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 🌊 Smooth Sliding Indicator Pill (Apple/iOS Segmented Style)
            AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              alignment: isCheckIn ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  decoration: BoxDecoration(
                    gradient: isCheckIn
                        ? const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isCheckIn
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEA580C))
                            .withValues(alpha: 0.45),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 🎯 Two Clickable Option Slots
            Row(
              children: [
                // CHECK-IN Slot
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (checkType != 'IN') {
                        HapticFeedback.selectionClick();
                        onSwitch('IN');
                      }
                    },
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.login_rounded,
                            size: isTablet ? 15 : 13.5,
                            color: isCheckIn ? Colors.white : Colors.white60,
                          ),
                          const SizedBox(width: 5),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: AppFonts.bold,
                              fontSize: isTablet ? 11.5 : 10.5,
                              fontWeight: FontWeight.w700,
                              color: isCheckIn ? Colors.white : Colors.white60,
                              letterSpacing: 0.6,
                            ),
                            child: const Text('CHECK-IN'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // CHECK-OUT Slot
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (checkType != 'OUT') {
                        HapticFeedback.selectionClick();
                        onSwitch('OUT');
                      }
                    },
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            size: isTablet ? 15 : 13.5,
                            color: !isCheckIn ? Colors.white : Colors.white60,
                          ),
                          const SizedBox(width: 5),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: AppFonts.bold,
                              fontSize: isTablet ? 11.5 : 10.5,
                              fontWeight: FontWeight.w700,
                              color: !isCheckIn ? Colors.white : Colors.white60,
                              letterSpacing: 0.6,
                            ),
                            child: const Text('CHECK-OUT'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
