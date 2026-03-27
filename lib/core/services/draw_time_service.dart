import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../app_constants.dart';

class DrawTimeService {
  static const String baseUrl = '${AppConstants.apiBaseUrl}/draw-times';

  /// Fetch all active draw times from the backend
  static Future<List<DrawTimeData>> fetchDrawTimes() async {
    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;

      final response = await http
          .get(
            Uri.parse('$baseUrl/list'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] is List) {
          final drawTimes = (json['data'] as List)
              .map((timeData) {
                try {
                  return DrawTimeData.fromJson(
                    timeData as Map<String, dynamic>,
                  );
                } catch (e) {
                  throw Exception(
                    'Error parsing draw time: $e, data: $timeData',
                  );
                }
              })
              .where((dt) => dt.isActive)
              .toList();
          return drawTimes;
        }
        return [];
      } else {
        throw Exception('Failed to fetch draw times: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching draw times: $e');
    }
  }
}

class DrawTimeData {
  final String id;
  final String drawTime; // ISO format: "0000-01-01T10:30:00Z"
  final int cutoffMinutes;
  final bool isActive;
  final String createdAt;
  final String? deletedAt;

  DrawTimeData({
    required this.id,
    required this.drawTime,
    required this.cutoffMinutes,
    required this.isActive,
    required this.createdAt,
    this.deletedAt,
  });

  factory DrawTimeData.fromJson(Map<String, dynamic> json) {
    return DrawTimeData(
      id: json['id'] as String,
      drawTime: json['draw_time'] as String,
      cutoffMinutes: json['cutoff_minutes'] as int,
      isActive: json['is_active'] as bool,
      createdAt: json['created_at'] as String,
      deletedAt: json['deleted_at'] as String?,
    );
  }

  /// Extract hour and minute from ISO format time string
  /// e.g., "0000-01-01T10:30:00Z" -> {'hour': 10, 'minute': 30}
  Map<String, int> extractTime() {
    try {
      final dateTime = DateTime.parse(drawTime);
      return {'hour': dateTime.hour, 'minute': dateTime.minute};
    } catch (e) {
      return {'hour': 0, 'minute': 0};
    }
  }
}
