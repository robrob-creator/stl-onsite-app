import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controllers/lottery_controller.dart';
import '../../widgets/lotto_number_input.dart';

class BetEntryPage extends StatefulWidget {
  const BetEntryPage({super.key});

  @override
  State<BetEntryPage> createState() => _BetEntryPageState();
}

class _BetEntryPageState extends State<BetEntryPage> {
  String _lottoNumbers = '';
  late TextEditingController _targetAmountController;
  late TextEditingController _rambolAmountController;
  late FocusNode _targetAmountFocusNode;
  late FocusNode _rambolAmountFocusNode;
  // 'target' | 'rambol' | '' (neither focused)
  String _activeBetField = 'target';

  @override
  void initState() {
    super.initState();
    _targetAmountController = TextEditingController();
    _rambolAmountController = TextEditingController();
    _targetAmountFocusNode = FocusNode();
    _rambolAmountFocusNode = FocusNode();

    _targetAmountFocusNode.addListener(() {
      if (_targetAmountFocusNode.hasFocus) {
        setState(() => _activeBetField = 'target');
      }
    });
    _rambolAmountFocusNode.addListener(() {
      if (_rambolAmountFocusNode.hasFocus) {
        setState(() => _activeBetField = 'rambol');
      }
    });
  }

  @override
  void dispose() {
    _targetAmountController.dispose();
    _rambolAmountController.dispose();
    _targetAmountFocusNode.dispose();
    _rambolAmountFocusNode.dispose();
    super.dispose();
  }

  /// Formats a number with comma separators, e.g. 1000 → "1,000"
  String _formatNumber(double value) {
    final intVal = value.toInt();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LotteryController());

