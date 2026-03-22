import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_controller.dart';
import '../models/bet.dart';
import '../models/game.dart';
import '../core/services/game_service.dart';
import '../core/services/profile_service.dart';
import '../widgets/receipt_modal.dart';

class BetEntry {
  final int betNumber;
  final String game;
  final double straightBetAmount;
  final double rambleBetAmount;
  final double winAmount;
  final List<String> digits;

  BetEntry({
    required this.betNumber,
    required this.game,
    required this.straightBetAmount,
    required this.rambleBetAmount,
    required this.winAmount,
    required this.digits,
  });

  double get totalBetAmount => straightBetAmount + rambleBetAmount;

  /// 'Target' when this is a straight entry, 'Rambol' when it's a ramble entry.
  String get betType => straightBetAmount > 0 ? 'Target' : 'Rambol';

  /// The non-zero bet amount for this entry.
  double get betAmount =>
      straightBetAmount > 0 ? straightBetAmount : rambleBetAmount;
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

  // Bet tracking
  final RxList<BetEntry> betList = <BetEntry>[].obs;
  final RxDouble balance = 0.0.obs;
  final RxInt betCounter = 0.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadGames();
    loadProfile();
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
        // Set the first *available* draw time of the selected game
        final firstAvailable = games[0].drawTimes
            .where((dt) => dt.isAvailable())
            .firstOrNull;
        if (firstAvailable != null) {
          selectedTime.value = firstAvailable.id;
        }
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
      update();
    } catch (e) {
      // Silently fail - keep existing balance if profile fetch fails
      print('Failed to load profile: $e');
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
    return currentGame?.drawTimes ?? [];
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

  void addBet() {
    if (selectedNumbers.isEmpty) {
      Get.snackbar('Error', 'Please select numbers');
      return;
    }

    double straightAmount = targetAmount.value.toDouble();
    double rambleAmount = rambolAmount.value.toDouble();

    // At least one amount must be > 0
    if (straightAmount == 0 && rambleAmount == 0) {
      Get.snackbar('Error', 'Please enter at least one bet amount');
      return;
    }

    final game = currentGame;
    if (game == null) {
      Get.snackbar('Error', 'Please select a game');
      return;
    }

    // When both amounts are provided, create two separate bet entries.
    if (straightAmount > 0) {
      betList.add(
        BetEntry(
          betNumber: betCounter.value,
          game: game.name,
          straightBetAmount: straightAmount,
          rambleBetAmount: 0,
          winAmount: straightAmount * game.straightMultiplier,
          digits: List<String>.from(selectedNumbers),
        ),
      );
      betCounter.value++;
    }

    if (rambleAmount > 0) {
      betList.add(
        BetEntry(
          betNumber: betCounter.value,
          game: game.name,
          straightBetAmount: 0,
          rambleBetAmount: rambleAmount,
          winAmount: rambleAmount * (game.rambleMultiplier ?? 0),
          digits: List<String>.from(selectedNumbers),
        ),
      );
      betCounter.value++;
    }

    clearNumbers();
    targetAmount.value = 0;
    rambolAmount.value = 0;
    update();

    Get.snackbar('Success', 'Bet added successfully');
  }

  void removeBet(int index) {
    betList.removeAt(index);
    update();
  }

  Future<void> submitBets() async {
    if (betList.isEmpty) {
      Get.snackbar('Error', 'Please add at least one bet');
      return;
    }

    isLoading.value = true;
    update();

    try {
      final authController = Get.find<AuthController>();

      if (!authController.isLoggedIn) {
        Get.snackbar('Error', 'Please log in first');
        isLoading.value = false;
        update();
        return;
      }

      final game = currentGame;
      if (game == null) {
        Get.snackbar('Error', 'Please select a game');
        isLoading.value = false;
        update();
        return;
      }

      // Get the selected draw time ID
      final drawId = selectedTime.value;
      final token = authController.token.value;
      final userId = authController.currentUser.value?.id ?? '';

      // Get the first cluster (default to first available cluster)
      final clusterId = game.clusters.isNotEmpty ? game.clusters[0].id : '';
      final clusterCode = game.clusters.isNotEmpty
          ? game.clusters[0].id.substring(0, 3).toUpperCase()
          : 'UNK';

      // Create bet objects for bulk submission
      List<Map<String, dynamic>> betsToSubmit = [];

      // Generate ONE unique ticket number for the entire batch
      final now = DateTime.now();
      final uniqueTimestamp =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}${now.millisecond.toString().padLeft(3, '0')}';
      final batchTicketNo =
          'TKT-$clusterCode-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}-$uniqueTimestamp';

      for (int i = 0; i < betList.length; i++) {
        final betEntry = betList[i];

        final bet = {
          'draw_id': drawId,
          'game_id': game.id,
          'ticket_no': batchTicketNo,
          'cluster_id': clusterId,
          'agent_id': userId,
          'straight_bet_amount': betEntry.straightBetAmount,
          'ramble_bet_amount': betEntry.rambleBetAmount,
          'total_bet_amount': betEntry.totalBetAmount,
          'digits': betEntry.digits,
        };

        betsToSubmit.add(bet);
      }

      // Submit bulk bets
      final payload = {'bets': betsToSubmit};

      final response = await http
          .post(
            Uri.parse('https://stl-backend-mws9.onrender.com/api/bets/bulk'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200 && response.statusCode != 201) {
        _handleBetError(response, 0);
        isLoading.value = false;
        update();
        return;
      }

      // Parse response
      final responseBody = jsonDecode(response.body);
      final responseData = responseBody['data'] as Map<String, dynamic>? ?? {};
      final submittedBets =
          (responseData['bets'] as List?)
              ?.map((bet) => Bet.fromJson(bet as Map<String, dynamic>))
              .toList() ??
          [];
      final transaction =
          responseData['transaction'] as Map<String, dynamic>? ?? {};
      final ledgers = (responseData['ledgers'] as List?) ?? [];
      final teller = responseData['teller'] as Map<String, dynamic>? ?? {};

      // All bets submitted successfully
      final totalAmount = betList.fold<double>(
        0,
        (prev, bet) => prev + bet.totalBetAmount,
      );

      // Show receipt as modal
      _showReceiptModal(
        submittedBets: submittedBets,
        totalAmount: totalAmount,
        transaction: transaction,
        ledgers: ledgers,
        batchId: responseData['batch_id'] as String? ?? '',
        teller: teller,
      );

      // Refresh user profile to update balance after bet submission
      await loadProfile();

      // Clear bets after successful submission
      betList.clear();
      selectedNumbers.clear();
      targetAmount.value = 0;
      rambolAmount.value = 0;
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

  void _showReceiptModal({
    required List<Bet> submittedBets,
    required double totalAmount,
    required Map<String, dynamic> transaction,
    required List<dynamic> ledgers,
    required String batchId,
    required Map<String, dynamic> teller,
  }) {
    Get.bottomSheet(
      ReceiptModal(
        submittedBets: submittedBets,
        totalAmount: totalAmount,
        transaction: transaction,
        ledgers: ledgers,
        batchId: batchId,
        teller: teller,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
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
            Uri.parse(
              'https://stl-backend-mws9.onrender.com/api/claims/create-by-ticket',
            ),
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

      final token = authController.token.value;
      final uri = Uri.parse(
        'https://stl-backend-mws9.onrender.com/api/tickets',
      ).replace(queryParameters: {'ticket_no': ticketNumber});

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

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
