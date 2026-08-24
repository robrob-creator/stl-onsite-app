import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../controllers/auth_controller.dart';
import '../app_constants.dart';

class NoGameDateService {
  /// Retries up to 3 times on 5xx errors. Never blocks the app — returns
  /// isNoGameDay: false on unrecoverable failure.
  static Future<NoGameDateResult> checkToday() async {
    final token = Get.find<AuthController>().token.value;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final uri = Uri.parse(
      '${AppConstants.apiBaseUrl}/no-game-date/list?game_date=$today',
    );
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final data = json['data'];
          final List<dynamic> items =
              data is List ? data : (data?['items'] as List? ?? []);
          final active =
              items.where((item) => item['is_active'] == true).toList();
          if (active.isEmpty) return NoGameDateResult(isNoGameDay: false);
          final desc = active.first['descriptions'] as String?;
          return NoGameDateResult(isNoGameDay: true, description: desc);
        }

        // 4xx — don't retry
        if (response.statusCode < 500) break;
        if (attempt < 3) await Future.delayed(Duration(seconds: attempt));
      } catch (_) {
        if (attempt < 3) await Future.delayed(Duration(seconds: attempt));
      }
    }
    return NoGameDateResult(isNoGameDay: false);
  }
}

class NoGameDateResult {
  final bool isNoGameDay;
  final String? description;

  NoGameDateResult({required this.isNoGameDay, this.description});
}
