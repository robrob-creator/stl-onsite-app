import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/lottery_controller.dart';

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LotteryController>();
    final submittedBets = Get.arguments['submittedBets'] as List? ?? [];
    final totalAmount = Get.arguments['totalAmount'];
    final transaction =
        Get.arguments['transaction'] as Map<String, dynamic>? ?? {};
    final ledgers = Get.arguments['ledgers'] as List? ?? [];
    final batchId = Get.arguments['batchId'] as String? ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () {},
        ),
        title: Text(
          '✓ ₱${totalAmount.toString()}',
          style: const TextStyle(
            color: Color(0xFF2563EB),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Logo at top
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logos/logo.png',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'OFFICIAL RECEIPT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Receipt Details
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildReceiptRow(
                    'Batch ID:',
                    batchId.substring(0, 8) + '...',
                  ),
                  _buildReceiptRow(
                    'Transaction ID:',
                    (transaction['id'] as String?)?.substring(0, 8) ?? 'N/A',
                  ),
                  _buildReceiptRow(
                    'Type:',
                    transaction['type'] ?? 'Bulk Bet Placement',
                  ),
                  _buildReceiptRow(
                    'Status:',
                    (transaction['status'] as String? ?? 'pending')
                        .toUpperCase(),
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    'Date:',
                    DateTime.now().toString().split(' ')[0],
                  ),
                  _buildReceiptRow(
                    'Time:',
                    DateTime.now().toString().split(' ')[1].substring(0, 5),
                  ),
                  _buildReceiptRow(
                    'Bets Submitted:',
                    submittedBets.length.toString(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bets Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 40,
                columns: const [
                  DataColumn(label: Text('TICKET #')),
                  DataColumn(label: Text('NUMBERS')),
                  DataColumn(label: Text('STRAIGHT')),
                  DataColumn(label: Text('RAMBOL')),
                  DataColumn(label: Text('TOTAL')),
                ],
                rows: submittedBets.map<DataRow>((bet) {
                  final digits = (bet.digits as List?)?.join(',') ?? '';
                  final straightAmount =
                      (bet.straightBetAmount as num?)?.toStringAsFixed(2) ??
                      '0.00';
                  final rambolAmount =
                      (bet.rambleBetAmount as num?)?.toStringAsFixed(2) ??
                      '0.00';
                  final totalAmount =
                      (bet.totalBetAmount as num?)?.toStringAsFixed(2) ??
                      '0.00';

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          bet.ticketNo ?? 'N/A',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(digits, style: const TextStyle(fontSize: 11)),
                      ),
                      DataCell(
                        Text(
                          '₱$straightAmount',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          '₱$rambolAmount',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        Text(
                          '₱$totalAmount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Totals
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'BETS TOTAL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₱${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Transaction'),
                      Text(
                        'Ref: ${(transaction['reference_id'] as String?)?.substring(0, 8) ?? 'N/A'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:'),
                      Text(
                        '₱${(transaction['amount'] as num?)?.toStringAsFixed(2) ?? totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Date Printed:'),
                      Text(
                        DateTime.now().toString().split(' ')[0],
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Time Printed:'),
                      Text(
                        DateTime.now().toString().split(' ')[1].substring(0, 5),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Ledger Details if available
            if (ledgers.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LEDGER DETAILS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Divider(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 12,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 40,
                        columns: const [
                          DataColumn(label: Text('DESCRIPTION')),
                          DataColumn(label: Text('DEBIT')),
                          DataColumn(label: Text('BALANCE')),
                        ],
                        rows: ledgers.map<DataRow>((ledger) {
                          final description =
                              ledger['description'] as String? ?? '';
                          final debit =
                              (ledger['debit'] as num?)?.toStringAsFixed(2) ??
                              '0.00';
                          final runningBalance =
                              (ledger['running_balance'] as num?)
                                  ?.toStringAsFixed(2) ??
                              '0.00';

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  description.length > 20
                                      ? description.substring(0, 20) + '...'
                                      : description,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '₱$debit',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '₱$runningBalance',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // QR Code Placeholder
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border.all(color: Colors.grey[400]!),
                    ),
                    child: Center(
                      child: Text(
                        'QR CODE',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Batch ID: ${batchId.substring(0, 8)}...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Implement share functionality
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Implement download functionality
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Download',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // New Bet Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  controller.clearNumbers();
                  controller.targetAmount.value = 0;
                  controller.rambolAmount.value = 0;
                  controller.draftBets.clear();
                  Get.offNamed('/bet-entry');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[400],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'New Bet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.description, color: Colors.grey),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: Color(0xFF2563EB)),
            label: 'Bet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time, color: Colors.grey),
            label: 'Transaction',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people, color: Colors.grey),
            label: 'Ticket',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star, color: Colors.grey),
            label: 'Claim',
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
