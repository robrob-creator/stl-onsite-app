import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const String apiBaseUrl = kDebugMode
      ? 'http://127.0.0.1:8080/api'
      : 'https://stl-backend-mws9.onrender.com/api';
}
