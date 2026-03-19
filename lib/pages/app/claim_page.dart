import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:permission_handler/permission_handler.dart';
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
  bool _showQRScanner = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Claim> _claims = [];
  bool _isLoadingClaims = false;
  String? _errorMessage;
  StreamSubscription? _qrSubscription;

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

    // Close the scanner
    setState(() {
      _showQRScanner = false;
    });

    // Create claim with the scanned ticket ID
    _createClaimFromQRCode(ticketId);
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
      final baseUrl = 'https://stl-backend-mws9.onrender.com/api/claims';

      // Build query parameters
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (ticketId != null && ticketId.isNotEmpty) {
        queryParams['ticket_id'] = ticketId;
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
                (claim.ticketId?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false) ||
                (claim.winningCombination?.toLowerCase().contains(
                      _searchQuery.toLowerCase(),
                    ) ??
                    false),
          )
          .toList();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
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

          // Column headers
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Amount',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Winning',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                      final isClaimable =
                          claim.status == 'pending' ||
                          claim.status == 'approved' ||
                          claim.status == 'won';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (claim.status ?? 'pending').toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            color: claim.status == 'paid'
                                                ? Colors.green
                                                : AppColors.primary,
                                          ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      claim.amount.toStringAsFixed(2),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      claim.winningAmount.toStringAsFixed(2),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ticket: ${claim.ticketId ?? 'N/A'}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                              if (claim.winningCombination != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    'Combination: ${claim.winningCombination}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: Colors.grey[600]),
                                  ),
                                ),
                              const SizedBox(height: 12),
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: isClaimable
                                      ? () {
                                          _showClaimDialog(context, claim);
                                        }
                                      : null,
                                  child: Text(
                                    isClaimable
                                        ? 'Claim Winnings'
                                        : 'Already Claimed',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showClaimDialog(BuildContext context, Claim claim) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Claim'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ticket: ${claim.ticketId ?? 'N/A'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Winnings: \$${claim.winningAmount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              if (claim.winningCombination != null)
                Text(
                  'Combination: ${claim.winningCombination}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Get.snackbar(
                  'Success',
                  'Winnings claimed successfully!',
                  backgroundColor: Colors.green[600],
                  colorText: Colors.white,
                );
              },
              child: const Text('Claim'),
            ),
          ],
        );
      },
    );
  }
}
