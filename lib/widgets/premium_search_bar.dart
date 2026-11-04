import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class PremiumSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final String? counterBadge;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilter;
  final EdgeInsetsGeometry? margin;

  const PremiumSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.counterBadge,
    this.onFilterTap,
    this.hasActiveFilter = false,
    this.margin,
  });

  @override
  State<PremiumSearchBar> createState() => _PremiumSearchBarState();
}

class _PremiumSearchBarState extends State<PremiumSearchBar> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _isFocused = _focusNode.hasFocus;
    _hasText = widget.controller.text.isNotEmpty;

    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  void _onTextChange() {
    final hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText && mounted) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isFocused ? AppColors.cyanAccent : AppColors.border,
            width: _isFocused ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (_isFocused)
              BoxShadow(
                color: AppColors.cyanAccent.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            else
              ...AppColors.cardShadow,
          ],
        ),
        child: Row(
          children: [
            // Tinted Search Icon Badge
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _isFocused
                      ? AppColors.cyanAccent.withValues(alpha: 0.15)
                      : AppColors.surfaceCardLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: _isFocused ? AppColors.cyanAccent : AppColors.textSecondary,
                ),
              ),
            ),

            // Text Input
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                onChanged: widget.onChanged,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            // Optional Counter Badge
            if (widget.counterBadge != null && !_hasText) ...[
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCardLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 0.8),
                ),
                child: Text(
                  widget.counterBadge!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            // Clear Button when query typed
            if (_hasText) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    widget.controller.clear();
                    widget.onChanged('');
                    widget.onClear?.call();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceCardLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],

            // Filter button if provided
            if (widget.onFilterTap != null) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: widget.onFilterTap,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: widget.hasActiveFilter
                          ? AppColors.primary
                          : AppColors.surfaceCardLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: widget.hasActiveFilter
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
