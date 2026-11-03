import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class ActionHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final Widget? trailingBadge;

  const ActionHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF0284C7), Color(0xFF0EA5E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF141E30), Color(0xFF0F1726)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            border: Border.all(
              color: isPrimary
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.55)
                  : AppColors.cyanAccent.withValues(alpha: 0.20),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                    ? const Color(0xFF0284C7).withValues(alpha: 0.28)
                    : Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
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
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.cyanAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.35)
                        : AppColors.cyanAccent.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: isPrimary ? Colors.white : AppColors.cyanAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isPrimary ? Colors.white : AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (trailingBadge != null) ...[
                          const SizedBox(width: 8),
                          trailingBadge!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isPrimary
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.06),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isPrimary ? Colors.white : AppColors.textMuted,
                  size: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
