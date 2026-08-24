import 'package:flutter/material.dart';

class CurrentSlipCard extends StatefulWidget {
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
    this.drawTimeLabel = '',
    required this.onDelete,
  });

  @override
  State<CurrentSlipCard> createState() => _CurrentSlipCardState();
}

class _CurrentSlipCardState extends State<CurrentSlipCard>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _sizeFactor;
  bool _removeHovered = false;

  // ── palette (faithful to source CSS vars) ──────────────────────
  static const _blue    = Color(0xFF2563EB);
  static const _blueD   = Color(0xFF1E40AF);
  static const _blueBg  = Color(0xFFEAF0FC);
  static const _purple  = Color(0xFF7C3AED);
  static const _purpleD = Color(0xFF5B21B6);
  static const _purpleBg= Color(0xFFF1EAFC);
  static const _teal    = Color(0xFF0284C7);
  static const _green   = Color(0xFF059669);
  static const _ink     = Color(0xFF0F172A);
  static const _muted   = Color(0xFF6B7280);
  static const _muted2  = Color(0xFF94A3B8);
  static const _faint   = Color(0xFFCBD5E1);
  static const _border  = Color(0xFFE5E7EB);
  static const _hair    = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 240));
    _sizeFactor = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  // ── helpers ─────────────────────────────────────────────────────
  bool get _is3D  => widget.gameName.contains('3D');
  bool get _isRambol => widget.betType == 'Rambol' || widget.betType == 'Both';

  Color get _digitBg => _is3D ? _purpleBg : _blueBg;
  Color get _digitFg => _is3D ? _purpleD  : _blueD;

  Color get _typeFg {
    switch (widget.betType) {
      case 'Rambol': return _purple;
      case 'Both':   return _teal;
      default:       return _blue;
    }
  }

  String get _typeLabel {
    if (widget.betType == 'Both') return 'Both';
    return widget.betType; // 'Target' | 'Rambol'
  }

  // Unique permutations via swap-backtrack (same algo as source JS)
  List<String> _perms(List<String> digits) {
    final result = <String>{};
    final arr = List<String>.from(digits);
    void go(int s) {
      if (s == arr.length) {
        result.add(arr.map((d) => int.tryParse(d)?.toString() ?? d).join('-'));
        return;
      }
      final seen = <String>{};
      for (int i = s; i < arr.length; i++) {
        if (seen.contains(arr[i])) continue;
        seen.add(arr[i]);
        final t = arr[s]; arr[s] = arr[i]; arr[i] = t;
        go(s + 1);
        final t2 = arr[s]; arr[s] = arr[i]; arr[i] = t2;
      }
    }
    go(0);
    return result.toList()..sort();
  }

  String _fmt(double n) {
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer('₱');
    final len = s.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final perms    = _isRambol ? _perms(widget.digits) : <String>[];
    final gameName = widget.gameName.replaceAll(' Lotto', '');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _open ? const Color(0xFFDBE3F1) : _border,
        ),
        boxShadow: [
          BoxShadow(
            color: _open
                ? _blue.withValues(alpha: 0.20)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius:   _open ? 22 : 2,
            spreadRadius: _open ? -8 : 0,
            offset:       Offset(0, _open ? 8 : 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── HEAD (always visible, always tappable) ─────────────
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 13, 11, 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ncol: digit tiles + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // nrow: digit tiles
                        Wrap(
                          spacing: 5,
                          children: widget.digits.map((d) => _DigitTile(
                            digit: (int.tryParse(d)?.toString() ?? d),
                            bg: _digitBg, fg: _digitFg,
                          )).toList(),
                        ),
                        const SizedBox(height: 9),
                        // meta row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // game tag
                            _GameTag(
                              label: gameName,
                              bg: _is3D ? _purpleBg : _blueBg,
                              fg: _is3D ? _purpleD  : _blueD,
                            ),
                            const SizedBox(width: 7),
                            _MDot(),
                            const SizedBox(width: 7),
                            // type
                            Text(
                              _typeLabel.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w800,
                                letterSpacing: 0.2, color: _typeFg,
                              ),
                            ),
                            // combo count + caret — Rambol/Both only
                            if (perms.isNotEmpty) ...[
                              const SizedBox(width: 7),
                              _MDot(),
                              const SizedBox(width: 7),
                              Text(
                                '${perms.length} combo${perms.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: _purple,
                                ),
                              ),
                              const SizedBox(width: 4),
                              // CSS triangle caret rotates 180° when open
                              AnimatedRotation(
                                turns: _open ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const _Caret(),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // rcol: amount + draw time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // amt — height 32 to align with digit tiles
                      SizedBox(
                        height: 32,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            _fmt(widget.totalAmount),
                            style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800,
                              color: _ink, height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      if (widget.drawTimeLabel.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 11, color: _muted2),
                            const SizedBox(width: 4),
                            Text(
                              widget.drawTimeLabel,
                              style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(width: 2),

                  // remove button — centered vertically
                  Align(
                    alignment: Alignment.center,
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _removeHovered = true),
                      onExit:  (_) => setState(() => _removeHovered = false),
                      child: GestureDetector(
                        onTap: widget.onDelete,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: _removeHovered
                                ? const Color(0xFFFEECEC)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.close,
                            size: 15,
                            color: _removeHovered
                                ? const Color(0xFFE0533D)
                                : _faint,
                          ),
                        ),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),

          // ── EXPAND PANEL — shown for ALL cards ────────────────
          SizeTransition(
            sizeFactor: _sizeFactor,
            axisAlignment: -1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // permutations (Rambol/Both only)
                  if (perms.isNotEmpty) ...[
                    Text(
                      'PERMUTATIONS · ${perms.length}',
                      style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        letterSpacing: 0.7, color: _muted2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5, runSpacing: 5,
                      children: perms.map((p) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F2FE),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          p,
                          style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800,
                            color: _purple,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                  // breakdown — always shown in expand
                  Container(
                    margin: const EdgeInsets.only(top: 11),
                    padding: const EdgeInsets.only(top: 11),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _hair)),
                    ),
                    child: Row(
                      children: [
                        if (widget.straightAmount > 0) ...[
                          _BItem(label: 'TARGET',
                              value: _fmt(widget.straightAmount)),
                          const SizedBox(width: 18),
                        ],
                        if (widget.rambolAmount > 0) ...[
                          _BItem(label: 'RAMBOL',
                              value: _fmt(widget.rambolAmount)),
                          const SizedBox(width: 18),
                        ],
                        _BItem(label: 'TOTAL STAKE',
                            value: _fmt(widget.totalAmount)),
                        const SizedBox(width: 18),
                        _BItem(label: 'EST. PAYOUT',
                            value: _fmt(widget.estPayout),
                            valueColor: _green),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}

// ── Atoms ────────────────────────────────────────────────────────────────────

class _DigitTile extends StatelessWidget {
  final String digit;
  final Color bg, fg;
  const _DigitTile({required this.digit, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 7),
    constraints: const BoxConstraints(minWidth: 30),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(9),
      boxShadow: [BoxShadow(
        color: fg.withValues(alpha: 0.10),
        spreadRadius: 1, blurRadius: 0,
      )],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(digit, style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w800, color: fg, height: 1,
        )),
      ],
    ),
  );
}

class _GameTag extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _GameTag({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(5),
    ),
    child: Text(label, style: TextStyle(
      fontSize: 9.5, fontWeight: FontWeight.w900,
      letterSpacing: 0.4, color: fg,
    )),
  );
}

class _MDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 3, height: 3,
    decoration: const BoxDecoration(
      color: Color(0xFFCBD5E1), shape: BoxShape.circle,
    ),
  );
}

// CSS border-trick triangle caret
class _Caret extends StatelessWidget {
  const _Caret();

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(7, 4),
    painter: _CaretPainter(),
  );
}

class _CaretPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _BItem extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const _BItem({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(
        fontSize: 9, fontWeight: FontWeight.w700,
        letterSpacing: 0.5, color: Color(0xFF94A3B8),
      )),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w800,
        color: valueColor ?? const Color(0xFF1F2937),
      )),
    ],
  );
}
