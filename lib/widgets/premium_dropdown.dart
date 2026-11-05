import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class PremiumDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final IconData prefixIcon;
  final bool isRequired;
  final String? badgeText;
  final String? hintText;
  final String? errorText;
  final bool enabled;

  const PremiumDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    required this.prefixIcon,
    this.isRequired = false,
    this.badgeText,
    this.hintText,
    this.errorText,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Label Row
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppFonts.bold,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.3,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: AppColors.roseError,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
            if (badgeText != null) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  badgeText!,
                  style: const TextStyle(
                    fontFamily: AppFonts.bold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cyanAccent,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),

        // Dropdown Container
        Container(
          decoration: BoxDecoration(
            color: enabled ? AppColors.surfaceCard : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasError ? AppColors.roseError : AppColors.border,
              width: hasError ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Tinted Prefix Icon Badge
              Padding(
                padding: const EdgeInsets.only(left: 10, right: 6),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: hasError
                        ? AppColors.roseError.withValues(alpha: 0.12)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasError
                          ? AppColors.roseError.withValues(alpha: 0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Icon(
                    prefixIcon,
                    size: 19,
                    color: hasError
                        ? AppColors.roseError
                        : AppColors.textSecondary,
                  ),
                ),
              ),

              // Dropdown Button
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<T>(
                    value: value,
                    isExpanded: true,
                    icon: const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.cyanAccent,
                        size: 22,
                      ),
                    ),
                    dropdownColor: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 8,
                    style: const TextStyle(
                      fontFamily: AppFonts.medium,
                      fontSize: 14.5,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    hint: hintText != null
                        ? Text(
                            hintText!,
                            style: const TextStyle(
                              fontFamily: AppFonts.medium,
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : null,
                    items: items.map((T item) {
                      final isSelected = item == value;
                      return DropdownMenuItem<T>(
                        value: item,
                        child: Text(
                          itemLabel(item),
                          style: TextStyle(
                            fontFamily: isSelected
                                ? AppFonts.bold
                                : AppFonts.medium,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.cyanAccent
                                : AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: enabled ? onChanged : null,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Error Text
        if (hasError) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 13,
                color: AppColors.roseError,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText!,
                  style: const TextStyle(
                    fontFamily: AppFonts.medium,
                    fontSize: 11.5,
                    color: AppColors.roseError,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
