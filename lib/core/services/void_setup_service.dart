import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import '../app_constants.dart';
import '../../controllers/auth_controller.dart';

class VoidSetupItem {
  final String id;
  final int minutes;
  final bool isActive;

  VoidSetupItem({required this.id, required this.minutes, required this.isActive});

  factory VoidSetupItem.fromJson(Map<String, dynamic> json) {
    return VoidSetupItem(
      id: json['id'] as String,
      minutes: json['minutes'] as int,
      isActive: json['is_active'] as bool,
    );
  }
}

class VoidSetupService {
  static final String _base = AppConstants.apiBaseUrl;

  /// Fetch list of void setups and return the most recent active one, or null.
  static Future<VoidSetupItem?> fetchActiveVoidSetup() async {
    try {
      final auth = Get.find<AuthController>();
      final token = auth.token.value;
      final uri = Uri.parse('$_base/void-setup/list');

      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final List<dynamic> data = body['data'] as List<dynamic>? ?? [];
      // find first active entry (list ordered by created_at desc in backend)
      for (final item in data) {
        final m = item as Map<String, dynamic>;
        if ((m['is_active'] as bool?) == true) {
          return VoidSetupItem.fromJson(m);
        }
      }
      return null;
    } catch (e) {
      // Swallow errors and return null to avoid breaking UI
      return null;
    }
  }
}
