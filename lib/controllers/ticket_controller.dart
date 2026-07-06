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
      final isSearch = searchQuery.value.isNotEmpty;
      final from = isSearch ? null : (dateFrom.value.isNotEmpty ? dateFrom.value : null);
      final to   = isSearch ? null : (dateTo.value.isNotEmpty   ? dateTo.value   : null);

      // Always fetch both tabs in parallel so counts stay current.
      // On search, skip status filter so all statuses are searched.
      final futures = await Future.wait([
        TicketService.fetchTickets(
          ticketNo: isSearch ? searchQuery.value : null,
          status: isSearch ? null : 'won,pending,lost',
          dateFrom: from,
          dateTo: to,
        ),
        TicketService.fetchTickets(
          ticketNo: isSearch ? searchQuery.value : null,
          status: isSearch ? null : 'pending_void,voided',
          dateFrom: from,
          dateTo: to,
        ),
      ]);

      final activeTickets = futures[0];
      final voidTickets   = futures[1];

      activeTabCount.value = activeTickets.length;

      // Sort void: pending_void first
      voidTickets.sort((a, b) {
        final aVoid = a.status?.toLowerCase() == 'pending_void';
        final bVoid = b.status?.toLowerCase() == 'pending_void';
        if (aVoid && !bVoid) return -1;
        if (!aVoid && bVoid) return 1;
        return 0;
      });
      voidTabCount.value = voidTickets.length;

      tickets.value = selectedStatus.value == 'Void' ? voidTickets : activeTickets;
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
