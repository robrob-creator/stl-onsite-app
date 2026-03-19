import 'package:flutter/material.dart';

class CustomPinInput extends StatefulWidget {
  final int length;
  final Function(String) onChanged;
  final VoidCallback? onComplete;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;

  const CustomPinInput({
    Key? key,
    this.length = 6,
    required this.onChanged,
    this.onComplete,
    this.controller,
    this.obscureText = true,
    this.keyboardType = TextInputType.number,
  }) : super(key: key);

  @override
  State<CustomPinInput> createState() => _CustomPinInputState();
}

class _CustomPinInputState extends State<CustomPinInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Hidden TextField for keyboard input
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          maxLength: widget.length,
          keyboardType: widget.keyboardType,
          obscureText: false,
          showCursor: false,
          style: const TextStyle(color: Colors.transparent),
          decoration: const InputDecoration(
            border: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            counterText: '',
          ),
          onChanged: (value) {
            widget.onChanged(value);
            // Call onComplete when PIN is fully entered
            if (value.length == widget.length && widget.onComplete != null) {
              widget.onComplete!();
            }
            setState(() {});
          },
        ),
        // Pin boxes UI
        GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
            FocusScope.of(context).requestFocus(_focusNode);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              widget.length,
              (index) => _buildPinBox(index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinBox(int index) {
    final isFilled = index < _controller.text.length;
    final isFocused = _focusNode.hasFocus && index == _controller.text.length;
    final text = isFilled
        ? (widget.obscureText ? '●' : _controller.text[index])
        : '';

    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        border: Border.all(
          color: isFocused
              ? const Color(0xFF2563EB)
              : (isFilled ? const Color(0xFF2563EB) : Colors.grey[300]!),
          width: isFocused ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isFilled ? Colors.blue[50] : Colors.grey[50],
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  String getPin() => _controller.text;

  void clearPin() {
    _controller.clear();
    setState(() {});
  }
}
