import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';

/// Bordered input with its label above and the error in a danger strip below.
class BrutalTextField extends StatefulWidget {
  const BrutalTextField({
    super.key,
    required this.label,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.autofocus = false,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? errorText;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool autofocus;
  final bool obscureText;
  final TextCapitalization textCapitalization;

  @override
  State<BrutalTextField> createState() => _BrutalTextFieldState();
}

class _BrutalTextFieldState extends State<BrutalTextField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2, color: c.ink),
        ),
        const SizedBox(height: BrutalMetrics.gapXs),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            // Focus is the heavy rule, not a colour change: visible to everyone.
            border: Border.all(color: c.line, width: _focus.hasFocus ? BrutalMetrics.borderHeavy : BrutalMetrics.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: BrutalMetrics.tap),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapM),
              child: Center(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  maxLength: widget.maxLength,
                  textCapitalization: widget.textCapitalization,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: c.ink,
                  cursorRadius: Radius.zero,
                  style: TextStyle(fontFamily: BrutalFonts.mono, fontSize: 18, color: c.ink),
                  decoration: InputDecoration.collapsed(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(fontFamily: BrutalFonts.mono, fontSize: 14, color: c.muted),
                  ).copyWith(counterText: ''),
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Container(
            color: c.danger,
            padding: const EdgeInsets.symmetric(horizontal: BrutalMetrics.gapS, vertical: BrutalMetrics.gapXs),
            child: Semantics(
              liveRegion: true,
              child: Text(
                widget.errorText!.toUpperCase(),
                style: TextStyle(fontFamily: BrutalFonts.mono, fontWeight: FontWeight.bold, fontSize: 12, color: c.onDanger),
              ),
            ),
          ),
      ],
    );
  }
}
