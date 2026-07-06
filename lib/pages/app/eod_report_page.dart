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

    final message = switch (result.error) {
      null => 'EOD report sent to printer.',
      PrintError.noPrinterConfigured => 'No printer configured.',
      PrintError.permissionDenied => 'Bluetooth permission denied.',
      PrintError.notConnected => 'Unable to connect to printer.',
      PrintError.outOfPaper => 'Printer is out of paper.',
      PrintError.nearEndOfPaper => 'Printer is near end of paper.',
      PrintError.unknown => 'Failed to print EOD report.',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildRow(String label, double value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            '₱ ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Colors.green : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
