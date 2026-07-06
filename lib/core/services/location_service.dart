import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../app_constants.dart';

class LocationService {
  /// Gets current device position. Returns null if GPS unavailable or denied.
  static Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetches device coordinates then PATCHes /auth/location.
  /// Silently fails — location update is best-effort.
  static Future<void> updateUserLocation() async {
    try {
      final position = await getCurrentPosition();
      if (position == null) return;

      final token = Get.find<AuthController>().token.value;
      if (token.isEmpty) return;

      await http
          .patch(
            Uri.parse('${AppConstants.apiBaseUrl}/auth/location'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'latitude': position.latitude,
              'longitude': position.longitude,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort — never block betting flow
    }
  }
}
