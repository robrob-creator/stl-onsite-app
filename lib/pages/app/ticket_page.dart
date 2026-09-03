import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/ticket_service.dart';
import '../../core/services/void_setup_service.dart';
import '../../core/services/reprint_setup_service.dart';
import '../../core/services/printer_service.dart';
import '../../core/services/websocket_service.dart';
import '../../models/ticket.dart';
import '../../controllers/ticket_controller.dart';

// ── palette ──────────────────────────────────────────────────────────────────
const _blue = Color(0xFF2563EB);
const _blueD = Color(0xFF1E40AF);
const _blueL = Color(0xFFEAF0FC);
const _green = Color(0xFF059669);
const _greenL = Color(0xFFECFDF5);
const _red = Color(0xFFDC2626);
const _redL = Color(0xFFFEF2F2);
const _ink = Color(0xFF0F172A);
const _ink2 = Color(0xFF1F2937);
const _muted = Color(0xFF6B7280);
const _muted2 = Color(0xFF94A3B8);
const _faint = Color(0xFFCBD5E1);
const _border = Color(0xFFE5E7EB);
const _hair = Color(0xFFF1F5F9);
const _bg = Color(0xFFF4F5F7);

class TicketPage extends StatefulWidget {
  const TicketPage({super.key});

  @override
  State<TicketPage> createState() => _TicketPageState();
}

class _TicketPageState extends State<TicketPage> {
  late final TicketController _ctrl;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  Timer? _clockTimer;
  VoidSetupItem? _activeVoidSetup;
  ReprintSetupItem? _activeReprintSetup;
  Function? _wsUnsub;

  // QR
  QRViewController? _qrCtrl;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  bool _showQRScanner = false;

  // Cache for resolved QR strings -> ticket numbers to avoid repeated network
  // resolution on rapid repeated scans
  final Map<String, String> _resolvedQrCache = {};
  final Map<String, DateTime> _resolvedQrCacheTs = {};
  static const Duration _resolvedQrCacheTTL = Duration(seconds: 60);

  // Single date filter
  bool _dateExplicitlySet = false;
  String _dateInput = '';

  // Expanded cards (ticket id → bool)
  final Set<String> _expandedCards = {};

