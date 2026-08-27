import 'dart:developer';
import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:onstite/controllers/auth_controller.dart';
import '../../controllers/lottery_controller.dart';
import '../../models/eod_report.dart';
import '../../models/ticket.dart';
import 'qr_crypto_service.dart';

enum PrintError {
  noPrinterConfigured,
  permissionDenied,
  notConnected,
  outOfPaper,
  nearEndOfPaper,
  unknown,
}

enum PrinterProfile {
  gsV0, // GS v 0 raster — standard ESC/POS printers
  escStar, // ESC * 24-pin — Goojprt PT-210 / MTP-2 series
}

enum PrinterReachabilityStatus {
  notConfigured,
  permissionDenied,
  reachable,
  unreachable,
}

class PrintResult {
  final bool success;
  final PrintError? error;

  const PrintResult.ok() : success = true, error = null;
  const PrintResult.fail(this.error) : success = false;
}

class PrinterService {
  static const _macKey = 'bluetooth_printer_mac';
  static const _nameKey = 'bluetooth_printer_name';
  static const _profileKey = 'bluetooth_printer_profile';

  static final _storage = GetStorage();

  static String? get savedMac => _storage.read<String>(_macKey);
  static String? get savedName => _storage.read<String>(_nameKey);
  static PrinterProfile get savedProfile {
    final v = _storage.read<String>(_profileKey);
    return v == 'escStar' ? PrinterProfile.escStar : PrinterProfile.gsV0;
  }

  static void savePrinter(String mac, String name) {
    _storage.write(_macKey, mac);
    _storage.write(_nameKey, name);
    _storage.write(_profileKey, _detectProfile(name).name);
  }

  static void clearPrinter() {
    _storage.remove(_macKey);
    _storage.remove(_nameKey);
    _storage.remove(_profileKey);
  }

  static void setProfile(PrinterProfile profile) {
    _storage.write(_profileKey, profile.name);
  }

  static PrinterProfile _detectProfile(String deviceName) {
    final n = deviceName.toLowerCase();
    if (n.contains('mtp') ||
        n.contains('goojprt') ||
        n.contains('pt-2') ||
        n.contains('pt210')) {
      return PrinterProfile.escStar;
    }
    return PrinterProfile.gsV0;
  }

  static Future<List<BluetoothInfo>> getPairedDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  static Future<bool> connect(String mac) async {
    return await PrintBluetoothThermal.connect(macPrinterAddress: mac);
  }

  static Future<bool> get isConnected async {
    return await PrintBluetoothThermal.connectionStatus;
  }

  static Future<bool> disconnect() async {
    return await PrintBluetoothThermal.disconnect;
  }

  static Future<bool> ensureBluetoothPermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  static Future<PrinterReachabilityStatus> getSavedPrinterReachability() async {
    final mac = savedMac;
    if (mac == null || mac.isEmpty) {
      return PrinterReachabilityStatus.notConfigured;
    }

    final hasPermission = await ensureBluetoothPermissions();
    if (!hasPermission) {
      return PrinterReachabilityStatus.permissionDenied;
    }

    return await canReachSavedPrinter(skipPermissionCheck: true)
        ? PrinterReachabilityStatus.reachable
        : PrinterReachabilityStatus.unreachable;
  }

