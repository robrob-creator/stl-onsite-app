import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import '../../models/ticket.dart';
import '../../controllers/auth_controller.dart';
import '../app_constants.dart';

class TicketService {
  static const String baseUrl = '${AppConstants.apiBaseUrl}/tickets';

  /// Fetch tickets with optional search by ticket number and status filter
  static Future<List<Ticket>> fetchTickets({
    String? ticketNo,
    String? status,
  }) async {
    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;

      final uri = Uri.parse(baseUrl);
      final queryParams = <String, String>{};

      if (ticketNo != null && ticketNo.isNotEmpty) {
        queryParams['ticket_no'] = ticketNo;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uriWithQuery = queryParams.isNotEmpty
          ? uri.replace(queryParameters: queryParams)
          : uri;

      final response = await http
          .get(
            uriWithQuery,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      print('[TicketService] Raw response: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> data = jsonResponse['data'] as List<dynamic>;
        final List<Ticket> tickets = [];
        for (final item in data) {
          try {
            tickets.add(Ticket.fromJson(item as Map<String, dynamic>));
          } catch (err) {
            print('[TicketService] Error parsing ticket: $err');
            print('[TicketService] Offending item: $item');
          }
        }
        return tickets;
      } else {
        print('[TicketService] HTTP error: ${response.statusCode}');
        throw Exception('Failed to load tickets: ${response.statusCode}');
      }
    } catch (e) {
      print('[TicketService] Exception: $e');
      throw Exception('Error fetching tickets: $e');
    }
  }

  /// Void a ticket (soft delete)
  /// Calls PUT /tickets/void-request with ticket ID
  static Future<void> voidTicket(String ticketId, [String? reason]) async {
    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;

      final uri = Uri.parse(
        '$baseUrl/void-request',
      ).replace(queryParameters: {'id': ticketId});

      final body = reason != null && reason.isNotEmpty
          ? jsonEncode({'reason': reason})
          : null;

      final response = await http
          .put(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to void ticket: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error voiding ticket: $e');
    }
  }
}
