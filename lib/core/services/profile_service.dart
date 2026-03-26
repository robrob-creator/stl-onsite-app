import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import '../../models/user.dart';
import '../../controllers/auth_controller.dart';
import '../app_constants.dart';

class ProfileService {
  static const String baseUrl = '${AppConstants.apiBaseUrl}/auth/profile';

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
        // Token expired or invalid - logout and return to login
        await authCtrl.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching profile: $e');
    }
  }
}
