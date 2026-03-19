import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/spacing.dart';
import '../layout/layout.dart';

/// Chip with custom styling
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final Color backgroundColor;
  final Color selectedColor;
  final Color textColor;
  final IconData? icon;
  final double borderRadius;
  final EdgeInsets padding;
  final Border? border;

  const AppChip({
    Key? key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onRemove,
    this.backgroundColor = AppColors.backgroundSecondary,
    this.selectedColor = AppColors.primary,
    this.textColor = AppColors.text,
    this.icon,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    this.border,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: selected ? selectedColor : backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? Colors.white : textColor),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? Colors.white : textColor,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: AppSpacing.xs),
              GestureDetector(
                onTap: onRemove,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: selected ? Colors.white : textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Info card with icon and title
class InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const InfoCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color = AppColors.primary,
    this.onTap,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// List tile with custom styling
class AppListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final Color selectedColor;
  final EdgeInsets contentPadding;
  final double borderRadius;

  const AppListTile({
    Key? key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.selectedColor = AppColors.primaryLight,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    this.borderRadius = 8,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: contentPadding,
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.lg),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.lg),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress indicator widget
class ProgressBar extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final Color backgroundColor;
  final Color valueColor;
  final double height;
  final double borderRadius;
  final String? label;
  final TextStyle? labelStyle;
  final bool showPercentage;

  const ProgressBar({
    Key? key,
    required this.value,
    this.backgroundColor = AppColors.backgroundSecondary,
    this.valueColor = AppColors.primary,
    this.height = 8,
    this.borderRadius = 4,
    this.label,
    this.labelStyle,
    this.showPercentage = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = (value * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || showPercentage) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label != null)
                Text(label!, style: labelStyle ?? AppTextStyles.labelMedium),
              if (showPercentage)
                Text(
                  '$percentage%',
                  style: labelStyle ?? AppTextStyles.labelMedium,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: height,
            backgroundColor: backgroundColor,
            valueColor: AlwaysStoppedAnimation<Color>(valueColor),
          ),
        ),
      ],
    );
  }
}

/// Summary card for displaying key metrics
class SummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final Widget? icon;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool isLoading;

  const SummaryCard({
    Key? key,
    required this.value,
    required this.label,
    this.valueColor,
    this.icon,
    this.backgroundColor,
    this.onTap,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(height: AppSpacing.md),
              ],
              if (isLoading)
                const SizedBox(
                  height: 20,
                  width: 100,
                  child: LinearProgressIndicator(),
                )
              else
                Text(
                  value,
                  style: AppTextStyles.displaySmall.copyWith(color: valueColor),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Network image with loading and error states
class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? backgroundColor;

  const AppNetworkImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = AppLayout.standardBorderRadius,
    this.placeholder,
    this.errorWidget,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Container(
        width: width,
        height: height,
        color: backgroundColor,
        child: Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return placeholder ??
                Container(
                  color: AppColors.backgroundSecondary,
                  child: const Center(child: CircularProgressIndicator()),
                );
          },
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ??
                Container(
                  color: AppColors.backgroundSecondary,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: AppColors.textTertiary,
                    ),
                  ),
                );
          },
        ),
      ),
    );
  }
}
