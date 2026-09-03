import 'package:get_storage/get_storage.dart';

class AppConstants {
  AppConstants._();

  static const String _storageKey = 'selected_env_url';

  static const String envStaging = 'https://staging.4play.com.co/api';
  static const String envProduction = 'https://api.4play.com.co/api';

  static String get apiBaseUrl {
    final stored = GetStorage().read<String>(_storageKey);
    return stored ?? envProduction;
  }

  static void setEnvironment(String url) {
    GetStorage().write(_storageKey, url);
  }

  static String get apiPing => '$apiBaseUrl/ping';
}
