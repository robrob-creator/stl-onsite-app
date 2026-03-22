import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/eod_report_service.dart';
import '../../models/eod_report.dart';

class EodReportPage extends StatefulWidget {
  final String makerId;
  final String date;
  const EodReportPage({Key? key, required this.makerId, required this.date})
    : super(key: key);

  @override
  State<EodReportPage> createState() => _EodReportPageState();
}

class _EodReportPageState extends State<EodReportPage> {
  late Future<EodReportModel> _futureReport;

  @override
  void initState() {
    super.initState();
    _futureReport = EodReportService.fetchEodReport(
      makerId: widget.makerId,
      date: widget.date,
    );
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
                    onPressed: () {},
                    icon: const Icon(Icons.print, color: Colors.white),
                    label: const Text('Print Report'),
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
