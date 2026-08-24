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
  // Optional draw type coming from backend (e.g., 'National', 'Regional')
  final String? drawType;
  // Optional association to a game (game_id) when provided by the backend.
  final String? gameId;
  // Convenience flag derived from available backend fields. True when this
  // draw time represents the National draw (preferred for the Live page).
  final bool isNational;

  DrawTimeData({
    required this.id,
    required this.drawTime,
    required this.cutoffMinutes,
    required this.isActive,
    required this.createdAt,
    this.deletedAt,
    this.drawType,
    this.gameId,
    this.isNational = false,
  });

  factory DrawTimeData.fromJson(Map<String, dynamic> json) {
    final drawType = json['draw_type'] as String?;
    // Backwards-compatible detection: some APIs may send explicit boolean
    // 'is_national' or a 'scope' string. Derive a best-effort flag here.
    final isNationalFlag = (json['is_national'] == true) ||
        (json['scope'] is String && (json['scope'] as String).toLowerCase() == 'national') ||
        (drawType != null && drawType.toLowerCase() == 'national');

    return DrawTimeData(
      id: json['id'] as String,
      drawTime: json['draw_time'] as String,
      cutoffMinutes: json['cutoff_minutes'] as int,
      isActive: json['is_active'] as bool,
      createdAt: json['created_at'] as String,
      deletedAt: json['deleted_at'] as String?,
      drawType: drawType,
      gameId: json['game_id'] as String? ?? json['gameId'] as String?,
      isNational: isNationalFlag,
    );
  }

  /// Extract hour and minute — handles both "HH:MM:SS" and "0000-01-01THH:MM:SSZ"
  Map<String, int> extractTime() {
    try {
      String timeStr = drawTime;
      if (drawTime.contains('T')) {
        timeStr = drawTime.split('T')[1].replaceAll('Z', '');
      }
      final timeParts = timeStr.split(':');
      if (timeParts.length < 2) return {'hour': 0, 'minute': 0};
      return {
        'hour': int.tryParse(timeParts[0]) ?? 0,
        'minute': int.tryParse(timeParts[1]) ?? 0,
      };
    } catch (e) {
      return {'hour': 0, 'minute': 0};
    }
  }
}
