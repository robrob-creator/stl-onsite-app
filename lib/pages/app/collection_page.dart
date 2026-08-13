import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/lottery_controller.dart';
import '../../core/services/claims_service.dart';
import '../../core/services/collections_service.dart';
import '../../models/claim.dart';
import '../../models/collection.dart';

class CollectionPage extends StatefulWidget {
  const CollectionPage({super.key});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  static final _apiDateFmt = DateFormat('yyyy-MM-dd');
  static final _displayDateFmt = DateFormat('MMM d, yyyy');
  static final _pesoFmt = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  late DateTime _startDate;
  late DateTime _endDate;
  late Future<List<Collection>> _future;
  List<Claim> _claims = [];
  Worker? _collectionWorker;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day);
    _startDate = _endDate.subtract(const Duration(days: 6));
    _future = _fetch();
    // Auto-refresh when collector records a payment (WS event).
    try {
      final lc = Get.find<LotteryController>();
      _collectionWorker = ever(lc.collectionRefreshTick, (_) {
        if (mounted) _refresh();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _collectionWorker?.dispose();
    super.dispose();
  }

  Future<List<Collection>> _fetch() {
    final start = _apiDateFmt.format(_startDate);
    final end = _apiDateFmt.format(_endDate);
    // Fetch claims in parallel; silently ignore failures.
    ClaimsService.list(startDate: start, endDate: end).then((c) {
      if (mounted) setState(() => _claims = c);
    }).catchError((_) {});
    return CollectionsService.list(startDate: start, endDate: end);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_startDate.isAfter(_endDate)) _startDate = _endDate;
      }
      _future = _fetch();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _fetch();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Collections'),
        leading: const BackButton(),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          _buildDateFilter(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Collection>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Failed to load collections.\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  final items = snapshot.data ?? const <Collection>[];
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _buildTotalsCard(const <Collection>[]),
                        const SizedBox(height: 120),
                        const Center(
                          child: Text(
                            'No collections in this date range.',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ),
                      ],
                    );
                  }
                  return _buildList(items);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _DateChip(
              label: 'Start',
              value: _displayDateFmt.format(_startDate),
              onTap: () => _pickDate(isStart: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DateChip(
              label: 'End',
              value: _displayDateFmt.format(_endDate),
              onTap: () => _pickDate(isStart: false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Collection> items) {
    // Group by draw_date so the header repeats only when the date changes.
    // Items are ordered oldest-first (draw_date ASC) so payment allocation
    // and display both flow from earliest to latest draw.
    final children = <Widget>[_buildTotalsCard(items)];
    String? currentDate;
    for (var i = 0; i < items.length; i++) {
      final c = items[i];
      if (c.drawDate != currentDate) {
        currentDate = c.drawDate;
        children.add(_buildDateHeader(currentDate));
      }
      children.add(_buildRow(c));
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Extra bottom padding so the last row is not hidden behind the
      // system nav bar / gesture area.
      padding: const EdgeInsets.only(bottom: 96),
      children: children,
    );
  }

  Widget _buildTotalsCard(List<Collection> items) {
    double gross = 0;
    double hits = 0;
    double commission = 0;
    double totalCollected = 0;
    double balance = 0; // sum of netAmount for unsettled draws only
    for (final c in items) {
      gross += c.grossAmount;
      hits += c.hitsAmount;
      commission += c.commissionAmount;
      // Tapada = collector paid out → subtract. Normal = collector received → add.
      totalCollected += c.isTapada ? -c.paidAmount : c.paidAmount;
      final isSettled = c.status == 'paid' || c.status == 'tapada';
      // carryoverAmount = remaining balance for both partial (leftover) and
      // uncollected (full net). Using this keeps Balance equal to the agent's
      // actual running balance after partial payments.
      // For unsettled tapada collections (wins > bets), netAmount is negative
      // and represents what the agent still owes net (hits - gross). Include it
      // in balance so the agent sees their true net position.
      if (!isSettled) {
        // If net is negative (hits > bets), use netAmount directly so balance
        // reflects the true position — collector owes agent the difference.
        // Works even when is_tapada flag is false (e.g. draw result came in after collection).
        balance += c.netAmount < 0 ? c.netAmount : c.carryoverAmount;
      }
    }

    // Claimed = winnings where QR scan completed (status='claimed').
    // Unclaimed = winnings still pending (status='pending').
    final claimAmount = _claims
        .where((c) => c.status == 'claimed')
        .fold(0.0, (s, c) => s + c.winningAmount);
    final unclaimAmount = _claims
        .where((c) => c.status == 'pending')
        .fold(0.0, (s, c) => s + c.winningAmount);
    final hasHits = _claims.isNotEmpty || hits > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _TotalStat(label: 'Gross', value: _pesoFmt.format(gross)),
              ),
              Expanded(
                child: _TotalStat(label: 'Hits', value: _pesoFmt.format(hits)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TotalStat(
                  label: 'Total Collected',
                  value: _pesoFmt.format(totalCollected),
                  emphasize: totalCollected > 0,
                  color: const Color(0xFF86EFAC),
                ),
              ),
              Expanded(
                child: _TotalStat(
                  label: 'Balance',
                  value: _pesoFmt.format(balance),
                  emphasize: balance != 0,
                ),
              ),
            ],
          ),
          if (commission > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TotalStat(
                    label: 'Commission',
                    value: _pesoFmt.format(commission),
                    emphasize: true,
                    color: const Color(0xFF93C5FD),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
          if (hasHits) ...[
            const SizedBox(height: 10),
            Container(
              height: 1,
              color: const Color(0xFF374151),
              margin: const EdgeInsets.only(bottom: 10),
            ),
            Row(
              children: [
                Expanded(
                  child: _TotalStat(
                    label: 'Claimed',
                    value: _pesoFmt.format(claimAmount),
                    emphasize: claimAmount > 0,
                    color: const Color(0xFF86EFAC),
                  ),
                ),
                Expanded(
                  child: _TotalStat(
                    label: 'Unclaimed',
                    value: _pesoFmt.format(unclaimAmount),
                    emphasize: unclaimAmount > 0,
                    color: const Color(0xFFFCA5A5),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateHeader(String rawDate) {
    String label = rawDate;
    final parsed = DateTime.tryParse(rawDate);
    if (parsed != null) label = _displayDateFmt.format(parsed);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildRow(Collection c) {
    final isPaid        = c.status == 'paid' || c.status == 'tapada';
    final isPartial     = c.status == 'partial';
    final isUncollected = !isPaid && !isPartial;
    final netAbs = c.netAmount.abs();
    final paidProgress = (netAbs > 0 && isPartial)
        ? (c.paidAmount / netAbs).clamp(0.0, 1.0)
        : 0.0;

    Color borderColor;
    Color bgColor;
    double borderWidth;
    if (isPaid) {
      borderColor = const Color(0xFF86EFAC);
      bgColor     = const Color(0xFFF0FDF4);
      borderWidth = 1.5;
    } else if (isPartial) {
      borderColor = const Color(0xFFFDE68A);
      bgColor     = const Color(0xFFFFFBEB);
      borderWidth = 1.5;
    } else {
      borderColor = const Color(0xFFE5E7EB);
      bgColor     = Colors.white;
      borderWidth = 1.0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF6B7280)),
              const SizedBox(width: 6),
              Text(
                _formatDrawTime(c.drawTime),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              _StatusBadge(collection: c),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MoneyStat(label: 'Gross', value: _pesoFmt.format(c.grossAmount)),
              ),
              if (c.commissionAmount > 0)
                Expanded(
                  child: _MoneyStat(
                    label: 'Commission',
                    value: _pesoFmt.format(c.commissionAmount),
                    highlightColor: const Color(0xFF2563EB),
                    highlight: true,
                  ),
                ),
              Expanded(
                child: _MoneyStat(label: 'Net', value: _pesoFmt.format(c.netAmount)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MoneyStat(
                  label: isPaid ? 'Collected' : isPartial ? 'Paid So Far' : 'Paid',
                  value: _pesoFmt.format(c.paidAmount),
                  highlight: isPaid,
                  highlightColor: const Color(0xFF15803D),
                ),
              ),
              Expanded(
                child: _MoneyStat(
                  label: isPaid ? 'Balance' : 'Remaining',
                  value: _pesoFmt.format(
                    isPaid ? 0.0 : isPartial ? c.carryoverAmount : c.netAmount,
                  ),
                  highlight: !isPaid && c.netAmount > 0,
                  highlightColor: isPartial
                      ? const Color(0xFFD97706)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          if (isPartial) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: paidProgress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFFEF3C7),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(paidProgress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text(
                  '${_pesoFmt.format(c.carryoverAmount)} remaining to pay collector',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ],
          if (isPaid) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF15803D)),
                const SizedBox(width: 4),
                Text(
                  c.status == 'tapada'
                      ? 'Tapada settled by collector'
                      : 'Fully collected by collector',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ],
          if (isUncollected && c.netAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule_outlined, size: 14, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  '${_pesoFmt.format(c.netAmount)} pending collection',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDrawTime(String raw) {
    if (raw.isEmpty) return '—';
    // Handle Postgres time strings like "11:00:00" or timestamp-ish inputs.
    String timeStr = raw;
    if (raw.contains('T')) {
      timeStr = raw.split('T').last.replaceAll('Z', '');
    }
    final parts = timeStr.split(':');
    if (parts.length < 2) return raw;
    final hourNum = int.tryParse(parts[0]);
    final minuteNum = int.tryParse(parts[1]);
    if (hourNum == null || minuteNum == null) return raw;
    final period = hourNum >= 12 ? 'PM' : 'AM';
    var hour12 = hourNum % 12;
    if (hour12 == 0) hour12 = 12;
    final minuteStr = minuteNum.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateChip({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final Collection collection;
  const _StatusBadge({required this.collection});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (collection.status.toLowerCase()) {
      case 'paid':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      case 'partial':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        break;
      case 'tapada':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        break;
      default:
        bg = const Color(0xFFE5E7EB);
        fg = const Color(0xFF374151);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        collection.statusLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _TotalStat extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final Color? color;

  const _TotalStat({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Color valueColor = Colors.white;
    if (color != null && emphasize) {
      valueColor = color!;
    } else if (emphasize) {
      valueColor = const Color(0xFFFCA5A5);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _MoneyStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final Color? highlightColor;

  const _MoneyStat({
    required this.label,
    required this.value,
    this.highlight = false,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? (highlightColor ?? const Color(0xFFDC2626))
        : const Color(0xFF1F2937);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
