import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/design_system.dart';
import '../../models/ticket.dart';
import '../../core/services/ticket_service.dart';

class TicketPage extends StatefulWidget {
  const TicketPage({super.key});

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> {
  String selectedStatus = 'Tickets'; // Active or Void
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Ticket>> _ticketsFuture;
  Timer? _debounceTimer;
  bool showDetails = false;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool _showQRScanner = false;
  @override
  void initState() {
    super.initState();
    _ticketsFuture = _fetchTickets();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _ticketsFuture = _fetchTickets(_searchController.text);
      });
    });
  }

  Future<List<Ticket>> _fetchTickets([String? ticketNo]) async {
    return await TicketService.fetchTickets(
      ticketNo: ticketNo,
      status: selectedStatus == 'Void'
          ? 'voided'
          : 'pending_void,pending,won,lost',
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final utcDate = DateTime.parse(dateStr);
      final localDate = utcDate.toLocal();
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
      int hour = localDate.hour;
      final minute = localDate.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final timeStr = '${hour.toString().padLeft(2, '0')}:$minute $period';
      return '${months[localDate.month - 1]}. ${localDate.day.toString().padLeft(2, '0')}, ${localDate.year} @ $timeStr';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.primary;
      case 'void':
        return const Color(0xFFEC4899);
      case 'won':
        return const Color(0xFF10B981);
      default:
        return Colors.grey[600]!;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    controller?.dispose();
    super.dispose();
  }

  Future<void> _startQRScan() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      Get.snackbar(
        'Permission Denied',
        'Camera permission is required to scan QR codes',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _showQRScanner = true;
    });
  }

  void _handleScannedQRCode(String qrCode) {
    // Stop scanner
    controller?.pauseCamera();

    // Set the scanned value as search query
    _searchController.text = qrCode;

    // Trigger search
    setState(() {
      _showQRScanner = false;
      _ticketsFuture = _fetchTickets(qrCode);
    });
  }

  @override
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        controller!.pauseCamera();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        controller!.resumeCamera();
      }
    }
  }

  void _showVoidConfirmation(Ticket ticket) {
    final TextEditingController _reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void Entry'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Void Ticket No. ${ticket.ticketNo}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reason for Void',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter reason for voiding this ticket',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),

              // Bet details table
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: OutlinedButton(
              style: ButtonStyle(alignment: Alignment.center),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showFinalVoidConfirmation(ticket, _reasonController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.backgroundDark,
              ),
              child: const Text(
                'Submit ',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFinalVoidConfirmation(Ticket ticket, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.orange[300]),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to void this transaction ?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _voidTicketAction(ticket, reason);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _voidTicketAction(Ticket ticket, String reason) async {
    try {
      await TicketService.voidTicket(ticket.id ?? '', reason);
      Get.snackbar(
        'Success',
        'Ticket voided successfully',
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
      // Refresh the tickets list
      setState(() {
        _ticketsFuture = _fetchTickets(_searchController.text);
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to void ticket: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showQRScanner) {
      return Stack(
        children: [
          QRView(
            key: qrKey,
            onQRViewCreated: (QRViewController controller) {
              this.controller = controller;
              controller.scannedDataStream.listen((scanData) {
                if (scanData.code != null) {
                  _handleScannedQRCode(scanData.code!);
                }
              });
            },
            overlay: QrScannerOverlayShape(
              borderColor: AppColors.primary,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 250,
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () {
                setState(() {
                  _showQRScanner = false;
                });
                controller?.dispose();
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Header with title and status filter
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Status filter
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: ['Tickets', 'Void']
                      .map(
                        (status) => Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedStatus = status;
                                _searchController.clear();
                                _ticketsFuture = _fetchTickets();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: selectedStatus == status
                                    ? AppColors.primary
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: selectedStatus == status
                                      ? Colors.white
                                      : Colors.grey[400],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        // Search and scan button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Ticket number (e.g., TKT-369)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _startQRScan,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Ticket list
        Expanded(
          child: FutureBuilder<List<Ticket>>(
            future: _ticketsFuture,
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
                        'Failed to load tickets',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _ticketsFuture = _fetchTickets();
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

              final allTickets = snapshot.data ?? [];

              if (allTickets.isEmpty) {
                return Center(
                  child: Text(
                    'No tickets found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }

              // Sort tickets: pending_void first, then others
              allTickets.sort((a, b) {
                if (a.status?.toLowerCase() == 'pending_void' &&
                    b.status?.toLowerCase() != 'pending_void') {
                  return -1;
                }
                if (a.status?.toLowerCase() != 'pending_void' &&
                    b.status?.toLowerCase() == 'pending_void') {
                  return 1;
                }
                return 0;
              });

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: allTickets.length,
                itemBuilder: (context, index) {
                  final ticket = allTickets[index];
                  return _buildTicketCard(ticket);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(Ticket ticket) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[100]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ticket number with icon
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/logos/logo.png'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: 160,
                          child: Text(
                            ticket.ticketNo ?? 'Unknown Ticket',
                            overflow: TextOverflow.visible,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if ((ticket.status ?? '').toLowerCase() == 'pending')
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.backgroundDark,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () => _showVoidConfirmation(ticket),
                            child: Row(
                              children: [
                                Text("Void"),
                                const SizedBox(width: 4),
                                const Icon(Icons.close, size: 14),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket.cluster?.name ?? 'Unknown',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Ticket details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bets:',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ticket.betObjects?.length ?? 0} bet${(ticket.betObjects?.length ?? 0) != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Status:',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (ticket.status ?? 'UNKNOWN').toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(ticket.status ?? 'unknown'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Transaction date
          Text(
            'Created:',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(ticket.createdAt),
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 16),
          // Bet details table
          if ((ticket.betObjects?.isNotEmpty ?? false) &&
                  ((ticket.status ?? '').toLowerCase() != 'voided')
              ? true
              : showDetails) ...[
            Text(
              'Bets Details',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[300]!, width: 1),
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // Table header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Bet No',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Amount',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Type',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Table rows
                  ...?ticket.betObjects?.map((bet) {
                    String betType = (bet.straightBetAmount ?? 0) > 0
                        ? 'Straight'
                        : 'Ramble';
                    return Column(
                      children: [
                        Divider(color: Colors.grey[200], height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Text(
                                  (bet.digits?.isNotEmpty ?? false)
                                      ? bet.digits!.join('-')
                                      : 'N/A',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '₱ ${(bet.totalBetAmount ?? 0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  betType,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        bet.status ?? '',
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      (bet.status ?? '').toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _getStatusColor(
                                          bet.status ?? '',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ] else if ((ticket.betObjects?.isEmpty ?? true) &&
              (ticket.status ?? '').toLowerCase() != 'voided') ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No bets in this ticket',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Bet Details Summary
          if ((ticket.betObjects?.isNotEmpty ?? false)) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  // Bet Amount
                  Row(
                    children: [
                      Icon(
                        Icons.card_giftcard,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bet Amount',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Text(
                        '₱ ${(ticket.betObjects?.fold<double>(0, (prev, bet) => prev + (bet.totalBetAmount ?? 0)) ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey[300], height: 1),
                  const SizedBox(height: 12),
                  // Status
                  Row(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            ticket.status ?? '',
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (ticket.status ?? '').toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(ticket.status ?? ''),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey[300], height: 1),
                  const SizedBox(height: 12),
                  // Price Payoff
                  Row(
                    children: [
                      Icon(
                        Icons.trending_up,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Price Payoff',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Text(
                        (ticket.winningPayout ?? 0) > 0
                            ? '₱ ${(ticket.winningPayout ?? 0).toStringAsFixed(2)}'
                            : '-',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // View bet details button
          if ((ticket.status ?? '').toLowerCase() == "voided")
            GestureDetector(
              onTap: () {
                setState(() {
                  showDetails = !showDetails;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'View Bet Details',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
