import 'package:flutter/material.dart';

/// Compact two-column Current Slip card: digits left, details middle, amounts/actions right.
class CurrentSlipCard extends StatelessWidget {
  final int index;
  final List<String> digits;
  final String gameName;
  final String betType;
  final double straightAmount;
  final double rambolAmount;
  final double totalAmount;
  final double estPayout;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CurrentSlipCard({
    super.key,
    required this.index,
    required this.digits,
    required this.gameName,
    required this.betType,
    required this.straightAmount,
    required this.rambolAmount,
    required this.totalAmount,
    required this.estPayout,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final digitsLabel = digits.join('-');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: digits block (compact)
          Column(
            children: [
              Container(
                width: 84,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      digitsLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gameName,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Est: ₱${estPayout.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),

          const SizedBox(width: 12),

          // Middle: details (game/type) — expanded with amounts and est payout to relieve right column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  betType,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (straightAmount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Amount: ₱${straightAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[800],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (straightAmount > 0) const SizedBox(width: 8),
                    if (rambolAmount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Amount: ₱${rambolAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple[800],
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Combinations: ${digits.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),

          // Right: total and compact actions (narrow)
          Container(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  width: 92,
                  child: ElevatedButton(onPressed: onEdit, child: Text("Edit")),
                ),
                SizedBox(
                  width: 92,
                  child: OutlinedButton(
                    onPressed: onDelete,
                    child: Text("Delete"),
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
