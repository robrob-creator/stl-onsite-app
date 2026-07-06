import 'package:flutter/material.dart';
import 'package:onstite/core/design_system.dart';
import 'package:onstite/models/bet_availability.dart';
import 'package:onstite/models/permutation_availability.dart';

class ConflictNoticeModal extends StatelessWidget {
  final BetAvailabilityResult result;
  final double requestedAmount;
  final VoidCallback? onUpdateAmount;
  final VoidCallback? onAdjustManually;
  final VoidCallback? onPlaceAdvance;
  final List<PermutationDetail>? permutations;
  final int availablePermCount;

  const ConflictNoticeModal({
    super.key,
    required this.result,
    required this.requestedAmount,
    this.onUpdateAmount,
    this.onAdjustManually,
    this.onPlaceAdvance,
    this.permutations,
    this.availablePermCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final available = result.availableAmount;
    final isSoldOut =
        result.state == AvailabilityState.soldOut || (available != null && available <= 0);
    final typeLabel = result.betType == BetType.target ? 'Target' : 'Rambol';
    final isRambol = result.betType == BetType.rambol;
    final perms = permutations;
    final N = availablePermCount > 0 ? availablePermCount : result.permutationCount;
    final share = (isRambol && N > 0) ? requestedAmount / N : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
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
              // Permutation distribution table for rambol
              if (isRambol && perms != null && perms.isNotEmpty) ...[
                const SizedBox(height: 20),
                _PermutationTable(
                  permutations: perms,
                  requestedAmount: requestedAmount,
                  share: share,
                  N: N,
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
      ),
    );
  }
}

class _PermutationTable extends StatelessWidget {
  final List<PermutationDetail> permutations;
  final double requestedAmount;
  final double share;
  final int N;

  const _PermutationTable({
    required this.permutations,
    required this.requestedAmount,
    required this.share,
    required this.N,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Permutation Breakdown',
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Header row
              Container(
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Row(
                  children: [
                    _Cell('Number', isHeader: true, flex: 2),
                    _Cell('Share', isHeader: true, flex: 2),
                    _Cell('Remaining', isHeader: true, flex: 2),
                    _Cell('Status', isHeader: true, flex: 3),
                  ],
                ),
              ),
              // Data rows
              ...permutations.asMap().entries.map((entry) {
                final i = entry.key;
                final p = entry.value;
                final isLast = i == permutations.length - 1;
                final exceeds = !p.isSoldOut && p.remaining > 0 && share > p.remaining;
                final statusColor = p.isSoldOut
                    ? AppColors.error
                    : exceeds
                        ? AppColors.warning
                        : AppColors.success;
                final statusLabel = p.isSoldOut
                    ? 'Sold Out'
                    : exceeds
                        ? 'Exceeds'
                        : 'OK';
                return Container(
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      _Cell(p.value, flex: 2, mono: true),
                      _Cell(
                        share > 0 ? '₱${share.toStringAsFixed(0)}' : '—',
                        flex: 2,
                        color: AppColors.text,
                      ),
                      _Cell(
                        p.isSoldOut ? '—' : '₱${p.remaining.toStringAsFixed(0)}',
                        flex: 2,
                      ),
                      _StatusCell(label: statusLabel, color: statusColor),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Share = ₱${requestedAmount.toStringAsFixed(0)} ÷ $N available perms',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final int flex;
  final bool mono;
  final Color? color;

  const _Cell(
    this.text, {
    this.isHeader = false,
    this.flex = 1,
    this.mono = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Text(
          text,
          style: isHeader
              ? AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                )
              : AppTextStyles.labelSmall.copyWith(
                  fontFamily: mono ? 'monospace' : null,
                  color: color ?? AppColors.text,
                ),
        ),
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusCell({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
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
