import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/lottery_controller.dart';
import '../../core/services/eod_report_service.dart';
import '../../core/services/printer_service.dart';
import '../../core/services/websocket_service.dart';
import '../../models/eod_report.dart';

/// End of Day Sales — visual layout matching the ops team wireframe:
/// top filter row (Draw Date / Game / Draw Time), totals block, then a
/// per-sched card with a Game/Gross/Hits/Bets/Payout/Net table.
class EodReportPage extends StatefulWidget {
  final String makerId;
  final String date;
  const EodReportPage({super.key, required this.makerId, required this.date});

  @override
  State<EodReportPage> createState() => _EodReportPageState();
}

class _EodReportPageState extends State<EodReportPage> {
  static final _pesoFmt = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱ ',
    decimalDigits: 2,
  );
  static final _apiDateFmt = DateFormat('yyyy-MM-dd');
  static final _headerTimeFmt = DateFormat('MM/dd/yyyy, hh:mm a');

  late Future<EodReportModel> _futureReport;
  bool _isPrinting = false;
  late LotteryController _lotteryController;
  final List<VoidCallback> _wsUnsubscribers = [];

  late DateTime _reportDate;
  String _gameFilter = ''; // '' = all
  String _timeFilter = ''; // '' = all

  @override
  void initState() {
    super.initState();
    _lotteryController = Get.find<LotteryController>();

    final parsed = DateTime.tryParse(widget.date);
    _reportDate = parsed ?? DateTime.now();
    _futureReport = _fetch();

    ever(_lotteryController.drawRefreshTick, (_) => _refresh());

    try {
      final ws = Get.find<WebSocketService>();
      _wsUnsubscribers.add(ws.on('bet.placed', (_) => _refresh()));
      _wsUnsubscribers.add(ws.on('bet.bulk_placed', (_) => _refresh()));
      _wsUnsubscribers.add(ws.on('claim.paid', (_) => _refresh()));
      _wsUnsubscribers.add(ws.on('bet.submitted', (_) => _refresh()));
      _wsUnsubscribers.add(ws.on('*', (payload) {
        final type = payload['_eventType'] as String? ?? '';
        final endpoint = (payload['endpoint'] as String?) ?? '';
        if (type.contains('bet') ||
            type.contains('claim') ||
            type.contains('transaction') ||
            type.contains('ticket') ||
            endpoint.contains('void') ||
            endpoint.contains('request/approve') ||
            endpoint.contains('request/disapprove')) {
          _refresh();
        }
      }));
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final unsub in _wsUnsubscribers) {
      try {
        unsub();
      } catch (_) {}
    }
    super.dispose();
  }

  Future<EodReportModel> _fetch() {
    return EodReportService.fetchEodReport(
      makerId: widget.makerId,
      date: _apiDateFmt.format(_reportDate),
    );
  }

  Future<void> _refresh() async {
    setState(() => _futureReport = _fetch());
    await _futureReport;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null) return;
    setState(() {
      _reportDate = picked;
      _futureReport = _fetch();
    });
  }

  List<EodSlotItem> _visibleSlots(EodReportModel r) => r.slots.where((s) {
        if (_gameFilter.isNotEmpty && s.gameId != _gameFilter) return false;
        if (_timeFilter.isNotEmpty && s.sched != _timeFilter) return false;
        return true;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('EOD Report'),
        leading: const BackButton(),
      ),
      body: FutureBuilder<EodReportModel>(
        future: _futureReport,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No data'));
          }
          final report = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFilterRow(report),
                const SizedBox(height: 20),
                _buildSalesHeader(),
                const SizedBox(height: 12),
                _buildTotals(report),
                const SizedBox(height: 20),
                _buildSchedSections(report),
                const SizedBox(height: 20),
                _buildPrintButton(report),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterRow(EodReportModel report) {
    final games = <String, String>{};
    final scheds = <String>{};
    for (final s in report.slots) {
      if (s.gameId.isNotEmpty) games[s.gameId] = s.gameName;
      if (s.sched.isNotEmpty) scheds.add(s.sched);
    }
    final schedList = scheds.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filterCard(
          label: _apiDateFmt.format(_reportDate),
          placeholder: 'Draw Date',
          onTap: _pickDate,
          isValueSet: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _dropdownFilterCard(
                label: 'Game',
                value: _gameFilter,
                items: [
                  const DropdownMenuItem(value: '', child: Text('Game')),
                  for (final entry in games.entries)
                    DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (v) => setState(() => _gameFilter = v ?? ''),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdownFilterCard(
                label: 'Draw Time',
                value: _timeFilter,
                items: [
                  const DropdownMenuItem(value: '', child: Text('Draw Time')),
                  for (final s in schedList)
                    DropdownMenuItem(value: s, child: Text(_formatSched(s))),
                ],
                onChanged: (v) => setState(() => _timeFilter = v ?? ''),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterCard({
    required String label,
    required String placeholder,
    required VoidCallback onTap,
    required bool isValueSet,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isValueSet ? label : placeholder,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _dropdownFilterCard({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          hint: Text(
            label,
            style: const TextStyle(fontSize: 20, color: Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildSalesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'End of Day Sales ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Tooltip(
              message: 'Total sales for the day.',
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        Text(
          _headerTimeFmt.format(DateTime.now()),
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTotals(EodReportModel report) {
    return Column(
      children: [
        _totalsRow('Gross Sales', report.grossSales, highlight: true),
        _totalsRow('Less Commission', report.lessCommission),
        _totalsRow('Hits', report.hits),
        _totalsRow('Total Net', report.totalNet),
        _totalsRow('For Collection', report.forCollection),
        _countRow('Total Bets', report.totalBets),
      ],
    );
  }

  Widget _totalsRow(String label, double value, {bool highlight = false}) {
    final isNeg = value < 0;
    final display = isNeg
        ? '- ₱ ${value.abs().toStringAsFixed(2)}'
        : '₱ ${value.toStringAsFixed(2)}';
    final color = highlight
        ? Colors.green
        : isNeg
            ? Colors.red
            : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            display,
            style: TextStyle(
              fontSize: 15,
              fontWeight: highlight || isNeg ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text('$count', style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildSchedSections(EodReportModel report) {
    final slots = _visibleSlots(report);
    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No sales for the selected filters.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ),
      );
    }
    final grouped = <String, List<EodSlotItem>>{};
    for (final s in slots) {
      grouped.putIfAbsent(s.sched, () => <EodSlotItem>[]).add(s);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in grouped.entries) ...[
          _schedSection(entry.key, entry.value),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _schedSection(String sched, List<EodSlotItem> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            _formatSched(sched).toUpperCase(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _schedTable(rows),
      ],
    );
  }

  Widget _schedTable(List<EodSlotItem> rows) {
    final gross = rows.fold<double>(0, (a, r) => a + r.gross);
    final hits = rows.fold<int>(0, (a, r) => a + r.hitsCount);
    final bets = rows.fold<double>(0, (a, r) => a + r.betsAmount);
    final payout = rows.fold<double>(0, (a, r) => a + r.payout);
    final net = gross - payout;

    return Table(
      border: TableBorder.all(color: const Color(0xFF9CA3AF), width: 1),
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1.4),
        2: FlexColumnWidth(1.0),
        3: FlexColumnWidth(1.4),
        4: FlexColumnWidth(1.4),
        5: FlexColumnWidth(1.4),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF3F4F6)),
          children: [
            _th('Game'),
            _th('Gross'),
            _th('Hits'),
            _th('Bets'),
            _th('Payout'),
            _th('Net'),
          ],
        ),
        for (final r in rows)
          TableRow(children: [
            _td(r.gameName),
            _td(_pesoFmt.format(r.gross)),
            _td('${r.hitsCount}'),
            _td(_pesoFmt.format(r.betsAmount)),
            _td(_pesoFmt.format(r.payout)),
            _td(_pesoFmt.format(r.net), negative: r.net < 0),
          ]),
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFF9FAFB)),
          children: [
            _td('Total', bold: true),
            _td(_pesoFmt.format(gross), bold: true),
            _td('$hits', bold: true),
            _td(_pesoFmt.format(bets), bold: true),
            _td(_pesoFmt.format(payout), bold: true),
            _td(_pesoFmt.format(net), bold: true, negative: net < 0),
          ],
        ),
      ],
    );
  }

  Widget _th(String s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(
          s,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      );

  Widget _td(String s, {bool bold = false, bool negative = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Text(
          s,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: negative ? Colors.red : Colors.black87,
          ),
        ),
      );

  Widget _buildPrintButton(EodReportModel report) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isPrinting ? null : () => _handlePrint(report),
        icon: Icon(
          _isPrinting ? Icons.hourglass_top : Icons.print,
          color: Colors.white,
        ),
        label: Text(_isPrinting ? 'Printing...' : 'Print Report'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  String _formatSched(String raw) {
    if (raw.isEmpty) return '—';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return raw;
    final period = h >= 12 ? 'PM' : 'AM';
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    if (m == 0) return '$h12$period';
    return '$h12:${m.toString().padLeft(2, '0')}$period';
  }

  Future<void> _handlePrint(EodReportModel report) async {
    setState(() => _isPrinting = true);
    final result = await PrinterService.printEodReport(report: report);
    if (!mounted) return;
    setState(() => _isPrinting = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('EOD report sent to printer.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    if (result.error == PrintError.noPrinterConfigured ||
        result.error == PrintError.notConnected) {
      Get.dialog(
        Dialog(
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bluetooth_disabled,
                    color: Color(0xFFF59E0B),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  result.error == PrintError.noPrinterConfigured
                      ? 'No Printer Connected'
                      : 'Printer Not Connected',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  result.error == PrintError.noPrinterConfigured
                      ? 'No printer configured. Please set up a Bluetooth printer to print the EOD report.'
                      : 'Unable to connect to printer. Make sure Bluetooth is on and the printer is paired.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.back();
                      Get.toNamed('/printer-settings');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D5A99),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Set Up Printer',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black45),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    final message = switch (result.error) {
      PrintError.permissionDenied => 'Bluetooth permission denied.',
      PrintError.outOfPaper => 'Printer is out of paper.',
      PrintError.nearEndOfPaper => 'Printer is near end of paper.',
      _ => 'Failed to print EOD report.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
