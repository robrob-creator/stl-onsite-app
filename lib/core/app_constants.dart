import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const String apiBaseUrl = kDebugMode
      ? 'http://127.0.0.1:8080/api'
      : 'https://stl-backend-mws9.onrender.com/api';

  // A lightweight client-facing ping URL (GET) that returns 200 when the
  // backend is reachable. Clients should use this for quick reachability checks
  // instead of probing the base URL which can return 404 for some setups.
  static const String apiPing = '$apiBaseUrl/ping';
}
