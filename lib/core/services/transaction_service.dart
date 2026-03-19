import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import '../../models/transaction.dart';
import '../../controllers/auth_controller.dart';

class TransactionService {
  static const String baseUrl =
      'https://stl-backend-mws9.onrender.com/api/transactions';

  /// Fetch transactions
  static Future<List<Transaction>> fetchTransactions() async {
    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;

      final response = await http
          .get(
            Uri.parse(baseUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> data = jsonResponse['data'] as List<dynamic>;
        return data
            .map((item) => Transaction.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load transactions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching transactions: $e');
    }
  }
}
