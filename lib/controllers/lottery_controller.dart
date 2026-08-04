import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:developer' show log;
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
import '../core/services/no_game_date_service.dart';
import '../core/services/location_service.dart';

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
  final String gameId;
  final List<String> digits;
  final double straightBetAmount;
  final double rambleBetAmount;
  final double totalBetAmount;
  final double estPayout;
  final int combinations;
  final String drawTimeLabel;
  final String drawTimeId;

  DraftBet({
    required this.id,
    required this.gameName,
    this.gameId = '',
    required this.digits,
    required this.straightBetAmount,
    required this.rambleBetAmount,
    required this.totalBetAmount,
    required this.estPayout,
    required this.combinations,
    this.drawTimeLabel = '',
    this.drawTimeId = '',
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
  // Increment when a collection is created/updated so CollectionPage refreshes.
  final RxInt collectionRefreshTick = 0.obs;

  // Permutation availability from server (preview endpoint)
  final Rx<PermutationAvailability?> permAvailability =
      Rx<PermutationAvailability?>(null);
  final RxBool isCheckingPermutations = false.obs;

  // No-game date restriction
  final RxBool isNoGameDay = false.obs;
  final RxString noGameDayDescription = ''.obs;

  // Blackout time restriction (computed from selected game)
  final RxBool isBlackoutTime = false.obs;
  Timer? _blackoutTimer;

  // Draw times that already have a posted result for the currently-selected
  // game + betDate. Used to disable those chips in the bet entry selector so
  // agents cannot place bets for a slot that already drew.
  final RxSet<String> drawnDrawTimeIds = <String>{}.obs;

  // Guards refreshDrawnDrawTimes from running concurrently for the same
  // (gameId, drawDate) pair — key format "gameId::YYYY-MM-DD".
  String? _drawnFetchInFlightKey;

  // The date bets will be placed for (today or tomorrow when after last draw)
  final Rx<DateTime> betDate = DateTime.now().obs;
  bool get isBettingForTomorrow {
    final now = DateTime.now();
    final d = betDate.value;
    return d.year != now.year || d.month != now.month || d.day != now.day;
  }

  @override
  void onInit() {
    super.onInit();
    _checkNoGameDay();
    loadGames();
    loadProfile();
    _subscribeToWebSocketEvents();
    _startBlackoutTimer();
    // Re-check which draw times already drew whenever the selected game or
    // bet date changes, so the selector chips disable/enable correctly.
    ever<String>(selectedGameId, (_) => refreshDrawnDrawTimes());
    ever<DateTime>(betDate, (_) => refreshDrawnDrawTimes());
    // Update user's location in background on app open
    LocationService.updateUserLocation();
  }

  @override
  void onClose() {
    _blackoutTimer?.cancel();
    super.onClose();
  }

  void _startBlackoutTimer() {
    _blackoutTimer?.cancel();
    // Check every 30 seconds so UI reacts promptly when blackout/date changes
    _blackoutTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateBlackoutState();
      _updateBetDate();
    });
  }

  void _updateBlackoutState() {
    final game = currentGame;
    isBlackoutTime.value = game?.isInBlackout ?? false;
    update(); // refresh game chips so per-chip blackout indicators stay current
  }

  /// Called from UI when user switches game tab.
  void updateBetDateForGame(game) {
    final today = DateTime.now();
    final hasAvailableToday =
        (game.drawTimes as List).any((dt) => dt.isAvailable());
    if (!hasAvailableToday) {
      final tomorrow = today.add(const Duration(days: 1));
      betDate.value = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    } else {
      betDate.value = DateTime(today.year, today.month, today.day);
    }
  }

  /// If all draw times for today are past, switch betDate to tomorrow.
  void _updateBetDate() {
    final game = currentGame;
    if (game == null) return;
    final today = DateTime.now();
    final hasAvailableToday = game.drawTimes.any((dt) => dt.isAvailable());
    if (!hasAvailableToday) {
      final tomorrow = today.add(const Duration(days: 1));
      betDate.value = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    } else {
      betDate.value = DateTime(today.year, today.month, today.day);
    }
  }

  Future<void> _checkNoGameDay() async {
    final result = await NoGameDateService.checkToday();
    isNoGameDay.value = result.isNoGameDay;
    noGameDayDescription.value = result.description ?? '';
  }

  void _subscribeToWebSocketEvents() {
    try {
      final ws = Get.find<WebSocketService>();
      ws.on('bet.placed', (_) => loadProfile());
      ws.on('bet.bulk_placed', (_) => loadProfile());
      ws.on('claim.paid', (_) => loadProfile());
      // Refresh balance and collection list when collector records a payment.
      void onCollectionEvent(_) {
        loadProfile();
        collectionRefreshTick.value = collectionRefreshTick.value + 1;
      }
      ws.on('collection.created', onCollectionEvent);
      ws.on('collection.updated', onCollectionEvent);
      // Trigger dashboard re-fetch when draw results are published and
      // refresh the agent's balance since winning payouts are deducted from
      // the maker's balance on approval.
      ws.on('draw_result.posted', (_) {
        drawRefreshTick.value = drawRefreshTick.value + 1;
        loadProfile();
        refreshDrawnDrawTimes();
      });
      // Sync agent app when admin changes game/schedule/no-game config
      ws.on('api.mutation', (payload) {
        final endpoint = (payload['endpoint'] as String?) ?? '';
        final endpoints =
            (payload['endpoints_to_update'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList();
        // Game settings or draw times changed (blackout, limits, etc.)
        if (endpoints.any((e) =>
            e.contains('/api/games') || e.contains('/api/draw-times'))) {
          loadGames();
        }
        // No-game date added/removed
        if (endpoints.any((e) => e.contains('/api/no-game-date'))) {
          _checkNoGameDay();
        }
        // Collection created/updated (direct check) or inferred from endpoint —
        // catches collector tapada payment, add-fund/tapada, and tapada-receive
        // even when endpoints_to_update doesn't list a collection endpoint.
        final isCollectionAction = endpoints.any((e) => e.contains('collection')) ||
            endpoint.contains('/api/collections') ||
            endpoint.contains('tapada') ||
            endpoint.contains('add-fund');
        if (isCollectionAction) {
          loadProfile();
          collectionRefreshTick.value = collectionRefreshTick.value + 1;
        }
        // Sold-out config changed — re-check permutations if user has digits entered
        if (endpoints.any((e) =>
            e.contains('/api/soldouts') || e.contains('/api/sold-out'))) {
          if (selectedNumbers.isNotEmpty) {
            final cartBets = <Map<String, dynamic>>[];
            for (final d in draftBets) {
              if (d.straightBetAmount > 0) {
                cartBets.add({'digits': d.digits, 'amount': d.straightBetAmount.toInt(), 'bet_type': 'straight'});
              }
              if (d.rambleBetAmount > 0) {
                cartBets.add({'digits': d.digits, 'amount': d.rambleBetAmount.toInt(), 'bet_type': 'rambol'});
              }
            }
            fetchPermutations(List<String>.from(selectedNumbers), cartBets: cartBets);
          }
        }
      });
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

      if (games.isNotEmpty) {
        // Preserve current selection when reloading — only reset if the
        // previously selected game is gone or nothing was selected yet.
        final prevGameId = selectedGameId.value;
        final prevTimeId = selectedTime.value;
        final prevGameStillExists = games.any((g) => g.id == prevGameId);

        if (prevGameId.isEmpty || !prevGameStillExists) {
          selectedGameId.value = games[0].id;
          selectedTime.value = getFirstAvailableDrawTimeId(games[0]);
        } else {
          // Game preserved — check if the draw time is still valid.
          final game = games.firstWhere((g) => g.id == prevGameId);
          final drawTimes = List<DrawTime>.from(game.drawTimes)
            ..sort(DrawTime.compareChronologically);
          final timeStillValid = drawTimes.any(
            (dt) =>
                dt.id == prevTimeId &&
                dt.isAvailableForDate(betDate.value) &&
                !isDrawTimeDrawn(dt.id),
          );
          if (!timeStillValid) {
            selectedTime.value = getFirstAvailableDrawTimeId(game);
          }
        }
      }
      _updateBlackoutState();
      _updateBetDate();
      update();
      // Load any saved drafts now that games are available for lookup
      await loadDraftBets();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load games: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load existing draft bets from server into [draftBets].
  /// Only runs when [draftBets] is empty to avoid overwriting in-session additions.
  Future<void> loadDraftBets() async {
    if (draftBets.isNotEmpty) return;
    try {
      final token = Get.find<AuthController>().token.value;
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/bets/list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final betsJson = (data['data'] as List?) ?? [];

      final drafts = <DraftBet>[];
      for (final betJson in betsJson) {
        if (betJson['status'] != 'draft') continue;

        final gameId = betJson['game_id'] as String? ?? '';
        final game = availableGames.firstWhereOrNull((g) => g.id == gameId);

        List<String> digits = [];
        final rawDigits = betJson['digits'];
        if (rawDigits is List) {
          digits = List<String>.from(rawDigits.map((e) => e.toString()));
        } else if (rawDigits is String) {
          digits = rawDigits
              .replaceAll('{', '')
              .replaceAll('}', '')
              .split(',')
              .map((d) => d.trim())
              .where((d) => d.isNotEmpty)
              .toList();
        }

        final combinations = digits.isNotEmpty ? calculateCombinations(digits) : 1;
        final drawId = betJson['draw_id'] as String? ?? '';
        String drawTimeLabel = '';
        if (game != null) {
          final dt = currentDrawTimes.cast<DrawTime?>().firstWhere(
            (dt) => dt?.id == drawId,
            orElse: () => null,
          );
          drawTimeLabel = dt?.getFormattedTime() ?? '';
        }

        drafts.add(DraftBet(
          id: betJson['id'] as String? ?? '',
          gameName: game?.name ?? (betJson['game_name'] as String? ?? 'Unknown'),
          gameId: gameId,
          digits: digits,
          straightBetAmount: (betJson['straight_bet_amount'] as num? ?? 0).toDouble(),
          rambleBetAmount: (betJson['ramble_bet_amount'] as num? ?? 0).toDouble(),
          totalBetAmount: (betJson['total_bet_amount'] as num? ?? 0).toDouble(),
          estPayout: (betJson['est_payout'] as num? ?? 0).toDouble(),
          combinations: combinations,
          drawTimeLabel: drawTimeLabel,
          drawTimeId: drawId,
        ));
      }

      if (drafts.isNotEmpty) {
        draftBets.value = drafts;
      }
    } catch (_) {
      // Fail open — drafts will just be empty
    }
  }

  /// Fetch user profile and update balance
  Future<void> loadProfile() async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final user = await ProfileService.fetchProfile();
        balance.value = user.balance;
        Get.find<AuthController>().syncCurrentUser(user);
        update();
        return;
      } catch (e) {
        debugPrint('Failed to load profile (attempt $attempt): $e');
        if (attempt < 3) {
          await Future.delayed(Duration(seconds: attempt));
        }
      }
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
    final date = betDate.value;
    return drawTimes
            .where((dt) =>
                dt.isAvailableForDate(date) && !isDrawTimeDrawn(dt.id))
            .firstOrNull
            ?.id ??
        '';
  }

  /// True when a draw result has already been posted for this draw time on
  /// the currently-selected game + bet date.
  bool isDrawTimeDrawn(String drawTimeId) =>
      drawnDrawTimeIds.contains(drawTimeId);

  /// Refresh [drawnDrawTimeIds] for the currently-selected game and bet date.
  /// Silently no-ops if there is no active game. Cheap to call on every
  /// game/date change and on `draw_result.posted` WS events.
  Future<void> refreshDrawnDrawTimes() async {
    final game = currentGame;
    if (game == null) {
      drawnDrawTimeIds.clear();
      return;
    }
    final d = betDate.value;
    final dateStr =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final key = '${game.id}::$dateStr';
    if (_drawnFetchInFlightKey == key) return;
    _drawnFetchInFlightKey = key;
    try {
      final response = await DrawResultsService.getLatestResultsByGameAndDate(
        gameId: game.id,
        drawDate: dateStr,
      );
      if (response == null) return;
      // Ignore if game/date changed while the request was in flight.
      if (game.id != currentGame?.id) return;
      final next = <String>{};
      for (final dt in response.drawTimes) {
        final id = dt.id;
        if (id == null || id.isEmpty) continue;
        if (dt.latestResult != null) next.add(id);
      }
      drawnDrawTimeIds
        ..clear()
        ..addAll(next);
      // If the currently-selected draw time just became drawn, jump to the
      // next available slot so the UI does not sit on a disabled chip.
      if (selectedTime.value.isNotEmpty &&
          isDrawTimeDrawn(selectedTime.value)) {
        selectedTime.value = getFirstAvailableDrawTimeId(game);
      }
      update();
    } catch (_) {
      // Fail open — chips stay enabled rather than incorrectly disabled.
    } finally {
      if (_drawnFetchInFlightKey == key) {
        _drawnFetchInFlightKey = null;
      }
    }
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
      final game = currentGame;
      final int limit = game?.numberOfCombinations ?? 2;

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

  Future<void> clearDraftBets() async {
    final token = Get.find<AuthController>().token.value;
    try {
      await http
          .delete(
            Uri.parse('${AppConstants.apiBaseUrl}/bets/drafts/clear'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {}
    draftBets.clear();
    update();
  }

  /// Sends the current bet inputs to `POST /bets/draft-bulk` and appends
  /// the returned draft to [draftBets]. Returns `true` on success.
  Future<bool> addBet() async {
    if (isNoGameDay.value) {
      Get.snackbar(
        'Betting Unavailable',
        noGameDayDescription.value.isNotEmpty
            ? noGameDayDescription.value
            : 'No games are scheduled for today.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
    if (isBlackoutTime.value) {
      Get.snackbar(
        'Blackout Period',
        'Betting is temporarily unavailable during the configured blackout period.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }


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
      final selectedDt = currentDrawTimes.cast<DrawTime?>().firstWhere(
        (dt) => dt?.id == drawId, orElse: () => null);
      final drawTimeLabel = selectedDt?.getFormattedTime() ?? '';
      final clusterId = game.clusters.isNotEmpty ? game.clusters[0].id : '';
      final combinations = calculateCombinations(selectedNumbers);
      final digits = List<String>.from(selectedNumbers);

      // Build separate items for each enabled bet type so the server stores
      // them as independent draft records (one per type).
      final List<Map<String, dynamic>> betItems = [];

      final betDateStr =
          '${betDate.value.year}-${betDate.value.month.toString().padLeft(2, '0')}-${betDate.value.day.toString().padLeft(2, '0')}';

      if (straightAmount > 0) {
        final estPayout = straightAmount * game.straightMultiplier;
        betItems.add({
          'draw_id': drawId,
          'draw_time_id': drawId,
          'draw_date': betDateStr,
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
          'draw_time_id': drawId,
          'draw_date': betDateStr,
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

      final currentDrawId = selectedTime.value;
      if (betsJson.isEmpty) {
        // Fallback: build placeholder drafts from local intent so the user
        // can still see and submit what they added.
        if (straightAmount > 0) {
          draftBets.add(
            DraftBet(
              id: '',
              gameName: game.name,
              gameId: game.id,
              digits: digits,
              straightBetAmount: straightAmount,
              rambleBetAmount: 0,
              totalBetAmount: straightAmount,
              estPayout: straightAmount * game.straightMultiplier,
              combinations: combinations,
              drawTimeLabel: drawTimeLabel,
              drawTimeId: currentDrawId,
            ),
          );
        }
        if (rambleAmount > 0) {
          draftBets.add(
            DraftBet(
              id: '',
              gameName: game.name,
              gameId: game.id,
              digits: digits,
              straightBetAmount: 0,
              rambleBetAmount: rambleAmount,
              totalBetAmount: rambleAmount,
              estPayout:
                  (rambleAmount / combinations) * (game.rambleMultiplier ?? 0),
              combinations: combinations,
              drawTimeLabel: drawTimeLabel,
              drawTimeId: currentDrawId,
            ),
          );
        }
      } else {
        for (final betJson in betsJson) {
          final serverStraight = (betJson['straight_bet_amount'] as num? ?? 0)
              .toDouble();
          final serverRamble = (betJson['ramble_bet_amount'] as num? ?? 0)
              .toDouble();
          final serverTotal = (betJson['total_bet_amount'] as num? ?? 0)
              .toDouble();
          final serverEstPayout = (betJson['est_payout'] as num? ?? 0)
              .toDouble();

          List<String> serverDigits = digits;
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
              gameId: game.id,
              digits: serverDigits,
              straightBetAmount: serverStraight,
              rambleBetAmount: serverRamble,
              totalBetAmount: serverTotal,
              estPayout: serverEstPayout,
              combinations: combinations,
              drawTimeLabel: drawTimeLabel,
              drawTimeId: currentDrawId,
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
    final drawDate = ManilaTime.dateString(betDate.value);
    isCheckingPermutations.value = true;
    try {
      final result = await SoldOutService.checkPermutations(
        gameId: game.id,
        drawId: drawTimeId,
        drawTimeId: drawTimeId,
        drawDate: drawDate,
        tokens: digits,
        cartBets: cartBets,
        targetAmount: targetAmount.value.toDouble(),
        rambolAmount: rambolAmount.value.toDouble(),
      );
      permAvailability.value = result;
    } catch (_) {
      permAvailability.value = null;
    } finally {
      isCheckingPermutations.value = false;
    }
  }

  /// Checks availability via POST /bet/token/permutations (with cart_bets).
  /// Returns null when open. Returns BetAvailabilityResult when a conflict exists.
  /// When [excludeDraftIndex] is non-null, that draft is skipped when building
  /// cart_bets so an edited bet does not double-count its own prior amount.
  Future<BetAvailabilityResult?> checkBetAvailability({
    required List<String> digits,
    required double targetAmount,
    required double rambolAmount,
    int? excludeDraftIndex,
  }) async {
    final game = currentGame;
    if (game == null) return null;

    final drawTimeId = selectedTime.value;
    final drawDate = ManilaTime.dateString(betDate.value);

    final cartBets = <Map<String, dynamic>>[];
    for (int i = 0; i < draftBets.length; i++) {
      if (excludeDraftIndex != null && i == excludeDraftIndex) continue;
      final d = draftBets[i];
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
        targetAmount: targetAmount,
        rambolAmount: rambolAmount,
      );
      permAvailability.value = result;
      final avail = buildBetAvailabilityResult(
        gameId: game.id,
        digits: digits,
        drawTimeId: drawTimeId,
        drawDate: drawDate,
        targetAmount: targetAmount,
        rambolAmount: rambolAmount,
        perm: result,
      );
      log('[AVAIL] state=${result.state} targetAvail=${result.target.availableAmount} '
          'targetAmt=$targetAmount rambolAmt=$rambolAmount '
          'result=${avail == null ? "null(OPEN)" : "EXCEEDS exceeds=${avail.exceeds}"}',
          name: 'AVAIL');
      return avail;
    } catch (e, st) {
      log('[AVAIL] ERROR: $e', name: 'AVAIL', error: e, stackTrace: st);
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

  /// Ensure location service (GPS) is on AND permission is granted.
  Future<bool> _ensureLocationEnabled() async {
    try {
      // First verify the location service (GPS hardware) is enabled
      final serviceStatus = await Permission.locationWhenInUse.serviceStatus;
      if (serviceStatus == ServiceStatus.disabled) {
        await _showLocationServicesPrompt();
        return false;
      }

      final status = await Permission.locationWhenInUse.status;
      if (status.isGranted) {
        LocationService.updateUserLocation();
        return true;
      }
      final req = await Permission.locationWhenInUse.request();
      if (req.isGranted) {
        LocationService.updateUserLocation();
        return true;
      }
      await _showLocationPrompt();
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showLocationServicesPrompt() async {
    try {
      Get.snackbar(
        'GPS Disabled',
        'Location/GPS services must be enabled to place bets.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 6),
      );
    } catch (_) {}
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
                  'Location Services Disabled',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Location/GPS must be enabled to comply with regulatory requirements when placing bets. Please enable Location Services in your device settings.',
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
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
    if (isNoGameDay.value) {
      Get.snackbar(
        'Betting Unavailable',
        noGameDayDescription.value.isNotEmpty
            ? noGameDayDescription.value
            : 'No games are scheduled for today.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (isBlackoutTime.value) {
      Get.snackbar(
        'Blackout Period',
        'Betting is temporarily unavailable during the configured blackout period.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

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

      final token = authController.token.value;

      final clusterId = game.clusters.isNotEmpty ? game.clusters[0].id : '';
      final clusterCode = game.clusters.isNotEmpty
          ? game.clusters[0].id.substring(0, 3).toUpperCase()
          : 'UNK';

      // Group draft bets by draw time — each group prints as a separate ticket
      final groups = <String, List<DraftBet>>{};
      for (final draft in draftBets) {
        final key = draft.drawTimeId.isNotEmpty ? draft.drawTimeId : selectedTime.value;
        groups.putIfAbsent(key, () => []).add(draft);
      }

      Map<String, dynamic> lastTeller = {};
      double? lastBalance;

      // Capture betDate now before it may change after submission
      final betDateStr =
          '${betDate.value.year}-${betDate.value.month.toString().padLeft(2, '0')}-${betDate.value.day.toString().padLeft(2, '0')}';

      // Collects print data for each submitted group; printed sequentially after
      // all API submissions succeed to avoid concurrent Bluetooth connections.
      final printQueue = <({
        List<BetEntry> betEntries,
        double totalAmount,
        String ticketNo,
        Map<String, dynamic> teller,
        String gameName,
        String drawTimeLabel,
        String drawDate,
      })>[];

      for (final entry in groups.entries) {
        final groupDrawId = entry.key;
        final groupBets = entry.value;

        final now = ManilaTime.now();
        final uniqueTimestamp =
            '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';
        final batchTicketNo =
            'TKT-$clusterCode-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-$uniqueTimestamp';

        final betIds = groupBets
            .map((d) => d.id)
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

        final payload = {
          'bet_ids': betIds,
          'ticket_no': batchTicketNo,
          'draw_id': groupDrawId,
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
          lastBalance = responseBalance;
        }
        lastTeller = teller;

        final ticketNo = responseData['batch_id'] as String? ?? batchTicketNo;
        final groupTotal = groupBets.fold<double>(0, (s, d) => s + d.totalBetAmount);

        // Resolve draw time label for this group
        final groupDt = currentDrawTimes.cast<DrawTime?>().firstWhere(
          (d) => d?.id == groupDrawId, orElse: () => null);
        final groupDrawTimeLabel = groupBets.isNotEmpty && groupBets[0].drawTimeLabel.isNotEmpty
            ? groupBets[0].drawTimeLabel
            : (groupDt?.getFormattedTime() ?? '');

        final groupGameName = groupBets.isNotEmpty ? groupBets[0].gameName : game.name;

        final printEntries = groupBets.expand((draft) {
          final entries = <BetEntry>[];
          if (draft.straightBetAmount > 0) {
            entries.add(BetEntry(
              betNumber: 0,
              game: draft.gameName,
              straightBetAmount: draft.straightBetAmount,
              rambleBetAmount: 0,
              winAmount: draft.straightBetAmount * game.straightMultiplier,
              digits: List<String>.from(draft.digits),
              combinations: draft.combinations,
            ));
          }
          if (draft.rambleBetAmount > 0) {
            entries.add(BetEntry(
              betNumber: 0,
              game: draft.gameName,
              straightBetAmount: 0,
              rambleBetAmount: draft.rambleBetAmount,
              winAmount: (draft.rambleBetAmount / draft.combinations) * (game.rambleMultiplier ?? 0),
              digits: List<String>.from(draft.digits),
              combinations: draft.combinations,
            ));
          }
          return entries;
        }).toList();

        printQueue.add((
          betEntries: printEntries,
          totalAmount: groupTotal,
          ticketNo: ticketNo,
          teller: Map<String, dynamic>.from(lastTeller),
          gameName: groupGameName,
          drawTimeLabel: groupDrawTimeLabel,
          drawDate: betDateStr,
        ));
      }

      if (lastBalance != null) {
        balance.value = lastBalance!;
        authController.updateCurrentUserBalance(lastBalance!);
      }

      await loadProfile();

      draftBets.clear();
      selectedNumbers.clear();
      targetAmount.value = 0;
      rambolAmount.value = 0;

      // Signal Dashboard to re-fetch gross amounts after bets are finalized
      drawRefreshTick.value = drawRefreshTick.value + 1;

      Get.snackbar(
        'Success',
        'Bets submitted successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF10B981),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );

      // Print tickets sequentially — one Bluetooth job at a time.
      for (final job in printQueue) {
        await _triggerPrint(
          betEntries: job.betEntries,
          totalAmount: job.totalAmount,
          ticketNo: job.ticketNo,
          teller: job.teller,
          gameName: job.gameName,
          drawTimeLabel: job.drawTimeLabel,
          drawDate: job.drawDate,
        );
      }
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
    String drawDate = '',
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

    final result = await PrinterService.printTicket(
      betEntries: betEntries,
      totalAmount: totalAmount,
      ticketNo: ticketNo,
      teller: teller,
      gameName: gameName,
      drawTimeLabel: drawTimeLabel,
      drawDate: drawDate,
    );

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
      final code = response.statusCode;
      final msg = code == 502 || code == 503 || code == 504
          ? 'Server is temporarily unavailable. Please try again.'
          : 'Bet submission failed (code $code). Please try again.';
      Get.snackbar('Error', msg, snackPosition: SnackPosition.BOTTOM);
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
