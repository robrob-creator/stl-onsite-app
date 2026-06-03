import 'package:flutter/material.dart';
import 'package:onstite/core/design_system.dart';
import 'package:onstite/models/bet_availability.dart';

class ConflictNoticeModal extends StatelessWidget {
  final BetAvailabilityResult result;
  final double requestedAmount;
  final VoidCallback? onUpdateAmount;
  final VoidCallback? onAdjustManually;
  final VoidCallback? onPlaceAdvance;

  const ConflictNoticeModal({
    super.key,
    required this.result,
    required this.requestedAmount,
    this.onUpdateAmount,
    this.onAdjustManually,
    this.onPlaceAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final available = result.availableAmount;
    final isSoldOut =
        result.state == AvailabilityState.soldOut || (available != null && available <= 0);
    final typeLabel = result.betType == BetType.target ? 'Target' : 'Rambol';

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
                color: isSoldOut ? AppColors.error.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSoldOut ? Icons.block_rounded : Icons.warning_amber_rounded,
                color: isSoldOut ? AppColors.error : AppColors.warning,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSoldOut ? 'Sold Out' : 'Limited Availability',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '"${result.number}" — $typeLabel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isSoldOut && available != null) ...[
              const SizedBox(height: 4),
              Text(
                '₱${available.toStringAsFixed(0)} available',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!isSoldOut && available != null && available > 0 && onUpdateAmount != null)
              _ActionButton(
                label: 'Yes, update to ₱${available.toStringAsFixed(0)}',
                backgroundColor: AppColors.primary,
                textColor: Colors.white,
                onTap: onUpdateAmount!,
              ),
            if (onAdjustManually != null) ...[
              const SizedBox(height: 10),
              _ActionButton(
                label: "No, I'll adjust manually",
                backgroundColor: AppColors.primaryLight,
                textColor: AppColors.primary,
                onTap: onAdjustManually!,
              ),
            ],
            if (onPlaceAdvance != null) ...[
              const SizedBox(height: 10),
              _ActionButton(
                label: 'Place advance ₱${requestedAmount.toStringAsFixed(0)}',
                backgroundColor: AppColors.success.withValues(alpha: 0.12),
                textColor: AppColors.success,
                onTap: onPlaceAdvance!,
              ),
            ],
            if (onUpdateAmount == null && onAdjustManually == null && onPlaceAdvance == null) ...[
              const SizedBox(height: 8),
              Text(
                'This combination is no longer available for the selected draw time.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _ActionButton(
                label: 'OK',
                backgroundColor: AppColors.primary,
                textColor: Colors.white,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
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
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
