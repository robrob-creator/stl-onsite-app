import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LottoNumberInput extends StatefulWidget {
  final String gameType; // Game name for display
  final int numberOfCombinations; // Number of input fields needed
  final int minNumber; // Minimum allowed number
  final int maxNumber; // Maximum allowed number
  final ValueChanged<String> onChanged;
  final String initialValue;
  final VoidCallback?
  onLastNumberEntered; // Callback when last number is entered

  const LottoNumberInput({
    Key? key,
    required this.gameType,
    required this.numberOfCombinations,
    required this.minNumber,
    required this.maxNumber,
    required this.onChanged,
    this.initialValue = '',
    this.onLastNumberEntered,
  }) : super(key: key);

  @override
  State<LottoNumberInput> createState() => _LottoNumberInputState();
}

class _LottoNumberInputState extends State<LottoNumberInput> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  late List<int>
  _previousLengths; // Track previous text length for backspace detection
  late int _cellCount;
  late int _digitsPerCell;
  late int _maxValue;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // Calculate digits per cell based on max number
    // e.g., max_number=9 → 1 digit, max_number=99 → 2 digits, max_number=999 → 3 digits
    _cellCount = widget.numberOfCombinations;
    _maxValue = widget.maxNumber;
    _digitsPerCell = widget.maxNumber.toString().length;

    _controllers = List.generate(
      _cellCount,
      (index) => TextEditingController(
        text: widget.initialValue.length > index * _digitsPerCell
            ? widget.initialValue.substring(
                index * _digitsPerCell,
                (index + 1) * _digitsPerCell,
              )
            : '',
      ),
    );

    _focusNodes = List.generate(_cellCount, (index) => FocusNode());
    _previousLengths = List.filled(_cellCount, 0);

    // Add listeners to controllers
    for (int i = 0; i < _controllers.length; i++) {
      _previousLengths[i] = _controllers[i].text.length;
      _controllers[i].addListener(() => _onCellChanged(i));
    }
  }

  void _onCellChanged(int index) {
    String value = _controllers[index].text;
    int currentLength = value.length;
    int previousLength = _previousLengths[index];

    // Detect backspace (length decreased)
    if (currentLength < previousLength) {
      // If current cell becomes empty after backspace and we're not at first cell, move to previous cell
      if (currentLength == 0 && index > 0) {
        // Only delete from previous cell if it was already empty before
        if (previousLength == 0) {
          _controllers[index - 1].text = _controllers[index - 1].text.substring(
            0,
            _controllers[index - 1].text.length - 1,
          );
        }
        // Always focus to previous cell when current becomes/is empty
        Future.microtask(() {
          FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
        });
      }
      _previousLengths[index] = currentLength;
      _notifyChange();
      return;
    }

    // Validate max value for the current field
    if (value.isNotEmpty) {
      int intValue = int.tryParse(value) ?? 0;
      if (intValue > _maxValue) {
        _controllers[index].text = _maxValue.toString();
        return;
      }
    }

    // Auto-move to next cell when full, or trigger callback for last cell
    if (currentLength == _digitsPerCell) {
      if (index < _cellCount - 1) {
        FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      } else if (index == _cellCount - 1) {
        // Last cell is filled, trigger callback
        if (widget.onLastNumberEntered != null) {
          Future.microtask(() => widget.onLastNumberEntered!());
        }
      }
    }

    _previousLengths[index] = currentLength;
    _notifyChange();
  }

  void _notifyChange() {
    // Pad each field with leading zeros to match digitsPerCell
    String result = _controllers
        .map((c) => c.text.padLeft(_digitsPerCell, '0'))
        .join();
    widget.onChanged(result);
  }

  @override
  void didUpdateWidget(LottoNumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.numberOfCombinations != widget.numberOfCombinations ||
        oldWidget.maxNumber != widget.maxNumber) {
      for (var controller in _controllers) {
        controller.dispose();
      }
      for (var focusNode in _focusNodes) {
        focusNode.dispose();
      }
      _initializeControllers();
    } else if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue.isEmpty) {
      // Clear controllers if initialValue became empty
      for (var controller in _controllers) {
        controller.clear();
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _cellCount,
        (index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildCell(index),
        ),
      ),
    );
  }

  Widget _buildCell(int index) {
    return SizedBox(
      width: widget.gameType == '2D Lotto' ? 80 : 60,
      height: 80,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: _digitsPerCell,
        decoration: InputDecoration(
          counterText: '',
          hintText: widget.gameType == '2D Lotto' ? '--' : '-',
          hintStyle: TextStyle(
            color: Colors.grey[300],
            fontSize: widget.gameType == '2D Lotto' ? 18 : 24,
          ),
          contentPadding: const EdgeInsets.all(12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _controllers[index].text.isEmpty
                  ? Colors.grey[300]!
                  : const Color(0xFF2563EB),
              width: _controllers[index].text.isEmpty ? 1.5 : 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
          ),
        ),
        style: TextStyle(
          fontSize: widget.gameType == '2D Lotto' ? 24 : 32,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2563EB),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(_digitsPerCell),
        ],
      ),
    );
  }
}
