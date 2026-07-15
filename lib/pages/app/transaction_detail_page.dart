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
          ? '$hour:00 $period Draw'
          : '$hour:${minute.toString().padLeft(2, '0')} $period Draw';
    } catch (_) {
      return drawTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          _formatDrawTimeLabel(group.drawTime),
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.text),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          _GroupSummaryStrip(group: group),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: group.tickets.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TicketCard(
                    ticket: group.tickets[index],
                    drawTime: group.drawTime,
                    index: index + 1,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupSummaryStrip extends StatelessWidget {
  final TicketGroup group;

  const _GroupSummaryStrip({required this.group});

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            _SummaryTile(
              icon: Icons.confirmation_number_outlined,
              label: 'Tickets',
              value: '${group.count}',
            ),
            _vDivider(),
            _SummaryTile(
              icon: Icons.payments_outlined,
              label: 'Total',
              value: '₱${group.totalAmount.toStringAsFixed(2)}',
            ),
            _vDivider(),
            _SummaryTile(
              icon: Icons.verified_outlined,
              label: 'Status',
              value: group.overallStatus.toUpperCase(),
              valueColor: _statusColor(group.overallStatus),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: AppColors.primary.withValues(alpha: 0.2),
      );
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(
              color: valueColor ?? AppColors.text,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatefulWidget {
  final Ticket ticket;
  final String drawTime;
  final int index;

  const _TicketCard({
    required this.ticket,
    required this.drawTime,
    required this.index,
  });

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
      try {
        final locale = Localizations.localeOf(context).toLanguageTag();
        final dateLabel = DateFormat.yMMMMd(locale).format(local);
        final timeLabel = DateFormat.jm(locale).format(local);
        return '$dateLabel @ $timeLabel';
      } catch (_) {
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        final dateLabel = '${months[local.month - 1]}. ${local.day}, ${local.year}';
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      case 'printed':
        return const Color(0xFF06B6D4);
      case 'pending':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  Color _statusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AppColors.successLight;
      case 'failed':
        return AppColors.errorLight;
      case 'printed':
        return const Color(0xFFE0F7FA);
      case 'pending':
        return AppColors.warningLight;
      default:
        return AppColors.primaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final statusColor = _statusColor(ticket.status);
    final statusBg = _statusBgColor(ticket.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: statusColor),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  image: const DecorationImage(
                                    image: AssetImage(
                                      'assets/images/logos/logo.png',
                                    ),
                                    fit: BoxFit.contain,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ticket #${widget.index}',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      ticket.ticketNo,
                                      style: AppTextStyles.titleSmall.copyWith(
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₱${ticket.totalBetAmount.toStringAsFixed(2)}',
                                    style: AppTextStyles.titleSmall.copyWith(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      ticket.status.toLowerCase() == 'lost' ? 'Lose' : ticket.status.toUpperCase(),
                                      style: AppTextStyles.caption.copyWith(
                                        color: statusColor,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 10),
                          _MetaRow(
                            label: 'Draw Time',
                            value: _formatDrawTime(widget.drawTime),
                          ),
                          const SizedBox(height: 5),
                          _MetaRow(
                            label: 'Date & Time',
                            value: _formatDateTime(ticket.createdAt),
                          ),
                          if (ticket.customer != null) ...[
                            const SizedBox(height: 5),
                            _MetaRow(
                              label: 'Agent',
                              value: ticket.customer!.name,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_expanded) ...[
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_error != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: Text(
                            'Failed to load bets',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.error,
                            ),
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
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: _expanded
                              ? AppColors.primaryLight
                              : const Color(0xFFF8FAFC),
                          border: Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _expanded ? 'Hide Bets' : 'View Bets',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBetsTable(List<TicketBet> bets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bet Details',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      _th('Game', flex: 2),
                      _th('No.', flex: 2),
                      _th('Amt', flex: 1),
                      _th('Type', flex: 2),
                      _th('Payout', flex: 2),
                    ],
                  ),
                ),
                ...bets.asMap().entries.map((entry) {
                  final i = entry.key;
                  final bet = entry.value;
                  final isLast = i == bets.length - 1;
                  return Container(
                    color: i.isEven ? Colors.white : const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    foregroundDecoration: isLast
                        ? null
                        : BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: AppColors.border),
                            ),
                          ),
                    child: Row(
                      children: [
                        _td(
                          bet.gameName.isNotEmpty ? bet.gameName : bet.gameId,
                          flex: 2,
                        ),
                        _td(bet.digits.join('-'), flex: 2),
                        _td(
                          bet.totalBetAmount.toStringAsFixed(0),
                          flex: 1,
                        ),
                        _td(bet.betType, flex: 2),
                        _td(bet.estPayout.toStringAsFixed(0), flex: 2),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _th(String text, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(
          text,
          style: AppTextStyles.labelSmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _td(String text, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(
          text,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
