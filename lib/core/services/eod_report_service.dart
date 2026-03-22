import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:onstite/controllers/auth_controller.dart';
import 'package:onstite/models/eod_report.dart';

class EodReportService {
  static const String baseUrl =
      'https://stl-backend-mws9.onrender.com/api/reports/eod';

  static Future<EodReportModel> fetchEodReport({
    required String makerId,
    required String date,
  }) async {
    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;
      final uri = Uri.parse('$baseUrl?maker_id=$makerId&date=$date');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return EodReportModel.fromJson(jsonResponse['data']);
      } else {
        throw Exception('Failed to fetch EOD report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching EOD report: $e');
    }
  }
}