    return Scaffold(
      backgroundColor: Colors.white,

      body: GestureDetector(
        onTap: () {
          // Unfocus all fields when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Game Selector
              GetBuilder<LotteryController>(
                builder: (ctrl) => Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: ctrl.availableGames
                        .map(
                          (game) => Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _lottoNumbers = '';
                                });
                                ctrl.selectedGameId.value = game.id;
                                // Select the first available draw time for the newly chosen game
                                final firstAvailable = game.drawTimes
                                    .where((dt) => dt.isAvailable())
                                    .firstOrNull;
                                ctrl.selectedTime.value =
                                    firstAvailable?.id ?? '';
                                ctrl.update();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ctrl.selectedGameId.value == game.id
                                      ? Colors.white
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.only(right: 12),
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: AssetImage(
                                            game.name.contains('2D')
                                                ? 'assets/images/logos/lotto2d.png'
                                                : 'assets/images/logos/lotto3d.png',
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      game.name,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color:
                                            ctrl.selectedGameId.value == game.id
                                            ? Colors.black
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Lotto Number Input
              GetBuilder<LotteryController>(
                builder: (ctrl) => Column(
                  children: [
                    // Lotto Number Input Widget
                    LottoNumberInput(
                      gameType: ctrl.currentGame?.name ?? '2D Lotto',
                      numberOfCombinations:
                          ctrl.currentGame?.numberOfCombinations ?? 2,
                      minNumber: ctrl.currentGame?.minNumber ?? 0,
                      maxNumber: ctrl.currentGame?.maxNumber ?? 99,
                      onChanged: (value) {
                        setState(() {
                          _lottoNumbers = value;
                        });
                      },
                      initialValue: _lottoNumbers,
                      onLastNumberEntered: () {
                        // Move focus to target amount field when last number is entered
                        FocusScope.of(
                          context,
                        ).requestFocus(_targetAmountFocusNode);
                      },
                    ),
                    // Play Type Selector (Only for games that enable both straight and ramble)
                  ],
                ),
              ),
              // const SizedBox(height: 24),

              // Draw Time Selector
              GetBuilder<LotteryController>(
                builder: (ctrl) {
                  final drawTimes = ctrl.currentDrawTimes
                      .where((dt) => dt.isAvailable())
                      .toList();

                  // If the previously selected draw time is no longer available,
                  // auto-select the first one that still is.
                  if (drawTimes.isNotEmpty &&
                      !drawTimes.any(
                        (dt) => dt.id == ctrl.selectedTime.value,
                      )) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ctrl.selectedTime.value = drawTimes.first.id;
                      ctrl.update();
                    });
                  }

                  // If no draw times are available, show message
                  if (drawTimes.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Text(
                        'No draw times available at this moment. Please try again later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: drawTimes
                          .map(
                            (drawTime) => Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  ctrl.selectedTime.value = drawTime.id;
                                  ctrl.update();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        ctrl.selectedTime.value == drawTime.id
                                        ? const Color(0xFF2563EB)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    drawTime.getFormattedTime(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          ctrl.selectedTime.value == drawTime.id
                                          ? Colors.white
                                          : Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Bet Amount Fields
              GetBuilder<LotteryController>(
                builder: (ctrl) {
                  final game = ctrl.currentGame;
                  if (game == null) return const SizedBox.shrink();

                  final bothEnabled = game.enableStraight && game.enableRamble;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target / Rambol toggle (only shown when both are available)
                      if (bothEnabled) ...[
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _activeBetField = 'target');
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(_targetAmountFocusNode);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _activeBetField == 'target'
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Target',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _activeBetField == 'target'
                                            ? Colors.white
                                            : Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _activeBetField = 'rambol');
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(_rambolAmountFocusNode);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _activeBetField == 'rambol'
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'Rambol',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: _activeBetField == 'rambol'
                                            ? Colors.white
                                            : Colors.grey[400],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Amount input fields
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (game.enableStraight)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!bothEnabled)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        'Target / Straight Bet',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  TextField(
                                    controller: _targetAmountController,
                                    focusNode: _targetAmountFocusNode,
                                    onChanged: (value) {
                                      ctrl.targetAmount.value =
                                          int.tryParse(value) ?? 0;
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Target Amount',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                            ),
                          if (game.enableStraight && game.enableRamble)
                            const SizedBox(width: 16),
                          if (game.enableRamble)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!bothEnabled)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text(
                                        'Rambol / Box Bet',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  TextField(
                                    controller: _rambolAmountController,
                                    focusNode: _rambolAmountFocusNode,
                                    onChanged: (value) {
                                      ctrl.rambolAmount.value =
                                          int.tryParse(value) ?? 0;
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Rambol Amount',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Add Bet Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (_lottoNumbers.isEmpty) {
                      Get.snackbar('Error', 'Please select numbers');
                      return;
                    }

                    final controller = Get.find<LotteryController>();
                    final game = controller.currentGame;

                    if (game == null) {
                      Get.snackbar('Error', 'Please select a game');
                      return;
                    }

                    // Calculate digits per cell based on max number
                    int digitsPerCell = game.maxNumber.toString().length;
                    int expectedTotalDigits =
                        game.numberOfCombinations * digitsPerCell;

                    // Validate input length
                    if (_lottoNumbers.length != expectedTotalDigits) {
                      String rangeText = '${game.minNumber}-${game.maxNumber}';
                      String numberText = game.numberOfCombinations == 1
                          ? 'number'
                          : 'numbers';
                      Get.snackbar(
                        'Error',
                        'Please enter ${game.numberOfCombinations} $numberText for ${game.name} (range: $rangeText)',
                      );
                      return;
                    }

                    // Validate that at least one amount is entered based on game settings
                    int targetAmount =
                        int.tryParse(_targetAmountController.text) ?? 0;
                    int rambolAmount =
                        int.tryParse(_rambolAmountController.text) ?? 0;

                    if (game.enableStraight && game.enableRamble) {
                      // Both enabled: at least one must be > 0
                      if (targetAmount == 0 && rambolAmount == 0) {
                        Get.snackbar(
                          'Error',
                          'Please enter at least one bet amount',
                        );
                        return;
                      }
                    } else if (game.enableStraight) {
                      // Only Target enabled
                      if (targetAmount == 0) {
                        Get.snackbar(
                          'Error',
                          'Please enter a Target/Straight bet amount',
                        );
                        return;
                      }
                    } else if (game.enableRamble) {
                      // Only Rambol enabled
                      if (rambolAmount == 0) {
                        Get.snackbar(
                          'Error',
                          'Please enter a Rambol/Box bet amount',
                        );
                        return;
                      }
                    }

                    // Convert lotto numbers to list for controller by grouping
                    controller.selectedNumbers.clear();
                    for (
                      int i = 0;
                      i < _lottoNumbers.length;
                      i += digitsPerCell
                    ) {
                      controller.selectedNumbers.add(
                        _lottoNumbers.substring(i, i + digitsPerCell),
                      );
                    }

                    controller.addBet();

                    // Clear all inputs after successful bet addition
                    // Use Future.microtask to defer setState until after build completes
                    Future.microtask(() {
                      setState(() {
                        _lottoNumbers = '';
                        _targetAmountController.clear();
                        _rambolAmountController.clear();
                      });
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Add Bet',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Bet List Table
              GetBuilder<LotteryController>(
                builder: (ctrl) => controller.betList.isEmpty
                    ? SizedBox(
                        height: 100,
                        child: Center(
                          child: Text(
                            'No bets added yet',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Bet #',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Game',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Type',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Amount',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Win',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 30),
                              ],
                            ),
                          ),
                          // Table Rows
                          ...ctrl.betList.asMap().entries.map((entry) {
                            int index = entry.key;
                            var bet = entry.value;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[200]!),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      bet.betNumber.toString(),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      bet.game,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      bet.betType,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      bet.betAmount.toStringAsFixed(0),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      _formatNumber(bet.winAmount),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Color(0xFFC7472D),
                                    ),
                                    onPressed: () => ctrl.removeBet(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
              ),

              const SizedBox(height: 24),

              // Totals Section
              GetBuilder<LotteryController>(
                builder: (ctrl) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Bets: ${ctrl.betList.length}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Total: ₱ ${ctrl.betList.fold<double>(0, (prev, bet) => prev + bet.totalBetAmount).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              GetBuilder<LotteryController>(
                builder: (ctrl) => SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: ctrl.isLoading.value
                        ? null
                        : () => ctrl.submitBets(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: ctrl.isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'Submit Bet Entry',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.receipt_long,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