  /// Checks whether the saved printer is still available to this device.
  ///
  /// The app only needs the printer to stay configured and paired here. A
  /// printer may be paired and ready to print later even when the plugin does
  /// not currently report an active Bluetooth session, so a paired-device match
  /// counts as reachable for the pre-submit warning flow.
  static Future<bool> canReachSavedPrinter({
    bool skipPermissionCheck = false,
  }) async {
    final mac = savedMac;
    if (mac == null || mac.isEmpty) {
      return false;
    }

    if (!skipPermissionCheck) {
      final hasPermission = await ensureBluetoothPermissions();
      if (!hasPermission) {
        return false;
      }
    }

    final normalizedSavedMac = _normalizeMac(mac);
    if (normalizedSavedMac.isEmpty) {
      return false;
    }

    try {
      if (await PrintBluetoothThermal.connectionStatus) {
        return true;
      }

      final pairedDevices = await getPairedDevices();
      final isStillPaired = pairedDevices.any(
        (device) => _normalizeMac(device.macAdress) == normalizedSavedMac,
      );
      if (isStillPaired) {
        return true;
      }
    } catch (e) {
      log('canReachSavedPrinter error: $e', name: 'PrinterService');
    }

    try {
      // Use a single fast-timeout probe — retries=1 so we don't hang multiple
      // seconds when the printer is off. The per-attempt timeout bounds the
      // worst-case delay to ~3 s instead of 10+ s.
      final connected = await _connectWithRetry(
        mac,
        retries: 1,
        delay: Duration.zero,
        connectTimeout: const Duration(seconds: 3),
      );
      if (!connected) {
        return false;
      }

      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}

      return true;
    } catch (e) {
      log(
        'canReachSavedPrinter connect probe failed: $e',
        name: 'PrinterService',
      );
      return false;
    }
  }

  static String _normalizeMac(String mac) {
    return mac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
  }

  /// Attempts to connect with up to [retries] attempts, with a short
  /// delay between each try.
  static Future<bool> _connectWithRetry(
    String mac, {
    int retries = 3,
    Duration delay = const Duration(seconds: 2),
    Duration? connectTimeout,
  }) async {
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        Future<bool> connectFuture = PrintBluetoothThermal.connect(
          macPrinterAddress: mac,
        );
        if (connectTimeout != null) {
          connectFuture = connectFuture.timeout(
            connectTimeout,
            onTimeout: () => false,
          );
        }
        final ok = await connectFuture;
        if (ok) return true;
      } catch (e) {
        log('Connect attempt $attempt failed: $e', name: 'PrinterService');
      }
      if (attempt < retries) await Future.delayed(delay);
    }
    return false;
  }

  /// Prints a ticket to the saved Bluetooth thermal printer.
  /// Returns a [PrintResult] describing success or specific failure reason.
  static Future<PrintResult> printTicket({
    required List<BetEntry> betEntries,
    required double totalAmount,
    required String ticketNo,
    required Map<String, dynamic> teller,
    required String gameName,
    required String drawTimeLabel,
    String drawDate = '',
    int reprintCount = 0,
  }) async {
    final mac = savedMac;
    if (mac == null || mac.isEmpty) {
      return const PrintResult.fail(PrintError.noPrinterConfigured);
    }

    final hasPermission = await ensureBluetoothPermissions();
    if (!hasPermission) {
      return const PrintResult.fail(PrintError.permissionDenied);
    }

    try {
      // Disconnect any stale session before connecting fresh.
      // Some printers reject a new connection if the previous one
      // was not cleanly closed.
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 250));

      final connected = await _connectWithRetry(
        mac,
        retries: 1,
        delay: Duration.zero,
        connectTimeout: const Duration(seconds: 3),
      );
      if (!connected) {
        return const PrintResult.fail(PrintError.notConnected);
      }

      final bytes = await _buildTicketBytes(
        betEntries: betEntries,
        totalAmount: totalAmount,
        ticketNo: ticketNo,
        teller: teller,
        gameName: gameName,
        drawTimeLabel: drawTimeLabel,
        drawDate: drawDate,
        reprintCount: reprintCount,
      );

      final result = await PrintBluetoothThermal.writeBytes(bytes);
      await _drainDelay(savedProfile);
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}

      return result
          ? const PrintResult.ok()
          : const PrintResult.fail(PrintError.unknown);
    } catch (e) {
      log('printTicket error: $e', name: 'PrinterService');
      return const PrintResult.fail(PrintError.unknown);
    }
  }

  static Future<PrintResult> reprintTicket({required Ticket ticket}) async {
    final betObjects = ticket.betObjects ?? const <BetData>[];
    if (betObjects.isEmpty) {
      return const PrintResult.fail(PrintError.unknown);
    }

    final authCtrl = Get.find<AuthController>();
    final user = authCtrl.currentUser.value;
    final teller = {
      'id': user?.id ?? '',
      'name': user?.name ?? '',
      'area_name': user?.areaName ?? '',
      'agent_no': user?.agentNo ?? '',
    };

    final betEntries = _buildBetEntriesFromTicketBets(betObjects);
    if (betEntries.isEmpty) {
      return const PrintResult.fail(PrintError.unknown);
    }

    final firstBet = betObjects.first;
    final totalAmount = betEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.totalBetAmount,
    );

    return printTicket(
      betEntries: betEntries,
      totalAmount: totalAmount,
      ticketNo: ticket.ticketNo ?? '',
      teller: teller,
      gameName: firstBet.gameName ?? 'STL',
      drawTimeLabel: firstBet.drawTime ?? '',
      drawDate: firstBet.drawDate ?? '',
      reprintCount: (ticket.printCount ?? 0) + 1,
    );
  }

  static Future<PrintResult> printEodReport({
    required EodReportModel report,
  }) async {
    final mac = savedMac;
    if (mac == null || mac.isEmpty) {
      return const PrintResult.fail(PrintError.noPrinterConfigured);
    }

    final hasPermission = await ensureBluetoothPermissions();
    if (!hasPermission) {
      return const PrintResult.fail(PrintError.permissionDenied);
    }

    try {
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 800));

      final connected = await _connectWithRetry(mac);
      if (!connected) {
        return const PrintResult.fail(PrintError.notConnected);
      }

      final bytes = await _buildEodReportBytes(report: report);
      final result = await PrintBluetoothThermal.writeBytes(bytes);
      await _drainDelay(savedProfile);
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}

      return result
          ? const PrintResult.ok()
          : const PrintResult.fail(PrintError.unknown);
    } catch (e) {
      log('printEodReport error: $e', name: 'PrinterService');
      return const PrintResult.fail(PrintError.unknown);
    }
  }

  static List<BetEntry> _buildBetEntriesFromTicketBets(List<BetData> bets) {
    final entries = <BetEntry>[];
    var betNumber = 1;

    for (final bet in bets) {
      final digits = bet.digits ?? const <String>[];
      final gameName = bet.gameName ?? 'STL';
      if ((bet.straightBetAmount ?? 0) > 0) {
        entries.add(
          BetEntry(
            betNumber: betNumber++,
            game: gameName,
            straightBetAmount: bet.straightBetAmount ?? 0,
            rambleBetAmount: 0,
            winAmount: bet.estPayout ?? 0,
            digits: digits,
          ),
        );
      }
      if ((bet.rambleBetAmount ?? 0) > 0) {
        entries.add(
          BetEntry(
            betNumber: betNumber++,
            game: gameName,
            straightBetAmount: 0,
            rambleBetAmount: bet.rambleBetAmount ?? 0,
            winAmount: bet.estPayout ?? 0,
            digits: digits,
          ),
        );
      }
    }

    return entries;
  }

  static Future<List<int>> _buildTicketBytes({
    required List<BetEntry> betEntries,
    required double totalAmount,
    required String ticketNo,
    required Map<String, dynamic> teller,
    required String gameName,
    required String drawTimeLabel,
    String drawDate = '',
    int reprintCount = 0,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final printerProfile = savedProfile;
    final List<int> bytes = [];

    final now = DateTime.now();

    // Format helpers
    const monthAbbr = [
      'Jan.',
      'Feb.',
      'Mar.',
      'Apr.',
      'May',
      'Jun.',
      'Jul.',
      'Aug.',
      'Sep.',
      'Oct.',
      'Nov.',
      'Dec.',
    ];

    // Draw date: use the bet's actual draw date; fall back to today
    String drawDateStr;
    if (drawDate.isNotEmpty) {
      try {
        final d = DateTime.parse(drawDate);
        drawDateStr =
            '${monthAbbr[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
      } catch (_) {
        drawDateStr =
            '${monthAbbr[now.month - 1]} ${now.day.toString().padLeft(2, '0')}, ${now.year}';
      }
    } else {
      drawDateStr =
          '${monthAbbr[now.month - 1]} ${now.day.toString().padLeft(2, '0')}, ${now.year}';
    }

    final dateStr =
        '${monthAbbr[now.month - 1]} ${now.day.toString().padLeft(2, '0')}, ${now.year}';
    final hour = now.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr =
        '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} $period';

    // Teller fields — prefer API response, fall back to current user
    AuthController? authCtrl;
    try {
      authCtrl = Get.find<AuthController>();
    } catch (_) {}
    final currentUser = authCtrl?.currentUser.value;

    final tellerName = (() {
      final v = (teller['name'] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
      return (currentUser?.name ?? '').toString().trim();
    })();
    final agentNo = (() {
      final v = (teller['agent_no'] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
      return (currentUser?.agentNo ?? '').toString().trim();
    })();

    // ── Header ────────────────────────────────────────────────────
    bool logoLoaded = false;
    try {
      final ByteData assetData = await rootBundle.load(
        'assets/images/logos/header.png',
      );
      final Uint8List rawBytes = assetData.buffer.asUint8List();
      img.Image? decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        // Resize to fit 58mm paper; preserve aspect ratio
        const int targetWidth = 380; // 48mm at 203dpi ≈ 380px
        final int targetHeight = (decoded.height * targetWidth / decoded.width)
            .round();
        final img.Image resized = img.copyResize(
          decoded,
          width: targetWidth,
          height: targetHeight,
        );

        bytes.addAll(_encodeImage(resized, printerProfile));
        logoLoaded = true;
      }
    } catch (err) {
      log('Logo load failed: $err', name: 'PrinterService');
    }
    if (!logoLoaded) {
      bytes.addAll(
        generator.text(
          'SMALL TOWN LOTTERY',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size1,
          ),
        ),
      );
    }
    bytes.addAll(
      generator.text(
        'OFFICIAL RECEIPT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      ),
    );
    bytes.addAll(generator.hr(ch: '-'));

    // ── Info rows (label | value) — full width, no side padding ──
    // 5(label) + 7(value) = 12
    void infoRow(String label, String value) {
      bytes.addAll(
        generator.row([
          PosColumn(text: label, width: 5, styles: const PosStyles(bold: true)),
          PosColumn(
            text: value,
            width: 7,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }

    infoRow('Draw Date:', drawDateStr);
    infoRow('Draw Time:', _formatDrawTimeLabel(drawTimeLabel));
    infoRow('Ticket No:', ticketNo);
    if (tellerName.isNotEmpty) infoRow('Teller:', tellerName);
    if (agentNo.isNotEmpty) infoRow('Agent No:', agentNo);

    bytes.addAll(generator.hr(ch: '-'));

    // ── Bet table with inline Win column ──────────────────────────
    // #(1) + Game(2) + Nos(3) + Amt(2) + T(1) + Win(3) = 12
    bytes.addAll(
      generator.row([
        PosColumn(text: '#', width: 1, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Game', width: 2, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Nos', width: 3, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'Amt',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(text: 'T', width: 1, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'Win',
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(generator.hr(ch: '-'));

    for (int i = 0; i < betEntries.length; i++) {
      final entry = betEntries[i];
      final nos = entry.digits.isNotEmpty ? entry.digits.join('-') : '-';
      final gameAbbr = _abbreviateGame(
        entry.game.isNotEmpty ? entry.game : gameName,
      );
      bytes.addAll(
        generator.row([
          PosColumn(text: '${i + 1}', width: 1),
          PosColumn(text: gameAbbr, width: 2),
          PosColumn(text: nos, width: 3),
          PosColumn(
            text: entry.betAmount.toStringAsFixed(0),
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(text: entry.betType.substring(0, 1), width: 1),
          PosColumn(
            text: _formatAmount(entry.winAmount),
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }

    bytes.addAll(generator.hr(ch: '-'));

    // TOTAL row — 4(label) + 5(empty) + 3(amount) = 12
    bytes.addAll(
      generator.row([
        PosColumn(text: 'TOTAL', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(text: '', width: 5),
        PosColumn(
          text: totalAmount.toStringAsFixed(0),
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]),
    );

    bytes.addAll(generator.hr(ch: '-'));

    // ── Footer info ───────────────────────────────────────────────
    if (reprintCount > 0) {
      bytes.addAll(
        generator.text(
          'Reprint - $reprintCount',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
    }
    infoRow('Print Date:', dateStr);
    infoRow('Print Time:', timeStr);

    bytes.addAll(generator.hr(ch: '-'));
    bytes.addAll(
      generator.text(
        'WALANG TICKET. WALANG CLAIM.',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(
      generator.text(
        'Ingatan ang tiket, Bisa ng tiket (1) taon mula sa petsa ng draw.',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );

    // ── QR Code ───────────────────────────────────────────────────
    final encryptedQrData = QrCryptoService.encrypt(ticketNo);
    final qrImage = _buildQrImage(encryptedQrData);
    if (qrImage != null) {
      final resizedQr = img.copyResize(
        qrImage,
        width: 200,
        height: 200,
        interpolation: img.Interpolation.nearest,
      );
      bytes.addAll(_encodeImage(resizedQr, printerProfile));
    } else if (printerProfile == PrinterProfile.escStar) {
      bytes.addAll(
        generator.text(
          encryptedQrData,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    } else {
      bytes.addAll([0x1B, 0x61, 0x01]);
      bytes.addAll(
        generator.qrcode(
          encryptedQrData,
          align: PosAlign.center,
          size: QRSize.size4,
          cor: QRCorrection.M,
        ),
      );
      bytes.addAll([0x1B, 0x61, 0x00]);
    }
    bytes.addAll(_cutOrFeed(generator, printerProfile));

    return bytes;
  }

  static Future<List<int>> _buildEodReportBytes({
    required EodReportModel report,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final printerProfile = savedProfile;
    final List<int> bytes = [];
    final now = DateTime.now();

    String currency(double value) {
      final rounded = value.roundToDouble();
      if ((value - rounded).abs() < 0.005) return rounded.toStringAsFixed(0);
      return value.toStringAsFixed(2);
    }

    final reportDate = DateTime.tryParse(report.reportDate);
    final reportDateLabel = reportDate != null
        ? '${reportDate.month.toString().padLeft(2, '0')}/${reportDate.day.toString().padLeft(2, '0')}/${reportDate.year}'
        : report.reportDate;
    final printedAt =
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year} '
        '${((now.hour % 12) == 0 ? 12 : now.hour % 12).toString()}:'
        '${now.minute.toString().padLeft(2, '0')} '
        '${now.hour >= 12 ? 'PM' : 'AM'}';

    void infoRow(
      String label,
      String value, {
      bool numeric = false,
      bool forceSingleLine = false,
    }) {
      // Match the simpler ticket layout: label (width=4, bold) on left,
      // value (width=6) right-aligned on the same line.
      bytes.addAll(
        generator.row([
          PosColumn(text: '', width: 1),
          PosColumn(text: label, width: 4, styles: const PosStyles(bold: true)),
          PosColumn(
            text: value,
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(text: '', width: 1),
        ]),
      );
    }

    bool logoLoaded = false;
    try {
      final assetData = await rootBundle.load('assets/images/logos/header.png');
      final rawBytes = assetData.buffer.asUint8List();
      final decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        const targetWidth = 380;
        final targetHeight = (decoded.height * targetWidth / decoded.width)
            .round();
        final resized = img.copyResize(
          decoded,
          width: targetWidth,
          height: targetHeight,
        );
        bytes.addAll(_encodeImage(resized, printerProfile));
        logoLoaded = true;
      }
    } catch (err) {
      log('EOD logo load failed: $err', name: 'PrinterService');
    }

    if (!logoLoaded) {
      bytes.addAll(
        generator.text(
          'SMALL TOWN LOTTERY',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
          ),
        ),
      );
    }

    bytes.addAll(
      generator.text(
        'END OF DAY REPORT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
    );
    bytes.addAll(generator.hr(ch: '-'));

    // Show only last 6 characters of teller ID for privacy/compactness
    final displayedTellerId = (report.tellerId ?? '').toString();
    final formattedTellerId = displayedTellerId.length > 6
        ? displayedTellerId.substring(displayedTellerId.length - 6)
        : displayedTellerId;

    // Force single-line label/value layout for header info rows
    infoRow('Location:', report.location, forceSingleLine: true);
    infoRow('Teller ID:', formattedTellerId, forceSingleLine: true);
    if (report.tellerName.isNotEmpty) {
      infoRow('Teller:', report.tellerName, forceSingleLine: true);
    }
    infoRow('Rpt Date:', reportDateLabel, forceSingleLine: true);
    infoRow('Printed:', printedAt, forceSingleLine: true);

    bytes.addAll(generator.hr(ch: '-'));
    infoRow('Gross:', currency(report.grossSales), numeric: true);
    infoRow('Comm:', currency(report.lessCommission), numeric: true);
    bytes.addAll(
      generator.row([
        PosColumn(text: '', width: 1),
        PosColumn(
          text: 'Hits:',
          width: 2,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: currency(report.hits),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: 'Net:',
          width: 2,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: currency(report.totalNet),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(text: '', width: 1),
      ]),
    );
    infoRow('Coll:', currency(report.forCollection), numeric: true);
    infoRow('T-Bets:', report.totalBets.toString(), numeric: true);

    // Prefer the per-(draw time, game) slots so the printed breakdown can be
    // grouped by draw time with a separator between groups; fall back to the
    // legacy flat breakdown when the backend hasn't sent slots yet.
    if (report.slots.isNotEmpty) {
      bytes.addAll(generator.hr(ch: '-'));
      bytes.addAll(
        generator.text(
          'GAME BREAKDOWN',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
      bytes.addAll(generator.hr(ch: '-'));

      String? currentSched;
      for (final slot in report.slots) {
        if (slot.sched != currentSched) {
          if (currentSched != null) {
            // Separator between groups so different draw times read distinct.
            bytes.addAll(generator.hr(ch: '-'));
          }
          currentSched = slot.sched;
          bytes.addAll(
            generator.text(
              _formatSchedForPrint(slot.sched),
              styles: const PosStyles(bold: true),
            ),
          );
          bytes.addAll(
            generator.row([
              PosColumn(
                text: 'Game',
                width: 1,
                styles: const PosStyles(bold: true),
              ),
              PosColumn(
                text: 'Bets',
                width: 1,
                styles: const PosStyles(bold: true, align: PosAlign.right),
              ),
              PosColumn(
                text: 'Gross',
                width: 3,
                styles: const PosStyles(bold: true, align: PosAlign.right),
              ),
              PosColumn(
                text: 'Hits',
                width: 4,
                styles: const PosStyles(bold: true, align: PosAlign.right),
              ),
              PosColumn(
                text: 'Net',
                width: 3,
                styles: const PosStyles(bold: true, align: PosAlign.right),
              ),
            ]),
          );
        }
        bytes.addAll(
          generator.row([
            PosColumn(
              text: _abbreviateGame(
                slot.gameName.isEmpty ? 'Game' : slot.gameName,
              ),
              width: 1,
            ),
            PosColumn(
              text: slot.lines.toString(),
              width: 1,
              styles: const PosStyles(align: PosAlign.right),
            ),
            PosColumn(
              text: currency(slot.gross),
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
            PosColumn(
              text: currency(slot.payout),
              width: 4,
              styles: const PosStyles(align: PosAlign.right),
            ),
            PosColumn(
              text: currency(slot.net),
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]),
        );
      }
      bytes.addAll(generator.hr(ch: '-'));
    } else if (report.breakdown.isNotEmpty) {
      bytes.addAll(generator.hr(ch: '-'));
      bytes.addAll(
        generator.text(
          'GAME BREAKDOWN',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        ),
      );
      bytes.addAll(generator.hr(ch: '-'));

      bytes.addAll(
        generator.row([
          PosColumn(text: 'Game', width: 1, styles: const PosStyles(bold: true)),
          PosColumn(text: 'Bets', width: 1, styles: const PosStyles(bold: true, align: PosAlign.right)),
          PosColumn(text: 'Gross', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
          PosColumn(text: 'Hits', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
          PosColumn(text: 'Net', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
        ]),
      );
      for (final item in report.breakdown) {
        final gameName = _abbreviateGame(
          item.gameName.isEmpty ? 'Game' : item.gameName,
        );
        bytes.addAll(
          generator.row([
            PosColumn(text: gameName, width: 1),
            PosColumn(text: item.betCount.toString(), width: 1, styles: const PosStyles(align: PosAlign.right)),
            PosColumn(text: currency(item.grossSales), width: 3, styles: const PosStyles(align: PosAlign.right)),
            PosColumn(text: currency(item.hits), width: 4, styles: const PosStyles(align: PosAlign.right)),
            PosColumn(text: currency(item.net), width: 3, styles: const PosStyles(align: PosAlign.right)),
          ]),
        );
      }
      bytes.addAll(generator.hr(ch: '-'));
    }

    bytes.addAll(_cutOrFeed(generator, printerProfile));
    return bytes;
  }

  /// Converts a Postgres TIME string ("14:00:00") to a compact schedule
  /// label the printed EOD groups by (e.g. "2:00 PM"). Empty input becomes
  /// "No Draw Time" so groups without a linked draw_time still print with a
  /// header.
  static String _formatSchedForPrint(String raw) {
    if (raw.isEmpty) return 'No Draw Time';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return raw;
    final period = h >= 12 ? 'PM' : 'AM';
    var h12 = h % 12;
    if (h12 == 0) h12 = 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  /// Renders a QR code directly from its module matrix — no Flutter rendering
  /// pipeline, no async, no silent failures.
  static img.Image? _buildQrImage(String data) {
    try {
      final qrCode = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final qrImage = QrImage(qrCode);
      final int dim = qrImage.moduleCount;

      const int moduleSize = 4; // pixels per QR module
      const int quietZone = 4; // blank modules around QR
      final int totalModules = dim + quietZone * 2;
      final int size = totalModules * moduleSize;

      final image = img.Image(width: size, height: size);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));

      for (int row = 0; row < dim; row++) {
        for (int col = 0; col < dim; col++) {
          if (qrImage.isDark(row, col)) {
            for (int py = 0; py < moduleSize; py++) {
              for (int px = 0; px < moduleSize; px++) {
                image.setPixel(
                  (col + quietZone) * moduleSize + px,
                  (row + quietZone) * moduleSize + py,
                  img.ColorRgb8(0, 0, 0),
                );
              }
            }
          }
        }
      }
      return image;
    } catch (err) {
      log('QR build failed: $err', name: 'PrinterService');
      return null;
    }
  }

  /// Converts raw draw_time strings to 12-hour format.
  /// Handles "HH:MM:SS", "HH:MM", and ISO "0000-01-01THH:MM:SSZ" formats.
  /// Returns the input unchanged if already in AM/PM format or unparseable.
  static String _formatDrawTimeLabel(String label) {
    if (label.isEmpty) return label;
    if (label.contains('AM') || label.contains('PM')) return label;
    try {
      String timeStr = label;
      if (label.contains('T')) {
        timeStr = label.split('T')[1].replaceAll('Z', '');
      }
      final parts = timeStr.substring(0, 5).split(':');
      if (parts.length < 2) return label;
      final h = int.parse(parts[0]);
      final m = parts[1];
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '${h12.toString().padLeft(2, '0')}:$m $period';
    } catch (_) {
      return label;
    }
  }

  static String _abbreviateGame(String name) {
    final abbr = name
        .replaceAll(RegExp(r'[Ll]otto'), '')
        .replaceAll(' ', '')
        .trim();
    // Column width 2 on 58mm = 4 chars. If abbr is longer, preserve trailing
    // digit (game variant) and truncate the text prefix to fit.
    if (abbr.length <= 4) return abbr;
    final trailingDigits = RegExp(r'\d+$').firstMatch(abbr)?.group(0) ?? '';
    final textPart = abbr.substring(0, abbr.length - trailingDigits.length);
    final maxText = (4 - trailingDigits.length).clamp(1, textPart.length);
    return textPart.substring(0, maxText) + trailingDigits;
  }

  static String _formatAmount(double amount) {
    final str = amount.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return buf.toString();
  }

  static List<int> _encodeImage(img.Image image, PrinterProfile profile) {
    return profile == PrinterProfile.escStar
        ? _imageToEscPosStar(image)
        : _imageToEscPosRaster(image);
  }

  // PT-210 has a small receive buffer — wait for it to drain before closing
  // the socket, otherwise bytes at the end of the stream (QR, feed) get dropped.
  static Future<void> _drainDelay(PrinterProfile profile) async {
    if (profile == PrinterProfile.escStar) {
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  // PT-210 has no cutter — feed paper so teller can tear cleanly.
  static List<int> _cutOrFeed(Generator generator, PrinterProfile profile) {
    if (profile == PrinterProfile.escStar) {
      return [0x1B, 0x64, 2]; // ESC d 2 — feed 2 lines (enough to tear)
    }
    return generator.cut();
  }

  /// ESC * 24-pin double-density — for Goojprt PT-210 / MTP-2 series.
  static List<int> _imageToEscPosStar(img.Image image) {
    final bytes = <int>[];
    final int width = image.width;
    final int height = image.height;

    bytes.addAll([0x1B, 0x61, 0x01]); // ESC a 1 — center
    bytes.addAll([0x1B, 0x33, 24]); // ESC 3 24 — set line spacing to 24 dots

    for (int y = 0; y < height; y += 24) {
      // ESC * 33 nL nH — 24-dot double density
      bytes.addAll([0x1B, 0x2A, 33, width & 0xFF, (width >> 8) & 0xFF]);

      for (int x = 0; x < width; x++) {
        for (int byteIdx = 0; byteIdx < 3; byteIdx++) {
          int b = 0;
          for (int bit = 0; bit < 8; bit++) {
            final int row = y + byteIdx * 8 + bit;
            if (row < height) {
              final p = image.getPixel(x, row);
              final alpha = p.a.toDouble();
              if (alpha > 30) {
                final lum =
                    0.299 * p.r.toDouble() +
                    0.587 * p.g.toDouble() +
                    0.114 * p.b.toDouble();
                if (lum < 127) b |= (0x80 >> bit);
              }
            }
          }
          bytes.add(b);
        }
      }

      bytes.add(0x0A); // LF — advance to next band
    }

    bytes.addAll([0x1B, 0x32]); // ESC 2 — restore default line spacing
    bytes.addAll([0x1B, 0x61, 0x00]); // ESC a 0 — restore left align

    return bytes;
  }

  /// Converts an [img.Image] to ESC/POS GS v 0 raster bytes, centered.
  /// Bypasses generator.imageRaster() which has a fixed-length list bug
  /// in esc_pos_utils_plus v2.0.4.
  static List<int> _imageToEscPosRaster(img.Image image) {
    final bytes = <int>[];

    final int width = image.width;
    final int height = image.height;
    final int bytesPerRow = (width + 7) ~/ 8;

    // ESC a 1 — center alignment
    bytes.addAll([0x1B, 0x61, 0x01]);

    // GS v 0 — raster image, normal density (m = 0)
    bytes.addAll([0x1D, 0x76, 0x30, 0x00]);
    bytes.addAll([bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF]); // xL xH
    bytes.addAll([height & 0xFF, (height >> 8) & 0xFF]); // yL yH

    for (int y = 0; y < height; y++) {
      for (int byteIdx = 0; byteIdx < bytesPerRow; byteIdx++) {
        int byte = 0;
        for (int bit = 0; bit < 8; bit++) {
          final int x = byteIdx * 8 + bit;
          if (x < width) {
            final p = image.getPixel(x, y);
            // Transparent pixels → white (don't print)
            final alpha = p.a.toDouble();
            if (alpha > 30) {
              // Luminance — dark pixels get printed
              final lum =
                  0.299 * p.r.toDouble() +
                  0.587 * p.g.toDouble() +
                  0.114 * p.b.toDouble();
              if (lum < 127) {
                byte |= (0x80 >> bit); // MSB first
              }
            }
          }
        }
        bytes.add(byte);
      }
    }

    // ESC a 0 — restore left alignment
    bytes.addAll([0x1B, 0x61, 0x00]);

    return bytes;
  }
}
