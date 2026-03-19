import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/spacing.dart';
import '../layout/layout.dart';

/// Custom primary button with rounded corners
class AppButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (isLoading || !isEnabled) ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            decoration: BoxDecoration(
              color: isEnabled ? backgroundColor : AppColors.disabled,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          foregroundColor,
                        ),
                      ),
                    )
                  : Padding(
                      padding: padding,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (leadingIcon != null) ...[
                            leadingIcon!,
                            const HSpacer(width: AppSpacing.sm),
                          ],
                          Text(
                            label,
                            style:
                                textStyle ??
                                AppTextStyles.button.copyWith(
                                  color: foregroundColor,
                                ),
                          ),
                          if (trailingIcon != null) ...[
                            const HSpacer(width: AppSpacing.sm),
                            trailingIcon!,
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
class SecondaryButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (isLoading || !isEnabled) ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(
                color: isEnabled ? borderColor : AppColors.disabled,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          foregroundColor,
                        ),
                      ),
                    )
                  : Padding(
                      padding: padding,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (leadingIcon != null) ...[
                            leadingIcon!,
                            const HSpacer(width: AppSpacing.sm),
                          ],
                          Text(
                            label,
                            style:
                                textStyle ??
                                AppTextStyles.button.copyWith(
                                  color: isEnabled
                                      ? foregroundColor
                                      : AppColors.disabledText,
                                ),
                          ),
                          if (trailingIcon != null) ...[
                            const HSpacer(width: AppSpacing.sm),
                            trailingIcon!,
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
