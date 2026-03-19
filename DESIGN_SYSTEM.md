# Design System & Layout System Documentation

A comprehensive Flutter design system for consistent UI/UX across the Mallown Lottery application.

## Quick Start

### Import the Design System

```dart
import 'package:onstite/core/design_system.dart';
```

This single import gives you access to:

- Colors
- Typography (Text Styles)
- Spacing
- Theme Configuration
- Responsive Utilities
- Layout Components
- Reusable UI Components

---

## 1. Color System

### Primary Colors

```dart
AppColors.primary           // #2563EB (Main blue)
AppColors.primaryLight      // #EFF6FF (Light blue)
AppColors.primaryDark       // #1E40AF (Dark blue)
```

### Secondary Colors

```dart
AppColors.secondary         // #F97316 (Orange)
AppColors.secondaryLight    // #FEF3E2
AppColors.secondaryDark     // #C2410C
```

### Semantic Colors

```dart
AppColors.success           // #10B981 (Green)
AppColors.error             // #EF4444 (Red)
AppColors.warning           // #FB923C (Orange)
AppColors.info              // #0EA5E9 (Cyan)
AppColors.accent            // #7C3AED (Purple)
```

### Neutral Colors

```dart
AppColors.text              // #1F2937 (Text color)
AppColors.textSecondary     // #6B7280
AppColors.textTertiary      // #9CA3AF
AppColors.background        // #FFFFFF
AppColors.backgroundSecondary // #F9FAFB
AppColors.border            // #E5E7EB
```

### Usage Example

```dart
Container(
  color: AppColors.primary,
  child: Text(
    'Hello',
    style: TextStyle(color: AppColors.text),
  ),
)
```

---

## 2. Typography System

### Text Styles Categories

#### Display Styles (Large Headings)

```dart
AppTextStyles.displayLarge    // 32px, Bold
AppTextStyles.displayMedium   // 28px, Bold
AppTextStyles.displaySmall    // 24px, Bold
```

#### Headline Styles

```dart
AppTextStyles.headlineLarge   // 22px, Bold
AppTextStyles.headlineMedium  // 20px, SemiBold
AppTextStyles.headlineSmall   // 18px, SemiBold
```

#### Title Styles

```dart
AppTextStyles.titleLarge      // 16px, SemiBold
AppTextStyles.titleMedium     // 14px, SemiBold
AppTextStyles.titleSmall      // 12px, SemiBold
```

#### Body Styles

```dart
AppTextStyles.bodyLarge       // 16px, Regular
AppTextStyles.bodyMedium      // 14px, Regular
AppTextStyles.bodySmall       // 12px, Regular
```

#### Label Styles

```dart
AppTextStyles.labelLarge      // 14px, Medium
AppTextStyles.labelMedium     // 12px, Medium
AppTextStyles.labelSmall      // 11px, Medium
```

### Usage Example

```dart
Text(
  'Welcome',
  style: AppTextStyles.headlineLarge,
)

Text(
  'Description',
  style: AppTextStyles.bodyMedium.copyWith(
    color: AppColors.textSecondary,
  ),
)
```

---

## 3. Spacing System

Consistent spacing values for padding, margins, and gaps:

```dart
AppSpacing.xs         // 4.0
AppSpacing.sm         // 8.0
AppSpacing.md         // 12.0
AppSpacing.lg         // 16.0
AppSpacing.xl         // 20.0
AppSpacing.xxl        // 24.0
AppSpacing.xxxl       // 32.0
AppSpacing.xxxxl      // 48.0
```

### Usage Example

```dart
Padding(
  padding: EdgeInsets.all(AppSpacing.lg),
  child: Text('Content'),
)

Column(
  children: [
    Text('Item 1'),
    SizedBox(height: AppSpacing.md),
    Text('Item 2'),
  ],
)
```

---

## 4. Layout System

### Standard Layout Components

#### Spacing Widgets

```dart
// Create vertical spaces
VSpacer()                          // Default 16.0
VSpacer(height: AppSpacing.xl)     // Custom height

// Create horizontal spaces
HSpacer()                          // Default 16.0
HSpacer(width: AppSpacing.sm)      // Custom width

// Flexible spacer (expands to fill space)
FlexSpacer()
```

#### Cards and Containers

```dart
// Custom card with borders
AppCard(
  child: Text('Card content'),
  backgroundColor: Colors.white,
  borderColor: AppColors.border,
)

// Section container
Section(
  child: Text('Section content'),
  backgroundColor: AppColors.backgroundSecondary,
)
```

#### Layout Constants

```dart
AppLayout.pagePadding           // Padding for full pages
AppLayout.cardPadding           // Padding for cards
AppLayout.standardBorderRadius  // Default radius (8.0)
AppLayout.largeBorderRadius     // Large radius (16.0)
```

### Responsive Grid

```dart
ResponsiveGrid(
  columnsOnMobile: 1,
  columnsOnTablet: 2,
  columnsOnDesktop: 3,
  spacing: AppSpacing.lg,
  children: [
    GridItem(),
    GridItem(),
    GridItem(),
  ],
)
```

---

## 5. Responsive Design

