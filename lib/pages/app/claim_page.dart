import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/app_constants.dart';
import 'package:onstite/core/design_system.dart';
import '../../controllers/lottery_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/claim.dart';

class ClaimPage extends StatefulWidget {
  const ClaimPage({super.key});

  @override
  State<ClaimPage> createState() => _ClaimPageState();
}

class _ClaimPageState extends State<ClaimPage> {
  late LotteryController lotteryController;
  late AuthController authController;
  QRViewController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool _showQRScanner = true; // Show QR scanner first
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Claim> _claims = [];
  bool _isLoadingClaims = false;
  String? _errorMessage;
  StreamSubscription? _qrSubscription;
  Map<String, dynamic>? _scannedTicketData; // Store scanned ticket data

  @override
  void initState() {
    super.initState();
    lotteryController = Get.find<LotteryController>();
    authController = Get.find<AuthController>();
    _fetchClaims();
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

  @override
  void dispose() {
    _qrSubscription?.cancel();
    controller?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    // Cancel any existing subscription before creating a new one
    _qrSubscription?.cancel();
    _qrSubscription = controller.scannedDataStream.listen((scanData) {
      final qrCode = scanData.code;
      if (qrCode != null) {
        controller.pauseCamera();
        _handleScannedQRCode(qrCode);
      }
    });
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();

    if (status.isDenied) {
      Get.snackbar(
        'Camera Permission',
        'Camera permission is required to scan QR codes',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } else if (status.isPermanentlyDenied) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        Get.dialog(
          AlertDialog(
            title: const Text('Camera Permission'),
            content: const Text(
              'Camera permission is permanently denied. Please enable it in app settings to use QR scanner.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  openAppSettings();
                  Get.back();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      } else {
        Get.snackbar(
          'Camera Permission',
          'Camera permission is permanently denied. Please enable it in app settings to use QR scanner.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    }
  }

  void _handleScannedQRCode(String qrCode) {
    // Parse the QR code to extract ticket ID
    String ticketId = qrCode.trim();

    // Cancel the subscription before closing the scanner
    _qrSubscription?.cancel();
    _qrSubscription = null;

    // Fetch ticket details and verify validity
    _fetchAndVerifyTicket(ticketId);
  }

  Future<void> _fetchAndVerifyTicket(String ticketNumber) async {
    try {
      Get.snackbar(
        'Loading',
        'Verifying ticket...',
        duration: const Duration(seconds: 1),
      );

      final result = await lotteryController.getTicketByNumber(ticketNumber);

      if (result['success'] as bool) {
        final ticketData = result['data'] as Map<String, dynamic>?;

        if (ticketData != null) {
          // Check if ticket is within 1 year validity period
          final isValid = _isTicketValidForClaim(ticketData);

          if (isValid) {
            // Store ticket data and show details dialog
            setState(() {
              _scannedTicketData = ticketData;
              _showQRScanner = false;
            });

            // Show ticket details for verification
            _showTicketDetailsForVerification(ticketData);
          } else {
            // Show error - ticket expired
            _showErrorModal(
              'Ticket Expired',
              'This ticket is no longer valid for claiming. Tickets can only be claimed within one (1) year from the date of issuance.',
            );

            // Resume camera for another scan
            if (mounted) {
              setState(() {
                _showQRScanner = true;
              });
              controller?.resumeCamera();
            }
          }
        } else {
          _showErrorModal(
            'Invalid Ticket',
            'Could not retrieve ticket data. Please try again.',
          );

          // Resume camera for another scan
          if (mounted) {
            setState(() {
              _showQRScanner = true;
            });
            controller?.resumeCamera();
          }
        }
      } else {
        final error = result['error'] as String?;
        _showErrorModal(
          'Ticket Not Found',
          error ??
              'No ticket found for this QR code. Please verify and try again.',
        );

        // Resume camera for another scan
        if (mounted) {
          setState(() {
            _showQRScanner = true;
          });
          controller?.resumeCamera();
        }
      }
    } catch (e) {
      _showErrorModal('Error', 'Failed to verify ticket: $e');

      // Resume camera for another scan
      if (mounted) {
        setState(() {
          _showQRScanner = true;
        });
        controller?.resumeCamera();
      }
    }
  }

  /// Check if ticket is valid for claiming (within 1 year from issuance)
  bool _isTicketValidForClaim(Map<String, dynamic> ticketData) {
    try {
      final createdAtStr = ticketData['created_at'] as String?;
      if (createdAtStr == null || createdAtStr.isEmpty) {
        return false;
      }

      final createdAt = DateTime.parse(createdAtStr);
      final now = DateTime.now();
      final daysDifference = now.difference(createdAt).inDays;

      // Valid if claiming within 365 days (1 year)
      return daysDifference <= 365;
    } catch (e) {
      // If we can't parse the date, mark as invalid for safety
      return false;
    }
  }

  void _showTicketDetailsForVerification(Map<String, dynamic> ticketData) {
    Get.dialog(
      AlertDialog(
        title: const Text('Verify Ticket Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticket: ${ticketData['ticket_no'] ?? 'N/A'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            if (ticketData['created_at'] != null)
              Text(
                'Issued: ${_formatDate(ticketData['created_at'])}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Please confirm this is the correct ticket before proceeding with the claim.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              // Resume QR scanner for retry
              setState(() {
                _showQRScanner = true;
              });
              controller?.resumeCamera();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Get.back();
              // Create claim with the scanned ticket
              if (_scannedTicketData != null) {
                _createClaimFromQRCode(_scannedTicketData!['ticket_no']);
              }
            },
            child: const Text('Claim Winnings'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _createClaimFromQRCode(String ticketId) async {
    try {
      Get.snackbar(
        'Processing',
        'Creating claim...',
        duration: const Duration(seconds: 1),
      );

      final result = await lotteryController.createClaimByTicket(ticketId);

      if (result['success'] as bool) {
        _showSuccessModal(
          'Claim Created',
          'Winning claim has been created successfully!',
        );
        // Refresh claims list and user profile
        _fetchClaims();
        await lotteryController.loadProfile();
      } else {
        final error = result['error'] as String?;
        _showErrorModal(
          'Failed to Create Claim',
          error ?? 'Unknown error occurred',
        );
      }
    } catch (e) {
      _showErrorModal('Error', 'Failed to create claim: $e');
    }
  }

  void _showErrorModal(String title, String message) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessModal(String title, String message) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          ElevatedButton(
            onPressed: () => Get.back(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchClaims({
    String? status,
    String? ticketId,
    String? customerId,
  }) async {
    setState(() {
      _isLoadingClaims = true;
      _errorMessage = null;
    });

    try {
      final token = authController.token.value;
      final baseUrl = '${AppConstants.apiBaseUrl}/claims';

      // Build query parameters
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (ticketId != null && ticketId.isNotEmpty) {
        queryParams['ticket_no'] = ticketId;
      }
      if (customerId != null && customerId.isNotEmpty) {
        queryParams['customer_id'] = customerId;
      }

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final claimsData = jsonData['data'] as List?;

        if (claimsData != null && claimsData.isNotEmpty) {
          final claims = claimsData
              .map((claim) => Claim.fromJson(claim as Map<String, dynamic>))
              .toList();

          setState(() {
            _claims = claims;
            _errorMessage = null;
            _isLoadingClaims = false;
          });
        } else {
          // Empty claims or null data
          setState(() {
            _claims = [];
            _errorMessage = null;
            _isLoadingClaims = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load claims';
          _isLoadingClaims = false;
        });
        Get.snackbar('Error', 'Failed to load claims: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching claims: $e';
        _isLoadingClaims = false;
      });
      Get.snackbar('Error', 'Error fetching claims: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 0,
        title: const Text(
          'Claim',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_showQRScanner)
            TextButton(
              onPressed: () {
                setState(() {
                  _showQRScanner = true;
                  _scannedTicketData = null;
                });
              },
              child: const Text('Scan QR'),
            ),
        ],
      ),
      body: _showQRScanner ? _buildQRScanner() : _buildClaimsList(),
    );
  }

  Widget _buildQRScanner() {
    return Stack(
      children: [
        QRView(
          key: qrKey,
          onQRViewCreated: _onQRViewCreated,
          overlay: QrScannerOverlayShape(
            borderColor: AppColors.primary,
            borderRadius: 10,
            borderLength: 30,
            borderWidth: 10,
            cutOutSize: 300,
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () {
                  _qrSubscription?.cancel();
                  _qrSubscription = null;
                  setState(() {
                    _showQRScanner = false;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.arrow_back, color: Colors.black87),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scan Qr Code',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Place an QR at the center of your\n camera and the QR will be automatically scanned',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  // ElevatedButton(
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: Colors.white,
                  //     foregroundColor: AppColors.primary,
                  //     padding: const EdgeInsets.symmetric(
                  //       horizontal: 24,
                  //       vertical: 12,
                  //     ),
                  //   ),
                  //   onPressed: () {
                  //     _qrSubscription?.cancel();
                  //     _qrSubscription = null;
                  //     setState(() {
                  //       _showQRScanner = false;
                  //     });
                  //   },
                  //   child: const Text('View Claims History'),
                  // ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClaimsList() {
    // Filter claims based on search query
    List<Claim> filteredClaims = _claims;
    if (_searchQuery.isNotEmpty) {
      filteredClaims = _claims
          .where(
            (claim) =>
                (claim.ticket?.ticketNo?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (claim.ticketId?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false),
          )
          .toList();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        children: [
          // Search bar and button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF6B7280),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await _requestCameraPermission();
                      final status = await Permission.camera.status;
                      if (status.isGranted) {
                        setState(() {
                          _showQRScanner = true;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Icon(Icons.qr_code_2, color: Color(0xFF6B7280)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Claims list
          Expanded(
            child: _isLoadingClaims
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.red),
                    ),
                  )
                : filteredClaims.isEmpty
                ? Center(
                    child: Text(
                      'No claims found',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredClaims.length,
                    itemBuilder: (context, index) {
                      final claim = filteredClaims[index];
                      return _buildClaimCard(context, claim);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimCard(BuildContext context, Claim claim) {
    final isClaimable = claim.status != 'claimed' && claim.status != 'paid';
    final bet = claim.bet;
    final statusColor = claim.status == 'claimed' || claim.status == 'paid'
        ? Colors.green
        : claim.status == 'won'
        ? Colors.green
        : AppColors.primary;

    return GestureDetector(
      onTap: () {
        _showClaimDetailsModal(context, claim);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ticket number
              Row(
                children: [
                  Image.asset(
                    'assets/images/logos/logo.png',
                    width: 32,
                    height: 32,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    claim.ticket?.ticketNo ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Draw Time and Transaction Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Draw Time:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const Text(
                        '3PM',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Transaction Date & Time:',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        _formatTransactionDate(
                          bet?.createdAt ?? claim.createdAt,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bets Table Header
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'BET NO',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'AMOUNT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'TYPE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'STATUS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // Bets rows
              if (bet != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          bet.digits?.join('-') ?? '-',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${bet.straightBetAmount.toInt()}',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          bet.straightBetAmount > 0 ? 'Target' : 'Rambol',
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          bet.status.capitalizeFirst ?? 'Pending',
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Bet Amount, Status, Price Payout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bet Amount',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        claim.amount.toStringAsFixed(0),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Status',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        bet != null ? bet.status.toUpperCase() : 'PENDING',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Price Payout',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        'PHP ${claim.winningAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Claim button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isClaimable
                        ? AppColors.primary
                        : Colors.grey[300],
                    foregroundColor: isClaimable
                        ? Colors.white
                        : Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: isClaimable
                      ? () {
                          _showClaimConfirmation(context, claim);
                        }
                      : null,
                  child: Text(
                    isClaimable ? 'Claim Winnings' : 'Claimed',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTransactionDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
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
      return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year} @ ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
    } catch (e) {
      return dateStr;
    }
  }

  void _showClaimDetailsModal(BuildContext context, Claim claim) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => _buildClaimDetailsSheet(context, claim),
    );
  }

  Widget _buildClaimDetailsSheet(BuildContext context, Claim claim) {
    final isClaimable = claim.status != 'claimed' && claim.status != 'paid';
    final bet = claim.bet;
    final statusColor = claim.status == 'claimed' || claim.status == 'paid'
        ? Colors.green
        : claim.status == 'won'
        ? Colors.green
        : AppColors.primary;

    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Claim Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailRow(
                'Ticket Number:',
                claim.ticket?.ticketNo ?? 'N/A',
              ),
              _buildDetailRow(
                'Status:',
                claim.status?.toUpperCase() ?? 'PENDING',
                statusColor,
              ),
              _buildDetailRow(
                'Bet Amount:',
                'PHP ${claim.amount.toStringAsFixed(0)}',
              ),
              _buildDetailRow(
                'Winning Amount:',
                'PHP ${claim.winningAmount.toStringAsFixed(2)}',
              ),
              if (bet != null) ...[
                _buildDetailRow('Digits:', bet.digits?.join('-') ?? '-'),
                _buildDetailRow('Draw Date:', _formatDate(bet.drawDate)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isClaimable
                        ? AppColors.primary
                        : Colors.grey[300],
                    foregroundColor: isClaimable
                        ? Colors.white
                        : Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isClaimable
                      ? () {
                          Get.back();
                          _showClaimConfirmation(context, claim);
                        }
                      : null,
                  child: Text(
                    isClaimable ? 'Claim Winnings' : 'Claimed',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showClaimConfirmation(BuildContext context, Claim claim) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Claim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticket: ${claim.ticket?.ticketNo ?? 'N/A'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Winning Amount: PHP ${claim.winningAmount.toStringAsFixed(2)}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to claim this winning ticket?',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Get.back();
              _processClaim(claim);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _processClaim(Claim claim) async {
    try {
      Get.snackbar(
        'Processing',
        'Processing your claim...',
        duration: const Duration(seconds: 2),
      );

      final result = await lotteryController.createClaimByTicket(
        claim.ticket?.ticketNo ?? claim.ticketId ?? '',
      );

      if (result['success'] as bool) {
        Get.snackbar(
          'Success',
          'Claim submitted successfully!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        _fetchClaims();
      } else {
        final error = result['error'] as String?;
        Get.snackbar(
          'Error',
          error ?? 'Failed to process claim',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to process claim: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
