import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import '../../models/transaction.dart';
import '../../controllers/auth_controller.dart';
import '../app_constants.dart';

class TransactionService {
  static const String _baseUrl = '${AppConstants.apiBaseUrl}/transactions';

  static String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Fetch transactions grouped by draw time for a given date (defaults to today).
  static Future<List<TransactionGroup>> fetchTransactions({
    DateTime? date,
  }) async {
    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;
      final dateStr = _formatDate(date ?? DateTime.now());

      final uri = Uri.parse('$_baseUrl/grouped-by-draw-time?date=$dateStr');

      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> groups = jsonResponse['data'] as List<dynamic>;
        return groups.map((group) {
          final drawTime = group['draw_time'] as String? ?? '';
          final drawTimeId = group['draw_time_id'] as String? ?? '';
          final txList = group['transactions'] as List<dynamic>? ?? [];
          final transactions = txList
              .map(
                (item) => Transaction.fromJson(
                  item as Map<String, dynamic>,
                  drawTime: drawTime,
                  drawTimeId: drawTimeId,
                ),
              )
              .toList();
          return TransactionGroup(
            drawTimeId: drawTimeId,
            drawTime: drawTime,
            transactions: transactions,
          );
        }).toList();
      } else {
        throw Exception('Failed to load transactions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching transactions: $e');
    }
  }

  /// Fetch bets for a specific transaction by its ID.
  static Future<List<TransactionBet>> fetchTransactionBets(
    String transactionId,
  ) async {
    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;
      final uri = Uri.parse('$_baseUrl/bets?id=$transactionId');

      final response = await http
          .get(
            uri,
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
            .map(
              (item) => TransactionBet.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw Exception('Failed to load bets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching bets: $e');
    }
  }
}
