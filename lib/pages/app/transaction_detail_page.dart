import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/design_system.dart';
import '../../models/transaction.dart';
import '../../core/services/transaction_service.dart';

class TransactionDetailPage extends StatelessWidget {
  final TicketGroup group;

  const TransactionDetailPage({super.key, required this.group});

  String _formatDrawTimeLabel(String drawTime) {
    try {
      final parts = drawTime.split(':');
      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return minute == 0
          ? '$hour$period'
          : '$hour:${minute.toString().padLeft(2, '0')}$period';
    } catch (_) {
      return drawTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          '${_formatDrawTimeLabel(group.drawTime)} Transaction',
          style: const TextStyle(
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
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: group.tickets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _TicketCard(
            ticket: group.tickets[index],
            drawTime: group.drawTime,
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatefulWidget {
  final Ticket ticket;
  final String drawTime;

  const _TicketCard({required this.ticket, required this.drawTime});

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  bool _expanded = false;
  bool _loading = false;
  String? _error;
  List<TicketBet>? _bets;

  Future<void> _loadBets() async {
    if (_bets != null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bets = await TransactionService.fetchTicketBets(widget.ticket.id);
      setState(() {
        _bets = bets;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDrawTime(String drawTime) {
    try {
      final parts = drawTime.split(':');
      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return minute == 0
          ? '$hour$period'
          : '$hour:${minute.toString().padLeft(2, '0')}$period';
    } catch (_) {
      return drawTime;
    }
  }

  String _formatDateTime(String dateStr) {
    try {
      final local = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final dateOnly = DateTime(local.year, local.month, local.day);

      // Always show explicit full date (e.g. June 6, 2026) followed by time
      try {
        final locale = Localizations.localeOf(context).toLanguageTag();
        final dateLabel = DateFormat.yMMMMd(locale).format(local);
        final timeLabel = DateFormat.jm(locale).format(local);
        return '$dateLabel @ $timeLabel';
      } catch (_) {
        // Fallback formatting
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
        final dateLabel =
            '${months[local.month - 1]}. ${local.day}, ${local.year}';
        int hour = local.hour;
        final minute = local.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$dateLabel @ $hour:$minute $period';
      }
    } catch (_) {
      return dateStr;
    }
  }

  // Map ticket status to a UI color
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'failed':
        return Colors.red;
      case 'printed':
        return const Color(0xFF06B6D4);
      case 'pending':
        return Colors.amber;
      default:
        return AppColors.primary;
    }
  }

  Widget _buildTableHeader(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    int flex = 1,
    Color? color,
    bool badge = false,
  }) {
    final content = Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: badge ? Colors.transparent : (color ?? Colors.black87),
      ),
    );
    if (badge) {
      return Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: (color ?? Colors.grey[400])!.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.grey[600],
              ),
            ),
          ),
        ),
      );
    }
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: content,
      ),
    );
  }

  Widget _buildBetsTable(List<TicketBet> bets) {
    return Column(
      children: [
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
              _buildTableHeader('Est. Payout', flex: 2),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[200]!),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: bets.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, i) {
              final bet = bets[i];
              final isSoldout = bet.status.toLowerCase() == 'soldout';
              return Row(
                children: [
                  _buildTableCell(
                    (bet.gameName.isNotEmpty) ? bet.gameName : bet.gameId,
                    flex: 2,
                  ),
                  _buildTableCell(bet.digits.join('-'), flex: 2),
                  _buildTableCell(
                    bet.totalBetAmount.toStringAsFixed(0),
                    flex: 2,
                  ),
                  _buildTableCell(bet.betType, flex: 2),
                  _buildTableCell(bet.estPayout.toStringAsFixed(0), flex: 2),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        image: const DecorationImage(
                          image: AssetImage('assets/images/logos/logo.png'),
                          fit: BoxFit.contain,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ticket.ticketNo,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    // Show ticket total amount and status chip on the right
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₱${ticket.totalBetAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(
                              ticket.status,
                            ).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _statusColor(
                                ticket.status,
                              ).withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            ticket.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _statusColor(ticket.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Draw Time:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      _formatDrawTime(widget.drawTime),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Transaction Date & Time:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    Text(
                      _formatDateTime(ticket.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (ticket.customer != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Agent:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        ticket.customer!.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          if (_expanded) ...[
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  'Failed to load bets',
                  style: TextStyle(fontSize: 12, color: Colors.red[400]),
                ),
              )
            else if (_bets != null && _bets!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: _buildBetsTable(_bets!),
              ),
          ],

          GestureDetector(
            onTap: () async {
              if (!_expanded) {
                setState(() => _expanded = true);
                await _loadBets();
              } else {
                setState(() => _expanded = false);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.only(
                  bottomLeft: const Radius.circular(12),
                  bottomRight: const Radius.circular(12),
                  topLeft: Radius.circular(_expanded ? 0 : 12),
                  topRight: Radius.circular(_expanded ? 0 : 12),
                ),
              ),
              child: Text(
                _expanded ? 'Hide Bet Details' : 'View Bet Details',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
