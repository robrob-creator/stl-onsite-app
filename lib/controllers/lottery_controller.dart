import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'auth_controller.dart';
import '../core/app_constants.dart';
import '../models/game.dart';
import '../core/utils/manila_time.dart';
import '../models/bet_availability.dart';
import '../models/permutation_availability.dart';
import '../core/services/game_service.dart';
import '../core/services/printer_service.dart';
import '../core/services/profile_service.dart';
import '../core/services/websocket_service.dart';
import '../core/services/sold_out_service.dart';
import '../core/services/draw_results_service.dart';
import '../core/services/ticket_service.dart';

class BetEntry {
  final int betNumber;
  final String game;
  final double straightBetAmount;
  final double rambleBetAmount;
  final double winAmount;
  final List<String> digits;
  final int combinations; // Store calculated combinations

  BetEntry({
    required this.betNumber,
    required this.game,
    required this.straightBetAmount,
    required this.rambleBetAmount,
    required this.winAmount,
    required this.digits,
    this.combinations = 1,
  });

  double get totalBetAmount => straightBetAmount + rambleBetAmount;

  /// 'Target' when this is a straight entry, 'Rambol' when it's a ramble entry.
  String get betType => straightBetAmount > 0 ? 'Target' : 'Rambol';

  /// The non-zero bet amount for this entry.
  double get betAmount =>
      straightBetAmount > 0 ? straightBetAmount : rambleBetAmount;
}

class DraftBet {
  final String id;
  final String gameName;
  final List<String> digits;
  final double straightBetAmount;
  final double rambleBetAmount;
  final double totalBetAmount;
  final double estPayout;
  final int combinations;

  DraftBet({
    required this.id,
    required this.gameName,
    required this.digits,
    required this.straightBetAmount,
    required this.rambleBetAmount,
    required this.totalBetAmount,
    required this.estPayout,
    required this.combinations,
  });

  String get betType {
    if (straightBetAmount > 0 && rambleBetAmount > 0) return 'Both';
    return straightBetAmount > 0 ? 'Target' : 'Rambol';
  }
}

class LotteryController extends GetxController {
  // Games from API
  final RxList<Game> availableGames = <Game>[].obs;
  final RxString selectedGameId = ''.obs;

  // Bet selection
  final RxString selectedTime = ''.obs;
  final RxString selectedBetType = 'Target'.obs;
  final RxList<String> selectedNumbers = <String>[].obs;
  final RxInt targetAmount = 0.obs;
  final RxInt rambolAmount = 0.obs;

  // Draft bets (API-backed, status=draft)
  final RxList<DraftBet> draftBets = <DraftBet>[].obs;
  final RxDouble balance = 0.0.obs;
  final RxBool isLoading = false.obs;
  // Increment this tick whenever bets are placed/changed so UI pages (Dashboard)
  // can react and refresh cached draw summaries.
  final RxInt drawRefreshTick = 0.obs;

  // Permutation availability from server (preview endpoint)
  final Rx<PermutationAvailability?> permAvailability =
      Rx<PermutationAvailability?>(null);

  @override
  void onInit() {
    super.onInit();
    loadGames();
    loadProfile();
    _subscribeToWebSocketEvents();
  }

  void _subscribeToWebSocketEvents() {
    try {
      final ws = Get.find<WebSocketService>();
      ws.on('bet.placed', (_) => loadProfile());
      ws.on('bet.bulk_placed', (_) => loadProfile());
      ws.on('claim.paid', (_) => loadProfile());
    } catch (_) {
      // WebSocketService not yet available — will connect after auth
    }
  }

