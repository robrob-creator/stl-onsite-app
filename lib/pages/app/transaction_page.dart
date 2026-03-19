import 'package:flutter/material.dart';
import '../../core/design_system.dart';
import '../../models/transaction.dart';
import '../../core/services/transaction_service.dart';
import 'transaction_detail_page.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  String? selectedFilter = 'All Time';
  late Future<List<Transaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _transactionsFuture = TransactionService.fetchTransactions();
  }

  String _formatDate(String dateStr) {
    try {
      final utcDate = DateTime.parse(dateStr);
      // Convert UTC to local time
      final localDate = utcDate.toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);

      String dateLabel;
      if (dateOnly == today) {
        dateLabel = 'Today';
      } else if (dateOnly == yesterday) {
        dateLabel = 'Yesterday';
      } else {
        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        dateLabel = '${months[localDate.month - 1]} ${localDate.day}';
      }

      // Format time in 12-hour format with AM/PM
      int hour = localDate.hour;
      final minute = localDate.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final timeStr = '${hour.toString().padLeft(2, '0')}:$minute $period';
      return '$dateLabel · $timeStr';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.primary;
      case 'completed':
        return const Color(0xFF10B981);
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with filter
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              DropdownButton<String>(
                value: selectedFilter,
                items: const [
                  DropdownMenuItem(value: 'Today', child: Text('Today')),
                  DropdownMenuItem(
                    value: 'This Week',
                    child: Text('This Week'),
                  ),
                  DropdownMenuItem(
                    value: 'This Month',
                    child: Text('This Month'),
                  ),
                  DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedFilter = value;
                  });
                },
                underline: Container(),
                icon: const Icon(Icons.expand_more, color: AppColors.primary),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
        // Transaction list
        Expanded(
          child: FutureBuilder<List<Transaction>>(
            future: _transactionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load transactions',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _transactionsFuture =
                                TransactionService.fetchTransactions();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final transactions = snapshot.data ?? [];

              if (transactions.isEmpty) {
                return Center(
                  child: Text(
                    'No transactions found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return _buildTransactionCard(transaction);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TransactionDetailPage(transaction: transaction),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(transaction.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Amount
                Text(
                  '₱${transaction.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      transaction.status,
                    ).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    transaction.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(transaction.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}
