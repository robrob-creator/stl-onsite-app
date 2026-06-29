import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../app_constants.dart';
import '../../controllers/auth_controller.dart';

class ReprintSetupItem {
  final String id;
  final int maxPrints;
  final int maxReprintRequests;
  final bool isActive;

  ReprintSetupItem({
    required this.id,
    required this.maxPrints,
    required this.maxReprintRequests,
    required this.isActive,
  });

  factory ReprintSetupItem.fromJson(Map<String, dynamic> json) {
    return ReprintSetupItem(
      id: json['id'] as String? ?? '',
      maxPrints: (json['max_prints'] as int?) ??
          (json['number_of_prints'] as int?) ??
          0,
      maxReprintRequests: (json['max_reprint_requests'] as int?) ??
          (json['reprint_limit'] as int?) ??
          0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class ReprintSetupService {
  static final String _base = AppConstants.apiBaseUrl;

  /// Fetch active reprint setup from admin configuration, or null if not set.
  static Future<ReprintSetupItem?> fetchActiveReprintSetup() async {
    try {
      final auth = Get.find<AuthController>();
      final token = auth.token.value;
      final uri = Uri.parse('$_base/reprint-setup/list');

      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final List<dynamic> data = body['data'] as List<dynamic>? ?? [];
      for (final item in data) {
        final m = item as Map<String, dynamic>;
        if ((m['is_active'] as bool?) == true) {
          return ReprintSetupItem.fromJson(m);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
