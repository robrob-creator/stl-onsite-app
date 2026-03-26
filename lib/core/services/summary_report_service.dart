import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:onstite/controllers/auth_controller.dart';
import 'package:onstite/models/summary_report.dart';
import '../app_constants.dart';

class SummaryReportService {
  static const String baseUrl = '${AppConstants.apiBaseUrl}/reports/summary';

  static Future<SummaryReportModel> fetchSummaryReport({
    required String date,
    required String gameId,
    required String makerId,
  }) async {
    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;
      final uri = Uri.parse(
        '$baseUrl?date=$date&game_id=$gameId&maker_id=$makerId',
      );
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return SummaryReportModel.fromJson(jsonResponse['data']);
      } else {
        throw Exception(
          'Failed to fetch summary report: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching summary report: $e');
    }
  }
}
