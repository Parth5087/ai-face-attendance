import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';

class PremiumTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool isRequired;
  final String? badgeText;
  final String? errorText;
  final String? helperText;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;

  const PremiumTextField({
    super.key,
    this.controller,
    required this.label,
    required this.hintText,
    required this.prefixIcon,
    this.suffixIcon,
    this.isRequired = false,
    this.badgeText,
    this.errorText,
    this.helperText,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onEditingComplete,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.inputFormatters,
  });

  @override
  State<PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<PremiumTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);

    if (widget.controller != null) {
      _hasText = widget.controller!.text.isNotEmpty;
      widget.controller!.addListener(_handleTextChange);
    }
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  void _handleTextChange() {
    final hasText = widget.controller?.text.isNotEmpty ?? false;
    if (hasText != _hasText && mounted) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_handleFocusChange);
    }
    widget.controller?.removeListener(_handleTextChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Label Row
        Row(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontFamily: AppFonts.bold,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.3,
              ),
            ),
            if (widget.isRequired) ...[
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
            if (widget.badgeText != null) ...[
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
                  widget.badgeText!,
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

        // Text Input Container
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: widget.enabled ? AppColors.surfaceCard : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasError
                  ? AppColors.roseError
                  : _isFocused
                      ? AppColors.primary
                      : AppColors.border,
              width: hasError || _isFocused ? 1.6 : 1.0,
            ),
            boxShadow: [
              if (_isFocused && !hasError)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                )
              else if (hasError)
                BoxShadow(
                  color: AppColors.roseError.withValues(alpha: 0.20),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              else
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
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: hasError
                        ? AppColors.roseError.withValues(alpha: 0.12)
                        : _isFocused
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasError
                          ? AppColors.roseError.withValues(alpha: 0.3)
                          : _isFocused
                              ? AppColors.primary.withValues(alpha: 0.4)
                              : AppColors.border,
                    ),
                  ),
                  child: Icon(
                    widget.prefixIcon,
                    size: 19,
                    color: hasError
                        ? AppColors.roseError
                        : _isFocused
                            ? AppColors.cyanAccent
                            : AppColors.textSecondary,
                  ),
                ),
              ),

              // The Native TextField
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: widget.keyboardType,
                  textCapitalization: widget.textCapitalization,
                  inputFormatters: widget.inputFormatters,
                  onChanged: widget.onChanged,
                  onEditingComplete: widget.onEditingComplete,
                  style: const TextStyle(
                    fontFamily: AppFonts.medium,
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(
                      fontFamily: AppFonts.medium,
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
              ),

              // Clear Button or Custom Suffix
              if (widget.suffixIcon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: widget.suffixIcon!,
                )
              else if (_hasText && widget.enabled)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      widget.controller?.clear();
                      if (widget.onChanged != null) widget.onChanged!('');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),

        // Error or Helper Text
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
                  widget.errorText!,
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
        ] else if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: const TextStyle(
              fontFamily: AppFonts.medium,
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
