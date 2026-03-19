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

  @override
  void initState() {
    super.initState();
    _targetAmountController = TextEditingController();
    _rambolAmountController = TextEditingController();
  }

  @override
  void dispose() {
    _targetAmountController.dispose();
    _rambolAmountController.dispose();
    super.dispose();
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
                                if (game.drawTimes.isNotEmpty) {
                                  ctrl.selectedTime.value =
                                      game.drawTimes[0].id;
                                }
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
                    ),
                    // Play Type Selector (Only for games that enable both straight and ramble)
                  ],
                ),
              ),
              // const SizedBox(height: 24),

              // Draw Time Selector
              GetBuilder<LotteryController>(
                builder: (ctrl) {
                  final drawTimes = ctrl.currentDrawTimes;

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

                  // Build Target field widget
                  Widget? targetField;
                  if (game.enableStraight) {
                    targetField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target / Straight Bet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _targetAmountController,
                          onChanged: (value) {
                            ctrl.targetAmount.value = int.tryParse(value) ?? 0;
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter Amount',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    );
                  }

                  // Build Rambol field widget
                  Widget? rambolField;
                  if (game.enableRamble) {
                    rambolField = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rambol / Box Bet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _rambolAmountController,
                          onChanged: (value) {
                            ctrl.rambolAmount.value = int.tryParse(value) ?? 0;
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter Amount',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    );
                  }

                  // Display in row if both present, column if only one
                  if (targetField != null && rambolField != null) {
                    return Row(
                      children: [
                        Expanded(child: targetField),
                        const SizedBox(width: 16),
                        Expanded(child: rambolField),
                      ],
                    );
                  } else if (targetField != null) {
                    return targetField;
                  } else if (rambolField != null) {
                    return rambolField;
                  } else {
                    return const SizedBox.shrink();
                  }
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

                    // Determine bet type based on which amounts are filled
                    if (targetAmount > 0 && rambolAmount == 0) {
                      controller.selectedBetType.value = 'Target';
                    } else if (rambolAmount > 0 && targetAmount == 0) {
                      controller.selectedBetType.value = 'Rambol';
                    } else if (targetAmount > 0 && rambolAmount > 0) {
                      // Both filled: default to Target
                      controller.selectedBetType.value = 'Target';
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
                                    'Numbers',
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
                                    'Straight',
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
                                    'Rambol',
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
                                    'Total',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(flex: 0, child: SizedBox(width: 30)),
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
                                      bet.digits.join('-'),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      bet.straightBetAmount > 0
                                          ? '₱${bet.straightBetAmount.toStringAsFixed(2)}'
                                          : '-',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      bet.rambleBetAmount > 0
                                          ? '₱${bet.rambleBetAmount.toStringAsFixed(2)}'
                                          : '-',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '₱${bet.totalBetAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 0,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Color(0xFFC7472D),
                                      ),
                                      onPressed: () => ctrl.removeBet(index),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
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
