import 'dart:math' as math;
import 'package:flutter/material.dart';

// Returns permutations as hyphenated strings e.g. ["1-2","2-1"]
List<String> _generatePermutations(List<String> digits) {
  if (digits.isEmpty) return [];
  final result = <String>{};
  void permute(List<String> arr, int start) {
    if (start == arr.length) { result.add(arr.join('-')); return; }
    final seen = <String>{};
    for (int i = start; i < arr.length; i++) {
      if (seen.contains(arr[i])) continue;
      seen.add(arr[i]);
      final tmp = arr[start]; arr[start] = arr[i]; arr[i] = tmp;
      permute(arr, start + 1);
      arr[start] = arr[i]; arr[i] = tmp;
    }
  }
  permute(List<String>.from(digits), 0);
  return result.toList()..sort();
}

class CurrentSlipCard extends StatelessWidget {
  final int index;
  final List<String> digits;
  final String gameName;
  final String betType;
  final double straightAmount;
  final double rambolAmount;
  final double totalAmount;
  final double estPayout;
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
  });

  bool get _isRambol  => betType == 'Rambol' || betType == 'Both';
  bool get _isStraight => betType == 'Target' || betType == 'Both';
  bool get _isBoth    => betType == 'Both';

  Color get _accent {
    if (_isBoth)   return const Color(0xFF0284C7);
    if (_isRambol) return const Color(0xFF7C3AED);
    return const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    final perms = _isRambol ? _generatePermutations(digits) : <String>[];
    final accent = _accent;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          const BoxShadow(
            color: Color(0x06000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent stripe
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _isBoth
                        ? [const Color(0xFF2563EB), const Color(0xFF8B5CF6)]
                        : [accent, accent.withOpacity(0.6)],
                  ),
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 9, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ── Row 1: serial · type badge · delete ──────
                      Row(
                        children: [
                          Text(
                            '#${(index + 1).toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent.withOpacity(0.5),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _isBoth ? 'TARGET + RAMBOL' : betType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: onDelete,
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: const Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // ── Row 2: number + game label ───────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ...digits.asMap().entries.expand((e) {
                            final ws = <Widget>[
                              Text(
                                e.value,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  height: 1.0,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ];
                            if (e.key < digits.length - 1) {
                              ws.add(Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Text('·',
                                  style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w900,
                                    color: accent.withOpacity(0.35), height: 1.3,
                                  ),
                                ),
                              ));
                            }
                            return ws;
                          }),
                          const SizedBox(width: 8),
                          Text(
                            gameName,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),

                      // ── Permutations row (Rambol only) ───────────
                      if (perms.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'COMBINATIONS',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: accent.withOpacity(0.45),
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                children: perms.map((p) => _PermChip(combination: p, color: accent)).toList(),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 8),

                      // ── Dashed separator ─────────────────────────
                      _Dash(color: const Color(0xFFF1F5F9)),

                      const SizedBox(height: 7),

                      // ── Row 3: amounts + total/payout ────────────
                      Row(
                        children: [
                          // Amount pills (left)
                          if (_isStraight && straightAmount > 0)
                            _Pill(label: 'S', amount: straightAmount, color: const Color(0xFF2563EB)),
                          if (_isStraight && straightAmount > 0 && _isRambol && rambolAmount > 0)
                            const SizedBox(width: 5),
                          if (_isRambol && rambolAmount > 0)
                            _Pill(label: 'R', amount: rambolAmount, color: const Color(0xFF7C3AED)),

                          const Spacer(),

                          // Total
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('TOTAL',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                              Text('₱${_fmt(totalAmount)}',
                                style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A),
                                  fontFeatures: [FontFeature.tabularFigures()],
                                )),
                            ],
                          ),

                          Container(
                            width: 1, height: 28,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: const Color(0xFFE2E8F0),
                          ),

                          // Est. payout
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('PAYOUT',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8), letterSpacing: 0.5)),
                              Text('₱${_fmt(estPayout)}',
                                style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF059669),
                                  fontFeatures: [FontFeature.tabularFigures()],
                                )),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _Pill({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15, height: 15,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          child: Center(
            child: Text(label,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
        ),
        const SizedBox(width: 5),
        Text('₱${amount.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color,
            fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    ),
  );
}

class _PermChip extends StatelessWidget {
  final String combination; // e.g. "1-2" or "2-1"
  final Color color;
  const _PermChip({required this.combination, required this.color});

  @override
  Widget build(BuildContext context) {
    // Style each digit and separator distinctly
    final parts = combination.split('-');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.22), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: parts.asMap().entries.expand((e) {
          final widgets = <Widget>[
            Text(
              e.value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ];
          if (e.key < parts.length - 1) {
            widgets.add(Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '-',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color.withOpacity(0.4),
                  height: 1.1,
                ),
              ),
            ));
          }
          return widgets;
        }).toList(),
      ),
    );
  }
}

class _Dash extends StatelessWidget {
  final Color color;
  const _Dash({required this.color});
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 1),
    painter: _DashPainter(color: color),
  );
}

class _DashPainter extends CustomPainter {
  final Color color;
  const _DashPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + 5, size.width), 0), p);
      x += 9;
    }
  }
  @override
  bool shouldRepaint(_DashPainter o) => o.color != color;
}
