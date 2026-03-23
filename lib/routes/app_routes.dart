import 'package:get/get.dart';
import '../pages/splash_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/app/home_page.dart';
import '../pages/app/bet_entry_page.dart';
import '../pages/app/receipt_page.dart';
import '../pages/settings/printer_settings_page.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/home';
  static const String betEntry = '/bet-entry';
  static const String receipt = '/receipt';
  static const String printerSettings = '/printer-settings';

  static final pages = [
    GetPage(name: splash, page: () => const SplashPage()),
    GetPage(name: login, page: () => const LoginPage()),
    GetPage(name: home, page: () => const HomePage()),
    GetPage(name: betEntry, page: () => const BetEntryPage()),
    GetPage(name: receipt, page: () => const ReceiptPage()),
    GetPage(name: printerSettings, page: () => const PrinterSettingsPage()),
  ];
}
