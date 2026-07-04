import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/ticket_service.dart';
import '../../core/services/void_setup_service.dart';
import '../../core/services/reprint_setup_service.dart';
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

  // QR
  QRViewController? _qrCtrl;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  bool _showQRScanner = false;

  // Date range popover
  bool _datePopOpen = false;
  bool _dateExplicitlySet = false;
  String _dateFromInput = '';
  String _dateToInput = '';
  static const _presets = [
    ('Today', 0, 0),
    ('Yesterday', -1, -1),
    ('This week', -6, 0),
  ];

  // Expanded cards (ticket id → bool)
  final Set<String> _expandedCards = {};

  // Search focus
  bool _searchFocused = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(TicketController());
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocusNode.hasFocus);
    });
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    VoidSetupService.fetchActiveVoidSetup()
        .then((v) {
          if (mounted && v != null) setState(() => _activeVoidSetup = v);
        })
        .catchError((_) {});
    ReprintSetupService.fetchActiveReprintSetup()
        .then((v) {
          if (mounted && v != null) setState(() => _activeReprintSetup = v);
        })
        .catchError((_) {});

    // init date inputs to match controller
    _dateFromInput = _ctrl.dateFrom.value;
    _dateToInput = _ctrl.dateTo.value;
  }

  @override
  void dispose() {
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
    final f = _ctrl.dateFrom.value;
    final t = _ctrl.dateTo.value;
    if (f.isEmpty && t.isEmpty) return 'All dates';
    if (f == t) return _fmtShort(f);
    return '${_fmtShort(f)} – ${_fmtShort(t)}';
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
    if (status != 'pending' || ticket.hasActiveRequest) return false;
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
    return true;
  }

  bool _canReprint(Ticket ticket) {
    final status = (ticket.status ?? '').toLowerCase();
    if (ticket.hasActiveRequest ||
        status == 'pending_void' ||
        status == 'voided') {
      return false;
    }
    if (ticket.betObjects?.isEmpty ?? true) return false;
    if (_activeReprintSetup != null && _activeReprintSetup!.isActive) {
      final cur = ticket.reprintRequests ?? 0;
      final maxR = _activeReprintSetup!.maxReprintRequests;
      if (maxR > 0 && cur >= maxR) return false;
    }
    return true;
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
    final resolved = await TicketService.resolveScannedTicketNumber(code);
    setState(() => _showQRScanner = false);
    _searchController.text = resolved;
    await _ctrl.fetchTickets(resolved);
  }

  // ── void actions ───────────────────────────────────────────────────────────

  void _showVoidSheet(Ticket ticket) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VoidConfirmSheet(
        ticketId: _shortId(ticket.id),
        onKeep: () => Navigator.pop(context),
        onVoid: () {
          Navigator.pop(context);
          _doVoid(ticket);
        },
      ),
    );
  }

  Future<void> _doVoid(Ticket ticket) async {
    try {
      final msg = await _ctrl.voidTicket(ticket.id ?? '', '');
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
      Get.snackbar(
        'Error',
        'Failed to request reprint: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _red,
        colorText: Colors.white,
      );
    }
  }

  // ── date popover actions ───────────────────────────────────────────────────

  void _applyDates() {
    var f = _dateFromInput;
    var t = _dateToInput;
    if (f.isNotEmpty && t.isNotEmpty && f.compareTo(t) > 0) {
      final tmp = f;
      f = t;
      t = tmp;
    }
    if (f.isEmpty && t.isEmpty) {
      setState(() {
        _datePopOpen = false;
        _dateExplicitlySet = false;
      });
      _ctrl.clearDateFilter();
    } else {
      setState(() {
        _datePopOpen = false;
        _dateExplicitlySet = true;
      });
      _ctrl.setDateRange(f.isNotEmpty ? f : t, t.isNotEmpty ? t : f);
    }
  }

  void _clearDates() {
    setState(() {
      _dateFromInput = '';
      _dateToInput = '';
      _datePopOpen = false;
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
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        // Main row
        SizedBox(
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
              // Date button
              Obx(
                () => _DateButton(
                  label: _fmtDateLabel(),
                  active:
                      _dateExplicitlySet &&
                      (_ctrl.dateFrom.value.isNotEmpty ||
                          _ctrl.dateTo.value.isNotEmpty),
                  onTap: () {
                    setState(() {
                      _datePopOpen = !_datePopOpen;
                      if (_datePopOpen) {
                        _dateFromInput = _ctrl.dateFrom.value;
                        _dateToInput = _ctrl.dateTo.value;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              // QR scan
              _IconBtn(icon: Icons.qr_code_scanner, onTap: _startQRScan),
            ],
          ),
        ),
        // Date popover
        if (_datePopOpen)
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: _DatePopover(
              dateFrom: _dateFromInput,
              dateTo: _dateToInput,
              presets: _presets,
              todayFn: _today,
              addDaysFn: _addDays,
              onFromChanged: (v) => setState(() => _dateFromInput = v),
              onToChanged: (v) => setState(() => _dateToInput = v),
              onApply: _applyDates,
              onClear: _clearDates,
              onPreset: (f, t) {
                setState(() {
                  _dateFromInput = f;
                  _dateToInput = t;
                });
              },
            ),
          ),
      ],
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
            shortId: _shortId(t.id),
            fmtPrinted: _fmtPrinted(t.createdAt),
            fmtAmount: _fmtAmount,
            fmtClock: _fmtClock,
            voidTimeLeft: _voidTimeLeft(t),
            canVoid: _canVoid(t),
            canReprint: _canReprint(t),
            expanded: _expandedCards.contains(t.id),
            onToggleExpand: () => setState(() {
              if (_expandedCards.contains(t.id)) {
                _expandedCards.remove(t.id);
              } else {
                _expandedCards.add(t.id!);
              }
            }),
            onVoid: () => _showVoidSheet(t),
            onReprint: () => _doReprint(t),
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
  final String Function(double?) fmtAmount;
  final String Function(Duration) fmtClock;
  final Duration? voidTimeLeft;
  final bool canVoid;
  final bool canReprint;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onVoid;
  final VoidCallback onReprint;

  const _TicketCard({
    required this.ticket,
    required this.shortId,
    required this.fmtPrinted,
    required this.fmtAmount,
    required this.fmtClock,
    required this.voidTimeLeft,
    required this.canVoid,
    required this.canReprint,
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
                // STL logo circle
                Container(
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
                // Bets count + printed
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
                          'PRINTED',
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

                const SizedBox(height: 11),

                // Action buttons
                Row(
                  children: [
                    // Reprint
                    Expanded(
                      child: _ReprintButton(
                        enabled: canReprint,
                        onTap: canReprint ? onReprint : null,
                      ),
                    ),
                    if (_status == 'pending') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _VoidButton(
                          timeLeft: voidTimeLeft,
                          canVoid: canVoid,
                          fmtClock: fmtClock,
                          onTap: canVoid ? onVoid : null,
                        ),
                      ),
                    ],
                  ],
                ),

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
                        const Text(
                          'Bets Details',
                          style: TextStyle(
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
                        ? _BetsTable(bets: bets, fmtAmount: fmtAmount)
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

// ── Reprint button ────────────────────────────────────────────────────────────

class _ReprintButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback? onTap;
  const _ReprintButton({required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: enabled ? _blue : _border, width: 1.5),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.print_outlined,
            size: 14,
            color: enabled ? _blue : _muted2,
          ),
          const SizedBox(width: 6),
          Text(
            'Request Reprint',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: enabled ? _blue : _muted2,
            ),
          ),
        ],
      ),
    ),
  );
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
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(2),
        },
        children: [
          // Header
          const TableRow(
            children: [
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          status.toUpperCase(),
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

class _VoidConfirmSheet extends StatelessWidget {
  final String ticketId;
  final VoidCallback onKeep;
  final VoidCallback onVoid;
  const _VoidConfirmSheet({
    required this.ticketId,
    required this.onKeep,
    required this.onVoid,
  });

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
          '$ticketId will be marked void and removed from active bets. '
          'This can\'t be undone.',
          style: const TextStyle(fontSize: 13, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onKeep,
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
                onTap: onVoid,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _red,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Void it',
                    style: TextStyle(
                      fontSize: 14,
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
      boxShadow: focused
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