  // Search focus
  bool _searchFocused = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(TicketController());
    // Always refresh on page show — handles cached controller with stale void count
    _ctrl.fetchTickets();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocusNode.hasFocus);
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _fetchSetups();

    // Re-fetch setups when admin changes void/reprint configuration
    try {
      final ws = Get.find<WebSocketService>();
      _wsUnsub = ws.on('api.mutation', (payload) {
        final endpoints =
            (payload['endpoints_to_update'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
        if (endpoints.any(
          (e) =>
              e.contains('/api/void-setup') || e.contains('/api/reprint-setup'),
        )) {
          _fetchSetups();
        }
        // Refresh ticket list when requests (void/reprint approval) or
        // tickets change so button states update without manual pull-to-refresh.
        if (endpoints.any(
          (e) => e.contains('/api/requests') || e.contains('/api/tickets'),
        )) {
          _ctrl.fetchTickets(_searchController.text);
        }
      });
    } catch (_) {}

    // init date input to match controller
    _dateInput = _ctrl.dateFrom.value;
  }

  void _fetchSetups() {
    VoidSetupService.fetchActiveVoidSetup()
        .then((v) {
          if (mounted) setState(() => _activeVoidSetup = v);
        })
        .catchError((_) {});
    ReprintSetupService.fetchActiveReprintSetup()
        .then((v) {
          if (mounted) setState(() => _activeReprintSetup = v);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _wsUnsub?.call();
    _clockTimer?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _qrCtrl?.dispose();
    Get.delete<TicketController>();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (_qrCtrl != null) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _qrCtrl!.pauseCamera();
      } else {
        _qrCtrl!.resumeCamera();
      }
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _ctrl.fetchTickets(_searchController.text);
    });
  }

  String _today() =>
      DateTime.now().toLocal().toIso8601String().substring(0, 10);

  String _addDays(int n) {
    final d = DateTime.now().toLocal().add(Duration(days: n));
    return d.toIso8601String().substring(0, 10);
  }

  String _shortId(String? id) {
    if (id == null || id.isEmpty) return '—';
    final parts = id.split('-');
    if (parts.length < 2) return id;
    final head = parts.take(2).join('-');
    final tail = parts.last.length >= 4
        ? parts.last.substring(parts.last.length - 4)
        : parts.last;
    return '$head…$tail';
  }

  String _fmtDateLabel() {
    final d = _ctrl.dateFrom.value;
    if (d.isEmpty) return 'All dates';
    return _fmtShort(d);
  }

  String _fmtShort(String iso) {
    try {
      final d = DateTime.parse('${iso}T00:00:00');
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}';
    } catch (_) {
      return iso;
    }
  }

  String _fmtDrawTime(String? dt) {
    if (dt == null || dt.isEmpty) return '—';
    try {
      String timeStr = dt.contains('T')
          ? dt.split('T')[1].replaceAll('Z', '')
          : dt;
      final parts = timeStr.split(':');
      int h = int.parse(parts[0]);
      final m = parts[1].padLeft(2, '0');
      final period = h >= 12 ? 'PM' : 'AM';
      h = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$h:$m $period';
    } catch (_) {
      return dt;
    }
  }

  String _fmtPrinted(String? iso) {
    if (iso == null) return '—';
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      int h = d.hour;
      final m = d.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'PM' : 'AM';
      h = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '${months[d.month - 1]} ${d.day} · $h:$m $period';
    } catch (_) {
      return iso;
    }
  }

  String _fmtDrawDateTime(String drawDate, String? drawTime) {
    String datePart = '';
    String timePart = '';
    try {
      if (drawDate.isNotEmpty) {
        final d = DateTime.parse('${drawDate}T00:00:00');
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        datePart = '${months[d.month - 1]} ${d.day}';
      }
    } catch (_) {}
    timePart = _fmtDrawTime(drawTime);
    if (datePart.isEmpty && timePart == '—') return '—';
    if (datePart.isEmpty) return timePart;
    if (timePart == '—') return datePart;
    return '$datePart · $timePart';
  }

  String _fmtAmount(double? v) {
    if (v == null) return '—';
    return '₱${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';
  }

  String _fmtClock(Duration d) {
    final s = d.inSeconds.clamp(0, 99 * 60 + 59);
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Duration? _printTimeLeft(Ticket ticket) {
    if (ticket.createdAt == null) return null;
    // Prefer admin-configured print timer; fall back to void window minutes
    // so the timer always shows when a print/void setup is active.
    int timer = _activeReprintSetup?.printTimerMinutes ?? 0;
    if (timer <= 0 && _activeVoidSetup != null && _activeVoidSetup!.isActive) {
      timer = _activeVoidSetup!.minutes;
    }
    if (timer <= 0) return null;
    try {
      final created = DateTime.parse(ticket.createdAt!).toLocal();
      final allowedUntil = created.add(Duration(minutes: timer));
      final diff = allowedUntil.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    } catch (_) {
      return null;
    }
  }

  Duration? _voidTimeLeft(Ticket ticket) {
    final now = DateTime.now();
    final expires = ticket.voidExpires;
    if (expires != null) {
      final diff = expires.difference(now);
      return diff.isNegative ? Duration.zero : diff;
    }
    if (ticket.voidWindowMinutes != null && ticket.createdAt != null) {
      try {
        final created = DateTime.parse(ticket.createdAt!).toLocal();
        final allowedUntil = created.add(
          Duration(minutes: ticket.voidWindowMinutes!),
        );
        final diff = allowedUntil.difference(now);
        return diff.isNegative ? Duration.zero : diff;
      } catch (_) {
        return null;
      }
    }
    if (_activeVoidSetup != null &&
        ticket.createdAt != null &&
        _activeVoidSetup!.isActive) {
      try {
        final created = DateTime.parse(ticket.createdAt!).toLocal();
        final allowedUntil = created.add(
          Duration(minutes: _activeVoidSetup!.minutes),
        );
        final diff = allowedUntil.difference(now);
        return diff.isNegative ? Duration.zero : diff;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _canVoid(Ticket ticket) {
    final status = (ticket.status ?? '').toLowerCase();
    if (status != 'pending' || ticket.hasPendingVoidRequest) return false;
    if (ticket.voidExpiresAt != null || ticket.voidWindowMinutes != null) {
      return ticket.isVoidWindowActive();
    }
    if (_activeVoidSetup != null &&
        _activeVoidSetup!.isActive &&
        ticket.createdAt != null) {
      final created = DateTime.tryParse(ticket.createdAt!)?.toLocal();
      if (created == null) return false;
      return DateTime.now().isBefore(
        created.add(Duration(minutes: _activeVoidSetup!.minutes)),
      );
    }
    return false;
  }

  /// True when the ticket still has direct-print allowance (printCount < maxPrints).
  /// Placing a bet counts as print #1, so printCount defaults to 1.
  bool _isDirectPrint(Ticket ticket) {
    if (_activeReprintSetup == null || !_activeReprintSetup!.isActive)
      return false;
    final maxP = _activeReprintSetup!.maxPrints;
    if (maxP <= 0) return false;
    final cur = ticket.printCount ?? 1;
    return cur < maxP;
  }

  /// True when all reprint request slots are used up (and no direct prints remain).
  bool _isReprintClosed(Ticket ticket) {
    if (_activeReprintSetup == null || !_activeReprintSetup!.isActive)
      return false;
    if (_isDirectPrint(ticket)) return false;
    if (ticket.hasApprovedReprintRequest) return false;
    final cur = ticket.reprintRequests ?? 0;
    final maxR = _activeReprintSetup!.maxReprintRequests;
    return maxR > 0 && cur >= maxR;
  }

  bool _canReprint(Ticket ticket) {
    final status = (ticket.status ?? '').toLowerCase();
    if ((ticket.hasActiveRequest && !ticket.hasApprovedReprintRequest) ||
        status == 'pending_void' ||
        status == 'voided') {
      return false;
    }
    if (ticket.betObjects?.isEmpty ?? true) return false;

    // Enforce reprint cut-off window using the draw time + grace period from
    // reprint setup. Falls back to same-calendar-day check when not configured.
    final grace = _activeReprintSetup?.cutoffGraceMinutes ?? 0;
    final bets = ticket.betObjects ?? [];
    bool withinWindow = true;
    if (grace > 0 && bets.isNotEmpty) {
      try {
        final firstBet = bets.first;
        final drawDateStr = firstBet.drawDate; // "2026-08-09"
        final drawTimeStr = firstBet.drawTime; // "14:00:00" or "14:00"
        if (drawDateStr != null && drawTimeStr != null) {
          final parts = drawTimeStr.split(':');
          final h = int.parse(parts[0]);
          final m = parts.length > 1 ? int.parse(parts[1]) : 0;
          final drawBase = DateTime.parse(drawDateStr);
          final drawDateTime = DateTime(
            drawBase.year,
            drawBase.month,
            drawBase.day,
            h,
            m,
          );
          final cutoff = drawDateTime.add(Duration(minutes: grace));
          withinWindow = DateTime.now().isBefore(cutoff);
        }
      } catch (_) {}
    } else {
      // No grace period configured — use same-calendar-day restriction.
      if (ticket.createdAt != null) {
        try {
          final created = DateTime.parse(ticket.createdAt!).toLocal();
          final now = DateTime.now();
          final sameDay =
              created.year == now.year &&
              created.month == now.month &&
              created.day == now.day;
          withinWindow = sameDay;
        } catch (_) {}
      }
    }
    if (!withinWindow) return false;

    // Direct print still available → button enabled
    if (_isDirectPrint(ticket)) return true;
    // Request reprint path
    if (_activeReprintSetup != null && _activeReprintSetup!.isActive) {
      final cur = ticket.reprintRequests ?? 0;
      final maxR = _activeReprintSetup!.maxReprintRequests;
      if (maxR > 0 && cur >= maxR) return false;
    }
    return _activeReprintSetup != null && _activeReprintSetup!.isActive;
  }

  /// Whether to render the void button at all (requires admin config or ticket-level window).
  bool _showVoidButton(Ticket ticket) {
    if ((ticket.status ?? '').toLowerCase() != 'pending') return false;
    if (ticket.hasPendingVoidRequest) return false;
    return _activeVoidSetup != null ||
        ticket.voidWindowMinutes != null ||
        ticket.voidExpiresAt != null;
  }

  /// Whether to render the reprint button at all (requires active admin config).
  bool _showReprintButton(Ticket ticket) {
    final status = (ticket.status ?? '').toLowerCase();
    if (status == 'voided' || status == 'lost' || status == 'won') return false;
    return _activeReprintSetup != null && _activeReprintSetup!.isActive;
  }

  // ── QR ─────────────────────────────────────────────────────────────────────

  Future<void> _startQRScan() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      Get.snackbar(
        'Permission Denied',
        'Camera permission required',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    setState(() => _showQRScanner = true);
  }

  Future<void> _handleScannedQR(String code) async {
    _qrCtrl?.pauseCamera();

    // Instant local validation — reject garbage before any network call.
    if (TicketService.tryDecodeValidQr(code) == null) {
      Get.snackbar(
        'Invalid QR',
        'Not a valid ticket QR code.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      await Future.delayed(const Duration(seconds: 2));
      _qrCtrl?.resumeCamera();
      return;
    }

    final now = DateTime.now();

    // Use cached resolution if available
    if (_resolvedQrCacheTs.containsKey(code) && _resolvedQrCache.containsKey(code)) {
      final ts = _resolvedQrCacheTs[code]!;
      if (now.difference(ts) <= _resolvedQrCacheTTL) {
        final resolved = _resolvedQrCache[code]!;
        setState(() => _showQRScanner = false);
        _searchController.text = resolved;
        await _ctrl.fetchTickets(resolved);
        return;
      }
    }

    String resolved;
    try {
      resolved = await TicketService.resolveScannedTicketNumber(code).timeout(const Duration(seconds: 5));
    } catch (e) {
      // fallback to raw code if resolution failed/timeout
      resolved = code;
    }

    // cache resolved value
    _resolvedQrCache[code] = resolved;
    _resolvedQrCacheTs[code] = now;

    setState(() => _showQRScanner = false);
    _searchController.text = resolved;
    await _ctrl.fetchTickets(resolved);
  }

  // ── void actions ───────────────────────────────────────────────────────────

  void _showVoidSheet(Ticket ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VoidConfirmSheet(
        ticketId: _shortId(ticket.id),
        onKeep: () => Navigator.pop(context),
        onVoid: (reason) {
          Navigator.pop(context);
          _doVoid(ticket, reason);
        },
      ),
    );
  }

  Future<void> _doVoid(Ticket ticket, String reason) async {
    try {
      final msg = await _ctrl.voidTicket(ticket.id ?? '', reason);
      Get.snackbar(
        'Success',
        msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to void: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _doReprint(Ticket ticket) async {
    try {
      final msg = await _ctrl.requestReprint(ticket.id ?? '');
      Get.snackbar(
        'Success',
        msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _green,
        colorText: Colors.white,
      );
    } catch (e) {
      final errMsg = e.toString();
      if (errMsg.contains('still be reprinted') &&
          errMsg.contains('without approval')) {
        // Backend says direct print still available — proceed without approval.
        await _doPrint(ticket);
        return;
      }
      Get.snackbar(
        'Error',
        'Failed to request reprint: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
    }
  }

  /// Direct BT print — used when printCount < maxPrints.
  /// Prints via Bluetooth then increments print_count on the backend.
  Future<void> _doPrint(
    Ticket ticket, {
    bool incrementPrintCount = true,
  }) async {
    // Ticket list endpoint doesn't include bet objects — fetch full ticket first.
    Ticket printTicket = ticket;
    if (ticket.betObjects == null || ticket.betObjects!.isEmpty) {
      final full = await TicketService.fetchTicketForPrint(ticket.id ?? '');
      if (full != null && full.betObjects?.isNotEmpty == true) {
        printTicket = full;
      }
    }
    final result = await PrinterService.reprintTicket(ticket: printTicket);
    if (!result.success) {
      final msg = switch (result.error) {
        PrintError.noPrinterConfigured => 'No printer configured.',
        PrintError.permissionDenied => 'Bluetooth permission denied.',
        PrintError.notConnected => 'Printer not connected. Check Bluetooth.',
        PrintError.outOfPaper => 'Printer out of paper.',
        _ => 'Print failed. Check printer and try again.',
      };
      Get.snackbar(
        'Print Failed',
        msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
      return;
    }
    if (incrementPrintCount) {
      try {
        await TicketService.incrementPrintCount(ticket.id ?? '');
      } catch (_) {
        // Print succeeded — backend count update failure is non-fatal
      }
    }
    _ctrl.fetchTickets();
    Get.snackbar(
      'Printed',
      'Ticket printed successfully.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: _green,
      colorText: Colors.white,
    );
  }

  Future<void> _doApprovedPrint(Ticket ticket) async {
    try {
      await _ctrl.consumeApprovedReprint(ticket.id ?? '');
      await _doPrint(ticket, incrementPrintCount: false);
    } catch (e) {
      Get.snackbar(
        'Print Failed',
        'Unable to use the approved reprint: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
    }
  }

  // ── date picker actions ────────────────────────────────────────────────────

  Future<void> _pickDate(BuildContext context) async {
    final initial = _dateInput.isNotEmpty
        ? DateTime.tryParse(_dateInput) ?? DateTime.now()
        : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _blue)),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final iso = picked.toIso8601String().substring(0, 10);
    setState(() {
      _dateInput = iso;
      _dateExplicitlySet = true;
    });
    _ctrl.setDate(iso);
  }

  void _clearDate() {
    setState(() {
      _dateInput = '';
      _dateExplicitlySet = false;
    });
    _ctrl.clearDateFilter();
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showQRScanner) return _buildQRScanner();

    return Column(
      children: [
        _buildTabBar(),
        _buildFilterRow(),
        Expanded(child: _buildList()),
      ],
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() => Obx(() {
    final activeCount = _ctrl.activeTabCount.value;
    final voidCount = _ctrl.voidTabCount.value;
    final isTickets = _ctrl.selectedStatus.value != 'Void';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _hair,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _tab(
              'Tickets',
              activeCount,
              isTickets,
              () => _ctrl.setStatus('Tickets'),
            ),
            _tab('Void', voidCount, !isTickets, () => _ctrl.setStatus('Void')),
          ],
        ),
      ),
    );
  });

  Widget _tab(String label, int count, bool active, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: active ? _blue : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: _blue.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : _muted,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '($count)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? Colors.white.withValues(alpha: 0.85)
                        : _muted2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  // ── Filter row ─────────────────────────────────────────────────────────────

  Widget _buildFilterRow() => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: _border)),
    ),
    child: SizedBox(
      height: 42,
      child: Row(
        children: [
          // Search
          Expanded(
            child: _SearchBox(
              controller: _searchController,
              focusNode: _searchFocusNode,
              focused: _searchFocused,
              onClear: () {
                _searchController.clear();
                _ctrl.fetchTickets('');
              },
            ),
          ),
          const SizedBox(width: 8),
          // Single date picker button
          Obx(() {
            final active =
                _dateExplicitlySet && _ctrl.dateFrom.value.isNotEmpty;
            return GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 0,
                ),
                height: 42,
                decoration: BoxDecoration(
                  color: active ? _blue : Colors.white,
                  border: Border.all(color: active ? _blue : _border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: active ? Colors.white : _muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _fmtDateLabel(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : _muted,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _clearDate,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          // QR scan
          _IconBtn(icon: Icons.qr_code_scanner, onTap: _startQRScan),
        ],
      ),
    ),
  );

  // ── List ───────────────────────────────────────────────────────────────────

  Widget _buildList() => Obx(() {
    if (_ctrl.isLoading.value) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
    if (_ctrl.hasError.value) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: _muted2),
            const SizedBox(height: 10),
            const Text(
              'Failed to load tickets',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _ctrl.fetchTickets(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final tickets = _ctrl.tickets;
    if (tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 36, color: _muted2),
            const SizedBox(height: 10),
            const Text(
              'No tickets found',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try widening the date range or clearing search.',
              style: TextStyle(color: _muted2, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _blue,
      onRefresh: () => _ctrl.fetchTickets(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        itemCount: tickets.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${tickets.length} ticket${tickets.length == 1 ? '' : 's'} found',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: _muted2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }
          final t = tickets[i - 1];
          return _TicketCard(
            ticket: t,
            shortId: t.ticketNo ?? _shortId(t.id),
            fmtPrinted: _fmtDrawDateTime(
              t.betObjects?.isNotEmpty == true
                  ? (t.betObjects!.first.drawDate ?? '')
                  : '',
              t.betObjects?.isNotEmpty == true
                  ? t.betObjects!.first.drawTime
                  : null,
            ),
            fmtDrawDate: _fmtPrinted(t.createdAt),
            fmtAmount: _fmtAmount,
            fmtClock: _fmtClock,
            voidTimeLeft: _voidTimeLeft(t),
            printTimeLeft: _printTimeLeft(t),
            canVoid: _canVoid(t),
            canReprint: _canReprint(t),
            isDirectPrint: _isDirectPrint(t),
            isReprintClosed: _isReprintClosed(t),
            showVoid: _showVoidButton(t),
            showReprint: _showReprintButton(t),
            expanded: _expandedCards.contains(t.id),
            onToggleExpand: () => setState(() {
              if (_expandedCards.contains(t.id)) {
                _expandedCards.remove(t.id);
              } else {
                _expandedCards.add(t.id!);
              }
            }),
            onVoid: () => _showVoidSheet(t),
            onReprint: t.hasApprovedReprintRequest
                ? () => _doApprovedPrint(t)
                : _isDirectPrint(t)
                ? () => _doPrint(t)
                : () => _doReprint(t),
          );
        },
      ),
    );
  });

  // ── QR scanner ─────────────────────────────────────────────────────────────

  Widget _buildQRScanner() => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Scan Ticket QR'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(() => _showQRScanner = false),
      ),
    ),
    body: QRView(
      key: _qrKey,
      onQRViewCreated: (c) {
        _qrCtrl = c;
        c.scannedDataStream.listen((d) {
          if (d.code != null) _handleScannedQR(d.code!);
        });
      },
    ),
  );
}

// ── Ticket card ────────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  final String shortId;
  final String fmtPrinted;
  final String fmtDrawDate;
  final String Function(double?) fmtAmount;
  final String Function(Duration) fmtClock;
  final Duration? voidTimeLeft;
  final Duration? printTimeLeft;
  final bool canVoid;
  final bool canReprint;
  final bool isDirectPrint;
  final bool isReprintClosed;
  final bool showVoid;
  final bool showReprint;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onVoid;
  final VoidCallback onReprint;

  const _TicketCard({
    required this.ticket,
    required this.shortId,
    required this.fmtPrinted,
    required this.fmtDrawDate,
    required this.fmtAmount,
    required this.fmtClock,
    required this.voidTimeLeft,
    required this.printTimeLeft,
    required this.canVoid,
    required this.canReprint,
    required this.isDirectPrint,
    required this.isReprintClosed,
    required this.showVoid,
    required this.showReprint,
    required this.expanded,
    required this.onToggleExpand,
    required this.onVoid,
    required this.onReprint,
  });

  String get _status => (ticket.status ?? '').toLowerCase();

  Widget _statusChip() {
    late Color bg, fg;
    late String label;
    switch (_status) {
      case 'pending':
        bg = _blueL;
        fg = _blueD;
        label = 'Pending';
      case 'won':
        bg = _greenL;
        fg = _green;
        label = 'Won';
      case 'voided':
        bg = _redL;
        fg = _red;
        label = 'Voided';
      case 'pending_void':
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFD97706);
        label = 'Void Request';
      case 'lost':
        bg = _hair;
        fg = _muted;
        label = 'Lose';
      default:
        bg = _hair;
        fg = _muted;
        label = _status.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bets = ticket.betObjects ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 10),
            child: Row(
              children: [
                // STL logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/images/logos/logo.png',
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: _hair,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'STL',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: _muted2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Ticket ID + location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortId,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _ink2,
                        ),
                      ),
                      if (ticket.cluster?.name != null)
                        Text(
                          ticket.cluster!.name!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _muted2,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(),
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bets count + draw time
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BETS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: _muted2,
                          ),
                        ),
                        Text(
                          '${bets.length} bet${bets.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'DRAW DATE & TIME',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: _muted2,
                          ),
                        ),
                        Text(
                          fmtPrinted,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Draw date + total bet amount
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PRINTED DATE & TIME',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: _muted2,
                          ),
                        ),
                        Text(
                          fmtDrawDate.isNotEmpty ? fmtDrawDate : '—',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'TOTAL BET',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: _muted2,
                          ),
                        ),
                        Text(
                          fmtAmount(
                            bets.fold<double>(
                              0.0,
                              (s, b) =>
                                  s +
                                  (b.straightBetAmount ?? 0.0) +
                                  (b.rambleBetAmount ?? 0.0),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Action buttons — only rendered when admin config allows
                if (showReprint || showVoid) ...[
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      if (showReprint)
                        Expanded(
                          child: _ReprintButton(
                            enabled: canReprint,
                            label: (isDirectPrint ||
                                    ticket.hasApprovedReprintRequest)
                                ? 'Print'
                                : 'Request Reprint',
                            isDirectPrint: isDirectPrint,
                            isPrintClosed: isReprintClosed,
                            printTimeLeft: printTimeLeft,
                            fmtClock: fmtClock,
                            onTap: canReprint ? onReprint : null,
                          ),
                        ),
                      if (showReprint && showVoid) const SizedBox(width: 8),
                      if (showVoid)
                        Expanded(
                          child: _VoidButton(
                            timeLeft: voidTimeLeft,
                            canVoid: canVoid,
                            fmtClock: fmtClock,
                            onTap: canVoid ? onVoid : null,
                          ),
                        ),
                    ],
                  ),
                ],

                // Bets Details toggle
                if (bets.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  GestureDetector(
                    onTap: onToggleExpand,
                    child: Row(
                      children: [
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 14,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          expanded ? 'Hide Details' : 'View Details',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Expandable bets table
                if (bets.isNotEmpty)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: expanded
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BetsTable(bets: bets, fmtAmount: fmtAmount),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text(
                                    'TOTAL BET',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: _muted2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    fmtAmount(
                                      bets.fold<double>(
                                        0.0,
                                        (s, b) =>
                                            s +
                                            (b.straightBetAmount ?? 0.0) +
                                            (b.rambleBetAmount ?? 0.0),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: _ink,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Void button with integrated countdown ────────────────────────────────────

class _VoidButton extends StatelessWidget {
  final Duration? timeLeft;
  final bool canVoid;
  final String Function(Duration) fmtClock;
  final VoidCallback? onTap;

  const _VoidButton({
    required this.timeLeft,
    required this.canVoid,
    required this.fmtClock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Expired / no window
    if (timeLeft != null && timeLeft!.inSeconds == 0) {
      return _btn(
        enabled: false,
        warn: false,
        pct: 1.0,
        label: 'Void Closed',
        time: null,
        onTap: null,
      );
    }
    if (!canVoid) {
      return _btn(
        enabled: false,
        warn: false,
        pct: 0,
        label: 'Void',
        time: null,
        onTap: null,
      );
    }
    // Active countdown
    final remaining = timeLeft;
    double pct = 0;
    bool warn = false;
    String? timeStr;
    if (remaining != null) {
      const total = 5 * 60; // 5 minutes total window
      pct = 1.0 - (remaining.inSeconds / total).clamp(0.0, 1.0);
      warn = remaining.inSeconds < 60;
      timeStr = fmtClock(remaining);
    }
    return _btn(
      enabled: true,
      warn: warn,
      pct: pct,
      label: 'Void',
      time: timeStr,
      onTap: onTap,
    );
  }

  Widget _btn({
    required bool enabled,
    required bool warn,
    required double pct,
    required String label,
    required String? time,
    required VoidCallback? onTap,
  }) {
    final bg = !enabled
        ? _hair
        : warn
        ? const Color(0xFFB91C1C)
        : _ink;
    final fg = !enabled ? _muted2 : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(11),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // progress fill (white, fills as time runs out)
            if (enabled && pct > 0)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              ),
            // content
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.close, size: 13, color: fg),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  if (time != null) ...[
                    Container(
                      width: 1,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: fg,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reprint / Print button with optional countdown timer ──────────────────────

class _ReprintButton extends StatelessWidget {
  final bool enabled;
  final String label;
  final bool isDirectPrint;
  final bool isPrintClosed;
  final Duration? printTimeLeft;
  final String Function(Duration) fmtClock;
  final VoidCallback? onTap;

  const _ReprintButton({
    required this.enabled,
    required this.label,
    required this.isDirectPrint,
    this.isPrintClosed = false,
    required this.printTimeLeft,
    required this.fmtClock,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Show timer only on the direct Print button when a timer is configured
    final showTimer = isDirectPrint && printTimeLeft != null;
    final expired = showTimer && printTimeLeft!.inSeconds == 0;
    final warn = showTimer && !expired && printTimeLeft!.inSeconds < 60;
    final timeStr = showTimer && !expired ? fmtClock(printTimeLeft!) : null;

    // Total window for progress bar (use printTimeLeft initial as approximation)
    double pct = 0;
    if (showTimer && !expired && printTimeLeft != null) {
      // Use 5-min window as reference (same as void button)
      const totalSecs = 5 * 60;
      pct = 1.0 - (printTimeLeft!.inSeconds / totalSecs).clamp(0.0, 1.0);
    }

    final effectiveEnabled = enabled && !expired && !isPrintClosed;
    final isClosed = expired || isPrintClosed;
    final borderColor = !effectiveEnabled
        ? _border
        : isClosed
        ? _red
        : warn
        ? const Color(0xFFDC2626)
        : _blue;
    final textColor = !effectiveEnabled ? _muted2 : borderColor;
    final bgColor = isClosed ? _redL : Colors.white;

    return GestureDetector(
      onTap: effectiveEnabled ? onTap : null,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(11),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Progress fill when timer active
            if (showTimer && !expired && pct > 0)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(color: _blue.withValues(alpha: 0.08)),
                  ),
                ),
              ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isClosed
                        ? Icons.print_disabled_outlined
                        : Icons.print_outlined,
                    size: 14,
                    color: textColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isClosed ? 'Print Closed' : label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  if (timeStr != null) ...[
                    Container(
                      width: 1,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 7),
                      color: borderColor.withValues(alpha: 0.3),
                    ),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bets table ────────────────────────────────────────────────────────────────

class _BetsTable extends StatelessWidget {
  final List<BetData> bets;
  final String Function(double?) fmtAmount;
  const _BetsTable({required this.bets, required this.fmtAmount});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(2),
        },
        children: [
          // Header
          const TableRow(
            children: [
              _TH('GAME'),
              _TH('BET NO'),
              _TH('AMOUNT'),
              _TH('TYPE'),
              _TH('STATUS'),
            ],
          ),
          // Rows
          ...bets.map((b) {
            final digits = b.digits?.join('-') ?? b.number ?? '—';
            final straight = b.straightBetAmount ?? 0;
            final ramble = b.rambleBetAmount ?? 0;
            final betType = straight > 0 && ramble > 0
                ? 'Both'
                : ramble > 0
                ? 'Rambol'
                : 'Target';
            final amt = (b.straightBetAmount ?? 0) + (b.rambleBetAmount ?? 0);
            return TableRow(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _hair)),
              ),
              children: [
                _TD(b.gameName ?? '—'),
                _TD(digits),
                _TD(fmtAmount(amt)),
                _TD(betType),
                _TDStatus(b.status ?? '—'),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: _muted2,
      ),
    ),
  );
}

class _TD extends StatelessWidget {
  final String text;
  const _TD(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(text, style: const TextStyle(fontSize: 12.5, color: _ink2)),
  );
}

class _TDStatus extends StatelessWidget {
  final String status;
  const _TDStatus(this.status);

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final bg = s == 'voided' ? _redL : _blueL;
    final fg = s == 'voided' ? _red : _blueD;
    final label = s == 'lost' ? 'LOSE' : status.toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ── Void confirm sheet ────────────────────────────────────────────────────────

class _VoidConfirmSheet extends StatefulWidget {
  final String ticketId;
  final VoidCallback onKeep;
  final void Function(String reason) onVoid;
  const _VoidConfirmSheet({
    required this.ticketId,
    required this.onKeep,
    required this.onVoid,
  });

  @override
  State<_VoidConfirmSheet> createState() => _VoidConfirmSheetState();
}

class _VoidConfirmSheetState extends State<_VoidConfirmSheet> {
  final _reasonCtrl = TextEditingController();
  bool _hasReason = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      18,
      18,
      18 + MediaQuery.of(context).viewInsets.bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Void this ticket?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.ticketId} will be marked void and removed from active bets. '
          'This can\'t be undone.',
          style: const TextStyle(fontSize: 13, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _reasonCtrl,
          autofocus: true,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (v) => setState(() => _hasReason = v.trim().isNotEmpty),
          decoration: InputDecoration(
            hintText: 'Reason for void (required)',
            hintStyle: const TextStyle(fontSize: 13, color: _muted2),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _blue, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: widget.onKeep,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _hair,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Keep ticket',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _hasReason
                    ? () => widget.onVoid(_reasonCtrl.text.trim())
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _hasReason ? _red : _faint,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Void it',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _hasReason ? Colors.white : _muted2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ── Search box ────────────────────────────────────────────────────────────────

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final VoidCallback onClear;
  const _SearchBox({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    height: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(
        color: focused ? _blue : _border,
        width: focused ? 1.5 : 1,
      ),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      children: [
        const SizedBox(width: 12),
        Icon(Icons.search, size: 16, color: focused ? _blue : _muted2),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 13, color: _ink),
            decoration: const InputDecoration(
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              filled: false,
              hintText: 'Search ticket number…',
              hintStyle: TextStyle(color: _muted2, fontWeight: FontWeight.w500),
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ),
        ValueListenableBuilder(
          valueListenable: controller,
          builder: (_, v, __) => v.text.isNotEmpty
              ? GestureDetector(
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.close, size: 14, color: _faint),
                  ),
                )
              : const SizedBox(width: 12),
        ),
      ],
    ),
  );
}

// ── Date button ───────────────────────────────────────────────────────────────

class _DateButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DateButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      constraints: const BoxConstraints(minWidth: 80, maxWidth: 140),
      decoration: BoxDecoration(
        color: active ? _blueL : _hair,
        border: active ? Border.all(color: _blue) : null,
        borderRadius: BorderRadius.circular(11),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _blue.withValues(alpha: 0.10),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 14,
            color: active ? _blue : _muted2,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? _blueD : _ink2,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Icon button ───────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: _muted),
    ),
  );
}

// ── Date popover ──────────────────────────────────────────────────────────────

class _DatePopover extends StatelessWidget {
  final String dateFrom;
  final String dateTo;
  final List<(String, int, int)> presets;
  final String Function() todayFn;
  final String Function(int) addDaysFn;
  final ValueChanged<String> onFromChanged;
  final ValueChanged<String> onToChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final void Function(String, String) onPreset;

  const _DatePopover({
    required this.dateFrom,
    required this.dateTo,
    required this.presets,
    required this.todayFn,
    required this.addDaysFn,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onApply,
    required this.onClear,
    required this.onPreset,
  });

  @override
  Widget build(BuildContext context) => Material(
    elevation: 8,
    borderRadius: BorderRadius.circular(14),
    shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.25),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Presets
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: presets.map((p) {
              final f = p.$2 == 0 ? todayFn() : addDaysFn(p.$2);
              final t = p.$3 == 0 ? todayFn() : addDaysFn(p.$3);
              final on = dateFrom == f && dateTo == t;
              return GestureDetector(
                onTap: () => onPreset(f, t),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: on ? _blue : Colors.white,
                    border: Border.all(color: on ? _blue : _border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    p.$1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : _muted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          // From / To
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'From',
                  value: dateFrom,
                  onChange: onFromChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateField(
                  label: 'To',
                  value: dateTo,
                  onChange: onToChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Actions
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _hair,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onApply,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Apply',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChange;
  const _DateField({
    required this.label,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: _muted2,
        ),
      ),
      const SizedBox(height: 5),
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value.isNotEmpty
                ? DateTime.tryParse(value) ?? DateTime.now()
                : DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (picked != null) {
            onChange(picked.toIso8601String().substring(0, 10));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            value.isNotEmpty ? value : 'Pick date',
            style: TextStyle(
              fontSize: 13,
              color: value.isNotEmpty ? _ink : _muted2,
            ),
          ),
        ),
      ),
    ],
  );
}
