import 'package:flutter/material.dart';
import 'package:onstite/core/layout/layout.dart';
import '../core/design_system.dart';
import '../core/utils/app_utils.dart';

/// Example page demonstrating all design system components
/// Remove this file after reviewing the design system
class DesignSystemShowcasePage extends StatefulWidget {
  const DesignSystemShowcasePage({super.key});

  @override
  State<DesignSystemShowcasePage> createState() =>
      _DesignSystemShowcasePageState();
}

class _DesignSystemShowcasePageState extends State<DesignSystemShowcasePage> {
  bool _expandedSection = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design System Showcase')),
      body: SingleChildScrollView(
        padding: AppLayout.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colors Section
            _buildSection(
              'Colors',
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildColorRow('Primary', AppColors.primary),
                  _buildColorRow('Secondary', AppColors.secondary),
                  _buildColorRow('Success', AppColors.success),
                  _buildColorRow('Error', AppColors.error),
                  _buildColorRow('Warning', AppColors.warning),
                  _buildColorRow('Info', AppColors.info),
                ],
              ),
            ),

            const VSpacer(height: AppSpacing.xl),

            // Typography Section
            _buildSection(
              'Typography',
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Display Large', style: AppTextStyles.displayLarge),
                  const VSpacer(),
                  Text('Headline Medium', style: AppTextStyles.headlineMedium),
                  const VSpacer(),
                  Text('Title Medium', style: AppTextStyles.titleMedium),
                  const VSpacer(),
                  Text('Body Medium', style: AppTextStyles.bodyMedium),
                  const VSpacer(),
                  Text('Label Medium', style: AppTextStyles.labelMedium),
                ],
              ),
            ),

            const VSpacer(height: AppSpacing.xl),

            // Buttons Section
            _buildSection(
              'Buttons',
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(label: 'Primary', onPressed: () {}),
                      ),
                      const HSpacer(),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Secondary',
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const VSpacer(),
                  Row(
                    children: [
                      AppIconButton(icon: Icons.favorite, onPressed: () {}),
                      const HSpacer(),
                      TextOnlyButton(label: 'Text Button', onPressed: () {}),
                      const Spacer(),
                      AppFAB(icon: Icons.add, onPressed: () {}),
                    ],
                  ),
                ],
              ),
            ),

            const VSpacer(height: AppSpacing.xl),

            // Cards Section
            _buildSection(
              'Cards & Components',
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppCard(
                    child: Padding(
                      padding: AppLayout.cardPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Card Title', style: AppTextStyles.titleMedium),
                          const VSpacer(height: AppSpacing.md),
                          Text(
                            'This is a card component with custom styling',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VSpacer(),
                  InfoCard(
                    title: 'Wallet Balance',
                    subtitle: '\$1,234.56',
                    icon: Icons.account_balance_wallet,
                    color: AppColors.primary,
                  ),
                  const VSpacer(),
                  SummaryCard(
                    value: '150',
                    label: 'Total Orders',
                    icon: Icon(Icons.shopping_bag),
                  ),
                ],
              ),
            ),

            const VSpacer(height: AppSpacing.xl),

            // Chips Section
            _buildSection(
              'Chips',
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  AppChip(label: 'Active', selected: true, onTap: () {}),
                  AppChip(label: 'Inactive', selected: false, onTap: () {}),
                  AppChip(label: 'Removable', onRemove: () {}),
                ],
              ),
            ),

            const VSpacer(height: AppSpacing.xl),

            // Input Fields Section
            _buildSection(
              'Input Fields',
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    label: 'Email Address',
                    hint: 'Enter your email',
                    prefixIcon: Icons.email,
                  ),
                  const VSpacer(),
                  PasswordTextField(label: 'Password'),
                  const VSpacer(),
                  NumericInputField(
                    label: 'Amount',
                    maxDigits: 5,
                    maxValue: 99999,
                  ),
                ],
              ),
            ),

            const VSpacer(height: AppSpacing.xl),

            // Progress Section
            _buildSection(
              'Progress & Lists',
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProgressBar(
                    value: 0.65,
                    label: 'Completion',
                    showPercentage: true,
                  ),
                  const VSpacer(height: AppSpacing.lg),
                  AppListTile(
                    leading: Icon(Icons.person),
                    title: 'John Doe',
                    subtitle: 'john@example.com',
                    trailing: Icon(Icons.arrow_forward),
                  ),
                  AppListTile(
                    leading: Icon(Icons.shopping_cart),
                    title: 'Order #12345',
                    subtitle: 'Pending',
                    trailing: AppBadge(label: 'New'),
                  ),
                ],
              ),
            ),

            const VSpacer(height: AppSpacing.xl),

            // Expandable Section
            _buildSection(
              'Expandable Section',
              ExpandableSection(
                title: 'Click to expand',
                initiallyExpanded: false,
                child: Text(
                  'This content is hidden by default and can be expanded.',
                  style: AppTextStyles.bodyMedium,
                ),
              ),
            ),

            const VSpacer(height: AppSpacing.xl),

            // Dialog Example
            _buildSection(
              'Dialogs & Feedback',
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    label: 'Show Success Message',
                    onPressed: () {
                      AppSnackBar.showSuccess(
                        context,
                        message: 'Operation successful!',
                      );
                    },
                    width: double.infinity,
                  ),
                  const VSpacer(),
                  AppButton(
                    label: 'Show Confirmation',
                    onPressed: () {
                      AppDialog.showConfirmation(
                        context,
                        title: 'Confirm',
                        message: 'Are you sure?',
                        onConfirm: () => AppSnackBar.showSuccess(
                          context,
                          message: 'Confirmed!',
                        ),
                      );
                    },
                    width: double.infinity,
                    backgroundColor: AppColors.secondary,
                  ),
                  const VSpacer(),
                  AppButton(
                    label: 'Show Bottom Sheet',
                    onPressed: () {
                      AppBottomSheet.show(
                        context,
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Bottom Sheet',
                                style: AppTextStyles.headlineSmall,
                              ),
                              const VSpacer(height: AppSpacing.lg),
                              AppButton(
                                label: 'Close',
                                onPressed: () => Navigator.pop(context),
                                width: double.infinity,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    width: double.infinity,
                    backgroundColor: AppColors.success,
                  ),
                ],
              ),
            ),

            const VSpacer(height: AppSpacing.xxxxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.headlineMedium),
        const VSpacer(height: AppSpacing.lg),
        AppCard(
          child: Padding(padding: AppLayout.cardPadding, child: content),
        ),
      ],
    );
  }

  Widget _buildColorRow(String name, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
          ),
          const HSpacer(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.titleSmall),
                Text(
                  AppUtils.colorToHex(color),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
