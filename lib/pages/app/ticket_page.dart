import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:onstite/core/services/printer_service.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/design_system.dart';
import '../../models/ticket.dart';
import '../../controllers/ticket_controller.dart';

class TicketPage extends StatefulWidget {
  const TicketPage({super.key});

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> {
  late final TicketController _ctrl;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool showDetails = false;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool _showQRScanner = false;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(TicketController());
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _ctrl.fetchTickets(_searchController.text);
    });
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
      case 'pending_void':
        return AppColors.warning;
      case 'void':
      case 'voided':
        return AppColors.error;
      case 'won':
        return AppColors.success;
      default:
        return Colors.grey[600]!;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending_void':
        return 'VOID REQUEST';
      case 'voided':
        return 'VOIDED';
      case 'pending':
        return 'PENDING';
      case 'won':
        return 'WON';
      case 'lost':
        return 'LOST';
      default:
        return status.toUpperCase();
    }
  }

  bool _canRequestVoid(Ticket ticket) =>
      (ticket.status ?? '').toLowerCase() == 'pending' &&
      !ticket.hasActiveRequest;

  bool _canRequestReprint(Ticket ticket) {
    final status = (ticket.status ?? '').toLowerCase();
    return !ticket.hasActiveRequest &&
        status != 'pending_void' &&
        status != 'voided' &&
        (ticket.betObjects?.isNotEmpty ?? false);
  }

  Color _getRequestStateColor(Ticket ticket) {
    if (ticket.hasApprovedReprintRequest) {
      return AppColors.success;
    }
    if (ticket.hasPendingReprintRequest || ticket.hasPendingVoidRequest) {
      return AppColors.warning;
    }
    return AppColors.textSecondary;
  }

  String _getRequestStateLabel(Ticket ticket) {
    if (ticket.hasApprovedReprintRequest) {
      return 'REPRINT APPROVED';
    }
    if (ticket.hasPendingReprintRequest) {
      return 'REPRINT NEEDS APPROVAL';
    }
    if (ticket.hasPendingVoidRequest) {
      return 'VOID NEEDS APPROVAL';
    }
    return '';
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    controller?.dispose();
    Get.delete<TicketController>();
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
    });
    _ctrl.fetchTickets(qrCode);
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
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Void Approval'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submit a void request for Ticket No. ${ticket.ticketNo}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reason for Void Request',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter reason for requesting a void',
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
                _showFinalVoidConfirmation(ticket, reasonController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.backgroundDark,
              ),
              child: const Text(
                'Submit',
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
        title: const Text('Submit Void Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.orange[300]),
            const SizedBox(height: 16),
            Text(
              'This will send the void request for approval before the ticket can be voided.\n\nContinue for ${ticket.ticketNo}?',
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
      final message = await _ctrl.voidTicket(ticket.id ?? '', reason);
      Get.snackbar(
        'Success',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to void ticket: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showReprintConfirmation(Ticket ticket) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Reprint Approval'),
        content: Text(
          'Submit a reprint request for Ticket No. ${ticket.ticketNo}? Approval is required before this ticket can be reprinted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestReprintAction(ticket);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _requestReprintAction(Ticket ticket) async {
    try {
      final message = await _ctrl.requestReprint(ticket.id ?? '');
      Get.snackbar(
        'Success',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        '$e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    }
  }

  Future<bool> _ensurePrinterReadyForReprint() async {
    final reachability = await PrinterService.getSavedPrinterReachability();
    switch (reachability) {
      case PrinterReachabilityStatus.reachable:
        return true;
      case PrinterReachabilityStatus.notConfigured:
        Get.snackbar(
          'Printer Required',
          'Connect a printer before using an approved reprint.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warning,
          colorText: Colors.white,
        );
        return false;
      case PrinterReachabilityStatus.permissionDenied:
        Get.snackbar(
          'Permission Required',
          'Allow Nearby devices permission so the app can connect to your printer.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warning,
          colorText: Colors.white,
        );
        return false;
      case PrinterReachabilityStatus.unreachable:
        Get.snackbar(
          'Printer Unavailable',
          'Make sure the configured printer is powered on and in Bluetooth range before reprinting.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warning,
          colorText: Colors.white,
        );
        return false;
    }
  }

  Future<void> _reprintTicketAction(Ticket ticket) async {
    if (!await _ensurePrinterReadyForReprint()) {
      return;
    }

    try {
      await _ctrl.consumeApprovedReprint(ticket.id ?? '');
      final result = await PrinterService.reprintTicket(ticket: ticket);
      await _ctrl.fetchTickets();

      if (result.success) {
        Get.snackbar(
          'Success',
          'Ticket sent to printer successfully.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
        );
        return;
      }

      Get.snackbar(
        'Print Failed',
        'The reprint approval was used but printing failed. Fix the printer issue and request approval again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        '$e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
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
                          child: Obx(
                            () => GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                _ctrl.setStatus(status);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: _ctrl.selectedStatus.value == status
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
                                    color: _ctrl.selectedStatus.value == status
                                        ? Colors.white
                                        : Colors.grey[400],
                                  ),
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
          child: Obx(() {
            if (_ctrl.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            if (_ctrl.hasError.value) {
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
                      onPressed: () => _ctrl.fetchTickets(),
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

            final allTickets = _ctrl.tickets;

            if (allTickets.isEmpty) {
              return Center(
                child: Text(
                  'No tickets found',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: allTickets.length,
              itemBuilder: (context, index) {
                final ticket = allTickets[index];
                return _buildTicketCard(ticket);
              },
            );
          }),
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
                        if (_canRequestVoid(ticket))
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
                                const Text('Request Void'),
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
                    _getStatusLabel(ticket.status ?? 'UNKNOWN'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(ticket.status ?? 'unknown'),
                    ),
                  ),
                  if (_getRequestStateLabel(ticket).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _getRequestStateLabel(ticket),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _getRequestStateColor(ticket),
                      ),
                    ),
                  ],
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
          if (_getRequestStateLabel(ticket).isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getRequestStateColor(ticket).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getRequestStateColor(ticket).withOpacity(0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getRequestStateLabel(ticket),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _getRequestStateColor(ticket),
                    ),
                  ),
                  if ((ticket.requestRemarks ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      ticket.requestRemarks!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (ticket.hasApprovedReprintRequest ||
              ticket.hasPendingReprintRequest ||
              _canRequestReprint(ticket))
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_canRequestReprint(ticket))
                  OutlinedButton.icon(
                    onPressed: () => _showReprintConfirmation(ticket),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Request Reprint'),
                  ),
                if (ticket.hasPendingReprintRequest)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.25),
                      ),
                    ),
                    child: const Text(
                      'Reprint request sent for approval',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (ticket.hasApprovedReprintRequest)
                  ElevatedButton.icon(
                    onPressed: () => _reprintTicketAction(ticket),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    icon: const Icon(
                      Icons.print,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Reprint',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
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
                                      _getStatusLabel(bet.status ?? ''),
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
                          _getStatusLabel(ticket.status ?? ''),
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
