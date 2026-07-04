import 'package:flutter/material.dart';

class CurrentSlipCard extends StatelessWidget {
  final int index;
  final List<String> digits;
  final String gameName;
  final String betType;
  final double straightAmount;
  final double rambolAmount;
  final double totalAmount;
  final double estPayout;
  final String drawTimeLabel;
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
    required this.onDelete,
    this.drawTimeLabel = '',
  });

  bool get _isRambol => betType == 'Rambol' || betType == 'Both';

  int get _comboCount {
    if (!_isRambol || digits.isEmpty) return 0;
    final freq = <String, int>{};
    for (final d in digits) {
      freq[d] = (freq[d] ?? 0) + 1;
    }
    int num = _factorial(digits.length);
    for (final f in freq.values) {
      num ~/= _factorial(f);
    }
    return num;
  }

  int _factorial(int n) {
    if (n <= 1) return 1;
    int r = 1;
    for (int i = 2; i <= n; i++) {
      r *= i;
    }
    return r;
  }

  String _gameShortName() {
    if (gameName.contains('3D')) return '3D';
    return '2D';
  }

  String _betTypeLabel() {
    switch (betType) {
      case 'Both':
        return 'BOTH';
      case 'Rambol':
        return 'RAMBOL';
      default:
        return 'TARGET';
    }
  }

  @override
  Widget build(BuildContext context) {
    const chipBg = Color(0xFFEAEBFF);
    const chipText = Color(0xFF3A3AB8);
    const badgeBg = Color(0xFFEAEBFF);
    const badgeText = Color(0xFF5050C8);
    const amountColor = Color(0xFF0F172A);
    const metaColor = Color(0xFF94A3B8);
    const cardBg = Colors.white;

    final combos = _comboCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: digit chips + amount + × button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Digit chips
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: digits.map((d) => _DigitChip(
                      digit: d,
                      bg: chipBg,
                      textColor: chipText,
                    )).toList(),
                  ),
                ),
                const SizedBox(width: 12),
                // Amount + delete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱${totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Row 2: game badge · bet type · combos · draw time
            Row(
              children: [
                // Game badge
                _Badge(label: _gameShortName(), bg: badgeBg, textColor: badgeText),
                const SizedBox(width: 6),
                const Text('·', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                const SizedBox(width: 6),
                // Bet type
                Text(
                  _betTypeLabel(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeText,
                    letterSpacing: 0.3,
                  ),
                ),
                // Combos (Rambol only)
                if (_isRambol && combos > 1) ...[
                  const SizedBox(width: 6),
                  const Text('·', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                  const SizedBox(width: 6),
                  Text(
                    '$combos ${combos == 1 ? 'combo' : 'combos'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: metaColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down, size: 16, color: metaColor),
                ],
                const Spacer(),
                // Draw time
                if (drawTimeLabel.isNotEmpty) ...[
                  const Icon(Icons.access_time, size: 13, color: metaColor),
                  const SizedBox(width: 4),
                  Text(
                    drawTimeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: metaColor,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DigitChip extends StatelessWidget {
  final String digit;
  final Color bg;
  final Color textColor;

  const _DigitChip({
    required this.digit,
    required this.bg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 48,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        digit,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textColor,
          height: 1.0,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;

  const _Badge({required this.label, required this.bg, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}
