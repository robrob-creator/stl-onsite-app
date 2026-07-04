import 'package:get/get.dart';
import '../models/ticket.dart';
import '../core/services/ticket_service.dart';
import '../core/services/websocket_service.dart';

class TicketController extends GetxController {
  final RxList<Ticket> tickets = <Ticket>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString selectedStatus = 'Tickets'.obs;
  final RxInt activeTabCount = 0.obs;
  final RxInt voidTabCount = 0.obs;
  final RxString searchQuery = ''.obs;
  final RxString selectedDate = DateTime.now().toLocal().toIso8601String().substring(0,10).obs;
  // Date range filter (YYYY-MM-DD); defaults to today
  final RxString dateFrom = DateTime.now().toLocal().toIso8601String().substring(0,10).obs;
  final RxString dateTo   = DateTime.now().toLocal().toIso8601String().substring(0,10).obs;

  @override
  void onInit() {
    super.onInit();
    fetchTickets();
    _subscribeToWebSocketEvents();
  }

  void _subscribeToWebSocketEvents() {
    try {
      final ws = Get.find<WebSocketService>();
      ws.on('ticket.voided', (_) => fetchTickets());
      ws.on('api.mutation', (payload) {
        final endpoints =
            (payload['endpoints_to_update'] as List<dynamic>? ?? [])
                .map((item) => item.toString())
                .toList();
        if (endpoints.contains('/api/tickets')) {
          fetchTickets();
        }
      });
    } catch (_) {
      // WebSocketService not yet available — safe to ignore
    }
  }

  void setStatus(String status) {
    selectedStatus.value = status;
    searchQuery.value = '';
    fetchTickets();
  }

  Future<void> fetchTickets([String? query]) async {
    if (query != null) searchQuery.value = query;
    isLoading.value = true;
    hasError.value = false;
    try {
      // When searching by ticket number (e.g., scanning QR), avoid restricting
      // by status to ensure tickets with non-standard statuses (printed,
      // completed, etc.) are returned. Otherwise searches may erroneously
      // report "No ticket found".
      final isSearch = searchQuery.value.isNotEmpty;
      final statusFilter = isSearch
          ? null
          : (selectedStatus.value == 'Void' ? 'pending_void,voided' : 'won,pending,lost');

      final result = await TicketService.fetchTickets(
        ticketNo: searchQuery.value.isNotEmpty ? searchQuery.value : null,
        status: statusFilter,
        dateFrom: isSearch ? null : (dateFrom.value.isNotEmpty ? dateFrom.value : null),
        dateTo:   isSearch ? null : (dateTo.value.isNotEmpty   ? dateTo.value   : null),
      );
      // Sort: pending_void first
      result.sort((a, b) {
        final aVoid = a.status?.toLowerCase() == 'pending_void';
        final bVoid = b.status?.toLowerCase() == 'pending_void';
        if (aVoid && !bVoid) return -1;
        if (!aVoid && bVoid) return 1;
        return 0;
      });
      tickets.value = result;
      if (selectedStatus.value == 'Void') {
        voidTabCount.value = result.length;
      } else {
        activeTabCount.value = result.length;
      }
    } catch (_) {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update the active date filter (expects YYYY-MM-DD) and refresh tickets
  void setDate(String yyyyMmDd) {
    selectedDate.value = yyyyMmDd;
    dateFrom.value = yyyyMmDd;
    dateTo.value = yyyyMmDd;
    fetchTickets();
  }

  /// Update date range filter and refresh
  void setDateRange(String from, String to) {
    dateFrom.value = from;
    dateTo.value = to;
    selectedDate.value = from;
    fetchTickets();
  }

  /// Clear date filter (show all dates)
  void clearDateFilter() {
    dateFrom.value = '';
    dateTo.value = '';
    selectedDate.value = '';
    fetchTickets();
  }

  Future<String> voidTicket(String ticketId, String reason) async {
    final message = await TicketService.voidTicket(ticketId, reason);
    await fetchTickets();
    return message;
  }

  Future<String> requestReprint(String ticketId) async {
    final message = await TicketService.requestReprint(ticketId);
    await fetchTickets();
    return message;
  }

  Future<String> consumeApprovedReprint(String ticketId) async {
    final message = await TicketService.consumeApprovedReprint(ticketId);
    await fetchTickets();
    return message;
  }
}
