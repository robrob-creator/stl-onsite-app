import 'package:flutter/material.dart';

/// Responsive design utilities for handling different screen sizes
class ResponsiveBreakpoints {
  // Breakpoint definitions
  static const double mobile = 0;
  static const double tablet = 600;
  static const double desktop = 1200;
  static const double wide = 1800;
}

/// Helper class for responsive design
class Responsive {
  final BuildContext context;

  Responsive(this.context);

  /// Get screen size
  Size get screenSize => MediaQuery.of(context).size;

  /// Get screen width
  double get screenWidth => screenSize.width;

  /// Get screen height
  double get screenHeight => screenSize.height;

  /// Get device padding (safe area)
  EdgeInsets get padding => MediaQuery.of(context).padding;

  /// Get device view insets
  EdgeInsets get viewInsets => MediaQuery.of(context).viewInsets;

  /// Check if device is in portrait mode
  bool get isPortrait =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  /// Check if device is in landscape mode
  bool get isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Check device type
  bool get isMobile => screenWidth < ResponsiveBreakpoints.tablet;
  bool get isTablet =>
      screenWidth >= ResponsiveBreakpoints.tablet &&
      screenWidth < ResponsiveBreakpoints.desktop;
  bool get isDesktop => screenWidth >= ResponsiveBreakpoints.desktop;
  bool get isWide => screenWidth >= ResponsiveBreakpoints.wide;

  /// Device pixel ratio
  double get devicePixelRatio => MediaQuery.of(context).devicePixelRatio;

  /// Get responsive value based on device type
  T value<T>({required T mobile, T? tablet, T? desktop, T? wide}) {
    if (isWide && wide != null) return wide;
    if (isDesktop && desktop != null) return desktop;
    if (isTablet && tablet != null) return tablet;
    return mobile;
  }

  /// Get responsive dimension value
  double dimension({
    required double mobile,
    double? tablet,
    double? desktop,
    double? wide,
  }) {
    return value<double>(
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      wide: wide,
    );
  }

  /// Get responsive font size
  double responsiveFontSize(double baseFontSize) {
    final scale = screenWidth / 360;
    final scaleFont = baseFontSize * scale;
    return scaleFont.clamp(baseFontSize * 0.8, baseFontSize * 1.2);
  }

  /// Get responsive padding
  EdgeInsets responsivePadding({
    required double horizontal,
    required double vertical,
  }) {
    final scale = (screenWidth / 360).clamp(0.8, 1.5);
    return EdgeInsets.symmetric(
      horizontal: horizontal * scale,
      vertical: vertical * scale,
    );
  }

  /// Get responsive border radius
  BorderRadius responsiveBorderRadius(double baseRadius) {
    final scale = (screenWidth / 360).clamp(0.8, 1.5);
    return BorderRadius.circular(baseRadius * scale);
  }

  /// Calculate responsive grid columns
  int getGridColumns() {
    if (isWide) return 4;
    if (isDesktop) return 3;
    if (isTablet) return 2;
    return 1;
  }

  /// Get aspect ratio for responsive widgets
  double? getResponsiveAspectRatio() {
    if (isPortrait) {
      if (isDesktop) return 16 / 9;
      if (isTablet) return 4 / 3;
      return 1;
    } else {
      if (isDesktop) return 21 / 9;
      if (isTablet) return 16 / 9;
      return 16 / 10;
    }
  }
}

/// Extension for easy access to Responsive class
extension ResponsiveExtension on BuildContext {
  Responsive get responsive => Responsive(this);
}
