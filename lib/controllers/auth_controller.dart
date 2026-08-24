import 'dart:async';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';
import '../models/login_response.dart';
import '../core/app_constants.dart';
import '../core/services/websocket_service.dart';
import '../core/services/notification_service.dart';
import '../models/user.dart';
import 'lottery_controller.dart';

class AuthController extends GetxController {
  final RxString phoneNumber = ''.obs;
  final RxString imei = ''.obs;
  final RxString deviceImei = ''.obs; // device identifier, never overwritten
  final RxString mpin = ''.obs;
  final RxBool isLoading = false.obs;
  final Rx<User?> currentUser = Rx<User?>(null);
  final RxString token = ''.obs;
  final RxBool isSessionRestored = false.obs;
  final RxBool isDeviceInitialized = false.obs;

  late FlutterSecureStorage _secureStorage;
  late DeviceInfoPlugin _deviceInfo;
  static const _androidId = AndroidId();

  static String get baseUrl => '${AppConstants.apiBaseUrl}/auth';

  // Secure storage keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'current_user';

  @override
  void onInit() {
    super.onInit();
    _secureStorage = const FlutterSecureStorage();
    _deviceInfo = DeviceInfoPlugin();
    Get.put(WebSocketService());
    _initializeDevice().then((_) {
      restoreSession();
    });
  }

  /// Initialize device and get the device identifier.
  Future<void> _initializeDevice() async {
    try {
      final imeiValue = await _getDeviceImei();
      if (imeiValue.isNotEmpty) {
        imei.value = imeiValue;
        deviceImei.value = imeiValue;
        print('✓ Device ID: $imeiValue');
      } else {
        print('⚠ Warning: Could not retrieve device ID');
      }
    } catch (e) {
      print('✗ Error getting device ID: $e');
    } finally {
      isDeviceInitialized.value = true;
      update();
    }
  }

  /// Get the Android SSAID or iOS vendor identifier.
  ///
  /// AndroidDeviceInfo.id is the OS build ID and is shared by every phone
  /// running the same firmware, so it must not be used for authentication.
  Future<String> _getDeviceImei() async {
    try {
      final androidId = await _androidId.getId();
      if (androidId != null && androidId.trim().isNotEmpty) {
        return androidId.trim();
      }
    } catch (e) {
      // Continue with the iOS identifier lookup below.
    }

    try {
      final iosInfo = await _deviceInfo.iosInfo;
      return iosInfo.identifierForVendor?.trim() ?? '';
    } catch (e) {
      return '';
    }
  }

  void setCustomImei(String value) => imei.value = value.trim();
  void resetToDeviceImei() => imei.value = deviceImei.value;
  bool get isUsingCustomImei => imei.value != deviceImei.value;

  /// Restore user session from secure storage if available
  Future<void> restoreSession() async {
    try {
      final savedToken = await _secureStorage.read(key: _tokenKey);
      final savedUserJson = await _secureStorage.read(key: _userKey);

      if (savedToken != null &&
          savedToken.isNotEmpty &&
          savedUserJson != null &&
          savedUserJson.isNotEmpty) {
        token.value = savedToken;
        try {
          final userMap = jsonDecode(savedUserJson);
          currentUser.value = User.fromJson(userMap);
        } catch (e) {
          // Clear invalid user data
          await _secureStorage.delete(key: _userKey);
        }
        _connectWebSocket();
        NotificationService.registerDevice();
      }
    } catch (e) {
      // Silently fail if restoration fails
    } finally {
      isSessionRestored.value = true;
      update();
    }
  }

