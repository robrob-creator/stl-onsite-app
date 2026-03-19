import 'package:flutter/material.dart';
import '../theme/spacing.dart';

/// Layout utilities for consistent spacing and padding
class AppLayout {
  /// Standard page padding
  static const EdgeInsets pagePadding = EdgeInsets.all(AppSpacing.lg);

  /// Standard horizontal padding
  static const EdgeInsets pagePaddingHorizontal = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
  );

  /// Standard vertical padding
  static const EdgeInsets pagePaddingVertical = EdgeInsets.symmetric(
    vertical: AppSpacing.lg,
  );

  /// Safe area padding
  static const EdgeInsets safeAreaPadding = EdgeInsets.all(AppSpacing.md);

  /// Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(AppSpacing.lg);

  /// Standard border radius
  static const Radius standardRadius = Radius.circular(8);
  static const BorderRadius standardBorderRadius = BorderRadius.all(
    standardRadius,
  );

  /// Large border radius (for modals, cards)
  static const Radius largeRadius = Radius.circular(16);
  static const BorderRadius largeBorderRadius = BorderRadius.all(largeRadius);

  /// Small border radius (for buttons, chips)
  static const Radius smallRadius = Radius.circular(4);
  static const BorderRadius smallBorderRadius = BorderRadius.all(smallRadius);

  /// Full border radius (for circles)
  static const Radius fullRadius = Radius.circular(100);
}

/// Common layout widgets
class CustomSpacer extends StatelessWidget {
  final double height;
  final double width;

  const CustomSpacer({Key? key, this.height = AppSpacing.lg, this.width = 0})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, width: width);
  }
}

/// Horizontal spacer widget
class HSpacer extends StatelessWidget {
  final double width;

  const HSpacer({Key? key, this.width = AppSpacing.lg}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width);
  }
}

/// Vertical spacer widget
class VSpacer extends StatelessWidget {
  final double height;

  const VSpacer({Key? key, this.height = AppSpacing.lg}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height);
  }
}

/// Flex spacer - expands to fill available space
class FlexSpacer extends StatelessWidget {
  final int flex;

  const FlexSpacer({Key? key, this.flex = 1}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Flexible(flex: flex, child: Container());
  }
}

/// Divider with custom styling
class CustomDivider extends StatelessWidget {
  final double height;
  final double thickness;
  final Color color;
  final EdgeInsets padding;

  const CustomDivider({
    Key? key,
    this.height = 1,
    this.thickness = 1,
    this.color = const Color(0xFFE5E7EB),
    this.padding = const EdgeInsets.symmetric(vertical: AppSpacing.lg),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Container(height: height, color: color),
    );
  }
}

/// Responsive grid view wrapper
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int columnsOnMobile;
  final int columnsOnTablet;
  final int columnsOnDesktop;
  final double spacing;
  final double runSpacing;
  final WrapCrossAlignment crossAxisAlignment;

  const ResponsiveGrid({
    Key? key,
    required this.children,
    this.columnsOnMobile = 1,
    this.columnsOnTablet = 2,
    this.columnsOnDesktop = 3,
    this.spacing = AppSpacing.lg,
    this.runSpacing = AppSpacing.lg,
    this.crossAxisAlignment = WrapCrossAlignment.start,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    int columns;
    if (screenWidth >= 1200) {
      columns = columnsOnDesktop;
    } else if (screenWidth >= 600) {
      columns = columnsOnTablet;
    } else {
      columns = columnsOnMobile;
    }

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        for (int i = 0; i < children.length; i++)
          SizedBox(
            width:
                (screenWidth - (spacing * (columns - 1))) / columns -
                (spacing * 0.5),
            child: children[i],
          ),
      ],
    );
  }
}

/// Section container with padding and optional background
class Section extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final BoxShadow? boxShadow;

  const Section({
    Key? key,
    required this.child,
    this.padding = AppLayout.cardPadding,
    this.backgroundColor,
    this.borderRadius = AppLayout.largeBorderRadius,
    this.border,
    this.boxShadow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: border,
        boxShadow: boxShadow != null ? [boxShadow!] : null,
      ),
      child: child,
    );
  }
}

/// Card container with consistent styling
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color backgroundColor;
  final BorderRadius borderRadius;
  final Color borderColor;
  final double borderWidth;
  final double elevation;
  final VoidCallback? onTap;

  const AppCard({
    Key? key,
    required this.child,
    this.padding = AppLayout.cardPadding,
    this.backgroundColor = Colors.white,
    this.borderRadius = AppLayout.largeBorderRadius,
    this.borderColor = const Color(0xFFE5E7EB),
    this.borderWidth = 1,
    this.elevation = 0,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: elevation > 0
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: elevation,
                      offset: Offset(0, elevation / 2),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Centered loading widget
class CenteredLoadingWidget extends StatelessWidget {
  final String? message;

  const CenteredLoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const VSpacer(),
            Text(message!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Centered empty state widget
class CenteredEmptyWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;

  const CenteredEmptyWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppLayout.pagePadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 64,
                color: const Color(0xFFC5A3FF).withValues(alpha: 0.5),
              ),
              const VSpacer(height: AppSpacing.xl),
            ],
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const VSpacer(height: AppSpacing.md),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const VSpacer(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
