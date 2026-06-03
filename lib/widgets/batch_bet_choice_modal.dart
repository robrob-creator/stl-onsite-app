import 'package:flutter/material.dart';
import 'package:onstite/core/design_system.dart';
import 'package:onstite/models/bet_availability.dart';

class BatchBetChoiceModal extends StatelessWidget {
  final BetAvailabilityResult targetResult;
  final BetAvailabilityResult rambolResult;
  final VoidCallback? onChooseTarget;
  final VoidCallback? onChooseRambol;

  const BatchBetChoiceModal({
    super.key,
    required this.targetResult,
    required this.rambolResult,
    this.onChooseTarget,
    this.onChooseRambol,
  });

  @override
  Widget build(BuildContext context) {
    final targetAvailable = targetResult.target.availableAmount;
    final rambolAvailable = rambolResult.rambol.availableAmount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.warning,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Choose Bet Type',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Both bet types have limits. Which would you like to place?',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            if (targetResult.target.allowed && onChooseTarget != null)
              _ChoiceButton(
                label: 'Target',
                sublabel: targetAvailable != null
                    ? '₱${targetAvailable.toStringAsFixed(0)} remaining'
                    : null,
                backgroundColor: AppColors.primary,
                textColor: Colors.white,
                onTap: onChooseTarget!,
              ),
            if (rambolResult.rambol.allowed && onChooseRambol != null) ...[
              const SizedBox(height: 10),
              _ChoiceButton(
                label: 'Rambol',
                sublabel: rambolAvailable != null
                    ? '₱${rambolAvailable.toStringAsFixed(0)} remaining'
                    : null,
                backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
                textColor: AppColors.secondary,
                onTap: onChooseRambol!,
              ),
            ],
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final String? sublabel;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    this.sublabel,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (sublabel != null)
              Text(
                sublabel!,
                style: AppTextStyles.labelSmall.copyWith(
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
