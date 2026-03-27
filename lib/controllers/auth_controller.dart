import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/login_response.dart';
import '../core/app_constants.dart';
import '../core/services/websocket_service.dart';
import '../models/user.dart';

class AuthController extends GetxController {
  final RxString phoneNumber = ''.obs;
  final RxString imei = ''.obs;
  final RxString mpin = ''.obs;
  final RxBool isLoading = false.obs;
  final Rx<User?> currentUser = Rx<User?>(null);
  final RxString token = ''.obs;
  final RxBool isSessionRestored = false.obs;
  final RxBool isDeviceInitialized = false.obs;

  late FlutterSecureStorage _secureStorage;
  late DeviceInfoPlugin _deviceInfo;

  static const String baseUrl = '${AppConstants.apiBaseUrl}/auth';

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

  /// Initialize device and get IMEI
  Future<void> _initializeDevice() async {
    try {
      final imeiValue = await _getDeviceImei();
      if (imeiValue.isNotEmpty) {
        imei.value = imeiValue;
        print('✓ Device IMEI: $imeiValue');
      } else {
        print('⚠ Warning: Could not retrieve device IMEI');
      }
    } catch (e) {
      print('✗ Error getting IMEI: $e');
    } finally {
      isDeviceInitialized.value = true;
      update();
    }
  }

  /// Get device IMEI
  Future<String> _getDeviceImei() async {
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.id; // IMEI equivalent on Android
    } catch (e) {
      try {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ??
            ''; // Use identifierForVendor on iOS
      } catch (e) {
        return '';
      }
    }
  }

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
        'Unable to retrieve device IMEI. Please restart the app.',
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
            body: jsonEncode({'imei': imei.value, 'pin': mpin.value}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final loginResponse = LoginResponse.fromJson(jsonDecode(response.body));

        // Store user data and token
        currentUser.value = loginResponse.user;
        token.value = loginResponse.token;

        // Save session to secure storage
        await _saveSession();

        Get.snackbar(
          'Success',
          loginResponse.message,
          snackPosition: SnackPosition.BOTTOM,
        );

        // Navigate to home
        Get.offNamed('/home');
        _connectWebSocket();
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
          displayMessage = 'Invalid IMEI or Unauthorized device.';
          break;
        case 'IMEI_NOT_REGISTERED':
          displayMessage = 'Invalid IMEI or Unauthorized device.';
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
      final game = payload['gameName'] ?? payload['game'] ?? 'Game';
      Get.snackbar(
        'Draw Result',
        '$game draw result is now available.',
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
