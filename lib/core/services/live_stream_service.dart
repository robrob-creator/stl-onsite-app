import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../controllers/auth_controller.dart';
import '../app_constants.dart';

class LiveStreamService {
  static Future<String?> getLiveVideoId() async {
    final token = Get.find<AuthController>().token.value;
    final response = await http.get(
      Uri.parse('${AppConstants.apiBaseUrl}/live/stream-url'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 204) return null;
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch live video ID: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['video_id'] as String?;
  }

  static Future<void> refreshVideoId() async {
    final token = Get.find<AuthController>().token.value;
    await http.post(
      Uri.parse('${AppConstants.apiBaseUrl}/live/stream-url/refresh'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
  }
}
