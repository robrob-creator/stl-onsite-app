import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:onstite/controllers/auth_controller.dart';
import 'package:onstite/core/app_constants.dart';
import 'package:onstite/models/permutation_availability.dart';
import 'package:onstite/models/sold_out_row.dart';

class SoldOutService {
  static Future<List<SoldOutRow>> fetchSoldOutRows({
    List<String>? gameIds,
  }) async {
    final token = Get.find<AuthController>().token.value;
    final queryParams = gameIds != null && gameIds.isNotEmpty
        ? '?game_ids=${gameIds.join(',')}'
        : '';

    final response = await http
        .get(
          Uri.parse('${AppConstants.apiBaseUrl}/sold-out/list$queryParams'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final list = data['sold_out'] as List? ?? [];
      return list.map((e) => SoldOutRow.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch sold_out rows: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> fetchPendingExposure({
    required List<String> gameIds,
    required List<String> drawIds,
  }) async {
    final token = Get.find<AuthController>().token.value;
    final params =
        'game_ids=${gameIds.join(',')}&draw_ids=${drawIds.join(',')}';

    final response = await http
        .get(
          Uri.parse(
              '${AppConstants.apiBaseUrl}/bets/pending-exposure?$params'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['bets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    }
    throw Exception(
        'Failed to fetch pending exposure: ${response.statusCode}');
  }

  static Future<PermutationAvailability> checkPermutations({
    required String gameId,
    required String drawId,
    required String drawTimeId,
    required String drawDate,
    required List<String> tokens,
    List<Map<String, dynamic>> cartBets = const [],
  }) async {
    final token = Get.find<AuthController>().token.value;
    final response = await http
        .post(
          Uri.parse('${AppConstants.apiBaseUrl}/bet/token/permutations'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'game_id': gameId,
            'draw_id': drawId,
            'draw_time_id': drawTimeId,
            'draw_date': drawDate,
            'tokens': tokens,
            'cart_bets': cartBets,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return PermutationAvailability.fromJson(data);
    }
    throw Exception('Failed to check permutations: ${response.statusCode}');
  }
}
