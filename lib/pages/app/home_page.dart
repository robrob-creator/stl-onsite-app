import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:onstite/core/design_system.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../core/main_layout.dart';
import '../../../controllers/lottery_controller.dart';
import '../../../core/services/printer_service.dart';
import '../../../controllers/live_draw_controller.dart';
import 'bet_entry_page.dart';
import 'transaction_page.dart';
import 'dashboard_page.dart';
import 'ticket_page.dart';
import 'claim_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 1; // Default to Bet tab

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<LotteryController>()) {
      Get.put(LotteryController());
    }
    if (!Get.isRegistered<LiveDrawController>()) {
      Get.put(LiveDrawController());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPrinter());
  }

  Future<void> _checkPrinter() async {
    // Verify Bluetooth service is enabled before printer checks
    try {
      final btEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!btEnabled) {
        Get.snackbar(
          'Bluetooth Required',
          'Bluetooth must be enabled for printer connectivity and ticket printing. Please enable Bluetooth.',
          icon: const Icon(Icons.bluetooth_disabled, color: Colors.white),
          backgroundColor: const Color(0xFFE53E3E),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
          borderRadius: 12,
          margin: const EdgeInsets.all(16),
        );
        return;
      }
    } catch (_) {}

    final mac = PrinterService.savedMac;

    if (mac == null) {
      // No printer configured — prompt setup
      _showNoPrinterDialog();
      return;
    }

    final reachability = await PrinterService.getSavedPrinterReachability();
    if (reachability == PrinterReachabilityStatus.permissionDenied) {
      Get.snackbar(
        'Bluetooth Permission Required',
        'Allow Nearby devices permission so the app can check and use your printer.',
        icon: const Icon(Icons.bluetooth_searching, color: Colors.white),
        backgroundColor: const Color(0xFFE53E3E),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
        mainButton: TextButton(
          onPressed: () {
            Get.closeCurrentSnackbar();
            openAppSettings();
          },
          child: const Text(
            'Open Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    if (reachability == PrinterReachabilityStatus.unreachable) {
      _showPrinterUnreachableDialog(mac);
    }
  }

  void _showPrinterUnreachableDialog(String mac) {
    final name = PrinterService.savedName ?? mac;
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bluetooth_disabled,
                  color: Color(0xFFE53E3E),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Printer Not Detected',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Could not connect to "$name". Make sure the printer is on and in range, then reconnect.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Color(0xFF3D5A99),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Later',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3D5A99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.toNamed('/printer-settings');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D5A99),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Connect',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _showNoPrinterDialog() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.print_outlined,
                  color: Color(0xFFF59E0B),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Printer Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'No printer is configured. Please connect to a Bluetooth printer before placing bets.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Color(0xFF3D5A99),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Later',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3D5A99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.toNamed('/printer-settings');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D5A99),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Set Up',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  String _formatAmount(double value) {
    final isNeg = value < 0;
    final str = value.abs().toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return '${isNeg ? '₱ -' : '₱ '}${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      onMenuPressed: () {},
      title: _currentIndex == 0 ? 'Dashboard' : null,
      appBarTrailing: Obx(() {
        final balance = Get.find<LotteryController>().balance.value;
        final isNegative = balance < 0;
        final accent = isNegative ? const Color(0xFFDC2626) : AppColors.primary;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/icons/moneys.png',
                width: 16,
                height: 16,
                color: accent,
              ),
              const SizedBox(width: 8),
              Text(
                _formatAmount(balance),
                style: TextStyle(
                  color: accent.withOpacity(0.9),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }),
      body: _buildBody(),
      onBottomNavTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },

      bottomNavItems: [
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/logos/home.png',
            width: 24,
            height: 24,
            color: _currentIndex == 0 ? AppColors.primary : Colors.grey,
          ),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/icons/reciept1.png',
            width: 24,
            height: 24,
            color: _currentIndex == 1 ? AppColors.primary : null,
          ),
          label: 'Bet',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/icons/clock1.png',
            width: 24,
            height: 24,
            color: _currentIndex == 2 ? AppColors.primary : null,
          ),
          label: 'Transaction',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/icons/ticket1.png',
            color: _currentIndex == 3 ? AppColors.primary : null,
            width: 24,
            height: 24,
          ),
          label: 'Ticket',
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            'assets/images/icons/star1.png',
            width: 24,
            height: 24,
            color: _currentIndex == 4 ? AppColors.primary : null,
          ),

          label: 'Claim',
        ),
      ],
      currentIndex: _currentIndex,
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return const DashboardPage();
      case 1:
        return const BetEntryPage();
      case 2:
        return const TransactionPage();
      case 3:
        return const TicketPage();
      case 4:
        return const ClaimPage();
      default:
        return const BetEntryPage();
    }
  }
}
