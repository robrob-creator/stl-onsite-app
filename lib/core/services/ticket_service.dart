import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import '../../models/ticket.dart';
import '../../controllers/auth_controller.dart';
import '../app_constants.dart';
import 'qr_crypto_service.dart';

class TicketService {
  static const String baseUrl = '${AppConstants.apiBaseUrl}/tickets';
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  static String _extractMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      final error = body['error'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    } catch (_) {}
    return 'Request failed with status ${response.statusCode}';
  }

  /// Fetch a single ticket by ID, including full bet objects — used for reprint.
  static Future<Ticket?> fetchTicketForPrint(String ticketId) async {
    try {
      final token = Get.find<AuthController>().token.value;
      final uri = Uri.parse('$baseUrl/get').replace(queryParameters: {'id': ticketId});
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as Map<String, dynamic>?;
        if (data != null) return Ticket.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Fetch tickets with optional search, status filter, and date range.
  /// Retries up to 3 times on 5xx errors.
  static Future<List<Ticket>> fetchTickets({
    String? ticketNo,
    String? status,
    String? drawDate,
    String? dateFrom,
    String? dateTo,
  }) async {
    final authCtrl = Get.find<AuthController>();
    final token = authCtrl.token.value;

    final queryParams = <String, String>{};
    if (ticketNo != null && ticketNo.isNotEmpty) {
      queryParams['ticket_no'] = ticketNo;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) {
      queryParams['date_from'] = dateFrom;
    } else if (drawDate != null && drawDate.isNotEmpty) {
      queryParams['draw_date'] = drawDate;
    }
    if (dateTo != null && dateTo.isNotEmpty) {
      queryParams['date_to'] = dateTo;
    }

    final uri = Uri.parse(baseUrl).replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          final List<dynamic> data = jsonResponse['data'] as List<dynamic>;
          final List<Ticket> tickets = [];
          for (final item in data) {
            try {
              tickets.add(Ticket.fromJson(item as Map<String, dynamic>));
            } catch (err) {
              print('[TicketService] Parse error: $err');
            }
          }
          return tickets;
        }

        print('[TicketService] HTTP ${response.statusCode}: ${response.body}');
        // 4xx — don't retry
        if (response.statusCode < 500) {
          throw Exception('Failed to load tickets: ${response.statusCode}');
        }
        if (attempt < 3) await Future.delayed(Duration(seconds: attempt));
      } catch (e) {
        if (attempt == 3) rethrow;
        if (attempt < 3) await Future.delayed(Duration(seconds: attempt));
      }
    }
    throw Exception('Failed to load tickets after retries');
  }

  /// Pure local check — no network. Returns decoded value if it looks like a
  /// valid STL ticket (starts with TKT- or is a UUID), null otherwise.
  static String? tryDecodeValidQr(String raw) {
    final decoded = QrCryptoService.decrypt(raw.trim());
    if (decoded.startsWith('TKT-') || _uuidPattern.hasMatch(decoded)) {
      return decoded;
    }
    return null;
  }

  static Future<String> resolveScannedTicketNumber(String scannedValue) async {
    final trimmedValue = QrCryptoService.decrypt(scannedValue.trim());
    if (trimmedValue.isEmpty || !_uuidPattern.hasMatch(trimmedValue)) {
      return trimmedValue;
    }

    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;
      final uri = Uri.parse(
        '$baseUrl/get',
      ).replace(queryParameters: {'id': trimmedValue});

      print('[TicketService] Resolving scanned UUID via $uri');

      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      print('[TicketService] resolve response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final data = jsonResponse['data'] as Map<String, dynamic>?;
        final ticketNo = data?['ticket_no'] as String?;
        print('[TicketService] Resolved ticket_no via /get: $ticketNo');
        if (ticketNo?.trim().isNotEmpty == true) {
          return ticketNo!.trim();
        }
      } else {
        print('[TicketService] /get returned ${response.statusCode}, trying /batch fallback');
      }

      // If /tickets/get did not return a ticket, try batch lookup — some flows print batch_id as QR
      try {
        final batchUri = Uri.parse('$baseUrl/batch').replace(queryParameters: {'batch_id': trimmedValue});
        print('[TicketService] Trying batch lookup via $batchUri');
        final batchResp = await http
            .get(
              batchUri,
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 30));
        print('[TicketService] batch response: ${batchResp.statusCode} ${batchResp.body}');
        if (batchResp.statusCode == 200) {
          final batchJson = jsonDecode(batchResp.body) as Map<String, dynamic>;
          final List<dynamic> list = batchJson['data'] as List<dynamic>;
          if (list.isNotEmpty) {
            final first = list[0] as Map<String, dynamic>;
            final ticketNo = first['ticket_no'] as String?;
            print('[TicketService] Resolved ticket_no via /batch: $ticketNo');
            if (ticketNo?.trim().isNotEmpty == true) {
              return ticketNo!.trim();
            }
          }
        }
      } catch (e) {
        print('[TicketService] batch resolve error: $e');
      }

      return trimmedValue;
    } catch (e) {
      print('[TicketService] resolve error: $e');
      return trimmedValue;
    }
  }

  /// Void a ticket (soft delete)
  /// Calls PUT /tickets/void-request with ticket ID
  static Future<String> voidTicket(String ticketId, [String? reason]) async {
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

      final message = _extractMessage(response);
      if (response.statusCode != 200) {
        throw Exception(message);
      }
      return message;
    } catch (e) {
      throw Exception('$e');
    }
  }

  static Future<String> requestReprint(String ticketId) async {
    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;
      final uri = Uri.parse(
        '$baseUrl/reprint-request',
      ).replace(queryParameters: {'id': ticketId});

      final response = await http
          .put(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      final message = _extractMessage(response);
      if (response.statusCode != 200) {
        throw Exception(message);
      }
      return message;
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('$e');
    }
  }

  /// Called after a successful direct BT print to increment print_count on the backend.
  static Future<void> incrementPrintCount(String ticketId) async {
    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;
      final uri = Uri.parse(
        '$baseUrl/direct-print',
      ).replace(queryParameters: {'id': ticketId});

      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        final message = _extractMessage(response);
        throw Exception(message);
      }
    } catch (e) {
      throw Exception('$e');
    }
  }

  static Future<String> consumeApprovedReprint(String ticketId) async {
    try {
      final authCtrl = Get.find<AuthController>();
      final token = authCtrl.token.value;
      final uri = Uri.parse(
        '$baseUrl/reprint',
      ).replace(queryParameters: {'id': ticketId});

      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      final message = _extractMessage(response);
      if (response.statusCode != 200) {
        throw Exception(message);
      }
      return message;
    } catch (e) {
      throw Exception('$e');
    }
  }
}
