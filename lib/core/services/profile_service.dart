import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/user.dart';
import '../../controllers/auth_controller.dart';
import '../app_constants.dart';

class ProfileService {
  static String get baseUrl => '${AppConstants.apiBaseUrl}/auth/profile';

  /// Fetch user profile
  static Future<User> fetchProfile() async {
    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;

      final response = await http
          .get(
            Uri.parse(baseUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final userData = jsonResponse['data'] as Map<String, dynamic>;
        return User.fromJson(userData);
      } else if (response.statusCode == 401) {
        String message = 'Session expired. Please log in again.';
        try {
          final body = jsonDecode(response.body);
          final code = body['code'] as String? ?? '';
          final apiMessage = body['message'] as String? ?? '';
          if (code == 'ACCOUNT_SUSPENDED' && apiMessage.isNotEmpty) {
            message = apiMessage;
          } else if (code == 'SESSION_REVOKED' && apiMessage.isNotEmpty) {
            message = apiMessage;
          }
        } catch (_) {}
        Get.snackbar(
          'Access Denied',
          message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFDC2626),
          colorText: const Color(0xFFFFFFFF),
          duration: const Duration(seconds: 4),
        );
        await Future.delayed(const Duration(milliseconds: 1500));
        await authCtrl.logout();
        throw Exception(message);
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }
}
