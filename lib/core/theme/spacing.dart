/// Centralized spacing constants for consistent padding and margins
class AppSpacing {
  // Micro spacing
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double xxxxl = 48.0;

  // Aliases for clarity
  static const double extraSmall = xs;
  static const double small = sm;
  static const double medium = md;
  static const double large = lg;
  static const double extraLarge = xl;
  static const double huge = xxxl;

  // Padding values (symmetric)
  static const edgeInsetsTiny = (xs, xs);
  static const edgeInsetsSmall = (sm, sm);
  static const edgeInsetsMedium = (md, md);
  static const edgeInsetsLarge = (lg, lg);
  static const edgeInsetsXLarge = (xl, xl);
  static const edgeInsetsXXLarge = (xxl, xxl);

  // Common patterns
  static const horizontalSmall = 8.0;
  static const horizontalMedium = 16.0;
  static const horizontalLarge = 24.0;

  static const verticalSmall = 8.0;
  static const verticalMedium = 12.0;
  static const verticalLarge = 16.0;

  // Safe area padding
  static const safeAreaHorizontal = 16.0;
  static const safeAreaVertical = 12.0;
}