### Using Responsive Helper

```dart
import 'package:onstite/core/design_system.dart';

// In your widget build method
@override
Widget build(BuildContext context) {
  final responsive = context.responsive;

  // Access screen properties
  responsive.screenWidth
  responsive.screenHeight
  responsive.isMobile
  responsive.isTablet
  responsive.isDesktop

  // Get responsive values
  responsive.dimension(
    mobile: 300,
    tablet: 500,
    desktop: 800,
  )

  // Get responsive font size
  responsive.responsiveFontSize(18)
}
```

### Screen Size Classes

```dart
// Mobile: width < 600
context.responsive.isMobile    // true/false

// Tablet: 600 <= width < 1200
context.responsive.isTablet    // true/false

// Desktop: width >= 1200
context.responsive.isDesktop   // true/false

// Wide: width >= 1800
context.responsive.isWide      // true/false
```

---

## 6. Button Components

### Primary Button

```dart
AppButton(
  label: 'Click Me',
  onPressed: () {},
  width: double.infinity,
  height: 48,
  backgroundColor: AppColors.primary,
)

// With icon
AppButton(
  label: 'Save',
  onPressed: () {},
  leadingIcon: Icon(Icons.save),
  isLoading: false,
  isEnabled: true,
)
```

### Secondary Button (Outline)

```dart
SecondaryButton(
  label: 'Cancel',
  onPressed: () {},
  borderColor: AppColors.primary,
  foregroundColor: AppColors.primary,
)
```

### Text Only Button

```dart
TextOnlyButton(
  label: 'Forgot Password?',
  onPressed: () {},
  color: AppColors.primary,
)
```

### Icon Button

```dart
AppIconButton(
  icon: Icons.menu,
  onPressed: () {},
  color: AppColors.primary,
  size: 48,
)
```

### Floating Action Button

```dart
AppFAB(
  icon: Icons.add,
  onPressed: () {},
  label: 'Add',
)
```

---

## 7. Input Components

### Text Field

```dart
AppTextField(
  label: 'Email Address',
  hint: 'Enter your email',
  keyboardType: TextInputType.emailAddress,
  validator: (value) {
    return AppValidation.validateEmail(value);
  },
  onChanged: (value) {
    // Handle change
  },
)
```

### Numeric Input

```dart
NumericInputField(
  label: 'Age',
  maxDigits: 2,
  maxValue: 100,
  onChanged: (value) {},
)
```

### Password Field

```dart
PasswordTextField(
  label: 'Password',
  validator: (value) => AppValidation.validatePassword(value),
)
```

### Search Field

```dart
SearchField(
  hint: 'Search items...',
  onChanged: (query) {
    // Handle search
  },
  onClear: () {
    // Handle clear
  },
)
```

---

## 8. Dialogs & Feedback

### Snackbar

```dart
AppSnackBar.showSuccess(context, message: 'Operation successful!');
AppSnackBar.showError(context, message: 'An error occurred');
AppSnackBar.showInfo(context, message: 'Information message');
AppSnackBar.showWarning(context, message: 'Warning message');
```

### Confirmation Dialog

```dart
AppDialog.showConfirmation(
  context,
  title: 'Confirm Action',
  message: 'Are you sure?',
  confirmLabel: 'Yes',
  cancelLabel: 'No',
  onConfirm: () {
    // Handle confirmation
  },
  onCancel: () {
    // Handle cancel
  },
)
```

### Alert Dialog

```dart
AppDialog.showError(
  context,
  title: 'Error',
  message: 'Something went wrong',
)

AppDialog.showInfo(
  context,
  title: 'Information',
  message: 'This is some information',
)
```

### Bottom Sheet

```dart
AppBottomSheet.show(
  context,
  child: Padding(
    padding: EdgeInsets.all(AppSpacing.lg),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Bottom Sheet Content'),
      ],
    ),
  ),
)
```

---

## 9. Card Components

### Info Card

```dart
InfoCard(
  title: 'Total Balance',
  subtitle: '\$1,234.56',
  icon: Icons.account_balance_wallet,
  color: AppColors.primary,
  onTap: () {},
)
```

### Summary Card

```dart
SummaryCard(
  value: '\$5,234.00',
  label: 'Total Earnings',
  valueColor: AppColors.success,
  icon: Icon(Icons.trending_up),
)
```

### Chip

```dart
AppChip(
  label: 'Active',
  selected: true,
  selectedColor: AppColors.primary,
  onTap: () {},
)
```

### List Tile

```dart
AppListTile(
  leading: Icon(Icons.person),
  title: 'John Doe',
  subtitle: 'john@example.com',
  trailing: Icon(Icons.arrow_forward),
  onTap: () {},
)
```

### Progress Bar

```dart
ProgressBar(
  value: 0.65,
  label: 'Progress',
  showPercentage: true,
)
```

---

## 10. Utilities

### Text Utilities

```dart
AppUtils.formatCurrency(100.50)           // $100.50
AppUtils.formatNumber(1500000)            // 1.5M
AppUtils.formatDate(DateTime.now())       // 3/7/2026
AppUtils.formatTime(DateTime.now())       // 14:30
AppUtils.capitalize('hello')              // Hello
AppUtils.truncate('Long text', 5)         // Long ...
```

