import 'package:flutter/material.dart';
import '../../core/design_system.dart';
import '../../models/transaction.dart';

class TransactionDetailPage extends StatefulWidget {
  final Transaction transaction;

  const TransactionDetailPage({super.key, required this.transaction});

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  bool _showBetDetails = true;

  String _formatDate(String dateStr) {
    try {
      final utcDate = DateTime.parse(dateStr);
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

  String _formatTimeOnly(String dateStr) {
    try {
      final utcDate = DateTime.parse(dateStr);
      final localDate = utcDate.toLocal();

      int hour = localDate.hour;
      final minute = localDate.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final timeStr = '${hour.toString().padLeft(2, '0')}:$minute $period';
      return timeStr;
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.primary;
      case 'completed':
      case 'yes':
        return const Color(0xFF10B981);
      case 'failed':
      case 'no':
        return Colors.red;
      default:
        return Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final bets = transaction.reference.bets;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Transaction Details',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transaction ID
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/logos/logo.png'),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transaction.type
                                    .replaceAll("_", " ")
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Draw Time & Transaction Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Draw Time:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimeOnly(transaction.createdAt),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Transaction Date & Time:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(transaction.createdAt),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_showBetDetails) const SizedBox(height: 24),
              // Bets Table
              if (bets.isNotEmpty) ...[
                if (_showBetDetails)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildTableHeader('Game', flex: 2),
                        _buildTableHeader('Bet.No', flex: 2),
                        _buildTableHeader('Amount', flex: 2),
                        _buildTableHeader('Type', flex: 2),
                        _buildTableHeader('Soldout', flex: 2),
                      ],
                    ),
                  ),
                // Bets list
                if (_showBetDetails)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: bets.length,
                    itemBuilder: (context, index) {
                      final bet = bets[index];
                      final isLast = index == bets.length - 1;
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[200]!,
                              width: isLast ? 0 : 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            _buildTableCell(bet.gameName, flex: 2),
                            _buildTableCell(bet.digits.join('-'), flex: 2),
                            _buildTableCell(
                              '₱${bet.totalBetAmount.toStringAsFixed(2)}',
                              flex: 2,
                            ),
                            _buildTableCell('Rambol', flex: 2),
                            _buildTableCell(
                              bet.status.toLowerCase() == 'yes' ? 'Yes' : 'No',
                              flex: 2,
                              statusColor: _getStatusColor(bet.status),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                // Hide/Show Bet Details Button
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                      ),
                      onPressed: () {
                        setState(() {
                          _showBetDetails = !_showBetDetails;
                        });
                      },
                      child: Text(
                        _showBetDetails
                            ? 'Hide Bet Details'
                            : 'Show Bet Details',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {int flex = 1, Color? statusColor}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: statusColor ?? Colors.black87,
          ),
        ),
      ),
    );
  }
}
