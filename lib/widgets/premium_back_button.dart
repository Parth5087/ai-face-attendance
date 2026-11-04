import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class PremiumBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? iconColor;
  final bool isDark;

  const PremiumBackButton({
    super.key,
    this.onPressed,
    this.iconColor,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed ?? () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.55)
                  : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : AppColors.border,
                width: 1.0,
              ),
              boxShadow: AppColors.cardShadow,
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: iconColor ?? AppColors.textPrimary,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}