### Validation Utilities

```dart
AppValidation.validateRequired(value, 'Email')
AppValidation.validateEmail(email)
AppValidation.validatePassword(password)
AppValidation.validatePhoneNumber(phone)
AppValidation.validateUrl(url)
AppValidation.validateLength(value, 8, 20)
AppValidation.validateMatch(password, confirmPassword)
```

### Device Utilities

```dart
DeviceUtils.isPortrait(context)
DeviceUtils.isLandscape(context)
DeviceUtils.isKeyboardVisible(context)
DeviceUtils.getKeyboardHeight(context)
DeviceUtils.hideKeyboard(context)
DeviceUtils.isTablet(context)
```

### Color Utilities

```dart
AppUtils.isValidEmail(email)
AppUtils.isStrongPassword(password)
AppUtils.getContrastColor(backgroundColor)
AppUtils.parseHexColor('#2563EB')
AppUtils.colorToHex(AppColors.primary)
AppUtils.getRandomColor()
```

---

## 11. Theme Configuration

### Using the Theme

The theme is automatically applied in `main.dart`:

```dart
GetMaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ThemeMode.light,
)
```

### Customizing Theme

Create a custom theme file extending `AppTheme`:

```dart
class CustomTheme extends AppTheme {
  static ThemeData get customLightTheme {
    // Extend or modify AppTheme.lightTheme
    return AppTheme.lightTheme.copyWith(
      // Custom modifications
    );
  }
}
```

---

## 12. Best Practices

### ✅ DO

- Use `AppColors` for all colors
- Use `AppTextStyles` for all text
- Use `AppSpacing` for all padding/margins
- Use responsive utilities for responsive layouts
- Use validators from `AppValidation` for form validation
- Use provided components instead of building from scratch
- Group related components in sections with `Section` widget

### ❌ DON'T

- Don't use hardcoded colors or spacing values
- Don't create custom buttons instead of using `AppButton`
- Don't use different text sizes that aren't in `AppTextStyles`
- Don't hardcode padding/margin values
- Don't create custom text fields instead of using `AppTextField`
- Don't forget to use responsive utilities for different screen sizes

---

## 13. Component Gallery Examples

### Complete Form Example

```dart
Column(
  children: [
    AppTextField(
      label: 'Email',
      hint: 'Enter your email',
      keyboardType: TextInputType.emailAddress,
      validator: (value) => AppValidation.validateEmail(value),
    ),
    VSpacer(height: AppSpacing.lg),
    PasswordTextField(
      label: 'Password',
      validator: (value) => AppValidation.validatePassword(value),
    ),
    VSpacer(height: AppSpacing.xl),
    AppButton(
      label: 'Sign In',
      onPressed: () {},
      width: double.infinity,
    ),
    VSpacer(height: AppSpacing.md),
    TextOnlyButton(
      label: 'Forgot Password?',
      onPressed: () {},
    ),
  ],
)
```

### Complete Card Example

```dart
AppCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Order Summary', style: AppTextStyles.titleLarge),
      VSpacer(height: AppSpacing.md),
      AppListTile(
        title: 'Subtotal',
        trailing: Text('\$99.99', style: AppTextStyles.titleMedium),
      ),
      AppListTile(
        title: 'Tax',
        trailing: Text('\$9.99', style: AppTextStyles.titleMedium),
      ),
      CustomDivider(),
      AppListTile(
        title: 'Total',
        trailing: Text('\$109.98', style: AppTextStyles.headlineSmall),
      ),
    ],
  ),
)
```

### Complete Dialog Example

```dart
ElevatedButton(
  onPressed: () async {
    final confirmed = await AppDialog.showConfirmation(
      context,
      title: 'Delete Item?',
      message: 'This action cannot be undone.',
      confirmLabel: 'Delete',
      onConfirm: () {
        AppSnackBar.showSuccess(context, message: 'Item deleted');
      },
    );
  },
  child: Text('Delete'),
)
```

---

## File Structure

```
lib/
├── core/
│   ├── design_system.dart          # Main export file
│   ├── theme/
│   │   ├── colors.dart             # Color palette
│   │   ├── text_styles.dart        # Typography
│   │   ├── spacing.dart            # Spacing constants
│   │   └── theme.dart              # Theme configuration
│   ├── layout/
│   │   ├── responsive.dart         # Responsive utilities
│   │   └── layout.dart             # Layout components
│   ├── components/
│   │   ├── buttons.dart            # Button components
│   │   ├── text_fields.dart        # Input components
│   │   ├── dialogs_and_feedback.dart# Dialog & feedback
│   │   └── cards_and_lists.dart    # Card & list components
│   └── utils/
│       └── app_utils.dart          # Utility functions
```

---

## Version History

- **v1.0.0** - Initial design system with:
  - Complete color system
  - Typography with 6 style categories
  - Spacing constants
  - Responsive utilities
  - 25+ reusable components
  - Comprehensive utilities and validators
  - Light and dark theme support

---

## Support

For questions or issues with the design system, please refer to the component implementations or contact the development team.
