import 'package:get/get.dart';
import '../models/ticket.dart';
import '../core/services/ticket_service.dart';
import '../core/services/websocket_service.dart';

class TicketController extends GetxController {
  final RxList<Ticket> tickets = <Ticket>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasError = false.obs;
  final RxString selectedStatus = 'Tickets'.obs;
  final RxString searchQuery = ''.obs;

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
      final result = await TicketService.fetchTickets(
        ticketNo: searchQuery.value.isNotEmpty ? searchQuery.value : null,
        status: selectedStatus.value == 'Void'
            ? 'pending_void,voided'
            : 'won,pending,lost',
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
    } catch (_) {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> voidTicket(String ticketId, String reason) async {
    await TicketService.voidTicket(ticketId, reason);
    await fetchTickets();
  }
}
