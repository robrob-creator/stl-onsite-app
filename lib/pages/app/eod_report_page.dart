import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../controllers/lottery_controller.dart';
import '../../core/services/eod_report_service.dart';
import '../../core/services/printer_service.dart';
import '../../core/services/websocket_service.dart';
import '../../models/eod_report.dart';

/// Draw Report page — matches the third-party "DRAW REPORT" layout the
/// operations team already uses on paper: header with date + agent, then
/// one line per (draw time, game) with a per-sched subtotal, plus a filter
/// row + action buttons at the bottom.
class EodReportPage extends StatefulWidget {
  final String makerId;
  final String date;
  const EodReportPage({super.key, required this.makerId, required this.date});

  @override
  State<EodReportPage> createState() => _EodReportPageState();
}

class _EodReportPageState extends State<EodReportPage> {
  static final _pesoFmt = NumberFormat('#,##0.00', 'en_PH');
  static final _apiDateFmt = DateFormat('yyyy-MM-dd');
  static final _displayDateFmt = DateFormat('yyyy-MM-dd');

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
    setState(() => _reportDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw Report'),
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(report),
                      const SizedBox(height: 8),
                      _buildTable(report),
                    ],
                  ),
                ),
              ),
              _buildFilterBar(report),
              _buildActionBar(report),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(EodReportModel report) {
    final agent = report.tellerName.isNotEmpty ? report.tellerName : '—';
    final agentNo = report.agentNo.isNotEmpty ? report.agentNo : '';
    final headerLine = agentNo.isEmpty ? agent : '$agent / $agentNo';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DRAW REPORT ${_apiDateFmt.format(_reportDate)}',
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            headerLine.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<EodSlotItem> _filteredSlots(EodReportModel report) {
    return report.slots.where((s) {
      if (_gameFilter.isNotEmpty && s.gameId != _gameFilter) return false;
      if (_timeFilter.isNotEmpty && s.sched != _timeFilter) return false;
      return true;
    }).toList();
  }

  Widget _buildTable(EodReportModel report) {
    final slots = _filteredSlots(report);

    // Group by sched preserving backend order (ORDER BY draw_time, game).
    final Map<String, List<EodSlotItem>> grouped = <String, List<EodSlotItem>>{};
    for (final s in slots) {
      grouped.putIfAbsent(s.sched, () => <EodSlotItem>[]).add(s);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: Colors.black87,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerRow(),
            _dashRule(),
            for (final entry in grouped.entries) ...[
              for (final row in entry.value) _dataRow(row),
              _dashRule(),
              _subtotalRow(entry.key, entry.value),
              _dashRule(),
            ],
            if (slots.isNotEmpty) _grandTotalRow(slots),
          ],
        ),
      ),
    );
  }

  static const _colSched = 90.0;
  static const _colGame = 90.0;
  static const _colNumeric = 90.0;

  Widget _headerRow() {
    return Row(
      children: const [
        SizedBox(width: _colSched, child: Text('Sched')),
        SizedBox(width: _colGame, child: Text('Game')),
        SizedBox(width: _colNumeric, child: Text('Lines', textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text('Gross', textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text('Hits', textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text('Bets', textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text('Payout', textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text('Net', textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _dashRule() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: SizedBox(
        width: _colSched + _colGame + _colNumeric * 6,
        child: Text(
          '----------------------------------------------------------------------------------------',
          overflow: TextOverflow.clip,
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
  }

  Widget _dataRow(EodSlotItem row) {
    return Row(
      children: [
        SizedBox(width: _colSched, child: Text(_formatSched(row.sched))),
        SizedBox(width: _colGame, child: Text(row.gameName)),
        SizedBox(width: _colNumeric, child: Text('${row.lines}', textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text(_pesoFmt.format(row.gross), textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text('${row.hitsCount}', textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text(_pesoFmt.format(row.betsAmount), textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text(_pesoFmt.format(row.payout), textAlign: TextAlign.right)),
        SizedBox(
          width: _colNumeric,
          child: Text(
            _pesoFmt.format(row.net),
            textAlign: TextAlign.right,
            style: TextStyle(color: row.net < 0 ? Colors.red : null),
          ),
        ),
      ],
    );
  }

  Widget _subtotalRow(String sched, List<EodSlotItem> rows) {
    final lines = rows.fold<int>(0, (a, r) => a + r.lines);
    final gross = rows.fold<double>(0, (a, r) => a + r.gross);
    final hits = rows.fold<int>(0, (a, r) => a + r.hitsCount);
    final bets = rows.fold<double>(0, (a, r) => a + r.betsAmount);
    final payout = rows.fold<double>(0, (a, r) => a + r.payout);
    final net = gross - payout;
    return Row(
      children: [
        const SizedBox(width: _colSched, child: SizedBox()),
        const SizedBox(width: _colGame, child: Text('Total')),
        SizedBox(width: _colNumeric, child: Text('$lines', textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text(_pesoFmt.format(gross), textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text('$hits', textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text(_pesoFmt.format(bets), textAlign: TextAlign.right)),
        SizedBox(width: _colNumeric, child: Text(_pesoFmt.format(payout), textAlign: TextAlign.right)),
        SizedBox(
          width: _colNumeric,
          child: Text(
            _pesoFmt.format(net),
            textAlign: TextAlign.right,
            style: TextStyle(color: net < 0 ? Colors.red : null),
          ),
        ),
      ],
    );
  }

  Widget _grandTotalRow(List<EodSlotItem> slots) {
    final lines = slots.fold<int>(0, (a, r) => a + r.lines);
    final gross = slots.fold<double>(0, (a, r) => a + r.gross);
    final hits = slots.fold<int>(0, (a, r) => a + r.hitsCount);
    final bets = slots.fold<double>(0, (a, r) => a + r.betsAmount);
    final payout = slots.fold<double>(0, (a, r) => a + r.payout);
    final net = gross - payout;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const SizedBox(width: _colSched, child: SizedBox()),
          const SizedBox(
            width: _colGame,
            child: Text('GRAND', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(width: _colNumeric, child: Text('$lines', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: _colNumeric, child: Text(_pesoFmt.format(gross), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: _colNumeric, child: Text('$hits', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: _colNumeric, child: Text(_pesoFmt.format(bets), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: _colNumeric, child: Text(_pesoFmt.format(payout), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(
            width: _colNumeric,
            child: Text(
              _pesoFmt.format(net),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: net < 0 ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(EodReportModel report) {
    // Distinct games + sched values sourced from the current report so the
    // dropdowns can only pick values that actually exist for this date.
    final games = <String, String>{}; // gameId -> gameName
    final scheds = <String>{};
    for (final s in report.slots) {
      if (s.gameId.isNotEmpty) games[s.gameId] = s.gameName;
      if (s.sched.isNotEmpty) scheds.add(s.sched);
    }
    final schedList = scheds.toList()..sort();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _pickDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16),
                  const SizedBox(width: 8),
                  Text(_displayDateFmt.format(_reportDate),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _gameFilter.isEmpty ? '' : _gameFilter,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All Games')),
                    for (final entry in games.entries)
                      DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                  ],
                  onChanged: (v) => setState(() => _gameFilter = v ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _timeFilter.isEmpty ? '' : _timeFilter,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All Times')),
                    for (final s in schedList)
                      DropdownMenuItem(value: s, child: Text(_formatSched(s))),
                  ],
                  onChanged: (v) => setState(() => _timeFilter = v ?? ''),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(EodReportModel report) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('GET RPT'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isPrinting ? null : () => _handlePrint(report),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3D5A99),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isPrinting ? 'PRINTING...' : 'PRINT'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: null,
                  child: const Text('MINMAX'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  child: const Text('CLOSE'),
                ),
              ),
            ],
          ),
        ],
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
    final period = h >= 12 ? 'pm' : 'am';
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    if (m == 0) return '$h12$period';
    return '$h12.${m.toString().padLeft(2, '0')}$period';
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