  /// Save session data to secure storage
  Future<void> _saveSession() async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token.value);
      if (currentUser.value != null) {
        await _secureStorage.write(
          key: _userKey,
          value: jsonEncode(currentUser.value?.toJson()),
        );
      }
    } catch (e) {
      // Silently fail if save fails
    }
  }

  void updateCurrentUserBalance(double newBalance) {
    final user = currentUser.value;
    if (user == null) return;

    currentUser.value = User(
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      createdAt: user.createdAt,
      phoneNumber: user.phoneNumber,
      balance: newBalance,
      cashFromCashier: user.cashFromCashier,
      isActive: user.isActive,
      isBlocked: user.isBlocked,
      winningsAmount: user.winningsAmount,
      shareAmount: user.shareAmount,
      areaName: user.areaName,
      clusterName: user.clusterName,
      agentNo: user.agentNo,
    );
    unawaited(_saveSession());
    update();
  }

  void syncCurrentUser(User user) {
    currentUser.value = user;
    unawaited(_saveSession());
    update();
  }

  void addDigit(String digit) {
    if (mpin.value.length < 6) {
      mpin.value += digit;
    }
  }

  void removeDigit() {
    if (mpin.value.isNotEmpty) {
      mpin.value = mpin.value.substring(0, mpin.value.length - 1);
    }
  }

  void clearMpin() {
    mpin.value = '';
  }

  Future<void> login() async {
    if (mpin.value.length != 6) {
      Get.snackbar(
        'Error',
        'PIN must be exactly 6 digits',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Wait for device initialization if not complete
    if (!isDeviceInitialized.value) {
      Get.snackbar(
        'Info',
        'Initializing device... Please try again',
        snackPosition: SnackPosition.BOTTOM,
      );
      await Future.delayed(const Duration(seconds: 1));
      return;
    }

    if (imei.value.isEmpty) {
      Get.snackbar(
        'Error',
        'Unable to retrieve device ID. Please restart the app.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isLoading.value = true;
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login/imei'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'imei': imei.value,
              'pin': mpin.value,
              'app_role': 'Agent',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final loginResponse = LoginResponse.fromJson(jsonDecode(response.body));

        // Store user data and token
        currentUser.value = loginResponse.user;
        token.value = loginResponse.token;

        // Remove focus and hide keyboard to ensure a smooth transition
        try {
          FocusManager.instance.primaryFocus?.unfocus();
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        } catch (_) {}

        // Navigate immediately to improve perceived performance
        Get.offNamed('/home');

        // Defer saving session and websocket connection so Home can render first
        Future.microtask(() async {
          // Persist session (non-blocking for UI)
          try {
            await _saveSession();
          } catch (_) {}

          // Small delay to allow first frame on Home to paint before connecting
          await Future.delayed(const Duration(milliseconds: 150));

          try {
            _connectWebSocket();
            NotificationService.registerDevice();
          } catch (_) {}
        });
      } else {
        _handleErrorResponse(response);
      }
    } on http.ClientException catch (e) {
      Get.snackbar(
        'Error',
        'Network error: ${e.message}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Login failed: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _handleErrorResponse(http.Response response) {
    try {
      final errorBody = jsonDecode(response.body);
      final message = errorBody['message'] ?? 'An error occurred';
      final code = errorBody['code'] ?? '';

      String displayMessage = message;

      // Handle specific error codes
      switch (code) {
        case 'INVALID_IMEI':
          displayMessage = 'Invalid device ID or unauthorized device.';
          break;
        case 'IMEI_NOT_REGISTERED':
          displayMessage = 'Invalid device ID or unauthorized device.';
          break;
        case 'INVALID_MPIN':
          displayMessage = 'Invalid MPIN.';
          break;
        case 'INVALID_PIN':
          displayMessage = 'Invalid MPIN.';
          break;
        case 'MISSING_FIELD':
          displayMessage = message;
          break;
        case 'INVALID_CREDENTIALS':
          displayMessage = message;
          break;
        default:
          displayMessage = message;
      }

      Get.snackbar(
        'Login Failed',
        displayMessage,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'An error occurred. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Logout function
  Future<void> logout() async {
    await Get.find<WebSocketService>().disconnect();
    currentUser.value = null;
    token.value = '';
    mpin.value = '';

    // Clear session from secure storage
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userKey);

    Get.offNamed('/login');
  }

  void _connectWebSocket() {
    final wsService = Get.find<WebSocketService>();
    wsService.connect(token.value);

    wsService.on('ticket.voided', (payload) {
      Get.snackbar(
        'Ticket Voided',
        'Ticket ${payload['ticketNo'] ?? ''} has been voided.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEC4899),
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      // Refresh balance and gross sales now that void is approved
      try {
        final lc = Get.find<LotteryController>();
        lc.loadProfile();
        lc.drawRefreshTick.value = lc.drawRefreshTick.value + 1;
      } catch (_) {}
    });

    wsService.on('bet.placed', (payload) {
      // balance refresh handled by LotteryController
    });

    wsService.on('bet.bulk_placed', (payload) {
      Get.snackbar(
        'Bets Confirmed',
        'Your bets have been placed successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
    });

    wsService.on('draw_result.posted', (payload) {
      // Only notify when result is fully approved — not when submitted for approval.
      final status = (payload['status'] as String? ?? '').toLowerCase();
      if (status == 'pending') return;
      final result = payload['result'];
      final resultStr = result is List ? result.join('-') : (result?.toString() ?? '');
      final drawDate = payload['drawDate'] as String? ?? '';
      final message = resultStr.isNotEmpty
          ? 'Result: $resultStr${drawDate.isNotEmpty ? ' · $drawDate' : ''}'
          : 'Draw result is now available.';
      Get.snackbar(
        'Draw Result Posted',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF2563EB),
        colorText: Colors.white,
        duration: const Duration(seconds: 6),
      );
    });

    wsService.on('claim.created', (payload) {
      Get.snackbar(
        'Claim Submitted',
        'A winning claim has been submitted.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
      );
    });

    wsService.on('claim.paid', (payload) {
      // balance refresh handled by LotteryController
      Get.snackbar(
        'Claim Paid',
        'A winning claim has been paid out.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        duration: const Duration(seconds: 6),
      );
    });
  }

  // Check if user is logged in
  bool get isLoggedIn => token.value.isNotEmpty && currentUser.value != null;
}
