import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../controllers/auth_controller.dart';
import '../../models/collection.dart';
import '../app_constants.dart';

class CollectionsService {
  static String get _baseUrl => '${AppConstants.apiBaseUrl}/collections';

  /// Fetch collections for the authenticated agent within an optional
  /// `[startDate, endDate]` window. Backend auto-scopes results to the caller
  /// when the caller's role is `agent`.
  ///
  /// Dates are `YYYY-MM-DD` strings; either side of the range may be omitted.
  static Future<List<Collection>> list({
    String? startDate,
    String? endDate,
  }) async {
    final token = Get.find<AuthController>().token.value;

    final params = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) {
      params['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      params['end_date'] = endDate;
    }

    final uri = Uri.parse(
      '$_baseUrl/agent-slots',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final response = await http
        .get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch collections: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = decoded['data'] as List? ?? const [];
    return data
        .map((item) => Collection.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
