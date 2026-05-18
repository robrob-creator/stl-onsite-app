import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/spacing.dart';
import '../layout/layout.dart';

/// Custom primary button with rounded corners
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double height;
  final Color backgroundColor;
  final Color foregroundColor;
  final double borderRadius;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final EdgeInsets padding;
  final TextStyle? textStyle;

  const AppButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height = 48,
    this.backgroundColor = AppColors.primary,
    this.foregroundColor = Colors.white,
    this.borderRadius = 8,
    this.leadingIcon,
    this.trailingIcon,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    this.textStyle,
  }) : super(key: key);

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  DateTime? _lastTap;

  bool get _canTap {
    if (_lastTap == null) return true;
    return DateTime.now().difference(_lastTap!) >
        const Duration(milliseconds: 800);
  }

  void _handleTap() {
    if (!_canTap) return;
    _lastTap = DateTime.now();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (widget.isLoading || !widget.isEnabled) ? null : _handleTap,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Container(
            decoration: BoxDecoration(
              color: widget.isEnabled
                  ? widget.backgroundColor
                  : AppColors.disabled,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.foregroundColor,
                        ),
                      ),
                    )
                  : Padding(
                      padding: widget.padding,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.leadingIcon != null) ...[
                            widget.leadingIcon!,
                            const HSpacer(width: AppSpacing.sm),
                          ],
                          Text(
                            widget.label,
                            style:
                                widget.textStyle ??
                                AppTextStyles.button.copyWith(
                                  color: widget.foregroundColor,
                                ),
                          ),
                          if (widget.trailingIcon != null) ...[
                            const HSpacer(width: AppSpacing.sm),
                            widget.trailingIcon!,
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary button with outline
class SecondaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double height;
  final Color borderColor;
  final Color foregroundColor;
  final double borderRadius;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final EdgeInsets padding;
  final TextStyle? textStyle;

  const SecondaryButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.width,
    this.height = 48,
    this.borderColor = AppColors.primary,
    this.foregroundColor = AppColors.primary,
    this.borderRadius = 8,
    this.leadingIcon,
    this.trailingIcon,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    this.textStyle,
  }) : super(key: key);

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  DateTime? _lastTap;

  bool get _canTap {
    if (_lastTap == null) return true;
    return DateTime.now().difference(_lastTap!) >
        const Duration(milliseconds: 800);
  }

  void _handleTap() {
    if (!_canTap) return;
    _lastTap = DateTime.now();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (widget.isLoading || !widget.isEnabled) ? null : _handleTap,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(
                color: widget.isEnabled
                    ? widget.borderColor
                    : AppColors.disabled,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.foregroundColor,
                        ),
                      ),
                    )
                  : Padding(
                      padding: widget.padding,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.leadingIcon != null) ...[
                            widget.leadingIcon!,
                            const HSpacer(width: AppSpacing.sm),
                          ],
                          Text(
                            widget.label,
                            style:
                                widget.textStyle ??
                                AppTextStyles.button.copyWith(
                                  color: widget.isEnabled
                                      ? widget.foregroundColor
                                      : AppColors.disabledText,
                                ),
                          ),
                          if (widget.trailingIcon != null) ...[
                            const HSpacer(width: AppSpacing.sm),
                            widget.trailingIcon!,
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text button with minimal styling
class TextOnlyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final TextStyle? textStyle;
  final double underlineWidth;

  const TextOnlyButton({
    Key? key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.primary,
    this.textStyle,
    this.underlineWidth = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Text(
        label,
        style:
            textStyle ??
            AppTextStyles.bodyMedium.copyWith(
              color: color,
              decoration: underlineWidth > 0 ? TextDecoration.underline : null,
              decorationThickness: underlineWidth,
            ),
      ),
    );
  }
}

/// Icon button with custom styling
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final Color backgroundColor;
  final double size;
  final double iconSize;
  final String? tooltip;
  final EdgeInsets padding;

  const AppIconButton({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.color = AppColors.primary,
    this.backgroundColor = Colors.transparent,
    this.size = 48,
    this.iconSize = 24,
    this.tooltip,
    this.padding = EdgeInsets.zero,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      showDuration: const Duration(seconds: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, size: iconSize, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating action button wrapper
class AppFAB extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  const AppFAB({
    Key? key,
    required this.icon,
    required this.onPressed,
    this.label = '',
    this.backgroundColor = AppColors.primary,
    this.foregroundColor = Colors.white,
    this.size = 56,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return FloatingActionButton(
        onPressed: onPressed,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(icon),
      );
    }

    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
