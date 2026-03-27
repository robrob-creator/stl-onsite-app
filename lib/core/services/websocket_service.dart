import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app_constants.dart';

/// Real-time WebSocket client.
///
/// Connect with [connect] after login. Disconnect with [disconnect] on logout.
/// Subscribe to typed events via [on].
class WebSocketService extends GetxController {
  WebSocket? _socket;
  Timer? _reconnectTimer;
  bool _intentionalDisconnect = false;

  // Minimum delay before first reconnect attempt; doubles each retry up to [_maxReconnectDelay].
  static const Duration _initialReconnectDelay = Duration(seconds: 3);
  static const Duration _maxReconnectDelay = Duration(minutes: 2);
  Duration _reconnectDelay = _initialReconnectDelay;

  // Observable connection state for UI bindings.
  final RxBool isConnected = false.obs;

  // Event listeners: eventType → list of callbacks.
  final Map<String, List<void Function(Map<String, dynamic> payload)>>
  _listeners = {};

  /// Derive the WebSocket base URL from the REST API base URL.
  static String get _wsBaseUrl {
    final rest = AppConstants.apiBaseUrl; // https://host/api
    return rest
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Open the WebSocket connection using [token] for authentication.
  Future<void> connect(String token) async {
    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();
    await _connect(token);
  }

  /// Close the connection permanently (e.g. on logout).
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    await _socket?.close();
    _socket = null;
    isConnected.value = false;
    print('✓ WebSocket disconnected');
  }

  /// Register a listener for a specific event type.
  ///
  /// Returns a function that removes the listener when called.
  VoidCallback on(
    String eventType,
    void Function(Map<String, dynamic> payload) callback,
  ) {
    _listeners.putIfAbsent(eventType, () => []).add(callback);
    return () => _listeners[eventType]?.remove(callback);
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  Future<void> _connect(String token) async {
    try {
      final uri = '$_wsBaseUrl/ws?token=$token';
      print('✓ WebSocket connecting: $uri');

      _socket = await WebSocket.connect(uri);
      // Send a WebSocket ping frame every 20 seconds so the Go server
      // keeps the connection alive and detects stale clients via pong timeout.
      _socket!.pingInterval = const Duration(seconds: 20);
      isConnected.value = true;
      _reconnectDelay = _initialReconnectDelay; // reset backoff on success
      print('✓ WebSocket connected');

      _socket!.listen(
        _onMessage,
        onError: _onError,
        onDone: () => _onDone(token),
        cancelOnError: false,
      );
    } catch (e) {
      print('✗ WebSocket connect error: $e');
      isConnected.value = false;
      _scheduleReconnect(token);
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final envelope = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = envelope['type'] as String?;
      final payload = (envelope['payload'] as Map<String, dynamic>?) ?? {};

      if (type == null) return;

      print('✓ WebSocket event: $type');
      final callbacks = _listeners[type];
      if (callbacks != null) {
        for (final cb in List.of(callbacks)) {
          cb(payload);
        }
      }
    } catch (e) {
      print('✗ WebSocket message parse error: $e');
    }
  }

  void _onError(dynamic error) {
    print('✗ WebSocket error: $error');
    isConnected.value = false;
  }

  void _onDone(String token) {
    isConnected.value = false;
    if (_intentionalDisconnect) return;
    print('⚠ WebSocket closed — scheduling reconnect');
    _scheduleReconnect(token);
  }

  void _scheduleReconnect(String token) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_intentionalDisconnect) return;
      // Exponential backoff, capped at max delay.
      _reconnectDelay = Duration(
        seconds: (_reconnectDelay.inSeconds * 2).clamp(
          _initialReconnectDelay.inSeconds,
          _maxReconnectDelay.inSeconds,
        ),
      );
      _connect(token);
    });
  }

  @override
  void onClose() {
    _reconnectTimer?.cancel();
    _socket?.close();
    super.onClose();
  }
}
