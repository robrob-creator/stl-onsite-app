import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/spacing.dart';
import '../layout/layout.dart';

/// Custom text input field
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? initialValue;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final Widget? prefix;
  final Widget? suffix;
  final Color borderColor;
  final Color focusedBorderColor;
  final Color errorBorderColor;
  final double borderRadius;
  final EdgeInsets contentPadding;
  final TextStyle? textStyle;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final bool showCounter;
  final bool isDense;

  const AppTextField({
    Key? key,
    this.controller,
    required this.label,
    this.hint,
    this.initialValue,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.prefix,
    this.suffix,
    this.borderColor = AppColors.border,
    this.focusedBorderColor = AppColors.primary,
    this.errorBorderColor = AppColors.error,
    this.borderRadius = 8,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    this.textStyle,
    this.labelStyle,
    this.hintStyle,
    this.inputFormatters,
    this.errorText,
    this.showCounter = false,
    this.isDense = false,
  }) : super(key: key);

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ??
        TextEditingController(text: widget.initialValue ?? '');
    _focusNode = FocusNode();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              widget.label,
              style:
                  widget.labelStyle ??
                  AppTextStyles.labelMedium.copyWith(color: AppColors.text),
            ),
          ),
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          obscureText: widget.obscureText && !_showPassword,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          inputFormatters: widget.inputFormatters,
          style: widget.textStyle ?? AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle:
                widget.hintStyle ??
                AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
            errorText: widget.errorText,
            prefixIcon:
                widget.prefix ??
                (widget.prefixIcon != null
                    ? Icon(widget.prefixIcon, color: AppColors.textSecondary)
                    : null),
            suffixIcon: widget.suffixIcon != null || widget.suffix != null
                ? GestureDetector(
                    onTap: widget.onSuffixIconPressed,
                    child:
                        widget.suffix ??
                        Icon(widget.suffixIcon, color: AppColors.textSecondary),
                  )
                : widget.obscureText
                ? GestureDetector(
                    onTap: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                    child: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textSecondary,
                    ),
                  )
                : null,
            counterText: widget.showCounter ? null : '',
            isDense: widget.isDense,
            filled: true,
            fillColor: widget.enabled
                ? AppColors.backgroundSecondary
                : AppColors.disabledBackground,
            contentPadding: widget.contentPadding,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: BorderSide(color: widget.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: BorderSide(color: widget.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: BorderSide(
                color: widget.focusedBorderColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: BorderSide(color: widget.errorBorderColor),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: BorderSide(color: widget.errorBorderColor, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              borderSide: BorderSide(color: AppColors.disabled),
            ),
          ),
        ),
      ],
    );
  }
}

/// Numeric input field with restrictions
class NumericInputField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final int maxDigits;
  final int maxValue;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;

  const NumericInputField({
    Key? key,
    this.controller,
    required this.label,
    this.hint,
    required this.maxDigits,
    required this.maxValue,
    this.onChanged,
    this.validator,
  }) : super(key: key);

  @override
  State<NumericInputField> createState() => _NumericInputFieldState();
}

class _NumericInputFieldState extends State<NumericInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      label: widget.label,
      hint: widget.hint,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(widget.maxDigits),
      ],
      validator:
          widget.validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return '${widget.label} is required';
            }
            if (int.parse(value) > widget.maxValue) {
              return 'Value must not exceed ${widget.maxValue}';
            }
            return null;
          },
      onChanged: widget.onChanged,
    );
  }
}

/// Password input field with show/hide toggle
class PasswordTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;

  const PasswordTextField({
    Key? key,
    this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.onChanged,
  }) : super(key: key);

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  late TextEditingController _controller;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      label: widget.label,
      hint: widget.hint ?? 'Enter your password',
      obscureText: true,
      validator: widget.validator,
      onChanged: widget.onChanged,
    );
  }
}

/// Search field with clear button
class SearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hint;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final VoidCallback? onClear;

  const SearchField({
    Key? key,
    this.controller,
    this.hint = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  }) : super(key: key);

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_updateUI);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _updateUI() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _controller,
      label: '',
      hint: widget.hint,
      prefixIcon: Icons.search,
      suffixIcon: _controller.text.isNotEmpty ? Icons.close : null,
      onSuffixIconPressed: _controller.text.isNotEmpty
          ? () {
              _controller.clear();
              widget.onClear?.call();
            }
          : null,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}
