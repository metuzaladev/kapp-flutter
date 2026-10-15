import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/theme.dart';
import '../core/theme/tokens.dart';
import 'text.dart';

/// Figma component "Input": label above the value, 1 pt border, error text below.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.onChanged,
    this.error,
    this.placeholder,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.autocorrect = true,
    this.capitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.enabled = true,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final ValueChanged<String>? onChanged;

  /// Validation message shown under the field and announced by screen readers.
  final String? error;
  final String? placeholder;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final TextCapitalization capitalization;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  TextEditingController? _own;

  TextEditingController get _controller =>
      widget.controller ?? (_own ??= TextEditingController(text: widget.initialValue));

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_rebuild);
    if (widget.focusNode == null) _focus.dispose();
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final borderColor = widget.error != null ? c.danger : (_focus.hasFocus ? c.brand : c.border);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.three, vertical: 12),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.r16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: AppText(widget.label, type: TextType.caption, themeColor: TextColor.muted),
              ),
              const SizedBox(height: 2),
              Semantics(
                label: widget.label,
                hint: widget.error,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  onChanged: widget.onChanged,
                  obscureText: widget.obscure,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  onSubmitted: widget.onSubmitted,
                  autofillHints: widget.autofillHints,
                  autocorrect: widget.autocorrect && !widget.obscure,
                  enableSuggestions: widget.autocorrect && !widget.obscure,
                  textCapitalization: widget.capitalization,
                  maxLines: widget.obscure ? 1 : widget.maxLines,
                  minLines: widget.minLines,
                  maxLength: widget.maxLength,
                  inputFormatters: widget.inputFormatters,
                  cursorColor: c.brand,
                  style: textStyle(TextType.body, color: c.text),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    hintText: widget.placeholder,
                    hintStyle: textStyle(TextType.body, color: c.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: Spacing.one),
          Semantics(
            liveRegion: true,
            child: AppText(widget.error!, type: TextType.caption, themeColor: TextColor.danger),
          ),
        ],
      ],
    );
  }
}
