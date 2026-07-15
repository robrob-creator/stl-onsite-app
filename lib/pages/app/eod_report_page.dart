import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/eod_report_service.dart';
import '../../core/services/printer_service.dart';
import '../../models/eod_report.dart';
import 'package:get/get.dart';
import '../../controllers/lottery_controller.dart';
import '../../core/services/websocket_service.dart';

class EodReportPage extends StatefulWidget {
  final String makerId;
  final String date;
  const EodReportPage({super.key, required this.makerId, required this.date});

  @override
  State<EodReportPage> createState() => _EodReportPageState();
}

class _EodReportPageState extends State<EodReportPage> {
  late Future<EodReportModel> _futureReport;
  bool _isPrinting = false;
  late LotteryController _lotteryController;
  final List<VoidCallback> _wsUnsubscribers = [];

  @override
  void initState() {
    super.initState();
    _lotteryController = Get.find<LotteryController>();

    // Initial fetch
    _futureReport = EodReportService.fetchEodReport(
      makerId: widget.makerId,
      date: widget.date,
    );

    // Refresh when bets change elsewhere
    ever(_lotteryController.drawRefreshTick, (_) => _refreshReport());

    // Listen to websocket events to refresh in near real-time. Also
    // subscribe to the wildcard '*' to catch transaction-like events that
    // may use different event names on the backend.
    try {
      final ws = Get.find<WebSocketService>();
      _wsUnsubscribers.add(ws.on('bet.placed', (_) => _refreshReport()));
      _wsUnsubscribers.add(ws.on('bet.bulk_placed', (_) => _refreshReport()));
      _wsUnsubscribers.add(ws.on('claim.paid', (_) => _refreshReport()));
      _wsUnsubscribers.add(ws.on('bet.submitted', (_) => _refreshReport()));

      // Wildcard listener: backend always emits api.mutation for POST/PUT/DELETE.
      // Check both _eventType and the endpoint path so approved-void events
      // (endpoint: /api/request/approve/void-ticket) also trigger a refresh.
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
          _refreshReport();
        }
      }));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EOD Report'), leading: BackButton()),
      body: FutureBuilder<EodReportModel>(
        future: _futureReport,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No data'));
          }
          final report = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                // Logo
                Image.asset('assets/images/logos/logo.png', height: 80),
                const SizedBox(height: 16),
                Text(
                  report.location,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Teller ID: ${report.tellerId}',
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'End of Day Sales ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
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
                      DateFormat('MM/dd/yyyy, hh:mm a').format(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _buildRow('Gross Sales', report.grossSales, highlight: true),
                _buildRow('Less Commission', report.lessCommission),
                _buildRow('Hits', report.hits),
                _buildRow('Total Net', report.totalNet),
                _buildRow('For Collection', report.forCollection),
                _buildCountRow('Total Bets', report.totalBets),
                if (report.breakdown.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(thickness: 1),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Game Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const Divider(thickness: 1),
                  for (final item in report.breakdown) ...[
                    const SizedBox(height: 10),
                    Text(
                      item.gameName.isNotEmpty ? item.gameName : 'Game',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildCountRow('Bets', item.betCount),
                    _buildRow('Gross', item.grossSales),
                    _buildRow('Hits', item.hits),
                    _buildRow('Net', item.net),
                    const Divider(thickness: 0.5),
                  ],
                ],
                const SizedBox(height: 32),
                SizedBox(
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
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
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

  Future<void> _refreshReport() async {
    setState(() {
      _futureReport = EodReportService.fetchEodReport(
        makerId: widget.makerId,
        date: widget.date,
      );
    });
  }

  Future<void> _handlePrint(EodReportModel report) async {
    setState(() {
      _isPrinting = true;
    });

    final result = await PrinterService.printEodReport(report: report);

    if (!mounted) {
      return;
    }

    setState(() {
      _isPrinting = false;
    });

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

  Widget _buildCountRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text('$count', style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildRow(String label, double value, {bool highlight = false}) {
    final isNegative = value < 0;
    final displayValue = isNegative
        ? '- ₱ ${value.abs().toStringAsFixed(2)}'
        : '₱ ${value.toStringAsFixed(2)}';
    final color = highlight
        ? Colors.green
        : isNegative
            ? Colors.red
            : Colors.black;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 15,
              fontWeight: highlight || isNegative ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
