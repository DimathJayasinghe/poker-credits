import 'package:flutter/material.dart';
import 'package:poker_credits/theme/brutal_theme.dart';
import 'package:poker_credits/theme/tokens.dart';
import 'package:poker_credits/util/strings.dart';
import 'package:poker_credits/widget/brutal/brutal_number.dart';
import 'package:poker_credits/widget/brutal/brutal_button.dart';
import 'package:poker_credits/widget/brutal/brutal_keypad.dart';

/// Asks the host for more chips: type an amount on the keypad. The host approves or ignores it;
/// the server enforces any limits.
class RebuySheet extends StatefulWidget {
  const RebuySheet({super.key, required this.onAsk, this.suggestion});

  final ValueChanged<int> onAsk;

  /// Pre-filled amount (the starting stack), if known.
  final int? suggestion;

  @override
  State<RebuySheet> createState() => _RebuySheetState();
}

class _RebuySheetState extends State<RebuySheet> {
  late String _digits = widget.suggestion?.toString() ?? '';

  static const int _maxDigits = 9;

  @override
  Widget build(BuildContext context) {
    final c = BrutalTheme.of(context).colors;
    final amount = int.tryParse(_digits) ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: BrutalMetrics.gapS),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.line, width: BrutalMetrics.border),
          ),
          child: BrutalNumber(int.tryParse(_digits) ?? 0, size: 40, color: c.ink),
        ),
        const SizedBox(height: BrutalMetrics.gapS),
        BrutalKeypad(
          onDigit: (d) => setState(() {
            if (_digits.length < _maxDigits && !(_digits.isEmpty && d == 0)) _digits += '$d';
          }),
          onBackspace: () => setState(() => _digits = _digits.isEmpty ? '' : _digits.substring(0, _digits.length - 1)),
          onClear: () => setState(() => _digits = ''),
        ),
        const SizedBox(height: BrutalMetrics.gapM),
        BrutalButton(
          label: Strings.topUpAsk,
          kind: BrutalButtonKind.primary,
          heavy: true,
          minHeight: BrutalMetrics.tapPlayer,
          onPressed: amount > 0 ? () => widget.onAsk(amount) : null,
        ),
      ],
    );
  }
}
