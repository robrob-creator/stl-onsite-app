import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../../controllers/lottery_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/app_constants.dart';
import '../../core/services/printer_service.dart';
import '../../models/bet_availability.dart';
import '../../models/game.dart';
import '../../widgets/lotto_number_input.dart';
import '../../widgets/conflict_notice_modal.dart';
import '../../widgets/batch_bet_choice_modal.dart';
import '../../widgets/current_slip_card.dart';

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
  bool _isAddingBet = false;
  bool _isSubmitting = false;
  // When editing an existing draft, store its index here. Null = creating new bet.
  int? _editingIndex;

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
  List<String> _generatePermutations(List<String> digits) {
    if (digits.isEmpty) return [];
    final result = <String>{};
    void permute(List<String> arr, int start) {
      if (start == arr.length) {
        result.add(arr.join('-'));
        return;
      }
      final seen = <String>{};
      for (int i = start; i < arr.length; i++) {
        if (seen.contains(arr[i])) continue;
        seen.add(arr[i]);
        final tmp = arr[start];
        arr[start] = arr[i];
        arr[i] = tmp;
        permute(arr, start + 1);
        arr[start] = arr[i];
        arr[i] = tmp;
      }
    }

    permute(List<String>.from(digits), 0);
    return result.toList()..sort();
  }

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

  Widget _labelValue(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSubmit(LotteryController ctrl) async {
    if (ctrl.draftBets.isEmpty) {
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
      final reachability = await PrinterService.getSavedPrinterReachability();
      if (reachability == PrinterReachabilityStatus.permissionDenied) {
        final proceed = await _showPrinterWarningDialog(
          icon: Icons.bluetooth_searching_rounded,
          title: 'Bluetooth Permission Required',
          message:
              'Allow Nearby devices permission so the app can check and use your printer.\n\nDo you want to submit anyway?',
          confirmLabel: 'Submit Anyway',
          cancelLabel: 'Open Settings',
          onCancel: () {
            Get.back();
            openAppSettings();
          },
        );
        if (!proceed) return;
      } else if (reachability == PrinterReachabilityStatus.unreachable) {
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
                      onPressed: _isSubmitting
                          ? null
                          : () async {
                              if (_isSubmitting) return;
                              setState(() => _isSubmitting = true);
                              Get.back(); // close confirmation dialog
                              try {
                                await ctrl.submitBets();
                              } finally {
                                if (mounted) {
                                  setState(() => _isSubmitting = false);
                                }
                              }
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
    final controller = Get.find<LotteryController>();

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
                                ctrl.selectedTime.value = ctrl
                                    .getFirstAvailableDrawTimeId(game);
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
                        final game = ctrl.currentGame;
                        if (game != null) {
                          final dpc = game.maxNumber.toString().length;
                          final expected = game.numberOfCombinations * dpc;
                          if (value.length == expected) {
                            final digs = <String>[];
                            for (int i = 0; i < value.length; i += dpc) {
                              digs.add(value.substring(i, i + dpc));
                            }
                            ctrl.fetchPermutations(digs);
                          } else {
                            ctrl.permAvailability.value = null;
                          }
                        }
                      },
                      initialValue: _lottoNumbers,
                      onLastNumberEntered: () {
                        FocusScope.of(
                          context,
                        ).requestFocus(_targetAmountFocusNode);
                      },
                    ),
                    // Availability badge — shown once digits are complete
                    Obx(() {
                      final perm = ctrl.permAvailability.value;
                      if (perm == null) return const SizedBox.shrink();
                      final Color bg;
                      final Color fg;
                      final IconData icon;
                      final String label;
                      switch (perm.state) {
                        case 'SOLD_OUT':
                          bg = const Color(0xFFFEE2E2);
                          fg = const Color(0xFFDC2626);
                          icon = Icons.block_rounded;
                          label = 'Sold Out';
                        case 'PARTIALLY_SOLD':
                          bg = const Color(0xFFFFF3E0);
                          fg = const Color(0xFFF59E0B);
                          icon = Icons.warning_amber_rounded;
                          label = 'Partially Sold';
                        default:
                          bg = const Color(0xFFD1FAE5);
                          fg = const Color(0xFF059669);
                          icon = Icons.check_circle_outline_rounded;
                          label = 'Available';
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icon, size: 14, color: fg),
                                const SizedBox(width: 4),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: fg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
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
                    final defaultDrawTimeId = ctrl.currentGame == null
                        ? drawTimes.first.id
                        : ctrl.getFirstAvailableDrawTimeId(ctrl.currentGame!);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ctrl.selectedTime.value = defaultDrawTimeId;
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
                      // Target / Rambol toggle — hidden when server says showBetTypeSelection=false
                      if (bothEnabled)
                        Obx(() {
                          final perm = ctrl.permAvailability.value;
                          if (perm != null && !perm.showBetTypeSelection) {
                            return const SizedBox.shrink();
                          }
                          final targetDisabled =
                              perm != null && !perm.target.allowed;
                          final rambolTabDisabled =
                              perm != null &&
                              (perm.rambolDisabled || !perm.rambol.allowed);
                          return Column(
                            children: [
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
                                        onTap: targetDisabled
                                            ? null
                                            : () {
                                                setState(
                                                  () => _activeBetField =
                                                      'target',
                                                );
                                                FocusScope.of(
                                                  context,
                                                ).requestFocus(
                                                  _targetAmountFocusNode,
                                                );
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: targetDisabled
                                                ? Colors.grey[200]
                                                : _activeBetField == 'target'
                                                ? const Color(0xFF2563EB)
                                                : Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Target',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: targetDisabled
                                                  ? Colors.grey[400]
                                                  : _activeBetField == 'target'
                                                  ? Colors.white
                                                  : Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: rambolTabDisabled
                                            ? null
                                            : () {
                                                setState(
                                                  () => _activeBetField =
                                                      'rambol',
                                                );
                                                FocusScope.of(
                                                  context,
                                                ).requestFocus(
                                                  _rambolAmountFocusNode,
                                                );
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: rambolTabDisabled
                                                ? Colors.grey[200]
                                                : _activeBetField == 'rambol'
                                                ? const Color(0xFF2563EB)
                                                : Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            'Rambol',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: rambolTabDisabled
                                                  ? Colors.grey[400]
                                                  : _activeBetField == 'rambol'
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
                          );
                        }),

                      // Amount input fields
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (game.enableStraight)
                            Expanded(
                              child: Obx(() {
                                final perm = ctrl.permAvailability.value;
                                final targetBlocked =
                                    perm != null && !perm.target.allowed;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!bothEnabled)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          'Target Bet',
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
                                      enabled: !targetBlocked,
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
                                        errorStyle: const TextStyle(
                                          fontSize: 11,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                );
                              }),
                            ),
                          if (game.enableStraight && game.enableRamble)
                            const SizedBox(width: 16),
                          if (game.enableRamble)
                            Expanded(
                              child: Obx(() {
                                final perm = ctrl.permAvailability.value;
                                final rambolBlocked =
                                    perm != null &&
                                    (perm.rambolDisabled ||
                                        !perm.rambol.allowed);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!bothEnabled)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
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
                                      enabled: !rambolBlocked,
                                      onChanged: (value) {
                                        ctrl.rambolAmount.value =
                                            int.tryParse(value) ?? 0;
                                        final n = int.tryParse(value) ?? 0;
                                        final dpc = game.maxNumber
                                            .toString()
                                            .length;
                                        final digs = <String>[];
                                        for (
                                          int i = 0;
                                          i + dpc <= _lottoNumbers.length;
                                          i += dpc
                                        ) {
                                          digs.add(
                                            _lottoNumbers.substring(i, i + dpc),
                                          );
                                        }
                                        final perm =
                                            ctrl.permAvailability.value;
                                        final pc =
                                            perm?.rambol.permutationCount ??
                                            (digs.isNotEmpty
                                                ? ctrl.calculateCombinations(
                                                    digs,
                                                  )
                                                : 1);
                                        final maxR =
                                            game.maxRambleBet ??
                                            game.maxStraightBet;
                                        setState(() {
                                          _rambolError = (n > 0 && n < pc)
                                              ? 'Min: ₱$pc  •  Max: ₱$maxR'
                                              : null;
                                        });
                                      },
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        _RangeFormatter(
                                          min: 1,
                                          max:
                                              game.maxRambleBet ??
                                              game.maxStraightBet,
                                        ),
                                      ],
                                      decoration: InputDecoration(
                                        hintText: 'Rambol Amount',
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                        ),
                                        errorText: _rambolError,
                                        errorStyle: const TextStyle(
                                          fontSize: 11,
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                );
                              }),
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
                  final canAdd =
                      hasDrawTimes && !ctrl.isLoading.value && !_isAddingBet;
                  return SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: canAdd
                          ? () async {
                              if (_isAddingBet) return;
                              setState(() => _isAddingBet = true);
                              try {
                                if (_lottoNumbers.isEmpty) {
                                  Get.snackbar(
                                    'Error',
                                    'Please select numbers',
                                  );
                                  return;
                                }

                                final controller =
                                    Get.find<LotteryController>();
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
                                if (_lottoNumbers.length !=
                                    expectedTotalDigits) {
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

                                // Build digits list (needed for permCount validation)
                                final digits = <String>[];
                                for (
                                  int i = 0;
                                  i < _lottoNumbers.length;
                                  i += digitsPerCell
                                ) {
                                  digits.add(
                                    _lottoNumbers.substring(
                                      i,
                                      i + digitsPerCell,
                                    ),
                                  );
                                }
                                final permCount = controller
                                    .calculateCombinations(digits);

                                // Validate that at least one amount is entered based on game settings
                                int targetAmount =
                                    int.tryParse(
                                      _targetAmountController.text,
                                    ) ??
                                    0;
                                int rambolAmount =
                                    int.tryParse(
                                      _rambolAmountController.text,
                                    ) ??
                                    0;

                                // Rambol validation (fail fast). Returns true = valid.
                                bool validateRambol() {
                                  // All identical → permCount == 1
                                  if (permCount <= 1) {
                                    Get.snackbar(
                                      'Invalid Bet',
                                      'Rambol not available — all digits are identical',
                                    );
                                    return false;
                                  }
                                  // Server says rambol is disabled/sold-out
                                  final perm =
                                      controller.permAvailability.value;
                                  if (perm != null &&
                                      (perm.rambolDisabled ||
                                          !perm.rambol.allowed)) {
                                    Get.snackbar(
                                      'Sold Out',
                                      'Rambol is not available for this combination',
                                    );
                                    return false;
                                  }
                                  // Min amount: use server permCount or local fallback
                                  final availPerms =
                                      perm?.rambol.permutationCount ??
                                      controller.calculateCombinations(digits);
                                  if (rambolAmount < availPerms) {
                                    Get.snackbar(
                                      'Invalid Amount',
                                      'Minimum Rambol bet is ₱$availPerms',
                                    );
                                    return false;
                                  }
                                  // Divisibility
                                  if (availPerms > 0 &&
                                      rambolAmount % availPerms != 0) {
                                    Get.snackbar(
                                      'Invalid Amount',
                                      'Rambol amount must be divisible by $availPerms',
                                    );
                                    return false;
                                  }
                                  // Exceeds max
                                  final maxR =
                                      game.maxRambleBet ?? game.maxStraightBet;
                                  if (rambolAmount > maxR) {
                                    Get.snackbar(
                                      'Invalid Amount',
                                      'Rambol bet must not exceed ₱$maxR',
                                    );
                                    return false;
                                  }
                                  return true;
                                }

                                if (game.enableStraight && game.enableRamble) {
                                  if (targetAmount == 0 && rambolAmount == 0) {
                                    Get.snackbar(
                                      'Error',
                                      'Please enter at least one bet amount',
                                    );
                                    return;
                                  }
                                  if (targetAmount > 0 &&
                                      targetAmount < game.minStraightBet) {
                                    Get.snackbar(
                                      'Invalid Amount',
                                      'Target bet must be at least ₱${game.minStraightBet}',
                                    );
                                    return;
                                  }
                                  if (rambolAmount > 0 && !validateRambol()) {
                                    return;
                                  }
                                } else if (game.enableStraight) {
                                  if (targetAmount == 0) {
                                    Get.snackbar(
                                      'Error',
                                      'Please enter a Target bet amount',
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
                                  if (rambolAmount == 0) {
                                    Get.snackbar(
                                      'Error',
                                      'Please enter a Rambol/Box bet amount',
                                    );
                                    return;
                                  }
                                  if (!validateRambol()) return;
                                }

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
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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

                                final availResult = await controller
                                    .checkBetAvailability(
                                      digits: digits,
                                      targetAmount: targetAmount.toDouble(),
                                      rambolAmount: rambolAmount.toDouble(),
                                    );

                                if (Get.isDialogOpen ?? false) Get.back();

                                if (availResult != null &&
                                    availResult.exceeds) {
                                  final bothTypes =
                                      targetAmount > 0 &&
                                      rambolAmount > 0 &&
                                      !availResult.target.allowed &&
                                      !availResult.rambol.allowed;

                                  if (bothTypes) {
                                    Get.dialog(
                                      BatchBetChoiceModal(
                                        targetResult: availResult,
                                        rambolResult: availResult,
                                        onChooseTarget:
                                            availResult.target.allowed
                                            ? () {
                                                Get.back();
                                                Future.microtask(
                                                  () =>
                                                      controller
                                                              .rambolAmount
                                                              .value =
                                                          0,
                                                );
                                              }
                                            : null,
                                        onChooseRambol:
                                            availResult.rambol.allowed
                                            ? () {
                                                Get.back();
                                                Future.microtask(
                                                  () =>
                                                      controller
                                                              .targetAmount
                                                              .value =
                                                          0,
                                                );
                                              }
                                            : null,
                                      ),
                                    );
                                  } else {
                                    final available =
                                        availResult.availableAmount;
                                    Get.dialog(
                                      ConflictNoticeModal(
                                        result: availResult,
                                        requestedAmount:
                                            availResult.requestedAmount,
                                        onUpdateAmount:
                                            available != null && available > 0
                                            ? () {
                                                Get.back();
                                                Future.microtask(() {
                                                  if (availResult.betType ==
                                                      BetType.target) {
                                                    controller
                                                        .targetAmount
                                                        .value = available
                                                        .toInt();
                                                  } else {
                                                    controller
                                                        .rambolAmount
                                                        .value = available
                                                        .toInt();
                                                  }
                                                });
                                              }
                                            : null,
                                        onAdjustManually: () => Get.back(),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                // If we're editing an existing draft, remove it first
                                if (_editingIndex != null) {
                                  final editIndex = _editingIndex!;
                                  // Capture ID to verify deletion succeeded
                                  final originalId =
                                      editIndex < controller.draftBets.length
                                      ? controller.draftBets[editIndex].id
                                      : '';

                                  await controller.removeBet(editIndex);

                                  // If the original had a server ID and it still exists,
                                  // treat the removal as failed and abort update.
                                  if (originalId.isNotEmpty &&
                                      controller.draftBets.any(
                                        (d) => d.id == originalId,
                                      )) {
                                    Get.snackbar(
                                      'Error',
                                      'Failed to remove original draft. Update aborted',
                                    );
                                    return;
                                  }
                                }

                                // Convert lotto numbers to list for controller by grouping
                                controller.selectedNumbers.clear();
                                controller.selectedNumbers.addAll(digits);

                                final ok = await controller.addBet();

                                // Clear inputs only when the draft was created successfully
                                if (ok) {
                                  Future.microtask(() {
                                    setState(() {
                                      _lottoNumbers = '';
                                      _targetAmountController.clear();
                                      _rambolAmountController.clear();
                                      _editingIndex = null; // exit edit mode
                                    });
                                  });
                                }
                              } finally {
                                if (mounted) {
                                  setState(() => _isAddingBet = false);
                                }
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAdd
                            ? Colors.orange[400]
                            : Colors.grey[300],
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
                          : Text(
                              _editingIndex != null ? 'Update Bet' : 'Add Bet',
                              style: TextStyle(
                                color: canAdd ? Colors.white : Colors.grey[500],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Bet List
              GetBuilder<LotteryController>(
                builder: (ctrl) {
                  if (ctrl.draftBets.isEmpty) {
                    return Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: Text(
                        'No bets added yet',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header: "Your Bets · N  /  Clear all"
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Your Bets',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' · ${ctrl.draftBets.length}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => ctrl.clearDraftBets(),
                              child: const Text(
                                'Clear all',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5050C8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Cards
                      ...ctrl.draftBets.asMap().entries.map((e) {
                        final idx = e.key;
                        final draft = e.value;
                        return CurrentSlipCard(
                          key: ValueKey(
                            draft.id.isNotEmpty ? draft.id : 'draft_$idx',
                          ),
                          index: idx,
                          digits: List<String>.from(draft.digits),
                          gameName: draft.gameName,
                          betType: draft.betType,
                          straightAmount: draft.straightBetAmount,
                          rambolAmount: draft.rambleBetAmount,
                          totalAmount: draft.totalBetAmount,
                          estPayout: draft.estPayout,
                          drawTimeLabel: draft.drawTimeLabel,
                          onDelete: () => ctrl.removeBet(idx),
                        );
                      }),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // Totals footer
              GetBuilder<LotteryController>(
                builder: (ctrl) {
                  if (ctrl.draftBets.isEmpty) return const SizedBox.shrink();
                  final total = ctrl.draftBets.fold<double>(
                    0,
                    (sum, d) => sum + d.totalBetAmount,
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Total Bets: ${ctrl.draftBets.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'TOTAL AMOUNT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₱${total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF3B4FFF),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
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

  Future<void> _showEditDialog(
    LotteryController controller,
    int index,
    dynamic draft,
  ) async {
    await Get.dialog(
      EditDraftDialog(controller: controller, index: index, draft: draft),
      barrierDismissible: false,
    );
  }
}

class EditDraftDialog extends StatefulWidget {
  final LotteryController controller;
  final int index;
  final dynamic draft;
  const EditDraftDialog({
    super.key,
    required this.controller,
    required this.index,
    required this.draft,
  });

  @override
  State<EditDraftDialog> createState() => _EditDraftDialogState();
}

class _EditDraftDialogState extends State<EditDraftDialog> {
  late TextEditingController _targetCtrl;
  late TextEditingController _rambolCtrl;
  late String _digitsStr;
  String? _targetErr;
  String? _rambolErr;
  bool _isSaving = false;
  late Game? _game;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _digitsStr = (draft.digits is List)
        ? (draft.digits as List).join('')
        : (draft.digits.toString());
    _targetCtrl = TextEditingController(
      text: (draft.straightBetAmount ?? 0).toInt().toString(),
    );
    _rambolCtrl = TextEditingController(
      text: (draft.rambleBetAmount ?? 0).toInt().toString(),
    );
    try {
      _game = widget.controller.availableGames.firstWhere(
        (g) => g.name == draft.gameName,
      );
    } catch (_) {
      _game = widget.controller.currentGame;
    }
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _rambolCtrl.dispose();
    super.dispose();
  }

  List<String> _getDigitsList(int digitsPerCell) {
    final list = <String>[];
    for (
      int i = 0;
      i + digitsPerCell <= _digitsStr.length;
      i += digitsPerCell
    ) {
      list.add(_digitsStr.substring(i, i + digitsPerCell));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final draft = widget.draft;
    final digitsPerCell = _game?.maxNumber.toString().length ?? 2;
    final expectedTotalDigits =
        (_game?.numberOfCombinations ?? draft.combinations) * digitsPerCell;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: WillPopScope(
        onWillPop: () async => !_isSaving,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Bet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              LottoNumberInput(
                gameType: _game?.name ?? '2D Lotto',
                numberOfCombinations:
                    _game?.numberOfCombinations ?? draft.combinations,
                minNumber: _game?.minNumber ?? 0,
                maxNumber: _game?.maxNumber ?? 99,
                initialValue: _digitsStr,
                onChanged: (v) => setState(() => _digitsStr = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text(
                            'Target Amount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        TextField(
                          controller: _targetCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '₱0',
                            errorText: _targetErr,
                          ),
                          onChanged: (v) {
                            setState(() {
                              final n = int.tryParse(v) ?? 0;
                              if (_game != null) {
                                _targetErr =
                                    (n > 0 &&
                                        n <
                                            (_game!.minStraightBet.toInt() ??
                                                0))
                                    ? 'Min: ₱${_game!.minStraightBet.toInt() ?? 0}'
                                    : null;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text(
                            'Rambol Amount',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        TextField(
                          controller: _rambolCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '₱0',
                            errorText: _rambolErr,
                          ),
                          onChanged: (v) {
                            setState(() {
                              final n = int.tryParse(v) ?? 0;
                              if (_game != null) {
                                final pc = controller.calculateCombinations(
                                  _getDigitsList(digitsPerCell),
                                );
                                final maxR =
                                    _game!.maxRambleBet ??
                                    _game!.maxStraightBet ??
                                    0;
                                _rambolErr = (n > 0 && n < pc)
                                    ? 'Min: ₱$pc'
                                    : (n > 0 && maxR > 0 && n > maxR
                                          ? 'Max: ₱$maxR'
                                          : null);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              try {
                                FocusScope.of(context).unfocus();
                              } catch (_) {}
                              Navigator.of(context).pop();
                            },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              final digits = _getDigitsList(digitsPerCell);
                              if (digits.length !=
                                  (_game?.numberOfCombinations ??
                                      draft.combinations)) {
                                Get.snackbar(
                                  'Error',
                                  'Please enter correct number of digits',
                                );
                                return;
                              }
                              final targetAmount =
                                  int.tryParse(_targetCtrl.text) ?? 0;
                              final rambolAmount =
                                  int.tryParse(_rambolCtrl.text) ?? 0;

                              if ((_game?.enableStraight ?? true) &&
                                  (_game?.enableRamble ?? true)) {
                                if (targetAmount == 0 && rambolAmount == 0) {
                                  Get.snackbar(
                                    'Error',
                                    'Please enter at least one bet amount',
                                  );
                                  return;
                                }
                                if (targetAmount > 0 &&
                                    targetAmount <
                                        (_game?.minStraightBet.toInt() ?? 0)) {
                                  Get.snackbar(
                                    'Invalid Amount',
                                    'Target bet must be at least ₱${_game?.minStraightBet.toInt() ?? 0}',
                                  );
                                  return;
                                }
                                if (rambolAmount > 0) {
                                  final pc = controller.calculateCombinations(
                                    digits,
                                  );
                                  if (pc <= 1) {
                                    Get.snackbar(
                                      'Invalid Bet',
                                      'Rambol not available — all digits are identical',
                                    );
                                    return;
                                  }
                                  if (rambolAmount < pc) {
                                    Get.snackbar(
                                      'Invalid Amount',
                                      'Minimum Rambol bet is ₱$pc',
                                    );
                                    return;
                                  }
                                  if (rambolAmount % pc != 0) {
                                    Get.snackbar(
                                      'Invalid Amount',
                                      'Rambol amount must be divisible by $pc',
                                    );
                                    return;
                                  }
                                }
                              }

                              final availResult = await controller
                                  .checkBetAvailability(
                                    digits: digits,
                                    targetAmount: targetAmount.toDouble(),
                                    rambolAmount: rambolAmount.toDouble(),
                                  );

                              if (availResult != null && availResult.exceeds) {
                                final bothTypes =
                                    targetAmount > 0 &&
                                    rambolAmount > 0 &&
                                    !availResult.target.allowed &&
                                    !availResult.rambol.allowed;
                                if (bothTypes) {
                                  await Get.dialog(
                                    BatchBetChoiceModal(
                                      targetResult: availResult,
                                      rambolResult: availResult,
                                      onChooseTarget: availResult.target.allowed
                                          ? () {
                                              Get.back();
                                            }
                                          : null,
                                      onChooseRambol: availResult.rambol.allowed
                                          ? () {
                                              Get.back();
                                            }
                                          : null,
                                    ),
                                  );
                                  return;
                                } else {
                                  final available = availResult.availableAmount;
                                  await Get.dialog(
                                    ConflictNoticeModal(
                                      result: availResult,
                                      requestedAmount:
                                          availResult.requestedAmount,
                                      onUpdateAmount:
                                          (available != null && available > 0)
                                          ? () {
                                              Get.back();
                                            }
                                          : null,
                                      onAdjustManually: () => Get.back(),
                                    ),
                                  );
                                  return;
                                }
                              }

                              setState(() => _isSaving = true);
                              try {
                                final gameId =
                                    _game?.id ??
                                    controller.selectedGameId.value;
                                final clusterId =
                                    (_game != null &&
                                        _game!.clusters.isNotEmpty)
                                    ? _game!.clusters[0].id
                                    : '';
                                final estPayout =
                                    (targetAmount > 0 && _game != null)
                                    ? targetAmount *
                                          (_game!.straightMultiplier ?? 0)
                                    : (rambolAmount > 0 && _game != null)
                                    ? (rambolAmount /
                                              (controller.calculateCombinations(
                                                digits,
                                              ))) *
                                          (_game!.rambleMultiplier ?? 0)
                                    : 0;

                                final resp = await http
                                    .put(
                                      Uri.parse(
                                        '${AppConstants.apiBaseUrl}/bets/update',
                                      ),
                                      headers: {
                                        'Content-Type': 'application/json',
                                        'Authorization':
                                            'Bearer ${Get.find<AuthController>().token.value}',
                                      },
                                      body: jsonEncode({
                                        'id': draft.id,
                                        'draw_id':
                                            controller.selectedTime.value,
                                        'game_id': gameId,
                                        'digits': digits,
                                        'straight_bet_amount': targetAmount,
                                        'ramble_bet_amount': rambolAmount,
                                        'total_bet_amount':
                                            targetAmount + rambolAmount,
                                        'est_payout': estPayout,
                                        'cluster_id': clusterId,
                                        'draw_time_id':
                                            controller.selectedTime.value,
                                      }),
                                    )
                                    .timeout(const Duration(seconds: 30));

                                if (resp.statusCode != 200 &&
                                    resp.statusCode != 201) {
                                  Get.snackbar(
                                    'Error',
                                    'Failed to update bet: ${resp.statusCode}',
                                  );
                                  return;
                                }

                                final respBody =
                                    jsonDecode(resp.body)
                                        as Map<String, dynamic>;
                                final betJson =
                                    respBody['data'] as Map<String, dynamic>? ??
                                    {};

                                final serverDigitsRaw = betJson['digits'];
                                List<String> serverDigits = digits;
                                if (serverDigitsRaw is List) {
                                  serverDigits = List<String>.from(
                                    serverDigitsRaw,
                                  );
                                } else if (serverDigitsRaw is String)
                                  serverDigits = serverDigitsRaw
                                      .replaceAll('{', '')
                                      .replaceAll('}', '')
                                      .split(',')
                                      .map((s) => s.trim())
                                      .toList();

                                final serverStraight =
                                    (betJson['straight_bet_amount'] as num? ??
                                            0)
                                        .toDouble();
                                final serverRamble =
                                    (betJson['ramble_bet_amount'] as num? ?? 0)
                                        .toDouble();
                                final serverTotal =
                                    (betJson['total_bet_amount'] as num? ?? 0)
                                        .toDouble();
                                final serverEst =
                                    (betJson['est_payout'] as num? ?? 0)
                                        .toDouble();

                                controller.draftBets[widget.index] = DraftBet(
                                  id: betJson['id'] as String? ?? draft.id,
                                  gameName: _game?.name ?? draft.gameName,
                                  digits: serverDigits,
                                  straightBetAmount: serverStraight,
                                  rambleBetAmount: serverRamble,
                                  totalBetAmount: serverTotal,
                                  estPayout: serverEst,
                                  combinations: controller
                                      .calculateCombinations(serverDigits),
                                );
                                controller.update();

                                try {
                                  FocusScope.of(context).unfocus();
                                } catch (_) {}
                                Navigator.of(context).pop();
                                Get.snackbar(
                                  'Success',
                                  'Draft updated',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              } catch (e) {
                                Get.snackbar(
                                  'Error',
                                  'Failed to update bet: $e',
                                );
                              } finally {
                                setState(() => _isSaving = false);
                              }
                            },
                      child: _isSaving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save'),
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
}
