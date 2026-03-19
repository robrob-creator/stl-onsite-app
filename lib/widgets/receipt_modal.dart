import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'dart:io';
import 'dart:typed_data' show Uint8List;
import 'dart:async' show TimeoutException;
import 'dart:math' show min;
import '../models/bet.dart';
import '../controllers/lottery_controller.dart';

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 5.0;
    const dashSpace = 5.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        Paint()
          ..color = Colors.black
          ..strokeWidth = 1,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ReceiptModal extends StatefulWidget {
  final List<Bet> submittedBets;
  final double totalAmount;
  final Map<String, dynamic> transaction;
  final List<dynamic> ledgers;
  final String batchId;
  final Map<String, dynamic> teller;

  const ReceiptModal({
    super.key,
    required this.submittedBets,
    required this.totalAmount,
    required this.transaction,
    required this.ledgers,
    required this.batchId,
    required this.teller,
  });

  @override
  State<ReceiptModal> createState() => _ReceiptModalState();
}

class _ReceiptModalState extends State<ReceiptModal> {
  final GlobalKey _receiptKey = GlobalKey();
  late WidgetsToImageController _imageController;

  @override
  void initState() {
    super.initState();
    _imageController = WidgetsToImageController();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
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
      return '${months[date.month - 1]}. ${date.day.toString().padLeft(2, '0')}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate totals for the summary row
    double totalStraight = 0;
    double totalRambol = 0;
    for (var bet in widget.submittedBets) {
      totalStraight += bet.straightBetAmount;
      totalRambol += bet.rambleBetAmount;
    }

    // Get draw date and time from first bet
    final firstBet = widget.submittedBets.isNotEmpty
        ? widget.submittedBets[0]
        : null;
    final drawDateStr = firstBet?.drawDate ?? DateTime.now().toString();
    final drawDate = drawDateStr.split('T')[0];
    final dateFormatted = _formatDate(drawDate);

    final now = DateTime.now();
    final timeFormatted =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final datePrintedFormatted = _formatDate(now.toString().split(' ')[0]);

    // Get teller info
    final tellerPhone = widget.teller['phone_number'] as String? ?? 'N/A';

    if (widget.submittedBets.isEmpty) {
      return const SizedBox();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16.0),
          child: WidgetsToImage(
            controller: _imageController,
            child: RepaintBoundary(
              key: _receiptKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Handle bar
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Logo
                        Image.asset(
                          'assets/images/logos/logo.png',
                          width: 100,
                          height: 100,
                        ),

                        const SizedBox(height: 16),

                        // Title
                        const Text(
                          'OFFICIAL RECEIPT',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        // Dashed line
                        SizedBox(
                          width: double.infinity,
                          height: 1,
                          child: CustomPaint(painter: DashedLinePainter()),
                        ),

                        const SizedBox(height: 20),

                        // Receipt Info
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              _buildInfoRow('Draw Date:', dateFormatted),
                              _buildInfoRow('Draw Time:', '2PM'),
                              _buildInfoRow(
                                'Ticket No.',
                                widget.submittedBets.isNotEmpty
                                    ? widget.submittedBets[0].ticketNo ?? 'N/A'
                                    : 'N/A',
                              ),
                              _buildInfoRow('Teller ID:', tellerPhone),
                              _buildInfoRow('Location:', 'N/A'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Bets Table
                        SizedBox(
                          width: double.infinity,
                          child: Table(
                            border: TableBorder.all(color: Colors.black),
                            children: [
                              // Header row
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'GAME',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'ENTRY',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'TARGET',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'RAMBOL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                              // Bet rows
                              ...widget.submittedBets.map((bet) {
                                final digits =
                                    (bet.digits as List?)?.join('-') ?? '';
                                return TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        '3D',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        digits,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        bet.straightBetAmount.toStringAsFixed(
                                          0,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        bet.rambleBetAmount.toStringAsFixed(0),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                              // Total row
                              TableRow(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      'TOTAL',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      '',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      totalStraight.toStringAsFixed(0),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      totalRambol.toStringAsFixed(0),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Transaction Summary
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              _buildInfoRow(
                                'Total Transaction:',
                                widget.submittedBets.length.toString(),
                              ),
                              _buildInfoRow(
                                'Total Amount:',
                                (widget.transaction['amount'] as num?)
                                        ?.toStringAsFixed(0) ??
                                    widget.totalAmount.toStringAsFixed(0),
                              ),
                              _buildInfoRow(
                                'Date Printed:',
                                datePrintedFormatted,
                              ),
                              _buildInfoRow('Time Printed:', timeFormatted),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Dashed line
                        SizedBox(
                          width: double.infinity,
                          height: 1,
                          child: CustomPaint(painter: DashedLinePainter()),
                        ),

                        const SizedBox(height: 20),

                        // QR Code
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            children: [
                              // Batch ID QR Code
                              Column(
                                children: [
                                  Text(
                                    'BATCH QR',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.black),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: PrettyQrView.data(
                                        data: widget.batchId,
                                        errorCorrectLevel:
                                            QrErrorCorrectLevel.Q,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Batch ID: ${widget.batchId.substring(0, 8)}...',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Ticket ID QR Code
                              if (widget.submittedBets.isNotEmpty &&
                                  widget.submittedBets[0].ticketId != null)
                                Column(
                                  children: [
                                    Text(
                                      'TICKET QR',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => _createClaimForTicket(
                                        widget.submittedBets[0].ticketId!,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.green,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: PrettyQrView.data(
                                            data: widget
                                                .submittedBets[0]
                                                .ticketId!,
                                            errorCorrectLevel:
                                                QrErrorCorrectLevel.Q,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Ticket ID: ${widget.submittedBets[0].ticketId!.substring(0, 8)}...',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap QR to create claim',
                                      style: TextStyle(
                                        color: Colors.green[600],
                                        fontSize: 10,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _shareReceipt,
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
                          onPressed: _downloadReceipt,
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

                  const SizedBox(height: 16),

                  // Close Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ), // RepaintBoundary
          ), // WidgetsToImage
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _shareReceipt() async {
    try {
      final batchId = widget.batchId;
      final betsCount = widget.submittedBets.length;
      final totalAmount = widget.totalAmount;

      final shareText =
          '''
Lottery Receipt
Batch ID: $batchId
Total Bets: $betsCount
Total Amount: ₱${totalAmount.toStringAsFixed(2)}

Share your receipt details!
      ''';

      await Share.share(shareText, subject: 'Lottery Receipt - Batch $batchId');
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to share receipt: $e',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _downloadReceipt() async {
    try {
      // Show loading indicator
      log('Starting receipt download process...');
      if (!mounted) return;

      Get.snackbar(
        'Processing',
        'Preparing receipt for download...',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1),
      );

      // Give the UI a moment to update before capturing
      await Future.delayed(const Duration(milliseconds: 500));

      log('Attempting to capture image...');

      // Capture the widget as an image with timeout
      Uint8List? image;
      try {
        image = await _imageController.capture().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            log('Image capture timed out');
            throw TimeoutException('Image capture timed out after 5 seconds');
          },
        );
      } catch (captureError) {
        log('Image capture error: $captureError');
        throw Exception('Failed to capture receipt: $captureError');
      }

      if (image == null || image.isEmpty) {
        log('Image is null or empty');
        throw Exception('Failed to capture receipt image - result is empty');
      }

      log('Image captured successfully, size: ${image.length} bytes');

      // Use app documents directory for saving (always available on iOS)
      log('Getting documents directory...');
      final directory = await getApplicationDocumentsDirectory();
      log('Documents directory: ${directory.path}');

      // Create a unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final batchIdShort = widget.batchId.substring(
        0,
        min(8, widget.batchId.length),
      );
      final filePath =
          '${directory.path}/receipt_${batchIdShort}_$timestamp.png';

      log('Writing file to: $filePath');

      // Save the image
      final file = File(filePath);
      await file.writeAsBytes(image);

      log('File written, verifying...');

      // Verify file was created and has content
      if (!await file.exists()) {
        log('File does not exist after writing: $filePath');
        throw Exception('File was not created');
      }

      final fileSize = await file.length();
      log('File size: $fileSize bytes');

      if (fileSize == 0) {
        log('File is empty after writing: $filePath');
        throw Exception('File was created but is empty');
      }

      // Save to gallery (non-blocking)
      log('Saving to photo gallery...');

      // Show success message immediately
      Get.snackbar(
        'Success',
        'Receipt saved! Size: ${(fileSize / 1024).toStringAsFixed(1)}KB',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );

      // Save to gallery in background (fire and forget with timeout)
      Future.delayed(const Duration(milliseconds: 100)).then((_) async {
        try {
          log('Gallery save starting...');
          // Try to save to gallery with a timeout using Future.timeout
          final galleryTask = ImageGallerySaverPlus.saveImage(
            image!,
            quality: 100,
          );
          await (galleryTask as Future).timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              log('Gallery save timeout - but file is saved to Documents');
            },
          );
          log('Gallery save completed');
        } catch (galleryError) {
          log('Gallery save error: $galleryError');
          // Silently fail - file is already saved to documents
        }
      });

      log('Download completed successfully');
    } catch (e) {
      log('Download error: $e');
      Get.snackbar(
        'Error',
        'Download failed: $e',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Create a claim for the winning ticket
  Future<void> _createClaimForTicket(String ticketId) async {
    try {
      Get.snackbar(
        'Processing',
        'Creating claim for ticket...',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      final lotteryController = Get.find<LotteryController>();
      final result = await lotteryController.createClaimByTicket(ticketId);

      if (result['success'] as bool) {
        log('Claim created successfully: ${result['data']}');
        Get.snackbar(
          'Success',
          'Winning claim has been created!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        // Refresh user profile after successful claim
        await lotteryController.loadProfile();
      } else {
        final error = result['error'] as String? ?? 'Failed to create claim';
        log('Claim creation failed: $error');
        Get.snackbar(
          'Error',
          error,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      log('Claim creation error: $e');
      Get.snackbar(
        'Error',
        'Failed to create claim: $e',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    }
  }
}
