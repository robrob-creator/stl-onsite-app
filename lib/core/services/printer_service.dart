import 'dart:developer';
import 'dart:io';
import 'dart:ui' as ui;
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
import '../../models/ticket.dart';

enum PrintError {
  noPrinterConfigured,
  permissionDenied,
  notConnected,
  outOfPaper,
  nearEndOfPaper,
  unknown,
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

  static final _storage = GetStorage();

  static String? get savedMac => _storage.read<String>(_macKey);
  static String? get savedName => _storage.read<String>(_nameKey);

  static void savePrinter(String mac, String name) {
    _storage.write(_macKey, mac);
    _storage.write(_nameKey, name);
  }

  static void clearPrinter() {
    _storage.remove(_macKey);
    _storage.remove(_nameKey);
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
      final connected = await _connectWithRetry(
        mac,
        retries: 2,
        delay: const Duration(milliseconds: 800),
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
  }) async {
    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
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
      await Future.delayed(const Duration(milliseconds: 800));

      final connected = await _connectWithRetry(mac);
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
      );

      final result = await PrintBluetoothThermal.writeBytes(bytes);
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
    final teller = {'id': user?.id ?? '', 'name': user?.name ?? ''};

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
    );
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
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
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
    final dateStr =
        '${monthAbbr[now.month - 1]} ${now.day.toString().padLeft(2, '0')}, ${now.year}';
    final hour = now.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final timeStr =
        '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} $period';

    // Teller fields from response
    final _tellerIdRaw =
        (teller['id'] ?? teller['teller_id'] ?? teller['code'] ?? '')
            .toString();
    final tellerId = _tellerIdRaw.length > 7
        ? _tellerIdRaw.substring(_tellerIdRaw.length - 7)
        : _tellerIdRaw;
    final location =
        (teller['location'] ??
                teller['area_name'] ??
                teller['area'] ??
                teller['cluster_name'] ??
                '')
            .toString();

    // ── Header ────────────────────────────────────────────────────
    bytes.addAll(generator.feed(1));
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

        // Build ESC/POS raster bytes manually — bypasses the
        // fixed-length list bug in generator.imageRaster().
        bytes.addAll(_imageToEscPosRaster(resized));
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
    bytes.addAll(generator.feed(1));
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

    // ── Info rows (label | value) ─────────────────────────────────
    // 1(pad) + 4(label) + 6(value) + 1(pad) = 12
    void infoRow(String label, String value) {
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

    infoRow('Draw Date:', dateStr);
    infoRow('Draw Time:', drawTimeLabel);
    infoRow(
      'Ticket No:',
      ticketNo.length > 10
          ? ticketNo.substring(ticketNo.length - 10)
          : ticketNo,
    );
    infoRow('Teller ID:', tellerId);
    if (location.isNotEmpty) infoRow('Location:', location);

    bytes.addAll(generator.hr(ch: '-'));

    // ── Bet table ─────────────────────────────────────────────────
    // 1(pad) + 2(game) + 3(entry) + 3(type) + 2(amnt) + 1(pad) = 12
    bytes.addAll(
      generator.row([
        PosColumn(text: '', width: 1),
        PosColumn(text: 'Game', width: 2, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Entry', width: 3, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Type', width: 3, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'Amnt',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(text: '', width: 1),
      ]),
    );
    bytes.addAll(generator.hr(ch: '-'));

    for (final entry in betEntries) {
      final formatted = entry.digits.isNotEmpty ? entry.digits.join('-') : '-';
      bytes.addAll(
        generator.row([
          PosColumn(text: '', width: 1),
          PosColumn(
            text: entry.game.isNotEmpty ? entry.game : gameName,
            width: 2,
          ),
          PosColumn(text: formatted, width: 3),
          PosColumn(text: entry.betType, width: 3),
          PosColumn(
            text: entry.betAmount.toStringAsFixed(0),
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(text: '', width: 1),
        ]),
      );
    }

    bytes.addAll(generator.hr(ch: '-'));

    // TOTAL row — 1+2+6+2+1 = 12
    bytes.addAll(
      generator.row([
        PosColumn(text: '', width: 1),
        PosColumn(text: 'TOTAL', width: 3, styles: const PosStyles(bold: true)),
        PosColumn(text: '', width: 5),
        PosColumn(
          text: totalAmount.toStringAsFixed(0),
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(text: '', width: 1),
      ]),
    );

    bytes.addAll(generator.hr(ch: '-'));

    // ── Footer info ───────────────────────────────────────────────
    infoRow('Tnx Count:', '${betEntries.length}');
    infoRow('Total Amt:', totalAmount.toStringAsFixed(0));
    infoRow('Date:', dateStr);
    infoRow('Time:', timeStr);

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
    bytes.addAll(generator.feed(1));
    final qrImage = await _buildQrRasterImage(ticketNo);
    if (qrImage != null) {
      final resizedQr = img.copyResize(
        qrImage,
        width: 180,
        height: 180,
        interpolation: img.Interpolation.nearest,
      );
      bytes.addAll(_imageToEscPosRaster(resizedQr));
    } else {
      bytes.addAll([0x1B, 0x61, 0x01]);
      bytes.addAll(
        generator.qrcode(
          ticketNo,
          align: PosAlign.center,
          size: QRSize.size4,
          cor: QRCorrection.M,
        ),
      );
      bytes.addAll([0x1B, 0x61, 0x00]);
    }
    bytes.addAll(generator.feed(3));
    bytes.addAll(generator.cut());

    return bytes;
  }

  static Future<img.Image?> _buildQrRasterImage(String data) async {
    try {
      final qrCode = QrCode.fromData(
        data: data,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final qrImage = QrImage(qrCode);
      final byteData = await qrImage.toImageAsBytes(
        size: 240,
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        return null;
      }
      return img.decodeImage(byteData.buffer.asUint8List());
    } catch (err) {
      log('QR raster build failed: $err', name: 'PrinterService');
      return null;
    }
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
