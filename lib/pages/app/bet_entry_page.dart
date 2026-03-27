import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../controllers/lottery_controller.dart';
import '../../core/services/printer_service.dart';
import '../../widgets/lotto_number_input.dart';

/// Restricts typed numeric input to [min, max].
/// Clears the field if the value exceeds max; does NOT clamp to min on typing
/// (min is enforced on submit instead, for a friendlier typing experience).
class _RangeFormatter extends TextInputFormatter {
  final int min;
  final int max;
  const _RangeFormatter({required this.min, required this.max});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final n = int.tryParse(newValue.text);
    if (n == null) return oldValue;
    if (n > max) return oldValue; // block over-limit
    return newValue;
  }
}

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
  String? _targetError;
  String? _rambolError;

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

  void _showLoadingDialog() {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3D5A99)),
                  strokeWidth: 3,
                ),
                SizedBox(height: 20),
                Text(
                  'Submitting bets...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  Future<void> _confirmSubmit(LotteryController ctrl) async {
    if (ctrl.betList.isEmpty) {
      Get.snackbar('Error', 'Please add at least one bet');
      return;
    }

    // Pre-check printer state before showing the confirmation dialog.
    final mac = PrinterService.savedMac;
    if (mac == null || mac.isEmpty) {
      // No printer configured at all.
      final proceed = await _showPrinterWarningDialog(
        icon: Icons.print_disabled_rounded,
        title: 'No Printer Connected',
        message:
            'Please connect to a printer before submitting bets.\n\nDo you want to submit anyway?',
        confirmLabel: 'Submit Anyway',
        cancelLabel: 'Set Up Printer',
        onCancel: () {
          Get.back();
          Get.toNamed('/printer-settings');
        },
      );
      if (!proceed) return;
    } else {
      // Printer is configured — do a quick connectivity check.
      final connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) {
        final proceed = await _showPrinterWarningDialog(
          icon: Icons.bluetooth_disabled_rounded,
          title: 'Printer Not Reachable',
          message:
              'Could not reach the configured printer. Make sure it is on and in Bluetooth range.\n\nDo you want to submit anyway?',
          confirmLabel: 'Submit Anyway',
          cancelLabel: 'Check Printer',
          onCancel: () {
            Get.back();
            Get.toNamed('/printer-settings');
          },
        );
        if (!proceed) return;
      }
    }

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFF59E0B),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                'Bet Confirmation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              // Message
              const Text(
                'Are you sure you want to bet this transactions ?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Color(0xFF3D5A99),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3D5A99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Get.back(); // close confirmation dialog
                        // _showLoadingDialog();
                        await ctrl.submitBets();
                        // Always dismiss the loading dialog here — the dialog
                        // is owned by this page so it is the most reliable
                        // place to close it regardless of GetX routing state.
                        // if (Get.isDialogOpen ?? false) Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D5A99),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a printer-warning dialog and returns [true] if the user
  /// chose to proceed anyway, [false] if they chose to cancel.
  Future<bool> _showPrinterWarningDialog({
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    required VoidCallback onCancel,
  }) async {
    bool proceed = false;
    await Get.dialog<void>(
      Dialog(
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
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFFDC2626), size: 36),
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
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(
                          color: Color(0xFF3D5A99),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        cancelLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3D5A99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        proceed = true;
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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
    return proceed;
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
                                      final n = int.tryParse(value) ?? 0;
                                      setState(() {
                                        _targetError =
                                            (n > 0 && n < game.minStraightBet)
                                            ? 'Min: ₱${game.minStraightBet}  •  Max: ₱${game.maxStraightBet}'
                                            : null;
                                      });
                                    },
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      _RangeFormatter(
                                        min: game.minStraightBet,
                                        max: game.maxStraightBet,
                                      ),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'Target Amount',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                      ),
                                      errorText: _targetError,
                                      errorStyle: const TextStyle(fontSize: 11),
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
                                      final n = int.tryParse(value) ?? 0;
                                      final minR = game.minRambleBet ?? 0;
                                      final maxR = game.maxRambleBet ?? 99999;
                                      setState(() {
                                        _rambolError = (n > 0 && n < minR)
                                            ? 'Min: ₱$minR  •  Max: ₱$maxR'
                                            : null;
                                      });
                                    },
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      _RangeFormatter(
                                        min: game.minRambleBet ?? 0,
                                        max: game.maxRambleBet ?? 99999,
                                      ),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: 'Rambol Amount',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                      ),
                                      errorText: _rambolError,
                                      errorStyle: const TextStyle(fontSize: 11),
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
              GetBuilder<LotteryController>(
                builder: (ctrl) {
                  final hasDrawTimes = ctrl.currentDrawTimes
                      .where((dt) => dt.isAvailable())
                      .isNotEmpty;
                  return SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: hasDrawTimes
                          ? () async {
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
                              int digitsPerCell = game.maxNumber
                                  .toString()
                                  .length;
                              int expectedTotalDigits =
                                  game.numberOfCombinations * digitsPerCell;

                              // Validate input length
                              if (_lottoNumbers.length != expectedTotalDigits) {
                                String rangeText =
                                    '${game.minNumber}-${game.maxNumber}';
                                String numberText =
                                    game.numberOfCombinations == 1
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
                                  int.tryParse(_targetAmountController.text) ??
                                  0;
                              int rambolAmount =
                                  int.tryParse(_rambolAmountController.text) ??
                                  0;

                              if (game.enableStraight && game.enableRamble) {
                                // Both enabled: at least one must be > 0
                                if (targetAmount == 0 && rambolAmount == 0) {
                                  Get.snackbar(
                                    'Error',
                                    'Please enter at least one bet amount',
                                  );
                                  return;
                                }
                                // Validate ranges for whichever fields are filled
                                if (targetAmount > 0) {
                                  if (targetAmount < game.minStraightBet) {
                                    Get.snackbar(
                                      'Invalid Amount',
                                      'Target bet must be at least ₱${game.minStraightBet}',
                                    );
                                    return;
                                  }
                                }
                                if (rambolAmount > 0) {
                                  final minR = game.minRambleBet ?? 0;
                                  final maxR = game.maxRambleBet ?? 99999;
                                  if (rambolAmount < minR) {
                                    Get.snackbar(
                                      'Invalid Amount',
                                      'Rambol bet must be at least ₱$minR',
                                    );
                                    return;
                                  }
                                  if (rambolAmount > maxR) {
                                    Get.snackbar(
                                      'Invalid Amount',
                                      'Rambol bet must not exceed ₱$maxR',
                                    );
                                    return;
                                  }
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
                                if (targetAmount < game.minStraightBet) {
                                  Get.snackbar(
                                    'Invalid Amount',
                                    'Target bet must be at least ₱${game.minStraightBet}',
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
                                final minR = game.minRambleBet ?? 0;
                                final maxR = game.maxRambleBet ?? 99999;
                                if (rambolAmount < minR) {
                                  Get.snackbar(
                                    'Invalid Amount',
                                    'Rambol bet must be at least ₱$minR',
                                  );
                                  return;
                                }
                                if (rambolAmount > maxR) {
                                  Get.snackbar(
                                    'Invalid Amount',
                                    'Rambol bet must not exceed ₱$maxR',
                                  );
                                  return;
                                }
                              }

                              // Build digits list
                              final digits = <String>[];
                              for (
                                int i = 0;
                                i < _lottoNumbers.length;
                                i += digitsPerCell
                              ) {
                                digits.add(
                                  _lottoNumbers.substring(i, i + digitsPerCell),
                                );
                              }

                              // Check availability (sold-out pre-check)
                              final totalBet = (targetAmount + rambolAmount)
                                  .toDouble();

                              // Show checking dialog
                              Get.dialog(
                                Dialog(
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 28,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF3D5A99),
                                                ),
                                            strokeWidth: 3,
                                          ),
                                          SizedBox(height: 20),
                                          Text(
                                            'Checking availability...',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                barrierDismissible: false,
                              );

                              final available = await controller.isBetAvailable(
                                digits: digits,
                                totalBetAmount: totalBet,
                              );

                              // Dismiss the checking dialog
                              if (Get.isDialogOpen ?? false) Get.back();

                              if (!available) {
                                Get.dialog(
                                  Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    backgroundColor: Colors.white,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        32,
                                        24,
                                        24,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              color: Colors.red[50],
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.block_rounded,
                                              color: Colors.red[400],
                                              size: 36,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          const Text(
                                            'Sold Out',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'This combination is no longer available for the selected draw time.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.black54,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 28),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () => Get.back(),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF3D5A99,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 14,
                                                    ),
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              child: const Text(
                                                'OK',
                                                style: TextStyle(
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
                                  ),
                                );
                                return;
                              }

                              // Convert lotto numbers to list for controller by grouping
                              controller.selectedNumbers.clear();
                              controller.selectedNumbers.addAll(digits);

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
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasDrawTimes
                            ? Colors.orange[400]
                            : Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Add Bet',
                        style: TextStyle(
                          color: hasDrawTimes ? Colors.white : Colors.grey[500],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
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
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Action',
                                    style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
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
                                      bet.digits.join("-").toString(),
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
                        : () async => _confirmSubmit(ctrl),
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
                            children: [
                              Text(
                                'Submit Bet Entry',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 8),
                              Image.asset(
                                'assets/images/icons/ticket2.png',
                                height: 24,
                                color: Colors.white,
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