  /// Fetch games from the API
  Future<void> loadGames() async {
    try {
      isLoading.value = true;
      final games = await GameService.fetchGames();
      availableGames.value = games;

      // Set the first game as selected by default
      if (games.isNotEmpty) {
        selectedGameId.value = games[0].id;
        selectedTime.value = getFirstAvailableDrawTimeId(games[0]);
      }
      update();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load games: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetch user profile and update balance
  Future<void> loadProfile() async {
    try {
      final user = await ProfileService.fetchProfile();
      balance.value = user.balance;
      Get.find<AuthController>().syncCurrentUser(user);
      update();
    } catch (e) {
      // Silently fail - keep existing balance if profile fetch fails
      debugPrint('Failed to load profile: $e');
    }
  }

  /// Get the currently selected game object
  Game? get currentGame {
    try {
      return availableGames.firstWhere(
        (game) => game.id == selectedGameId.value,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get the list of draw times for the currently selected game
  List<DrawTime> get currentDrawTimes {
    final drawTimes = List<DrawTime>.from(currentGame?.drawTimes ?? const []);
    drawTimes.sort(DrawTime.compareChronologically);
    return drawTimes;
  }

  String getFirstAvailableDrawTimeId(Game game) {
    final drawTimes = List<DrawTime>.from(game.drawTimes)
      ..sort(DrawTime.compareChronologically);
    return drawTimes.where((dt) => dt.isAvailable()).firstOrNull?.id ?? '';
  }

  /// Calculate the number of unique permutations for the given digits
  /// Examples:
  /// [1, 2, 3] -> 3! = 6 (all different)
  /// [2, 2, 3] -> 3!/2! = 3 (one pair)
  /// [1, 2] -> 2! = 2 (both different for 2D)
  /// [2, 2] -> 2!/2! = 1 (both same for 2D)
  int calculateCombinations(List<String> digits) {
    if (digits.isEmpty) return 1;

    // Calculate factorial
    int factorial(int n) {
      if (n <= 1) return 1;
      int result = 1;
      for (int i = 2; i <= n; i++) {
        result *= i;
      }
      return result;
    }

    // Get frequency of each digit
    final frequencyMap = <String, int>{};
    for (final digit in digits) {
      frequencyMap[digit] = (frequencyMap[digit] ?? 0) + 1;
    }

    // Calculate n! / (n1! * n2! * ... * nk!)
    int numerator = factorial(digits.length);
    int denominator = 1;

    for (final frequency in frequencyMap.values) {
      denominator *= factorial(frequency);
    }

    return numerator ~/ denominator;
  }

  void toggleNumber(String number) {
    if (selectedNumbers.contains(number)) {
      selectedNumbers.remove(number);
    } else {
      // Get the limit from the current game
      final game = currentGame;
      int limit = 2; // Default for 2D
      if (game != null) {
        // Calculate number of digits needed based on max number
        if (game.maxNumber >= 1000) {
          limit = 3; // 3D
        } else if (game.maxNumber >= 100) {
          limit = 2; // 2D
        }
      }

      if (selectedNumbers.length < limit) {
        selectedNumbers.add(number);
      }
    }
    update();
  }

  void clearNumbers() {
    selectedNumbers.clear();
    update();
  }

  /// Sends the current bet inputs to `POST /bets/draft-bulk` and appends
  /// the returned draft to [draftBets]. Returns `true` on success.
  Future<bool> addBet() async {
    // Verify internet connectivity before attempting to add a bet
    if (!await _hasInternetConnection()) {
      // Run a quick diagnostic to capture connectivity and server reachability
      final diag = await _diagnoseConnectivity();
      // Log diagnostic to developer console for debugging
      try {
        developer.log('Connectivity diagnostic: $diag', name: 'LotteryController');
      } catch (_) {}
      debugPrint('LotteryController: Connectivity diagnostic: $diag');

      Get.snackbar(
        'No internet connection',
        'Please check your network connection and try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    // Ensure location/GPS permission is granted for compliance
    if (!await _ensureLocationEnabled()) {
      Get.snackbar(
        'Location Required',
        'Location/GPS is required to place bets. Please enable location services and grant permission.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (selectedNumbers.isEmpty) {
      Get.snackbar('Error', 'Please select numbers');
      return false;
    }

    final double straightAmount = targetAmount.value.toDouble();
    final double rambleAmount = rambolAmount.value.toDouble();

    if (straightAmount == 0 && rambleAmount == 0) {
      Get.snackbar('Error', 'Please enter at least one bet amount');
      return false;
    }

    final game = currentGame;
    if (game == null) {
      Get.snackbar('Error', 'Please select a game');
      return false;
    }

    isLoading.value = true;
    update();

    try {
      final token = Get.find<AuthController>().token.value;
      final drawId = selectedTime.value;
      final clusterId = game.clusters.isNotEmpty ? game.clusters[0].id : '';
      final combinations = calculateCombinations(selectedNumbers);
      final digits = List<String>.from(selectedNumbers);

      // Build separate items for each enabled bet type so the server stores
      // them as independent draft records (one per type).
      final List<Map<String, dynamic>> betItems = [];

      if (straightAmount > 0) {
        final estPayout = straightAmount * game.straightMultiplier;
        betItems.add({
          'draw_id': drawId,
          'game_id': game.id,
          'total_bet_amount': straightAmount,
          'digits': digits,
          'cluster_id': clusterId,
          'straight_bet_amount': straightAmount,
          'ramble_bet_amount': 0,
          'est_payout': estPayout,
        });
      }

      if (rambleAmount > 0) {
        final estPayout =
            (rambleAmount / combinations) * (game.rambleMultiplier ?? 0);
        betItems.add({
          'draw_id': drawId,
          'game_id': game.id,
          'total_bet_amount': rambleAmount,
          'digits': digits,
          'cluster_id': clusterId,
          'straight_bet_amount': 0,
          'ramble_bet_amount': rambleAmount,
          'est_payout': estPayout,
        });
      }

      final response = await http
          .post(
            Uri.parse('${AppConstants.apiBaseUrl}/bets/draft-bulk'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'bets': betItems}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 && response.statusCode != 201) {
        _handleBetError(response, 0);
        return false;
      }

      // Response shape: { "message": "...", "data": [ {...}, ... ] }
      // `data` is a flat List of the created bet objects.
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final betsJson = (responseData['data'] as List?) ?? [];

      if (betsJson.isEmpty) {
        // Fallback: build placeholder drafts from local intent so the user
        // can still see and submit what they added.
        if (straightAmount > 0) {
          draftBets.add(
            DraftBet(
              id: '',
              gameName: game.name,
              digits: digits,
              straightBetAmount: straightAmount,
              rambleBetAmount: 0,
              totalBetAmount: straightAmount,
              estPayout: straightAmount * game.straightMultiplier,
              combinations: combinations,
            ),
          );
        }
        if (rambleAmount > 0) {
          draftBets.add(
            DraftBet(
              id: '',
              gameName: game.name,
              digits: digits,
              straightBetAmount: 0,
              rambleBetAmount: rambleAmount,
              totalBetAmount: rambleAmount,
              estPayout:
                  (rambleAmount / combinations) * (game.rambleMultiplier ?? 0),
              combinations: combinations,
            ),
          );
        }
      } else {
        // Map each returned bet to a DraftBet.
        // The server sends back one record per item we submitted so the
        // count should match betItems.length, but we iterate what we get.
        for (final betJson in betsJson) {
          final serverStraight = (betJson['straight_bet_amount'] as num? ?? 0)
              .toDouble();
          final serverRamble = (betJson['ramble_bet_amount'] as num? ?? 0)
              .toDouble();
          final serverTotal = (betJson['total_bet_amount'] as num? ?? 0)
              .toDouble();
          final serverEstPayout = (betJson['est_payout'] as num? ?? 0)
              .toDouble();

          // Parse digits from the server response (may be a JSON list or
          // PostgreSQL-array literal like "{25,17}").
          List<String> serverDigits = digits; // default to what we sent
          final rawDigits = betJson['digits'];
          if (rawDigits is List) {
            serverDigits = List<String>.from(rawDigits);
          } else if (rawDigits is String) {
            serverDigits = rawDigits
                .replaceAll('{', '')
                .replaceAll('}', '')
                .split(',')
                .map((d) => d.trim())
                .toList();
          }

          draftBets.add(
            DraftBet(
              id: betJson['id'] as String? ?? '',
              gameName: game.name,
              digits: serverDigits,
              straightBetAmount: serverStraight,
              rambleBetAmount: serverRamble,
              totalBetAmount: serverTotal,
              estPayout: serverEstPayout,
              combinations: combinations,
            ),
          );
        }
      }

      clearNumbers();
      targetAmount.value = 0;
      rambolAmount.value = 0;
      await loadProfile();

      // Try to force-refresh draw summaries on the server so Dashboard shows
      // updated gross/totalBet values as soon as possible.
      try {
        final gameId = game.id;
        final drawDate = ManilaTime.dateString();
        await DrawResultsService.getLatestResultsByGameAndDate(
          gameId: gameId,
          drawDate: drawDate,
        );
      } catch (_) {}

      // Notify interested UI (Dashboard) to refresh draw summaries/gross totals
      try {
        drawRefreshTick.value = drawRefreshTick.value + 1;
      } catch (_) {}
      update();
      return true;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to add bet: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      isLoading.value = false;
      update();
    }
  }

  Future<void> removeBet(int index) async {
    final draft = draftBets[index];

    // If no server ID yet (fallback placeholder), just remove locally.
    if (draft.id.isEmpty) {
      draftBets.removeAt(index);
      update();
      return;
    }

    try {
      final token = Get.find<AuthController>().token.value;
      final response = await http
          .delete(
            Uri.parse('${AppConstants.apiBaseUrl}/bets/delete?id=${draft.id}'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 404) {
        // 404 means already gone — treat as success
        draftBets.removeAt(index);
        update();
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
        final message =
            body['message'] as String? ??
            'Failed to delete bet (${response.statusCode})';
        Get.snackbar('Error', message, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete bet: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Calls POST /bet/token/permutations and stores result in [permAvailability].
  /// Pass [cartBets] to factor in existing draft bets.
  Future<void> fetchPermutations(
    List<String> digits, {
    List<Map<String, dynamic>> cartBets = const [],
  }) async {
    final game = currentGame;
    if (game == null) return;
    final drawTimeId = selectedTime.value;
    final drawDate = ManilaTime.dateString();
    try {
      final result = await SoldOutService.checkPermutations(
        gameId: game.id,
        drawId: drawTimeId,
        drawTimeId: drawTimeId,
        drawDate: drawDate,
        tokens: digits,
        cartBets: cartBets,
      );
      permAvailability.value = result;
    } catch (_) {
      permAvailability.value = null;
    }
  }

  /// Checks availability via POST /bet/token/permutations (with cart_bets).
  /// Returns null when open. Returns BetAvailabilityResult when a conflict exists.
  Future<BetAvailabilityResult?> checkBetAvailability({
    required List<String> digits,
    required double targetAmount,
    required double rambolAmount,
  }) async {
    final game = currentGame;
    if (game == null) return null;

    final drawTimeId = selectedTime.value;
    final drawDate = ManilaTime.dateString();

    final cartBets = <Map<String, dynamic>>[];
    for (final d in draftBets) {
      if (d.straightBetAmount > 0) {
        cartBets.add({
          'digits': d.digits,
          'amount': d.straightBetAmount.toInt(),
          'bet_type': 'straight',
        });
      }
      if (d.rambleBetAmount > 0) {
        cartBets.add({
          'digits': d.digits,
          'amount': d.rambleBetAmount.toInt(),
          'bet_type': 'rambol',
        });
      }
    }

    try {
      final result = await SoldOutService.checkPermutations(
        gameId: game.id,
        drawId: drawTimeId,
        drawTimeId: drawTimeId,
        drawDate: drawDate,
        tokens: digits,
        cartBets: cartBets,
      );
      permAvailability.value = result;
      return buildBetAvailabilityResult(
        gameId: game.id,
        digits: digits,
        drawTimeId: drawTimeId,
        drawDate: drawDate,
        targetAmount: targetAmount,
        rambolAmount: rambolAmount,
        perm: result,
      );
    } catch (_) {
      return null; // fail open
    }
  }

  /// Check internet connectivity with fallbacks.
  ///
  /// Prefer using connectivity_plus, but if that check throws we fall back to
  /// a quick API GET (treat HTTP 2xx-4xx as reachable) and finally a DNS
  /// lookup. This accounts for devices where the connectivity plugin may
  /// throw (some Android devices or permission issues) while the network is
  /// still functional.
  Future<bool> _hasInternetConnection() async {
    // 1) Basic interface check
    try {
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult != ConnectivityResult.none) return true;
      } on MissingPluginException catch (e) {
        // Plugin not available on this platform (e.g., unit tests or unsupported)
        debugPrint('LotteryController: connectivity plugin missing: $e');
      } catch (e) {
        // Other connectivity errors - log and continue to active checks
        try {
          developer.log('Connectivity check failed: $e', name: 'LotteryController');
        } catch (_) {}
        debugPrint('LotteryController: Connectivity check failed: $e');
      }

      // 2) Quick reachability check against API ping endpoint (longer timeout)
      try {
        var uri = Uri.parse(AppConstants.apiPing);
        if ((uri.host == '127.0.0.1' || uri.host == 'localhost') && Platform.isAndroid) {
          uri = uri.replace(host: '10.0.2.2');
        }
        final resp = await http.get(uri).timeout(const Duration(seconds: 5));
        if (resp.statusCode >= 200 && resp.statusCode < 500) return true;
      } on TimeoutException catch (e) {
        // Ping timed out — try health endpoint as a slightly heavier fallback
        debugPrint('LotteryController: ping timeout, trying health endpoint: $e');
        try {
          var uri = Uri.parse('${AppConstants.apiBaseUrl}/health');
          if ((uri.host == '127.0.0.1' || uri.host == 'localhost') && Platform.isAndroid) {
            uri = uri.replace(host: '10.0.2.2');
          }
          final resp = await http.get(uri).timeout(const Duration(seconds: 3));
          if (resp.statusCode >= 200 && resp.statusCode < 500) return true;
        } catch (e) {
          try {
            developer.log('Health endpoint reachability check failed: $e', name: 'LotteryController');
          } catch (_) {}
          debugPrint('LotteryController: Health endpoint reachability check failed: $e');
        }
      } catch (e) {
        try {
          developer.log('API reachability check failed: $e', name: 'LotteryController');
        } catch (_) {}
        debugPrint('LotteryController: API reachability check failed: $e');
      }

      // 3) DNS lookup fallback
      try {
        final lookup = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 3));
        return lookup.isNotEmpty;
      } catch (e) {
        try {
          developer.log('DNS lookup failed: $e', name: 'LotteryController');
        } catch (_) {}
        debugPrint('LotteryController: DNS lookup failed: $e');
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Ensure location permission is granted (used for compliance/location checks).
  Future<bool> _ensureLocationEnabled() async {
    try {
      final status = await Permission.locationWhenInUse.status;
      // If already granted, we're good.
      if (status.isGranted) return true;

      // Ask the system permission prompt first.
      final req = await Permission.locationWhenInUse.request();
      if (req.isGranted) return true;

      // If permission is permanently denied or still denied, show an in-app
      // dialog explaining why location is needed with a button to open app
      // settings. Also show a snackbar as a lightweight notification.
      await _showLocationPrompt();
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Diagnostic helper that returns a short string describing connectivity
  /// state, API reachability, and DNS lookup result. Intended for debugging
  /// emulator/device connectivity issues.
  Future<String> _diagnoseConnectivity() async {
    final parts = <String>[];
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      parts.add('iface=${connectivityResult.toString().split('.').last}');
    } catch (e) {
      parts.add('iface=err');
    }

    // Quick GET to API ping endpoint (longer timeout) with health fallback
    try {
      var uri = Uri.parse(AppConstants.apiPing);
      if ((uri.host == '127.0.0.1' || uri.host == 'localhost') && Platform.isAndroid) {
        uri = uri.replace(host: '10.0.2.2');
      }
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      parts.add('api_status=${resp.statusCode}');
    } on TimeoutException catch (e) {
      parts.add('api_err=ping_timeout');
      // Try health endpoint as fallback
      try {
        var uri = Uri.parse('${AppConstants.apiBaseUrl}/health');
        if ((uri.host == '127.0.0.1' || uri.host == 'localhost') && Platform.isAndroid) {
          uri = uri.replace(host: '10.0.2.2');
        }
        final resp = await http.get(uri).timeout(const Duration(seconds: 3));
        parts.add('api_health=${resp.statusCode}');
      } catch (e) {
        parts.add('api_health_err=${e.runtimeType}');
      }
    } catch (e) {
      parts.add('api_err=${e.runtimeType}');
    }

    // DNS lookup
    try {
      final lookup = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 3));
      parts.add('dns=${lookup.isNotEmpty ? 'ok' : 'empty'}');
    } catch (e) {
      parts.add('dns_err=${e.runtimeType}');
    }

    return parts.join('; ');
  }

  Future<void> _showLocationPrompt() async {
    // Lightweight notification (snackbar)
    try {
      Get.snackbar(
        'Location Required',
        'Location access is required to place bets. Please enable Location in Settings.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 6),
      );
    } catch (_) {}

    // Show modal dialog with Open Settings action
    try {
      await Get.dialog(
        Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location Permission',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This app requires location access to comply with regulatory checks when placing bets. Please enable Location permission in your device settings.',
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Get.back();
                        },
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          openAppSettings();
                        },
                        child: const Text('Open Settings'),
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
    } catch (_) {}
  }

  Future<void> submitBets() async {
    // Verify internet connectivity before submitting bets
    if (!await _hasInternetConnection()) {
      Get.snackbar(
        'No internet connection',
        'No internet connection. Please check your network connection and try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Ensure location/GPS permission is granted before submitting
    if (!await _ensureLocationEnabled()) {
      Get.snackbar(
        'Location Required',
        'Location/GPS is required to submit bets. Please enable location services and grant permission.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (draftBets.isEmpty) {
      Get.snackbar('Error', 'Please add at least one bet');
      return;
    }

    isLoading.value = true;
    update();

    try {
      final authController = Get.find<AuthController>();

      if (!authController.isLoggedIn) {
        Get.snackbar('Error', 'Please log in first');
        return;
      }

      final game = currentGame;
      if (game == null) {
        Get.snackbar('Error', 'Please select a game');
        return;
      }

      final drawId = selectedTime.value;
      final token = authController.token.value;

      final clusterId = game.clusters.isNotEmpty ? game.clusters[0].id : '';
      final clusterCode = game.clusters.isNotEmpty
          ? game.clusters[0].id.substring(0, 3).toUpperCase()
          : 'UNK';

      final now = ManilaTime.now();
      final uniqueTimestamp =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';
      final batchTicketNo =
          'TKT-$clusterCode-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-$uniqueTimestamp';

      // Collect unique draft bet IDs (exclude empty-id fallback entries)
      final betIds = draftBets
          .map((d) => d.id)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final payload = {
        'bet_ids': betIds,
        'ticket_no': batchTicketNo,
        'draw_id': drawId,
        'cluster_id': clusterId,
        'payment_method': 'cash',
      };

      final response = await http
          .post(
            Uri.parse('${AppConstants.apiBaseUrl}/bets/submit-draft'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 && response.statusCode != 201) {
        _handleBetError(response, 0);
        return;
      }

      final responseBody = jsonDecode(response.body);
      final responseData = responseBody['data'] as Map<String, dynamic>? ?? {};
      final teller = responseData['teller'] as Map<String, dynamic>? ?? {};
      final responseBalance =
          (teller['balance'] as num?)?.toDouble() ??
          (responseData['balance'] as num?)?.toDouble();
      if (responseBalance != null) {
        balance.value = responseBalance;
        authController.updateCurrentUserBalance(responseBalance);
      }
      final ticketNo = responseData['batch_id'] as String? ?? batchTicketNo;

      final totalAmount = draftBets.fold<double>(
        0,
        (prev, draft) => prev + draft.totalBetAmount,
      );

      // Capture context before clearing state
      final gameName = game.name;
      final selectedDt = currentDrawTimes.cast<DrawTime?>().firstWhere(
        (d) => d?.id == selectedTime.value,
        orElse: () => null,
      );
      final drawTimeLabel = selectedDt?.getFormattedTime() ?? '';

      // Convert DraftBet entries to BetEntry for printing
      final printEntries = draftBets.expand((draft) {
        final entries = <BetEntry>[];
        if (draft.straightBetAmount > 0) {
          entries.add(
            BetEntry(
              betNumber: 0,
              game: draft.gameName,
              straightBetAmount: draft.straightBetAmount,
              rambleBetAmount: 0,
              winAmount: draft.straightBetAmount * (game.straightMultiplier),
              digits: List<String>.from(draft.digits),
              combinations: draft.combinations,
            ),
          );
        }
        if (draft.rambleBetAmount > 0) {
          entries.add(
            BetEntry(
              betNumber: 0,
              game: draft.gameName,
              straightBetAmount: 0,
              rambleBetAmount: draft.rambleBetAmount,
              winAmount:
                  (draft.rambleBetAmount / draft.combinations) *
                  (game.rambleMultiplier ?? 0),
              digits: List<String>.from(draft.digits),
              combinations: draft.combinations,
            ),
          );
        }
        return entries;
      }).toList();

      _triggerPrint(
        betEntries: printEntries,
        totalAmount: totalAmount,
        ticketNo: ticketNo,
        teller: teller,
        gameName: gameName,
        drawTimeLabel: drawTimeLabel,
      );

      await loadProfile();

      draftBets.clear();
      selectedNumbers.clear();
      targetAmount.value = 0;
      rambolAmount.value = 0;

      Get.snackbar(
        'Success',
        'Bets submitted successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to submit bets: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
      update();
    }
  }

  /// Shows a brief "Printing Ticket…" snackbar and sends the ticket to
  /// the configured Bluetooth thermal printer in the background.
  Future<void> _triggerPrint({
    required List<BetEntry> betEntries,
    required double totalAmount,
    required String ticketNo,
    required Map<String, dynamic> teller,
    required String gameName,
    required String drawTimeLabel,
  }) async {
    // Verify saved printer reachability before attempting to print
    final reach = await PrinterService.getSavedPrinterReachability();
    if (reach != PrinterReachabilityStatus.reachable) {
      Get.dialog(
        _printerAlertDialog(
          icon: Icons.bluetooth_disabled,
          title: 'Printer Unavailable',
          message: reach == PrinterReachabilityStatus.notConfigured
              ? 'No printer configured. Please set up a Bluetooth printer to print tickets.'
              : reach == PrinterReachabilityStatus.permissionDenied
              ? 'Bluetooth permission denied. Please grant Bluetooth permissions in settings.'
              : 'Saved printer is not reachable. Ensure Bluetooth is enabled and the printer is paired.',
          actionLabel: 'Set Up Printer',
          onAction: () {
            Get.back();
            Get.toNamed('/printer-settings');
          },
        ),
      );
      return;
    }

    // Show user-facing "Printing Ticket…" feedback immediately
    Get.snackbar(
      '',
      '',
      titleText: const Row(
        children: [
          Icon(Icons.print, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text(
            'Printing Ticket…',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
      messageText: const SizedBox.shrink(),
      backgroundColor: const Color(0xFF3D5A99),
      duration: const Duration(seconds: 2),
      snackPosition: SnackPosition.BOTTOM,
      borderRadius: 12,
      margin: const EdgeInsets.all(16),
    );

    // Print in background — do not await so UI stays responsive.
    // All error conditions (no printer, disconnected, out of paper) are
    // surfaced via the typed PrintResult.
    PrinterService.printTicket(
      betEntries: betEntries,
      totalAmount: totalAmount,
      ticketNo: ticketNo,
      teller: teller,
      gameName: gameName,
      drawTimeLabel: drawTimeLabel,
    ).then((result) {
      if (result.success) return;

      switch (result.error) {
        case PrintError.noPrinterConfigured:
          Get.dialog(
            _printerAlertDialog(
              icon: Icons.bluetooth_disabled,
              title: 'No Printer Connected',
              message: 'Please connect to a printer before submitting bets.',
              actionLabel: 'Set Up Printer',
              onAction: () {
                Get.back();
                Get.toNamed('/printer-settings');
              },
            ),
          );
          break;
        case PrintError.permissionDenied:
          Get.dialog(
            _printerAlertDialog(
              icon: Icons.bluetooth_searching,
              title: 'Bluetooth Permission Required',
              message:
                  'Allow Nearby devices permission so the app can connect to your printer.',
              actionLabel: 'Open Settings',
              onAction: () {
                Get.back();
                openAppSettings();
              },
            ),
          );
          break;
        case PrintError.notConnected:
          Get.dialog(
            _printerAlertDialog(
              icon: Icons.bluetooth_disabled,
              title: 'Printer Not Connected',
              message:
                  'Please connect to a printer. Make sure Bluetooth is on and the printer is paired.',
              actionLabel: 'Go to Settings',
              onAction: () {
                Get.back();
                Get.toNamed('/printer-settings');
              },
            ),
          );
          break;
        case PrintError.outOfPaper:
          Get.dialog(
            _printerAlertDialog(
              icon: Icons.feed_outlined,
              title: 'Printer Out of Paper',
              message:
                  'The printer has no paper. Please load paper and print again.',
              actionLabel: 'OK',
              onAction: Get.back,
            ),
          );
          break;
        case PrintError.nearEndOfPaper:
          // Ticket printed but paper is running low — show warning snackbar
          Get.snackbar(
            'Low Paper',
            'Ticket printed, but printer paper is running low. Please refill soon.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange[700],
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
          );
          break;
        default:
          Get.dialog(
            _printerAlertDialog(
              icon: Icons.print_disabled_rounded,
              title: 'Print Failed',
              message:
                  'Could not print the ticket. Please check:\n\n'
                  '• Printer has paper loaded\n'
                  '• Printer is powered on\n'
                  '• Bluetooth is connected',
              actionLabel: 'OK',
              onAction: Get.back,
            ),
          );
      }
    });
  }

  /// Builds a reusable alert dialog for printer-related errors.
  Widget _printerAlertDialog({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Dialog(
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
              child: Icon(icon, color: const Color(0xFFF59E0B), size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D5A99),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBetError(http.Response response, int betNumber) {
    try {
      final errorBody = jsonDecode(response.body);
      final message = errorBody['message'] ?? 'Unknown error';

      if (betNumber == 0) {
        Get.snackbar(
          'Error',
          'Failed to submit bets: $message',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Error',
          'Bet $betNumber failed: $message',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Bet submission failed with status code ${response.statusCode}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Create a claim for a winning ticket by ticket ID
  /// Returns: {success: bool, data?: Map, error?: String, statusCode?: int}
  Future<Map<String, dynamic>> createClaimByTicket(String ticketId) async {
    try {
      final authController = Get.find<AuthController>();

      if (!authController.isLoggedIn) {
        return {'success': false, 'error': 'Please log in first'};
      }

      final token = authController.token.value;
      final payload = {'ticket_number': ticketId};

      final response = await http
          .post(
            Uri.parse('${AppConstants.apiBaseUrl}/claims/create-by-ticket'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 && response.statusCode != 201) {
        try {
          final errorBody = jsonDecode(response.body);
          final message = errorBody['message'] ?? 'Failed to create claim';
          return {
            'success': false,
            'error': message,
            'statusCode': response.statusCode,
            'fullResponse': errorBody,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to create claim (Status: ${response.statusCode})',
            'statusCode': response.statusCode,
          };
        }
      }

      // Parse successful response
      final responseBody = jsonDecode(response.body);
      final claimData = responseBody['data'] as Map<String, dynamic>? ?? {};

      return {'success': true, 'data': claimData};
    } catch (e) {
      return {'success': false, 'error': 'Failed to create claim: $e'};
    }
  }

  /// Fetch ticket details by ticket number
  /// Returns: {success: bool, data?: Ticket, error?: String, statusCode?: int}
  Future<Map<String, dynamic>> getTicketByNumber(String ticketNumber) async {
    try {
      final authController = Get.find<AuthController>();

      if (!authController.isLoggedIn) {
        return {'success': false, 'error': 'Please log in first'};
      }

      // If QR encodes a UUID, resolve it to ticket_no first (robustness for different QR formats)
      try {
        final resolved = await TicketService.resolveScannedTicketNumber(ticketNumber);
        if (resolved.isNotEmpty && resolved != ticketNumber) {
          ticketNumber = resolved;
        }
      } catch (_) {}

      final token = authController.token.value;
      final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/tickets',
      ).replace(queryParameters: {'ticket_no': ticketNumber});

      print('[LotteryController] GET $uri');
      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      print('[LotteryController] Response (${response.statusCode}): ${response.body}');

      if (response.statusCode != 200) {
        try {
          final errorBody = jsonDecode(response.body);
          final message = errorBody['message'] ?? 'Ticket not found';
          return {
            'success': false,
            'error': message,
            'statusCode': response.statusCode,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'Failed to fetch ticket (Status: ${response.statusCode})',
            'statusCode': response.statusCode,
          };
        }
      }

      // Parse successful response
      final responseBody = jsonDecode(response.body);
      final ticketsData = responseBody['data'] as List?;

      // Get the first ticket from the results
      if (ticketsData != null && ticketsData.isNotEmpty) {
        final ticketData = ticketsData[0] as Map<String, dynamic>;
        return {'success': true, 'data': ticketData};
      } else {
        return {'success': false, 'error': 'No ticket found with this number'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Failed to fetch ticket: $e'};
    }
  }
}
