import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../controllers/auth_controller.dart';
import '../app_constants.dart';

class NotificationService {
  static const String _oneSignalAppId = '1dac9f08-f605-43b7-b3f1-cf753c4446f7';

  /// Call once at app startup, before login.
  static Future<void> initialize() async {
    OneSignal.initialize(_oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);
  }

  /// Call after successful login/session restore to register this device.
  static Future<void> registerDevice() async {
    try {
      final playerId = await _getPlayerId();
      if (playerId == null || playerId.isEmpty) return;
      await _sendPlayerIdToBackend(playerId);
    } catch (e) {
      debugPrint('NotificationService.registerDevice error: $e');
    }
  }

  static Future<String?> _getPlayerId() async {
    try {
      final state = await OneSignal.User.getOnesignalId();
      return state;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _sendPlayerIdToBackend(String playerId) async {
    final authCtrl = Get.find<AuthController>();
    final token = authCtrl.token.value;
    if (token.isEmpty) return;

    await http.put(
      Uri.parse('${AppConstants.apiBaseUrl}/users/onesignal-player-id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'player_id': playerId}),
    ).timeout(const Duration(seconds: 10));
  }
}
