// Utility functions and helpers for common operations
import 'package:flutter/material.dart';
import '../design_system.dart';

/// General utilities
class AppUtils {
  /// Format currency values
  static String formatCurrency(double value) {
    return '\$${value.toStringAsFixed(2)}';
  }

  /// Format large numbers with K, M, B suffixes
  static String formatNumber(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    } else if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  /// Format date string
  static String formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  /// Format time
  static String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Truncate text with ellipsis
  static String truncate(String text, int length) {
    if (text.length <= length) return text;
    return '${text.substring(0, length)}...';
  }

  /// Check if email is valid
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Check if password is strong
  static bool isStrongPassword(String password) {
    return password.length >= 8 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'));
  }

  /// Get password strength message
  static String getPasswordStrengthMessage(String password) {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain uppercase letter';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain lowercase letter';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain number';
    }
    return 'Password is strong';
  }

  /// Get text contrast color (black or white) based on background
  static Color getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Convert hex color to Color object
  static Color parseHexColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse('0x$hexColor'));
  }

  /// Convert Color to hex string
  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  /// Check if value is null or empty
  static bool isEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.isEmpty;
    if (value is List) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  /// Get random color
  static Color getRandomColor() {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.error,
      AppColors.warning,
      AppColors.info,
      AppColors.accent,
    ];
    return colors[DateTime.now().millisecond % colors.length];
  }
}

/// Validation utilities
class AppValidation {
  /// Validate required field
  static String? validateRequired(
    String? value, {
    String fieldName = 'This field',
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!AppUtils.isValidEmail(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  /// Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  /// Validate phone number
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(
      r'^[0-9]{10,15}$',
    ).hasMatch(value.replaceAll(RegExp(r'[^\d]'), ''))) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  /// Validate URL
  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'URL is required';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAbsolutePath) {
      return 'Please enter a valid URL';
    }
    return null;
  }

  /// Validate numeric
  static String? validateNumeric(
    String? value, {
    String fieldName = 'This field',
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (!RegExp(r'^[0-9.]+$').hasMatch(value)) {
      return '$fieldName must be numeric';
    }
    return null;
  }

  /// Validate length
  static String? validateLength(
    String? value,
    int minLength,
    int maxLength, {
    String fieldName = 'This field',
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    if (value.length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }
    return null;
  }

  /// Validate match (for password confirmation)
  static String? validateMatch(
    String? value,
    String compareWith, {
    String fieldName = 'Passwords',
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (value != compareWith) {
      return '$fieldName do not match';
    }
    return null;
  }
}

/// Device and screen utilities
class DeviceUtils {
  /// Check if device is in portrait mode
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Check if device is in landscape mode
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Get keyboard height
  static double getKeyboardHeight(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  /// Check if keyboard is visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  /// Hide keyboard
  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  /// Get status bar height
  static double getStatusBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }

  /// Get device safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return MediaQuery.of(context).padding;
  }

  /// Get device pixel ratio
  static double getDevicePixelRatio(BuildContext context) {
    return MediaQuery.of(context).devicePixelRatio;
  }

  /// Check if device is a tablet
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }
}

/// Animation utilities
class AnimUtils {
  /// Create a fade transition
  static Animation<double> createFadeAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeIn));
  }

  /// Create a slide transition
  static Animation<Offset> createSlideAnimation(
    AnimationController controller, {
    Offset begin = const Offset(0.0, 1.0),
    Offset end = Offset.zero,
  }) {
    return Tween<Offset>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
  }

  /// Create a scale animation
  static Animation<double> createScaleAnimation(
    AnimationController controller,
  ) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.elasticOut));
  }

  /// Standard animation duration
  static const Duration standardDuration = Duration(milliseconds: 300);
  static const Duration shortDuration = Duration(milliseconds: 150);
  static const Duration longDuration = Duration(milliseconds: 500);
}
