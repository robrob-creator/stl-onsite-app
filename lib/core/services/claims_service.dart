import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../controllers/auth_controller.dart';
import '../../models/claim.dart';
import '../app_constants.dart';

class ClaimsService {
  static String get _baseUrl => '${AppConstants.apiBaseUrl}/claims';

  /// Fetch claims for the authenticated agent within a date range.
  /// Scoped to the agent's own bets via maker_id.
  static Future<List<Claim>> list({
    String? startDate,
    String? endDate,
    String? status,
  }) async {
    final auth = Get.find<AuthController>();
    final token = auth.token.value;
    final agentId = auth.currentUser.value?.id ?? '';
    final params = <String, String>{};
    if (agentId.isNotEmpty) params['maker_id'] = agentId;
    if (startDate != null && startDate.isNotEmpty) params['start_date'] = startDate;
    if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;
    if (status != null && status.isNotEmpty) params['status'] = status;

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: params.isEmpty ? null : params,
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch claims: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List? ?? const [];
    return data
        .map((j) => Claim.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
